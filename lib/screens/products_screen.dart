import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../data/models.dart';
import '../state/product_catalog.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final search = TextEditingController();
  String query = '';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<ProductCatalog>();
    final normalizedQuery = query.trim().toLowerCase();
    final items = catalog.products
        .where(
          (product) =>
              normalizedQuery.isEmpty ||
              product.name.toLowerCase().contains(normalizedQuery) ||
              product.barcode.toLowerCase().contains(normalizedQuery),
        )
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: () async {
        try {
          await context.read<ProductCatalog>().synchronize(force: true);
        } catch (_) {}
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            sliver: SliverList.list(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'المنتجات',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${catalog.count} صنف متاح في متجرك',
                            style: const TextStyle(
                              color: ZColors.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (catalog.syncing)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: search,
                  onChanged: (value) => setState(() => query = value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'ابحث باسم المنتج أو رقم الباركود',
                  ),
                ),
                if (catalog.syncError != null && catalog.hasLocalData) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: ZColors.warningSurface,
                      borderRadius: BorderRadius.circular(ZRadius.md),
                      border: Border.all(color: const Color(0xFFF2DE98)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: ZColors.yellowText,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'نعرض آخر قائمة محفوظة حتى يعود الاتصال.',
                            style: TextStyle(
                              fontSize: 12,
                              color: ZColors.yellowText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: ZColors.greenSoft,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          size: 30,
                          color: ZColors.green,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        catalog.hasLocalData
                            ? 'ما لقينا منتجًا مطابقًا'
                            : 'ما عندك منتجات ظاهرة الآن',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'جرّب كلمة أخرى أو اسحب الشاشة للأسفل للتحديث.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ZColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
              sliver: SliverList.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final product = items[index];
                  return _ProductCard(
                    product: product,
                    onTap: () => _showProductDetails(context, product),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showProductDetails(
    BuildContext context,
    Product product,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ProductDetailsSheet(product: product),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stock = _StockVisual.from(product.stockQuantity);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ZRadius.lg),
        boxShadow: ZShadow.card,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(ZRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ZRadius.lg),
              border: Border.all(color: const Color(0xFFE5E8EE)),
            ),
            child: Row(
              children: [
                _ProductImage(
                  imageUrl: product.imageUrl,
                  width: 64,
                  height: 64,
                  radius: 11,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          height: 1.35,
                          fontWeight: FontWeight.w900,
                          color: ZColors.text,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          product.barcode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                          style: const TextStyle(
                            fontSize: 11,
                            color: ZColors.subtle,
                            letterSpacing: .25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 104),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${product.price.toStringAsFixed(0)} ر.ي',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: ZColors.green,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: stock.background,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          stock.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: stock.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductDetailsSheet extends StatelessWidget {
  const _ProductDetailsSheet({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final stock = _StockVisual.from(product.stockQuantity);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          20 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD7DADF),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 190,
                color: ZColors.surfaceSoft,
                child: _ProductImage(
                  imageUrl: product.imageUrl,
                  width: double.infinity,
                  height: 190,
                  radius: 0,
                  iconSize: 48,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 21,
                      height: 1.35,
                      fontWeight: FontWeight.w900,
                      color: ZColors.text,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: stock.background,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    stock.shortLabel,
                    style: TextStyle(
                      color: stock.foreground,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${product.price.toStringAsFixed(0)} ر.ي',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: ZColors.yellowText,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: ZColors.background,
                borderRadius: BorderRadius.circular(ZRadius.md),
                border: Border.all(color: const Color(0xFFE5E8EE)),
              ),
              child: Column(
                children: [
                  _DetailRow(
                    icon: Icons.inventory_2_outlined,
                    label: 'المخزون',
                    value: '${product.stockQuantity} قطعة',
                  ),
                  const Divider(),
                  _DetailRow(
                    icon: Icons.qr_code_2_rounded,
                    label: 'الباركود',
                    value: product.barcode,
                    ltrValue: true,
                  ),
                  const Divider(),
                  _DetailRow(
                    icon: Icons.tag_rounded,
                    label: 'رقم المنتج',
                    value: '#${product.id}',
                    ltrValue: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.check_rounded),
              label: const Text('تم'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.ltrValue = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool ltrValue;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: ZColors.greenSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: ZColors.green),
            ),
            const SizedBox(width: 11),
            Text(
              label,
              style: const TextStyle(
                color: ZColors.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Directionality(
                textDirection:
                    ltrValue ? TextDirection.ltr : Directionality.of(context),
                child: SelectableText(
                  value,
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  style: const TextStyle(
                    color: ZColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.radius,
    this.iconSize = 28,
  });

  final String? imageUrl;
  final double width;
  final double height;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final resolved = _resolveImageUrl(imageUrl);
    final fallback = Container(
      width: width,
      height: height,
      color: ZColors.surfaceContainer,
      alignment: Alignment.center,
      child: Icon(
        Icons.inventory_2_outlined,
        size: iconSize,
        color: ZColors.greenMid,
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: resolved == null
          ? fallback
          : Image.network(
              resolved,
              width: width,
              height: height,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => fallback,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  width: width,
                  height: height,
                  color: ZColors.surfaceSoft,
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
            ),
    );
  }
}

String? _resolveImageUrl(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;

  final parsed = Uri.tryParse(value);
  if (parsed != null && parsed.hasScheme) return value;

  const base = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );
  final baseUri = Uri.tryParse(base);
  if (baseUri == null) return value;

  try {
    return baseUri.resolve(value).toString();
  } catch (_) {
    return value;
  }
}

class _StockVisual {
  const _StockVisual({
    required this.label,
    required this.shortLabel,
    required this.foreground,
    required this.background,
  });

  final String label;
  final String shortLabel;
  final Color foreground;
  final Color background;

  factory _StockVisual.from(int quantity) {
    if (quantity <= 0) {
      return const _StockVisual(
        label: 'نفد المخزون',
        shortLabel: 'نافد',
        foreground: ZColors.danger,
        background: ZColors.dangerSoft,
      );
    }
    if (quantity <= 5) {
      return _StockVisual(
        label: 'باقي $quantity',
        shortLabel: 'منخفض',
        foreground: ZColors.yellowText,
        background: ZColors.warningSurface,
      );
    }
    return _StockVisual(
      label: '$quantity متاح',
      shortLabel: 'متوفر',
      foreground: ZColors.success,
      background: ZColors.successSoft,
    );
  }
}
