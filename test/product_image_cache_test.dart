import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marketplus_mobile/core/product_image.dart';

void main() {
  test('downloads a product image once and reuses the disk cache', () async {
    final temp = await Directory.systemTemp.createTemp('marketplus-image-cache-');
    var downloads = 0;
    final imageBytes = <int>[
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      1,
      2,
      3,
      4,
    ];

    final cache = ProductImageCache(
      cacheDirectoryProvider: () async => temp,
      downloadOverride: (uri, target, maxFileBytes) async {
        downloads++;
        await target.writeAsBytes(imageBytes, flush: true);
        return target;
      },
      maxConcurrentDownloads: 2,
    );

    try {
      const url = 'https://example.test/images/products/item.png';

      final concurrent = await Future.wait([
        cache.getFile(url),
        cache.getFile(url),
        cache.getFile(url),
      ]);

      expect(downloads, 1);
      expect(concurrent.every((file) => file != null), isTrue);
      expect(await concurrent.first!.readAsBytes(), imageBytes);

      final fromDisk = await cache.getFile(url);
      expect(fromDisk, isNotNull);
      expect(
        downloads,
        1,
        reason: 'a cached image must not consume the network again',
      );
      expect(await fromDisk!.readAsBytes(), imageBytes);
    } finally {
      cache.dispose();
      if (await temp.exists()) await temp.delete(recursive: true);
    }
  });

  test('limits simultaneous product image downloads', () async {
    final temp = await Directory.systemTemp.createTemp('marketplus-image-limit-');
    var active = 0;
    var maxActive = 0;

    final cache = ProductImageCache(
      cacheDirectoryProvider: () async => temp,
      maxConcurrentDownloads: 2,
      downloadOverride: (uri, target, maxFileBytes) async {
        active++;
        if (active > maxActive) maxActive = active;
        try {
          await Future<void>.delayed(const Duration(milliseconds: 35));
          await target.writeAsBytes(const [1, 2, 3, 4], flush: true);
          return target;
        } finally {
          active--;
        }
      },
    );

    try {
      await Future.wait([
        for (var index = 0; index < 6; index++)
          cache.getFile('https://example.test/images/products/$index.jpg'),
      ]);

      expect(maxActive, 2);
    } finally {
      cache.dispose();
      if (await temp.exists()) await temp.delete(recursive: true);
    }
  });

  test('cache filenames are deterministic and do not expose the source URL', () {
    const url = 'https://example.test/images/products/private-item.webp';
    final first = cacheFileNameForUrl(url);
    final second = cacheFileNameForUrl(url);

    expect(first, second);
    expect(first, endsWith('.webp'));
    expect(first, isNot(contains('example.test')));
    expect(first, isNot(contains('private-item')));
  });

  test('absolute product image URL is preserved and unsupported schemes fail closed', () {
    expect(
      resolveProductImageUrl('https://cdn.example.test/item.jpg'),
      'https://cdn.example.test/item.jpg',
    );
    expect(resolveProductImageUrl('ftp://example.test/item.jpg'), isNull);
    expect(resolveProductImageUrl('file:///tmp/item.jpg'), isNull);
    expect(resolveProductImageUrl('   '), isNull);
  });
}
