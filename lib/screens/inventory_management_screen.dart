import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../data/models.dart';
import '../data/operations_models.dart';
import '../data/repositories.dart';
import '../state/product_catalog.dart';

class InventoryManagementScreen extends StatefulWidget {
  const InventoryManagementScreen({super.key});

  @override
  State<InventoryManagementScreen> createState() => _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends State<InventoryManagementScreen> {
  Future<InventoryOverview>? future;
  int threshold = 5;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= _load();
  }

  Future<InventoryOverview> _load() => context.read<InventoryRepository>().summary(threshold: threshold);

  Future<void> refresh() async {
    final next = _load();
    setState(() => future = next);
    try {
      await context.read<ProductCatalog>().synchronize(force: true);
    } catch (_) {}
    await next;
  }

  Future<void> openProductForm([Product? product]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductEditor(product: product),
    );
    if (changed == true && mounted) await refresh();
  }

  Future<void> adjust(Product product) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StockAdjustment(product: product),
    );
    if (changed == true && mounted) await refresh();
  }

  Future<void> showMovements(Product product) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MovementSheet(product: product),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<ProductCatalog>();
    final lowProducts = catalog.products.where((p) => p.stockQuantity <= threshold).toList()
      ..sort((a, b) => a.stockQuantity.compareTo(b.stockQuantity));

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المخزون'),
        actions: [
          IconButton(
            tooltip: 'إضافة منتج',
            onPressed: () => openProductForm(),
            icon: const Icon(Icons.add_box_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openProductForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('منتج جديد'),
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: FutureBuilder<InventoryOverview>(
          future: future,
          builder: (context, snap) {
            final overview = snap.data;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
              children: [
                _InventoryHero(overview: overview),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E8EE))),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active_outlined, color: ZColors.green),
                      const SizedBox(width: 9),
                      const Expanded(child: Text('حد تنبيه المخزون', style: TextStyle(fontWeight: FontWeight.w800))),
                      DropdownButton<int>(
                        value: threshold,
                        underline: const SizedBox.shrink(),
                        items: const [2, 3, 5, 10, 20].map((value) => DropdownMenuItem(value: value, child: Text('$value'))).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          threshold = value;
                          refresh();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Expanded(child: Text('يحتاج إعادة تعبئة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ZColors.green))),
                    Text('${lowProducts.length} منتج', style: const TextStyle(fontSize: 10.5, color: ZColors.subtle)),
                  ],
                ),
                const SizedBox(height: 10),
                if (snap.connectionState == ConnectionState.waiting && overview == null)
                  const Padding(padding: EdgeInsets.all(50), child: Center(child: CircularProgressIndicator()))
                else if (snap.hasError && overview == null)
                  _InventoryMessage(title: 'تعذر تحميل المخزون', subtitle: '${snap.error}', icon: Icons.cloud_off_rounded)
                else if (lowProducts.isEmpty)
                  const _InventoryMessage(title: 'المخزون بحالة جيدة', subtitle: 'لا توجد منتجات وصلت لحد التنبيه الحالي.', icon: Icons.check_circle_outline_rounded)
                else
                  ...lowProducts.take(20).map((product) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _StockProductCard(
                      product: product,
                      onAdjust: () => adjust(product),
                      onEdit: () => openProductForm(product),
                      onHistory: () => showMovements(product),
                    ),
                  )),
                const SizedBox(height: 22),
                const Text('كل المنتجات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ZColors.green)),
                const SizedBox(height: 10),
                ...catalog.products.map((product) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _StockProductCard(
                    product: product,
                    onAdjust: () => adjust(product),
                    onEdit: () => openProductForm(product),
                    onHistory: () => showMovements(product),
                  ),
                )),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InventoryHero extends StatelessWidget {
  const _InventoryHero({required this.overview});
  final InventoryOverview? overview;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF1A3C34), ZColors.green]),
          boxShadow: ZShadow.float,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 48, height: 48, decoration: BoxDecoration(color: ZColors.yellow, borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.warehouse_rounded, color: ZColors.green)),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('مركز المخزون', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)), SizedBox(height: 2), Text('إضافة، تسوية ومراجعة حركة الأصناف', style: TextStyle(fontSize: 10.5, color: Color(0xFFC5D7D2)))])),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _HeroMetric(label: 'المنتجات', value: '${overview?.totalProducts ?? 0}')),
                const SizedBox(width: 8),
                Expanded(child: _HeroMetric(label: 'إجمالي الوحدات', value: '${overview?.totalUnits ?? 0}')),
                const SizedBox(width: 8),
                Expanded(child: _HeroMetric(label: 'نافد', value: '${overview?.outOfStockProducts ?? 0}')),
              ],
            ),
          ],
        ),
      );
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0x13FFFFFF), borderRadius: BorderRadius.circular(13)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 9.5, color: Color(0xFFC5D7D2))), const SizedBox(height: 3), Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: ZColors.yellow))]),
      );
}

