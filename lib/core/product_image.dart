import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app_theme.dart';

typedef ProductImageCacheDirectoryProvider = Future<Directory> Function();

enum ProductImageProfile { thumbnail, detail }

/// Loads product images through a bounded, persistent on-device cache.
///
/// Product image URLs are immutable in MarketPlus because the API writes a new
/// GUID file name whenever an image is replaced. That makes URL-keyed caching
/// safe while avoiding repeated downloads on weak or metered connections.
class ProductImageCache {
  ProductImageCache({
    ProductImageCacheDirectoryProvider? cacheDirectoryProvider,
    HttpClient? httpClient,
    this.maxConcurrentDownloads = 2,
    this.maxFileBytes = 6 * 1024 * 1024,
    this.maxCacheBytes = 160 * 1024 * 1024,
    this.maxCacheEntries = 500,
  })  : _cacheDirectoryProvider =
            cacheDirectoryProvider ?? _defaultCacheDirectory,
        _httpClient = httpClient ?? HttpClient() {
    if (maxConcurrentDownloads < 1) {
      throw ArgumentError.value(
        maxConcurrentDownloads,
        'maxConcurrentDownloads',
        'must be at least 1',
      );
    }
    _httpClient.connectionTimeout = const Duration(seconds: 5);
    _httpClient.idleTimeout = const Duration(seconds: 15);
  }

  static final ProductImageCache instance = ProductImageCache();

  final ProductImageCacheDirectoryProvider _cacheDirectoryProvider;
  final HttpClient _httpClient;
  final int maxConcurrentDownloads;
  final int maxFileBytes;
  final int maxCacheBytes;
  final int maxCacheEntries;

  final Map<String, Future<File?>> _inFlight = <String, Future<File?>>{};
  final Queue<Completer<void>> _downloadWaiters = Queue<Completer<void>>();
  int _activeDownloads = 0;
  Future<Directory>? _directoryFuture;
  bool _cleanupRunning = false;

  Future<File?> getFile(String url) {
    final normalized = url.trim();
    if (normalized.isEmpty) return Future<File?>.value(null);

    final existing = _inFlight[normalized];
    if (existing != null) return existing;

    late final Future<File?> future;
    future = _getFileInternal(normalized).whenComplete(() {
      if (identical(_inFlight[normalized], future)) {
        _inFlight.remove(normalized);
      }
    });
    _inFlight[normalized] = future;
    return future;
  }

