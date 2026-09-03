import 'package:flutter_test/flutter_test.dart';
import 'package:marketplus_mobile/data/models.dart';

void main() {
  test('invoice API id is exposed as a short display number', () {
    final invoice = Invoice.fromJson({
      'id': 42,
      'invoiceNumber': 'INV-20260903-1234567890ABCDEF1234567890ABCDEF',
      'totalAmount': 100,
      'subtotalAmount': 100,
      'taxRate': 0,
      'taxAmount': 0,
      'paidAmount': 100,
      'remainingAmount': 0,
      'paymentType': 1,
      'status': 2,
      'createdAt': '2026-09-03T10:00:00Z',
      'items': const [],
      'payments': const [],
    });

    expect(invoice.number, 'INV-42');
  });

  test('invalid or missing id keeps the server reference as fallback', () {
    expect(compactInvoiceNumber(0, '  LEGACY-9  '), 'LEGACY-9');
  });
}
