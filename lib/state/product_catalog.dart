import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models.dart';
import '../data/repositories.dart';

class ProductCatalog extends ChangeNotifier {
  ProductCatalog(this.repository, this.preferences);

  static const _cacheKey = 'zimmati.products.cache.v1';
  static const _cacheTimeKey = 'zimmati.products.cache.updatedAt.v1';

  final ProductSource repository;
  final SharedPreferences preferences;

  final Map<String, Product> _byBarcode = <String, Product>{};
  final Map<int, Product> _byId = <int, Product>{};
  List<Product> _products = const [];
  Future<void>? _syncFuture;

  bool syncing = false;
  String? syncError;
  DateTime? lastSyncedAt;

  List<Product> get products => List.unmodifiable(_products);
  int get count => _products.length;
  bool get hasLocalData => _products.isNotEmpty;

  String normalizeBarcode(String raw) => raw.trim().replaceAll(RegExp(r'\s+'), '');

  Product? findByBarcode(String rawBarcode) => _byBarcode[normalizeBarcode(rawBarcode)];
  Product? findById(int id) => _byId[id];

  Future<void> hydrate() async {
    final cached = preferences.getString(_cacheKey);
    final lastSyncRaw = preferences.getString(_cacheTimeKey);
    if (lastSyncRaw != null) lastSyncedAt = DateTime.tryParse(lastSyncRaw);
    if (cached == null || cached.isEmpty) return;

    try {
      final decoded = jsonDecode(cached);
      if (decoded is! List) return;
      final products = decoded
          .whereType<Map>()
          .map((item) => Product.fromJson(Map<String, dynamic>.from(item)))
          .where((product) => product.id > 0 && product.barcode.isNotEmpty)
          .toList(growable: false);
      _replace(products, notify: false);
    } catch (e) {
      debugPrint('[Catalog] Failed to hydrate cache: $e');
    }
  }

  Future<void> synchronize({bool force = false}) {
    final existing = _syncFuture;
    if (existing != null) return existing;
    final future = _synchronizeInternal();
    _syncFuture = future;
    return future.whenComplete(() => _syncFuture = null);
  }

  Future<void> _synchronizeInternal() async {
    syncing = true;
    syncError = null;
    notifyListeners();
    try {
      final remote = await repository.all();
      _replace(remote);
      lastSyncedAt = DateTime.now();
      await preferences.setString(_cacheKey, jsonEncode(remote.map((product) => product.toJson()).toList()));
      await preferences.setString(_cacheTimeKey, lastSyncedAt!.toIso8601String());
    } catch (e) {
      syncError = e.toString();
      rethrow;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<Product> resolveBarcode(String rawBarcode) async {
    final barcode = normalizeBarcode(rawBarcode);
    final local = _byBarcode[barcode];
    if (local != null) return local;

    final remote = await repository.byBarcode(barcode);
    _upsert(remote);
    unawaited(_persist());
    return remote;
  }

  void applySale(List<CartLine> soldLines) {
    if (soldLines.isEmpty) return;
    for (final line in soldLines) {
      final current = _byId[line.product.id];
      if (current == null) continue;
      final nextStock = (current.stockQuantity - line.quantity).clamp(0, current.stockQuantity).toInt();
      _upsert(current.copyWith(stockQuantity: nextStock), notify: false);
    }
    _products = _byId.values.toList(growable: false)..sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
    unawaited(_persist());
  }

  void _replace(List<Product> products, {bool notify = true}) {
    _byBarcode.clear();
    _byId.clear();
    for (final product in products) {
      final barcode = normalizeBarcode(product.barcode);
      if (product.id <= 0 || barcode.isEmpty) continue;
      _byBarcode[barcode] = product;
      _byId[product.id] = product;
    }
    _products = _byId.values.toList(growable: false)..sort((a, b) => a.name.compareTo(b.name));
    if (notify) notifyListeners();
  }

  void _upsert(Product product, {bool notify = true}) {
    final old = _byId[product.id];
    if (old != null && old.barcode != product.barcode) {
      _byBarcode.remove(normalizeBarcode(old.barcode));
    }
    _byId[product.id] = product;
    _byBarcode[normalizeBarcode(product.barcode)] = product;
    final index = _products.indexWhere((item) => item.id == product.id);
    if (index >= 0) {
      final mutable = List<Product>.of(_products);
      mutable[index] = product;
      _products = mutable;
    } else {
      _products = [..._products, product]..sort((a, b) => a.name.compareTo(b.name));
    }
    if (notify) notifyListeners();
  }

  Future<void> _persist() async {
    await preferences.setString(_cacheKey, jsonEncode(_products.map((product) => product.toJson()).toList()));
    if (lastSyncedAt != null) await preferences.setString(_cacheTimeKey, lastSyncedAt!.toIso8601String());
  }
}
