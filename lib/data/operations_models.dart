import 'models.dart';

class SalesHistorySummary {
  const SalesHistorySummary({
    required this.totalSales,
    required this.cashSales,
    required this.deferredSales,
    required this.outstanding,
    required this.collectedDebt,
    required this.averageInvoice,
  });

  final double totalSales;
  final double cashSales;
  final double deferredSales;
  final double outstanding;
  final double collectedDebt;
  final double averageInvoice;

  factory SalesHistorySummary.fromJson(Map<String, dynamic> json) => SalesHistorySummary(
        totalSales: (json['totalSales'] as num? ?? 0).toDouble(),
        cashSales: (json['cashSales'] as num? ?? 0).toDouble(),
        deferredSales: (json['deferredSales'] as num? ?? 0).toDouble(),
        outstanding: (json['outstanding'] as num? ?? 0).toDouble(),
        collectedDebt: (json['collectedDebt'] as num? ?? 0).toDouble(),
        averageInvoice: (json['averageInvoice'] as num? ?? 0).toDouble(),
      );
}

class SalesHistoryPage {
  const SalesHistoryPage({required this.items, required this.totalCount, required this.page, required this.pageSize, required this.totalPages, required this.summary});
  final List<Invoice> items;
  final int totalCount;
  final int page;
  final int pageSize;
  final int totalPages;
  final SalesHistorySummary summary;

  factory SalesHistoryPage.fromJson(Map<String, dynamic> json) => SalesHistoryPage(
        items: (json['items'] as List? ?? const []).whereType<Map>().map((e) => Invoice.fromJson(Map<String, dynamic>.from(e))).toList(growable: false),
        totalCount: (json['totalCount'] as num? ?? 0).toInt(),
        page: (json['page'] as num? ?? 1).toInt(),
        pageSize: (json['pageSize'] as num? ?? 30).toInt(),
        totalPages: (json['totalPages'] as num? ?? 0).toInt(),
        summary: SalesHistorySummary.fromJson(json['summary'] is Map ? Map<String, dynamic>.from(json['summary'] as Map) : const <String, dynamic>{}),
      );
}

class CollectionEntry {
  const CollectionEntry({
    required this.id,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.amount,
    required this.createdAt,
    required this.currencySymbol,
    this.customerName,
    this.customerPhone,
    this.note,
    this.receivedByName,
  });

  final int id;
  final int invoiceId;
  final String invoiceNumber;
  final String? customerName;
  final String? customerPhone;
  final double amount;
  final String? note;
  final String? receivedByName;
  final DateTime createdAt;
  final String currencySymbol;

  factory CollectionEntry.fromJson(Map<String, dynamic> json) => CollectionEntry(
        id: (json['id'] as num? ?? 0).toInt(),
        invoiceId: (json['invoiceId'] as num? ?? 0).toInt(),
        invoiceNumber: '${json['invoiceNumber'] ?? ''}',
        customerName: json['customerName']?.toString(),
        customerPhone: json['customerPhone']?.toString(),
        amount: (json['amount'] as num? ?? 0).toDouble(),
        note: json['note']?.toString(),
        receivedByName: json['receivedByName']?.toString(),
        createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.now(),
        currencySymbol: '${json['currencySymbol'] ?? 'ر.ي'}',
      );
}

class CollectionPage {
  const CollectionPage({required this.items, required this.totalCount, required this.totalAmount, required this.page, required this.totalPages});
  final List<CollectionEntry> items;
  final int totalCount;
  final double totalAmount;
  final int page;
  final int totalPages;

  factory CollectionPage.fromJson(Map<String, dynamic> json) => CollectionPage(
        items: (json['items'] as List? ?? const []).whereType<Map>().map((e) => CollectionEntry.fromJson(Map<String, dynamic>.from(e))).toList(growable: false),
        totalCount: (json['totalCount'] as num? ?? 0).toInt(),
        totalAmount: (json['totalAmount'] as num? ?? 0).toDouble(),
        page: (json['page'] as num? ?? 1).toInt(),
        totalPages: (json['totalPages'] as num? ?? 0).toInt(),
      );
}

class StockMovementModel {
  const StockMovementModel({required this.id, required this.productId, required this.productName, required this.type, required this.quantity, required this.previousQuantity, required this.newQuantity, required this.reason, required this.createdAt, this.reference, this.invoiceId, this.userName});
  final int id;
  final int productId;
  final String productName;
  final int type;
  final int quantity;
  final int previousQuantity;
  final int newQuantity;
  final String reason;
  final String? reference;
  final int? invoiceId;
  final String? userName;
  final DateTime createdAt;

  bool get isIncrease => type == 1 || type == 2 || type == 4 || type == 5;

  factory StockMovementModel.fromJson(Map<String, dynamic> json) => StockMovementModel(
        id: (json['id'] as num? ?? 0).toInt(),
        productId: (json['productId'] as num? ?? 0).toInt(),
        productName: '${json['productName'] ?? ''}',
        type: (json['type'] as num? ?? 0).toInt(),
        quantity: (json['quantity'] as num? ?? 0).toInt(),
        previousQuantity: (json['previousQuantity'] as num? ?? 0).toInt(),
        newQuantity: (json['newQuantity'] as num? ?? 0).toInt(),
        reason: '${json['reason'] ?? ''}',
        reference: json['reference']?.toString(),
        invoiceId: (json['invoiceId'] as num?)?.toInt(),
        userName: json['userName']?.toString(),
        createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.now(),
      );
}

class InventoryOverview {
  const InventoryOverview({required this.totalProducts, required this.lowStockProducts, required this.outOfStockProducts, required this.totalUnits, required this.recentMovements});
  final int totalProducts;
  final int lowStockProducts;
  final int outOfStockProducts;
  final int totalUnits;
  final List<StockMovementModel> recentMovements;

  factory InventoryOverview.fromJson(Map<String, dynamic> json) => InventoryOverview(
        totalProducts: (json['totalProducts'] as num? ?? 0).toInt(),
        lowStockProducts: (json['lowStockProducts'] as num? ?? 0).toInt(),
        outOfStockProducts: (json['outOfStockProducts'] as num? ?? 0).toInt(),
        totalUnits: (json['totalUnits'] as num? ?? 0).toInt(),
        recentMovements: (json['recentMovements'] as List? ?? const []).whereType<Map>().map((e) => StockMovementModel.fromJson(Map<String, dynamic>.from(e))).toList(growable: false),
      );
}

class ReportSummary {
  const ReportSummary(this.raw);
  final Map<String, dynamic> raw;

  double number(String key) => (raw[key] as num? ?? 0).toDouble();
  int integer(String key) => (raw[key] as num? ?? 0).toInt();
  List<Map<String, dynamic>> list(String key) => (raw[key] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
}

class ProductUpload {
  const ProductUpload({required this.fileName, required this.bytes});
  final String fileName;
  final List<int> bytes;
}
