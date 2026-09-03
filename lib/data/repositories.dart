import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/client_operation_id.dart';
import 'models.dart';
import 'operations_models.dart';

class AuthRepository {
  AuthRepository(this.api);
  final ApiClient api;

  Future<UserSession> login(String email, String password) async {
    final response = await api.post('/api/auth/login', data: {
      'email': email.trim(),
      'password': password,
      'rememberMe': true,
    });
    final map = Map<String, dynamic>.from(response.data as Map);
    return UserSession.fromJson(Map<String, dynamic>.from(map['user'] as Map));
  }

  Future<UserSession?> restore() async {
    try {
      final response = await api.get('/api/auth/me');
      return UserSession.fromJson(
          Map<String, dynamic>.from(response.data as Map));
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await api.cookies.deleteAll();
        return null;
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await api.post('/api/auth/logout');
    } finally {
      await api.cookies.deleteAll();
    }
  }
}

abstract interface class ProductSource {
  Future<List<Product>> all();
  Future<Product> byBarcode(String barcode);
}

class ProductRepository implements ProductSource {
  ProductRepository(this.api);
  final ApiClient api;

  @override
  Future<List<Product>> all() async {
    final response = await api.get('/api/products');
    final raw = api.unwrap(response.data);
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Product.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  @override
  Future<Product> byBarcode(String barcode) async {
    final response =
        await api.get('/api/products/barcode/${Uri.encodeComponent(barcode)}');
    final raw = api.unwrap(response.data);
    return Product.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<Product> create({
    required String name,
    required String barcode,
    required double price,
    required int stockQuantity,
    ProductUpload? image,
  }) async {
    final form = FormData.fromMap({
      'Name': name.trim(),
      'Barcode': barcode.trim(),
      'Price': price,
      'StockQuantity': stockQuantity,
      if (image != null)
        'ImageFile':
            MultipartFile.fromBytes(image.bytes, filename: image.fileName),
    });
    final response = await api.post('/api/products', data: form);
    final raw = api.unwrap(response.data);
    return Product.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<void> update({
    required Product product,
    required String name,
    required String barcode,
    required double price,
    required int stockQuantity,
    ProductUpload? image,
    bool removeImage = false,
  }) async {
    final form = FormData.fromMap({
      'Id': product.id,
      'Name': name.trim(),
      'Barcode': barcode.trim(),
      'Price': price,
      'StockQuantity': stockQuantity,
      'RemoveImage': removeImage,
      if (image != null)
        'ImageFile':
            MultipartFile.fromBytes(image.bytes, filename: image.fileName),
    });
    await api.put('/api/products/${product.id}', data: form);
  }

  Future<void> deleteProduct(int id) => api.delete('/api/products/$id');
}

class InvoiceRepository {
  InvoiceRepository(this.api);
  final ApiClient api;

  Future<Invoice> create({
    required List<CartLine> lines,
    required PaymentType payment,
    String? customerName,
    String? customerPhone,
    double taxRate = 0,
    String? clientRequestId,
  }) =>
      createRaw(
        items: lines
            .map((line) => {
                  'productId': line.product.id,
                  'quantity': line.quantity,
                  'unitPrice': line.product.price,
                })
            .toList(),
        payment: payment,
        customerName: customerName,
        customerPhone: customerPhone,
        taxRate: taxRate,
        clientRequestId: clientRequestId,
      );

  Future<Invoice> createRaw({
    required List<Map<String, dynamic>> items,
    required PaymentType payment,
    String? customerName,
    String? customerPhone,
    double taxRate = 0,
    String? clientRequestId,
  }) async {
    final operationId = clientRequestId?.trim().isNotEmpty == true
        ? clientRequestId!.trim()
        : ClientOperationId.create('mob');
    final response = await api.post('/api/invoices', data: {
      'clientRequestId': operationId,
      'customerName':
          customerName?.trim().isEmpty == true ? null : customerName?.trim(),
      'customerPhone':
          customerPhone?.trim().isEmpty == true ? null : customerPhone?.trim(),
      'paymentType': payment.value,
      'taxRate': taxRate,
      'currencyCode': 'YER',
      'currencySymbol': 'ر.ي',
      'items': items,
    });
    final raw = api.unwrap(response.data);
    return Invoice.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<Invoice> byId(int id) async {
    final response = await api.get('/api/invoices/$id');
    return Invoice.fromJson(
        Map<String, dynamic>.from(api.unwrap(response.data) as Map));
  }

  Future<List<Invoice>> all() async {
    final response = await api.get('/api/invoices');
    final raw = api.unwrap(response.data);
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Invoice.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<SalesHistoryPage> history({
    String? query,
    DateTime? from,
    DateTime? to,
    PaymentType? payment,
    int? status,
    int page = 1,
    int pageSize = 30,
  }) async {
    final response = await api.get('/api/sales', queryParameters: {
      if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
      if (payment != null) 'paymentType': payment.value,
      if (status != null) 'status': status,
      'page': page,
      'pageSize': pageSize,
    });
    final raw = api.unwrap(response.data);
    return SalesHistoryPage.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<List<Invoice>> debts() async {
    final response = await api.get('/api/invoices/debts');
    final raw = api.unwrap(response.data);
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Invoice.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<Invoice> recordPayment(
    int id,
    double amount, {
    String? note,
    String? clientOperationId,
  }) async {
    final operationId = clientOperationId?.trim().isNotEmpty == true
        ? clientOperationId!.trim()
        : ClientOperationId.create('mob-payment');
    final response = await api.post('/api/invoices/$id/payments', data: {
      'amount': amount,
      'note': note?.trim().isEmpty == true ? null : note?.trim(),
      'clientOperationId': operationId,
    });
    return Invoice.fromJson(
        Map<String, dynamic>.from(api.unwrap(response.data) as Map));
  }

  Future<void> settle(int id) async {
    await api.put('/api/invoices/$id/settle');
  }

  Future<void> voidInvoice(int id, {required String reason}) async {
    await api.post('/api/invoices/$id/void', data: {'reason': reason.trim()});
  }
}

class CustomerRepository {
  CustomerRepository(this.api);
  final ApiClient api;

  Future<List<CustomerSummary>> all() async {
    final response = await api.get('/api/customers/directory');
    final raw = api.unwrap(response.data);
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => CustomerSummary.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<CustomerDetails> byPhone(String phone) async {
    final response =
        await api.get('/api/customers/${Uri.encodeComponent(phone)}');
    final raw = api.unwrap(response.data);
    return CustomerDetails.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<void> save(
      {required String phone, String? name, String? notes}) async {
    await api.post('/api/customers', data: {
      'phone': phone.trim(),
      'fullName': name?.trim(),
      'notes': notes?.trim(),
    });
  }

  Future<void> update(
      {required String phone, String? name, String? notes}) async {
    await api.put('/api/customers/${Uri.encodeComponent(phone)}', data: {
      'phone': phone.trim(),
      'fullName': name?.trim(),
      'notes': notes?.trim(),
    });
  }
}

class InventoryRepository {
  InventoryRepository(this.api);
  final ApiClient api;

  Future<InventoryOverview> summary({int threshold = 5}) async {
    final response = await api.get('/api/inventory/summary', queryParameters: {
      'lowStockThreshold': threshold,
    });
    final raw = api.unwrap(response.data);
    return InventoryOverview.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<List<StockMovementModel>> movements(
      {int? productId, int take = 100}) async {
    final response =
        await api.get('/api/inventory/movements', queryParameters: {
      if (productId != null) 'productId': productId,
      'take': take,
    });
    final raw = api.unwrap(response.data);
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => StockMovementModel.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<void> adjust({
    required int productId,
    required int quantity,
    required bool increase,
    required String reason,
    String? reference,
  }) async {
    await api.post('/api/inventory/adjustments', data: {
      'productId': productId,
      'quantity': quantity,
      'type': increase ? 5 : 6,
      'reason': reason.trim(),
      'reference': reference?.trim(),
    });
  }
}

class ReportRepository {
  ReportRepository(this.api);
  final ApiClient api;

  Future<ReportSummary> summary(
      {DateTime? from, DateTime? to, int lowStockThreshold = 5}) async {
    final response = await api.get('/api/reports/summary', queryParameters: {
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
      'lowStockThreshold': lowStockThreshold,
    });
    final raw = api.unwrap(response.data);
    return ReportSummary(Map<String, dynamic>.from(raw as Map));
  }

  Future<Map<String, dynamic>> closeout({DateTime? date}) async {
    final response = await api.get('/api/reports/closeout', queryParameters: {
      if (date != null) 'date': date.toIso8601String(),
    });
    final raw = api.unwrap(response.data);
    return Map<String, dynamic>.from(raw as Map);
  }
}

class DashboardRepository {
  DashboardRepository(this.api);
  final ApiClient api;

  Future<Map<String, dynamic>> stats() async {
    final response = await api.get('/api/dashboard/stats');
    final raw = api.unwrap(response.data);
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }
}

class WhatsAppRepository {
  WhatsAppRepository(this.api);
  final ApiClient api;

  Future<String> buildLink(String phone, String message) async {
    final response = await api.post('/api/whatsapp/link', data: {
      'phoneNumber': phone,
      'message': message,
    });
    final map = Map<String, dynamic>.from(response.data as Map);
    return '${map['url'] ?? ''}';
  }
}
