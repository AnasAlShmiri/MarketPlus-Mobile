import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marketplus_mobile/data/models.dart';
import 'package:marketplus_mobile/data/repositories.dart';
import 'package:marketplus_mobile/state/product_catalog.dart';

class FakeProductSource implements ProductSource {
  FakeProductSource(this.items);
  final List<Product> items;
  int allCalls = 0;
  int barcodeCalls = 0;

  @override
  Future<List<Product>> all() async {
    allCalls++;
    return items;
  }

  @override
  Future<Product> byBarcode(String barcode) async {
    barcodeCalls++;
    return items.firstWhere((product) => product.barcode == barcode);
  }
}

void main() {
  const product = Product(
    id: 1,
    name: 'ماء',
    barcode: '123456789',
    price: 500,
    stockQuantity: 10,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('synchronization builds O(1) barcode index and cached resolve avoids API barcode call', () async {
    final preferences = await SharedPreferences.getInstance();
    final source = FakeProductSource(const [product]);
    final catalog = ProductCatalog(source, preferences);

    await catalog.synchronize();
    expect(source.allCalls, 1);
    expect(catalog.findByBarcode('123456789')?.id, 1);

    final resolved = await catalog.resolveBarcode('123456789');
    expect(resolved.id, 1);
    expect(source.barcodeCalls, 0, reason: 'A barcode already in the local index must never wait for the API.');
  });

  test('catalog survives app restart by hydrating persisted products', () async {
    final preferences = await SharedPreferences.getInstance();
    final source = FakeProductSource(const [product]);
    final first = ProductCatalog(source, preferences);
    await first.synchronize();

    final second = ProductCatalog(FakeProductSource(const []), preferences);
    await second.hydrate();

    expect(second.hasLocalData, isTrue);
    expect(second.findByBarcode('123456789')?.name, 'ماء');
  });

  test('successful sale updates cached stock immediately', () async {
    final preferences = await SharedPreferences.getInstance();
    final catalog = ProductCatalog(FakeProductSource(const [product]), preferences);
    await catalog.synchronize();

    catalog.applySale([CartLine(product: product, quantity: 3)]);

    expect(catalog.findByBarcode('123456789')?.stockQuantity, 7);
  });
}
