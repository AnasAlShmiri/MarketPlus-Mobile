class UserSession {
  const UserSession({required this.id, required this.fullName, required this.email, required this.roles});
  final String id;
  final String fullName;
  final String email;
  final List<String> roles;

  bool get isAdmin => roles.contains('Admin');
  bool get isCashier => roles.contains('Cashier');

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
        id: '${json['id'] ?? ''}',
        fullName: '${json['fullName'] ?? ''}',
        email: '${json['email'] ?? ''}',
        roles: (json['roles'] as List? ?? const []).map((e) => e.toString()).toList(),
      );
}

class Product {
  const Product({required this.id, required this.name, required this.barcode, required this.price, required this.stockQuantity, this.imageUrl});
  final int id;
  final String name;
  final String barcode;
  final double price;
  final int stockQuantity;
  final String? imageUrl;

  bool get inStock => stockQuantity > 0;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: (json['id'] as num? ?? 0).toInt(),
        name: '${json['name'] ?? ''}',
        barcode: '${json['barcode'] ?? ''}'.trim(),
        price: (json['price'] as num? ?? 0).toDouble(),
        stockQuantity: (json['stockQuantity'] as num? ?? 0).toInt(),
        imageUrl: json['imageUrl']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'barcode': barcode,
        'price': price,
        'stockQuantity': stockQuantity,
        'imageUrl': imageUrl,
      };

  Product copyWith({String? name, String? barcode, double? price, int? stockQuantity, String? imageUrl}) => Product(
        id: id,
        name: name ?? this.name,
        barcode: barcode ?? this.barcode,
        price: price ?? this.price,
        stockQuantity: stockQuantity ?? this.stockQuantity,
        imageUrl: imageUrl ?? this.imageUrl,
      );
}

class CartLine {
  CartLine({required this.product, this.quantity = 1});
  final Product product;
  int quantity;
  double get total => product.price * quantity;
}

enum PaymentType {
  cash(1, 'نقدي'),
  deferred(2, 'آجل');

  const PaymentType(this.value, this.label);
  final int value;
  final String label;
}

class InvoiceItem {
  const InvoiceItem({required this.productId, required this.name, required this.barcode, required this.quantity, required this.unitPrice});
  final int productId;
  final String name;
  final String barcode;
  final int quantity;
  final double unitPrice;
  double get total => quantity * unitPrice;

  factory InvoiceItem.fromJson(Map<String, dynamic> json) => InvoiceItem(
        productId: (json['productId'] as num? ?? 0).toInt(),
        name: '${json['productName'] ?? ''}',
        barcode: '${json['barcode'] ?? ''}',
        quantity: (json['quantity'] as num? ?? 0).toInt(),
        unitPrice: (json['unitPrice'] as num? ?? 0).toDouble(),
      );
}

class DebtPayment {
  const DebtPayment({required this.id, required this.amount, required this.createdAt, this.note, this.receivedByName});
  final int id;
  final double amount;
  final DateTime createdAt;
  final String? note;
  final String? receivedByName;

  factory DebtPayment.fromJson(Map<String, dynamic> json) => DebtPayment(
        id: (json['id'] as num? ?? 0).toInt(),
        amount: (json['amount'] as num? ?? 0).toDouble(),
        createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.now(),
        note: json['note']?.toString(),
        receivedByName: json['receivedByName']?.toString(),
      );
}

class Invoice {
  const Invoice({
    required this.id,
    required this.number,
    required this.total,
    required this.subtotal,
    required this.tax,
    required this.taxRate,
    required this.paidAmount,
    required this.remainingAmount,
    required this.paymentType,
    required this.status,
    required this.createdAt,
    required this.items,
    required this.payments,
    this.customerName,
    this.customerPhone,
  });

  final int id;
  final String number;
  final String? customerName;
  final String? customerPhone;
  final double subtotal;
  final double taxRate;
  final double tax;
  final double total;
  final double paidAmount;
  final double remainingAmount;
  final int paymentType;
  final int status;
  final DateTime createdAt;
  final List<InvoiceItem> items;
  final List<DebtPayment> payments;

  bool get isPartiallyPaid => status == 3;
  bool get isVoided => status == 4;
  bool get isPaid => status == 2;