class _StockProductCard extends StatelessWidget {
  const _StockProductCard({required this.product, required this.onAdjust, required this.onEdit, required this.onHistory});
  final Product product;
  final VoidCallback onAdjust;
  final VoidCallback onEdit;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final danger = product.stockQuantity <= 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E8EE)), boxShadow: ZShadow.card),
      child: Row(
        children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: danger ? ZColors.dangerSoft : ZColors.greenSoft, borderRadius: BorderRadius.circular(13)), child: Icon(danger ? Icons.remove_shopping_cart_outlined : Icons.inventory_2_outlined, color: danger ? ZColors.danger : ZColors.green)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Directionality(textDirection: TextDirection.ltr, child: Text(product.barcode, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.left, style: const TextStyle(fontSize: 10, color: ZColors.subtle))),
                const SizedBox(height: 5),
                Row(children: [Text('${product.stockQuantity} وحدة', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: danger ? ZColors.danger : ZColors.green)), const SizedBox(width: 8), Text('${product.price.toStringAsFixed(0)} ر.ي', style: const TextStyle(fontSize: 10.5, color: ZColors.muted))]),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'adjust') onAdjust();
              if (value == 'edit') onEdit();
              if (value == 'history') onHistory();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'adjust', child: ListTile(leading: Icon(Icons.add_chart_rounded), title: Text('تعديل المخزون'), dense: true)),
              PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('تعديل المنتج'), dense: true)),
              PopupMenuItem(value: 'history', child: ListTile(leading: Icon(Icons.history_rounded), title: Text('سجل الحركة'), dense: true)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductEditor extends StatefulWidget {
  const _ProductEditor({this.product});
  final Product? product;
  @override
  State<_ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<_ProductEditor> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController barcode;
  late final TextEditingController price;
  late final TextEditingController openingStock;
  ProductUpload? image;
  bool removeImage = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    name = TextEditingController(text: product?.name ?? '');
    barcode = TextEditingController(text: product?.barcode ?? '');
    price = TextEditingController(text: product == null ? '' : product.price.toStringAsFixed(0));
    openingStock = TextEditingController(text: product == null ? '0' : product.stockQuantity.toString());
  }

  @override
  void dispose() {
    name.dispose();
    barcode.dispose();
    price.dispose();
    openingStock.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 86, maxWidth: 1600);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      image = ProductUpload(fileName: picked.name, bytes: bytes);
      removeImage = false;
    });
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false) || saving) return;
    final parsedPrice = double.tryParse(price.text.trim()) ?? 0;
    final parsedStock = int.tryParse(openingStock.text.trim()) ?? 0;
    setState(() => saving = true);
    try {
      final repository = context.read<ProductRepository>();
      if (widget.product == null) {
        await repository.create(name: name.text, barcode: barcode.text, price: parsedPrice, stockQuantity: parsedStock, image: image);
      } else {
        await repository.update(
          product: widget.product!,
          name: name.text,
          barcode: barcode.text,
          price: parsedPrice,
          stockQuantity: widget.product!.stockQuantity,
          image: image,
          removeImage: removeImage,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.product != null;
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: ZColors.line, borderRadius: BorderRadius.circular(99)))),
              const SizedBox(height: 16),
              Text(editing ? 'تعديل المنتج' : 'منتج جديد', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: ZColors.green)),
              const SizedBox(height: 16),
              TextFormField(controller: name, decoration: const InputDecoration(labelText: 'اسم المنتج', prefixIcon: Icon(Icons.inventory_2_outlined)), validator: (v) => (v ?? '').trim().length < 2 ? 'اكتب اسم المنتج' : null),
              const SizedBox(height: 10),
              TextFormField(controller: barcode, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'الباركود', prefixIcon: Icon(Icons.qr_code_2_rounded)), validator: (v) => (v ?? '').trim().isEmpty ? 'الباركود مطلوب' : null),
              const SizedBox(height: 10),
              TextFormField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'السعر', suffixText: 'ر.ي'), validator: (v) => (double.tryParse((v ?? '').trim()) ?? 0) <= 0 ? 'اكتب سعرًا صالحًا' : null),
              if (!editing) ...[
                const SizedBox(height: 10),
                TextFormField(controller: openingStock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الرصيد الافتتاحي', suffixText: 'وحدة'), validator: (v) => (int.tryParse((v ?? '').trim()) ?? -1) < 0 ? 'الكمية غير صالحة' : null),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: pickImage, icon: const Icon(Icons.add_photo_alternate_outlined), label: Text(image == null ? 'اختيار صورة المنتج' : 'تم اختيار صورة جديدة')),
              if (editing && (widget.product?.imageUrl ?? '').isNotEmpty)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: removeImage,
                  onChanged: image != null ? null : (value) => setState(() => removeImage = value == true),
                  title: const Text('إزالة الصورة الحالية'),
                ),
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: saving ? null : save, icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded), label: Text(saving ? 'جارٍ الحفظ...' : 'حفظ المنتج'))),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockAdjustment extends StatefulWidget {
  const _StockAdjustment({required this.product});
  final Product product;
  @override
  State<_StockAdjustment> createState() => _StockAdjustmentState();
}