  Future<void> evict(String url) async {
    final directory = await _directory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}${cacheFileNameForUrl(url)}',
    );
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {
        // Cache eviction must never break the product screen.
      }
    }
  }

  Future<File?> _getFileInternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }

    final directory = await _directory();
    final target = File(
      '${directory.path}${Platform.pathSeparator}${cacheFileNameForUrl(url)}',
    );

    if (await target.exists()) {
      try {
        final length = await target.length();
        if (length > 0 && length <= maxFileBytes) {
          await target.setLastModified(DateTime.now());
          unawaited(_trimCache(directory, protectedPath: target.path));
          return target;
        }
        await target.delete();
      } catch (_) {
        // A stale/corrupt cache file falls through to a network refresh.
      }
    }

    try {
      final downloaded = await _withDownloadPermit(
        () => _download(uri, target),
      );
      unawaited(_trimCache(directory, protectedPath: downloaded.path));
      return downloaded;
    } catch (_) {
      return null;
    }
  }

  Future<File> _download(Uri uri, File target) async {
    final request = await _httpClient.getUrl(uri).timeout(
          const Duration(seconds: 6),
        );
    request.headers.set(
      HttpHeaders.acceptHeader,
      'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
    );

    final response = await request.close().timeout(
          const Duration(seconds: 8),
        );
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Unexpected product image status ${response.statusCode}',
        uri: uri,
      );
    }

    final declaredLength = response.contentLength;
    if (declaredLength > maxFileBytes) {
      throw const HttpException('Product image exceeds cache size limit');
    }

    final mimeType = response.headers.contentType?.mimeType;
    if (mimeType != null && !mimeType.toLowerCase().startsWith('image/')) {
      throw const HttpException('Product image response is not an image');
    }

    final temp = File(
      '${target.path}.part-${DateTime.now().microsecondsSinceEpoch}',
    );
    IOSink? sink;
    try {
      sink = temp.openWrite(mode: FileMode.writeOnly);
      var received = 0;
      await for (final chunk in response.timeout(const Duration(seconds: 12))) {
        received += chunk.length;
        if (received > maxFileBytes) {
          throw const HttpException('Product image exceeds cache size limit');
        }
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (received == 0) {
        throw const HttpException('Product image response is empty');
      }

      if (await target.exists()) {
        await temp.delete();
        return target;
      }

      return await temp.rename(target.path);
    } catch (_) {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      if (await temp.exists()) {
        try {
          await temp.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<T> _withDownloadPermit<T>(Future<T> Function() action) async {
    if (_activeDownloads >= maxConcurrentDownloads) {
      final waiter = Completer<void>();
      _downloadWaiters.add(waiter);
      await waiter.future;
    }

    _activeDownloads++;
    try {
      return await action();
    } finally {
      _activeDownloads--;
      if (_downloadWaiters.isNotEmpty) {
        _downloadWaiters.removeFirst().complete();
      }
    }
  }

  Future<Directory> _directory() =>
      _directoryFuture ??= _prepareDirectory();

  Future<Directory> _prepareDirectory() async {
    final root = await _cacheDirectoryProvider();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}marketplus_product_images_v1',
    );
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<void> _trimCache(
    Directory directory, {
    required String protectedPath,
  }) async {
    if (_cleanupRunning) return;
    _cleanupRunning = true;
    try {
      final entries = <_CacheEntry>[];
      var totalBytes = 0;

      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File || entity.path.contains('.part-')) continue;
        try {
          final stat = await entity.stat();
          totalBytes += stat.size;
          entries.add(
            _CacheEntry(
              file: entity,
              size: stat.size,
              modified: stat.modified,
            ),
          );
        } catch (_) {}
      }

      if (entries.length <= maxCacheEntries && totalBytes <= maxCacheBytes) {
        return;
      }

      entries.sort((a, b) => a.modified.compareTo(b.modified));
      var remainingEntries = entries.length;
      for (final entry in entries) {
        if (remainingEntries <= maxCacheEntries && totalBytes <= maxCacheBytes) {
          break;
        }
        if (entry.file.path == protectedPath) continue;
        try {
          await entry.file.delete();
          remainingEntries--;
          totalBytes -= entry.size;
        } catch (_) {}
      }
    } finally {
      _cleanupRunning = false;
    }
  }

  void dispose() {
    _httpClient.close(force: true);
  }

  static Future<Directory> _defaultCacheDirectory() => getTemporaryDirectory();
}

class ProductImage extends StatefulWidget {
  const ProductImage({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.radius = 12,
    this.profile = ProductImageProfile.thumbnail,
    this.iconSize = 28,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.inventory_2_outlined,
  });

  final String? imageUrl;
  final double width;
  final double height;
  final double radius;
  final ProductImageProfile profile;
  final double iconSize;
  final BoxFit fit;
  final IconData fallbackIcon;

  @override
  State<ProductImage> createState() => _ProductImageState();
}

