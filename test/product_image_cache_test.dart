import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marketplus_mobile/core/product_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('downloads a product image once and reuses the disk cache', () async {
    final temp = await Directory.systemTemp.createTemp('marketplus-image-cache-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
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

    server.listen((request) async {
      requests++;
      request.response.headers.contentType = ContentType('image', 'png');
      request.response.add(imageBytes);
      await request.response.close();
    });

    final cache = ProductImageCache(
      cacheDirectoryProvider: () async => temp,
      maxConcurrentDownloads: 2,
    );

    try {
      final url =
          'http://${server.address.address}:${server.port}/images/products/item.png';

      final concurrent = await Future.wait([
        cache.getFile(url),
        cache.getFile(url),
        cache.getFile(url),
      ]);

      expect(requests, 1);
      expect(concurrent.every((file) => file != null), isTrue);
      expect(await concurrent.first!.readAsBytes(), imageBytes);

      final fromDisk = await cache.getFile(url);
      expect(fromDisk, isNotNull);
      expect(requests, 1, reason: 'a cached image must not consume the network again');
      expect(await fromDisk!.readAsBytes(), imageBytes);
    } finally {
      cache.dispose();
      await server.close(force: true);
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
    expect(resolveProductImageUrl('   '), isNull);
  });
}
