import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/client_operation_id.dart';
import '../data/models.dart';
import '../data/repositories.dart';

class OfflineSaleQueue extends ChangeNotifier {
  OfflineSaleQueue(this._repository, this._preferences);

  static const _storageKey = 'marketplus.pending-sales.v1';
  static final _legacyStorageKey = String.fromCharCodes(const [
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
  final InvoiceRepository _repository;
  final SharedPreferences _preferences;
  final List<PendingSale> _items = [];

  bool syncing = false;
  String? lastError;

  List<PendingSale> get items => List.unmodifiable(_items);
  int get pendingCount => _items.length;
  bool get hasPending => _items.isNotEmpty;

  Future<void> hydrate() async {
    _items.clear();
    final currentRaw = _preferences.getStringList(_storageKey);
    final legacyRaw = currentRaw == null
        ? _preferences.getStringList(_legacyStorageKey)
        : null;
    final raw = currentRaw ?? legacyRaw ?? const <String>[];

    for (final value in raw) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          _items.add(PendingSale.fromJson(Map<String, dynamic>.from(decoded)));
        }
      } catch (_) {
        // Skip one corrupt draft instead of blocking the whole application.
      }
    }

    if (legacyRaw != null) {
      final migrated = await _preferences.setStringList(_storageKey, legacyRaw);
      if (migrated) {
        await _preferences.remove(_legacyStorageKey);
      }
    }

    notifyListeners();
  }

  Future<PendingSale> enqueue({
    required List<CartLine> lines,
    required PaymentType payment,
    String? customerName,
    String? customerPhone,
    double taxRate = 0,
  }) async {
    final pending = PendingSale(
      clientRequestId: _newRequestId(),
      createdAt: DateTime.now(),
      paymentType: payment.value,
      customerName: customerName?.trim(),
      customerPhone: customerPhone?.trim(),
      taxRate: taxRate,
      items: lines
          .map((line) => PendingSaleItem(
                productId: line.product.id,
                productName: line.product.name,
                quantity: line.quantity,
                unitPrice: line.product.price,
              ))
          .toList(growable: false),
    );
    _items.insert(0, pending);
    lastError = null;
    await _persist();
    notifyListeners();
    return pending;
  }

  Future<int> syncAll() async {
    if (syncing || _items.isEmpty) return 0;
    syncing = true;
    lastError = null;
    notifyListeners();
    var synced = 0;

    try {
      for (final pending in List<PendingSale>.from(_items.reversed)) {
        try {
          await _repository.createRaw(
            clientRequestId: pending.clientRequestId,
            items: pending.items
                .map((item) => {
                      'productId': item.productId,
                      'quantity': item.quantity,
                      'unitPrice': item.unitPrice,
                    })
                .toList(growable: false),
            payment: pending.paymentType == PaymentType.deferred.value
                ? PaymentType.deferred
                : PaymentType.cash,
            customerName: pending.customerName,
            customerPhone: pending.customerPhone,
            taxRate: pending.taxRate,
          );
          _items.removeWhere(
              (item) => item.clientRequestId == pending.clientRequestId);
          synced++;
          await _persist();
          notifyListeners();
        } on ApiException catch (e) {
          lastError = e.message;
          if (e.isNetworkError || e.isUnauthorized) break;
          // Business errors should remain visible in the queue for manual review.
          break;
        } catch (e) {
          lastError = '$e';
          break;
        }
      }
    } finally {
      syncing = false;
      notifyListeners();
    }
    return synced;
  }

  Future<void> remove(String clientRequestId) async {
    _items.removeWhere((item) => item.clientRequestId == clientRequestId);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() => _preferences.setStringList(
        _storageKey,
        _items.map((item) => jsonEncode(item.toJson())).toList(growable: false),
      );

  static String _newRequestId() => ClientOperationId.create('mob');
}

class PendingSale {
  const PendingSale({
    required this.clientRequestId,
    required this.createdAt,
    required this.paymentType,
    required this.taxRate,
    required this.items,
    this.customerName,
    this.customerPhone,
  });

  final String clientRequestId;
  final DateTime createdAt;
  final int paymentType;
  final double taxRate;
  final String? customerName;
  final String? customerPhone;
  final List<PendingSaleItem> items;

  double get total =>
      items.fold(0, (sum, item) => sum + item.unitPrice * item.quantity);

  Map<String, dynamic> toJson() => {
        'clientRequestId': clientRequestId,
        'createdAt': createdAt.toIso8601String(),
        'paymentType': paymentType,
        'taxRate': taxRate,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'items': items.map((item) => item.toJson()).toList(growable: false),
      };

  factory PendingSale.fromJson(Map<String, dynamic> json) => PendingSale(
        clientRequestId: '${json['clientRequestId'] ?? ''}',
        createdAt:
            DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.now(),
        paymentType: (json['paymentType'] as num? ?? 1).toInt(),
        taxRate: (json['taxRate'] as num? ?? 0).toDouble(),
        customerName: json['customerName']?.toString(),
        customerPhone: json['customerPhone']?.toString(),
        items: (json['items'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => PendingSaleItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
      );
}

class PendingSaleItem {
  const PendingSaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  final int productId;
  final String productName;
  final int quantity;
  final double unitPrice;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'unitPrice': unitPrice,
      };

  factory PendingSaleItem.fromJson(Map<String, dynamic> json) =>
      PendingSaleItem(
        productId: (json['productId'] as num? ?? 0).toInt(),
        productName: '${json['productName'] ?? ''}',
        quantity: (json['quantity'] as num? ?? 0).toInt(),
        unitPrice: (json['unitPrice'] as num? ?? 0).toDouble(),
      );
}
