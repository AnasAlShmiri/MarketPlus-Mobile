import 'package:flutter/foundation.dart';
import '../data/models.dart';
import '../data/repositories.dart';
import 'product_catalog.dart';

class AppSession extends ChangeNotifier {
  AppSession(this.auth, this.catalog);

  final AuthRepository auth;
  final ProductCatalog catalog;

  UserSession? user;
  final List<CartLine> cart = [];
  bool busy = false;
  String? error;
  String? catalogWarning;

  bool get authenticated => user != null;
  int get cartCount => cart.fold(0, (sum, line) => sum + line.quantity);
  double get cartSubtotal => cart.fold(0, (sum, line) => sum + line.total);

  Future<void> restoreSession() async {
    try {
      user = await auth.restore();
    } catch (e) {
      debugPrint('[Session] restore failed: $e');
      user = null;
    }
    notifyListeners();

    if (authenticated) {
      await _prewarmCatalog();
    }
  }

  Future<bool> login(String email, String password) async {
    busy = true;
    error = null;
    catalogWarning = null;
    notifyListeners();
    try {
      user = await auth.login(email, password);
      notifyListeners();
      await _prewarmCatalog();
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _prewarmCatalog() async {
    try {
      await catalog.synchronize();
      catalogWarning = null;
    } catch (e) {
      catalogWarning = catalog.hasLocalData
          ? 'تعذر تحديث المنتجات الآن؛ سيتم استخدام آخر نسخة محفوظة.'
          : 'تعذر تحميل المنتجات. تحقق من اتصال التطبيق بالخادم.';
      debugPrint('[Catalog] prewarm failed: $e');
    }
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await auth.logout();
    } finally {
      user = null;
      cart.clear();
      error = null;
      catalogWarning = null;
      notifyListeners();
    }
  }

  bool addProduct(Product product) {
    if (product.stockQuantity <= 0) return false;
    final index = cart.indexWhere((line) => line.product.id == product.id);
    if (index >= 0) {
      if (cart[index].quantity >= product.stockQuantity) return false;
      cart[index].quantity++;
    } else {
      cart.add(CartLine(product: product));
    }
    notifyListeners();
    return true;
  }

  void increment(CartLine line) {
    if (line.quantity < line.product.stockQuantity) line.quantity++;
    notifyListeners();
  }

  void decrement(CartLine line) {
    if (line.quantity > 1) {
      line.quantity--;
    } else {
      cart.remove(line);
    }
    notifyListeners();
  }

  void clearCart() {
    cart.clear();
    notifyListeners();
  }
}