class _StockAdjustmentState extends State<_StockAdjustment> {
  final quantity = TextEditingController();
  final reason = TextEditingController();
  bool increase = true;
  bool saving = false;

  @override
  void dispose() {
    quantity.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final qty = int.tryParse(quantity.text.trim()) ?? 0;
    if (qty <= 0 || reason.text.trim().length < 3 || saving) return;
    setState(() => saving = true);
    try {
      await context.read<InventoryRepository>().adjust(productId: widget.product.id, quantity: qty, increase: increase, reason: reason.text);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: ZColors.line, borderRadius: BorderRadius.circular(99)))),
            const SizedBox(height: 16),
            Text(widget.product.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ZColors.green)),
            const SizedBox(height: 3),
            Text('المخزون الحالي: ${widget.product.stockQuantity}', style: const TextStyle(color: ZColors.muted)),
            const SizedBox(height: 14),
            SegmentedButton<bool>(
              segments: const [ButtonSegment(value: true, label: Text('إضافة'), icon: Icon(Icons.add_rounded)), ButtonSegment(value: false, label: Text('تخفيض'), icon: Icon(Icons.remove_rounded))],
              selected: {increase},
              onSelectionChanged: (value) => setState(() => increase = value.first),
            ),
            const SizedBox(height: 12),
            TextField(controller: quantity, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية', suffixText: 'وحدة')),
            const SizedBox(height: 10),
            TextField(controller: reason, maxLength: 250, decoration: const InputDecoration(labelText: 'سبب الحركة', hintText: 'مثال: توريد بضاعة جديدة')),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: saving ? null : save, child: Text(saving ? 'جارٍ التسجيل...' : 'تسجيل حركة المخزون'))),
          ],
        ),
      );
}

class _MovementSheet extends StatelessWidget {
  const _MovementSheet({required this.product});
  final Product product;
  @override
  Widget build(BuildContext context) => Container(
        height: MediaQuery.sizeOf(context).height * .78,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: ZColors.line, borderRadius: BorderRadius.circular(99)))),
            const SizedBox(height: 16),
            Text('حركة ${product.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ZColors.green)),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<StockMovementModel>>(
                future: context.read<InventoryRepository>().movements(productId: product.id, take: 100),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (snap.hasError) return Center(child: Text('${snap.error}'));
                  final items = snap.data ?? const <StockMovementModel>[];
                  if (items.isEmpty) return const Center(child: Text('لا توجد حركات مسجلة.'));
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final item = items[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(backgroundColor: item.isIncrease ? ZColors.successSoft : ZColors.dangerSoft, child: Icon(item.isIncrease ? Icons.add_rounded : Icons.remove_rounded, color: item.isIncrease ? ZColors.success : ZColors.danger)),
                        title: Text(item.reason, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${DateFormat('yyyy/MM/dd • HH:mm').format(item.createdAt.toLocal())} • ${item.previousQuantity} ← ${item.newQuantity}'),
                        trailing: Text('${item.isIncrease ? '+' : '-'}${item.quantity}', style: TextStyle(fontWeight: FontWeight.w900, color: item.isIncrease ? ZColors.success : ZColors.danger)),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
}

class _InventoryMessage extends StatelessWidget {
  const _InventoryMessage({required this.title, required this.subtitle, required this.icon});
  final String title;
  final String subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E8EE))),
        child: Column(children: [Icon(icon, size: 32, color: ZColors.green), const SizedBox(height: 9), Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, color: ZColors.muted))]),
      );
}