class _ProductImageState extends State<ProductImage> {
  String? _resolvedUrl;
  Future<File?>? _fileFuture;
  ScrollPosition? _scrollPosition;
  bool _retriedCorruptFile = false;
  bool _visibilityCheckScheduled = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextPosition = Scrollable.maybeOf(context)?.position;
    if (!identical(nextPosition, _scrollPosition)) {
      _scrollPosition?.isScrollingNotifier.removeListener(_onScrollActivity);
      _scrollPosition = nextPosition;
      _scrollPosition?.isScrollingNotifier.addListener(_onScrollActivity);
    }
    _scheduleVisibilityCheck();
  }

  @override
  void didUpdateWidget(covariant ProductImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) _reload();
  }

  @override
  void dispose() {
    _scrollPosition?.isScrollingNotifier.removeListener(_onScrollActivity);
    super.dispose();
  }

  void _reload() {
    _resolvedUrl = resolveProductImageUrl(widget.imageUrl);
    _retriedCorruptFile = false;
    _fileFuture = null;
    _scheduleVisibilityCheck();
  }

  void _onScrollActivity() {
    if (!(_scrollPosition?.isScrollingNotifier.value ?? false)) {
      _scheduleVisibilityCheck();
    }
  }

  void _scheduleVisibilityCheck() {
    if (_visibilityCheckScheduled || _fileFuture != null || _resolvedUrl == null) {
      return;
    }
    _visibilityCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityCheckScheduled = false;
      if (mounted) _loadWhenNearViewport();
    });
  }

  void _loadWhenNearViewport() {
    final url = _resolvedUrl;
    if (url == null || _fileFuture != null) return;

    if (_scrollPosition == null) {
      _startLoad(url);
      return;
    }

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return;

    final top = renderObject.localToGlobal(Offset.zero).dy;
    final bottom = top + renderObject.size.height;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final prefetchMargin = screenHeight * .35;

    if (bottom >= -prefetchMargin && top <= screenHeight + prefetchMargin) {
      _startLoad(url);
    }
  }

  void _startLoad(String url) {
    if (!mounted || _fileFuture != null) return;
    setState(() {
      _fileFuture = ProductImageCache.instance.getFile(url);
    });
  }

  Widget _fallback() => Container(
        width: widget.width,
        height: widget.height,
        color: ZColors.surfaceContainer,
        alignment: Alignment.center,
        child: Icon(
          widget.fallbackIcon,
          size: widget.iconSize,
          color: ZColors.greenMid,
        ),
      );

  void _recoverCorruptFile() {
    final url = _resolvedUrl;
    if (url == null || _retriedCorruptFile) return;
    _retriedCorruptFile = true;
    unawaited(() async {
      await ProductImageCache.instance.evict(url);
      if (!mounted) return;
      setState(() {
        _fileFuture = ProductImageCache.instance.getFile(url);
      });
    }());
  }

  @override
  Widget build(BuildContext context) {
    final future = _fileFuture;
    final fallback = _fallback();

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: future == null
          ? fallback
          : FutureBuilder<File?>(
              future: future,
              builder: (context, snapshot) {
                final file = snapshot.data;
                if (file == null) return fallback;

                final logicalWidth = widget.width.isFinite
                    ? widget.width
                    : MediaQuery.sizeOf(context).width;
                final dpr = MediaQuery.devicePixelRatioOf(context);
                final requestedPixels = (logicalWidth * dpr).round();
                final cacheWidth = widget.profile == ProductImageProfile.thumbnail
                    ? requestedPixels.clamp(96, 384).toInt()
                    : requestedPixels.clamp(320, 1440).toInt();

                return Image.file(
                  file,
                  width: widget.width,
                  height: widget.height,
                  fit: widget.fit,
                  cacheWidth: cacheWidth,
                  gaplessPlayback: true,
                  filterQuality: widget.profile == ProductImageProfile.thumbnail
                      ? FilterQuality.low
                      : FilterQuality.medium,
                  errorBuilder: (_, __, ___) {
                    _recoverCorruptFile();
                    return fallback;
                  },
                );
              },
            ),
    );
  }
}

String? resolveProductImageUrl(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;

  final parsed = Uri.tryParse(value);
  if (parsed != null && (parsed.scheme == 'http' || parsed.scheme == 'https')) {
    return value;
  }

  const base = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );
  final baseUri = Uri.tryParse(base);
  if (baseUri == null || !baseUri.hasScheme) return null;

  try {
    return baseUri.resolve(value).toString();
  } catch (_) {
    return null;
  }
}

String cacheFileNameForUrl(String url) {
  var hash = 0xcbf29ce484222325;
  const mask64 = 0xFFFFFFFFFFFFFFFF;
  for (final byte in utf8.encode(url)) {
    hash ^= byte;
    hash = (hash * 0x100000001b3) & mask64;
  }

  final uri = Uri.tryParse(url);
  final lastSegment = uri == null || uri.pathSegments.isEmpty
      ? ''
      : uri.pathSegments.last.toLowerCase();
  final dot = lastSegment.lastIndexOf('.');
  final extension = dot < 0 ? '' : lastSegment.substring(dot + 1);
  final safeExtension = const {'png', 'jpg', 'jpeg', 'webp'}.contains(extension)
      ? '.$extension'
      : '.img';

  return '${hash.toRadixString(16).padLeft(16, '0')}$safeExtension';
}

class _CacheEntry {
  const _CacheEntry({
    required this.file,
    required this.size,
    required this.modified,
  });

  final File file;
  final int size;
  final DateTime modified;
}