  factory Invoice.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as num? ?? 0).toInt();
    final total = (json['totalAmount'] as num? ?? 0).toDouble();
    final paymentType = (json['paymentType'] as num? ?? 0).toInt();
    final status = (json['status'] as num? ?? 0).toInt();
    final paid = (json['paidAmount'] as num? ?? 0).toDouble();
    final remainingRaw = json['remainingAmount'] as num?;
    final fallbackRemaining = paymentType == 2 && status != 2 && status != 4 ? (total - paid).clamp(0, total).toDouble() : 0.0;

    return Invoice(
      id: id,
      number: compactInvoiceNumber(id, '${json['invoiceNumber'] ?? ''}'),
      customerName: json['customerName']?.toString(),
      customerPhone: json['customerPhone']?.toString(),
      subtotal: (json['subtotalAmount'] as num? ?? 0).toDouble(),
      taxRate: (json['taxRate'] as num? ?? 0).toDouble(),
      tax: (json['taxAmount'] as num? ?? 0).toDouble(),
      total: total,
      paidAmount: paid,
      remainingAmount: remainingRaw?.toDouble() ?? fallbackRemaining,
      paymentType: paymentType,
      status: status,
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.now(),
      items: (json['items'] as List? ?? const []).whereType<Map>().map((e) => InvoiceItem.fromJson(Map<String, dynamic>.from(e))).toList(),
      payments: (json['payments'] as List? ?? const []).whereType<Map>().map((e) => DebtPayment.fromJson(Map<String, dynamic>.from(e))).toList(),
    );
  }
}

String compactInvoiceNumber(int id, String fallback) =>
    id > 0 ? 'INV-$id' : fallback.trim();

class CustomerSummary {
  const CustomerSummary({
    this.id,
    required this.name,
    required this.phone,
    this.notes,
    required this.totalPurchases,
    required this.paidAmount,
    required this.outstandingAmount,
    required this.invoiceCount,
    required this.openInvoiceCount,
    required this.firstPurchaseAt,
    required this.latestActivityAt,
    required this.currencySymbol,
  });

  final int? id;
  final String name;
  final String phone;
  final String? notes;
  final double totalPurchases;
  final double paidAmount;
  final double outstandingAmount;
  final int invoiceCount;
  final int openInvoiceCount;
  final DateTime firstPurchaseAt;
  final DateTime latestActivityAt;
  final String currencySymbol;

  bool get hasDebt => outstandingAmount > 0;
  String get displayName => name.trim().isEmpty ? 'عميل بدون اسم' : name.trim();
  String get initial => displayName.isEmpty ? 'ع' : displayName[0];

  factory CustomerSummary.fromJson(Map<String, dynamic> json) => CustomerSummary(
        id: (json['customerId'] as num?)?.toInt(),
        name: '${json['customerName'] ?? ''}',
        phone: '${json['customerPhone'] ?? ''}'.trim(),
        notes: json['notes']?.toString(),
        totalPurchases: (json['totalPurchasesAmount'] as num? ?? 0).toDouble(),
        paidAmount: (json['paidAmount'] as num? ?? 0).toDouble(),
        outstandingAmount: (json['outstandingAmount'] as num? ?? 0).toDouble(),
        invoiceCount: (json['invoiceCount'] as num? ?? 0).toInt(),
        openInvoiceCount: (json['openInvoiceCount'] as num? ?? 0).toInt(),
        firstPurchaseAt: DateTime.tryParse('${json['firstPurchaseAt'] ?? ''}') ?? DateTime.now(),
        latestActivityAt: DateTime.tryParse('${json['latestActivityAt'] ?? ''}') ?? DateTime.now(),
        currencySymbol: '${json['currencySymbol'] ?? 'ر.ي'}',
      );
}

class CustomerDetails {
  const CustomerDetails({required this.summary, required this.invoices});

  final CustomerSummary summary;
  final List<Invoice> invoices;

  factory CustomerDetails.fromJson(Map<String, dynamic> json) {
    final summaryRaw = json['summary'];
    final invoicesRaw = json['invoices'];
    return CustomerDetails(
      summary: CustomerSummary.fromJson(
        summaryRaw is Map ? Map<String, dynamic>.from(summaryRaw) : const <String, dynamic>{},
      ),
      invoices: (invoicesRaw as List? ?? const [])
          .whereType<Map>()
          .map((e) => Invoice.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
    );
  }
}
