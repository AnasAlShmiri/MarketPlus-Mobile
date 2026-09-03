import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/core/api_client.dart';
import '../lib/data/repositories.dart';
import '../lib/state/offline_sale_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('migrates pending sales from the pre-rebrand storage key', () async {
    final legacyKey = String.fromCharCodes(const [
      122,
      105,
      109,
      109,
      97,
      116,
      105,
      46,
      112,
      101,
      110,
      100,
      105,
      110,
      103,
      45,
      115,
      97,
      108,
      101,
      115,
      46,
      118,
      49,
    ]);
    final pendingSale = jsonEncode({
      'clientRequestId': 'mob-11111111-1111-4111-8111-111111111111',
      'createdAt': '2026-09-03T12:00:00.000Z',
      'paymentType': 2,
      'taxRate': 0,
      'customerName': 'عميل اختبار',
      'customerPhone': '771234567',
      'items': [
        {
          'productId': 17,
          'productName': 'منتج اختبار',
          'quantity': 2,
          'unitPrice': 1500.0,
        },
      ],
    });

    SharedPreferences.setMockInitialValues({
      legacyKey: <String>[pendingSale],
    });
    final preferences = await SharedPreferences.getInstance();
    final queue = OfflineSaleQueue(
      InvoiceRepository(_UnusedApiClient()),
      preferences,
    );

    await queue.hydrate();

    expect(queue.pendingCount, 1);
    expect(queue.items.single.clientRequestId,
        'mob-11111111-1111-4111-8111-111111111111');
    expect(queue.items.single.total, 3000.0);
    expect(
      preferences.getStringList('marketplus.pending-sales.v1'),
      <String>[pendingSale],
    );
    expect(preferences.getStringList(legacyKey), isNull);
  });
}

class _UnusedApiClient implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Network access is not used by this test.');
}
