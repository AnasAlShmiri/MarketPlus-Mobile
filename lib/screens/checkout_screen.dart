import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../data/models.dart';
import '../data/repositories.dart';
import '../state/app_session.dart';
import '../state/offline_sale_queue.dart';
import '../state/product_catalog.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final phone = TextEditingController();
  final phoneFocus = FocusNode();

  PaymentType payment = PaymentType.cash;
  bool saving = false;
  bool loadingCustomers = false;
  List<CustomerSummary> customers = const [];
  List<CustomerSummary> suggestions = const [];

  @override
  void initState() {
    super.initState();
    phone.addListener(_filterCustomers);
    phoneFocus.addListener(_filterCustomers);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (customers.isEmpty && !loadingCustomers) _loadCustomers();
  }

  @override
  void dispose() {
    phone.removeListener(_filterCustomers);
    phoneFocus.removeListener(_filterCustomers);
    phoneFocus.dispose();
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    loadingCustomers = true;
    try {
      final loaded = await context.read<CustomerRepository>().all();
      if (!mounted) return;
      setState(() => customers = loaded);
      _filterCustomers();
    } catch (_) {
      // Checkout remains usable even when the customer directory cannot refresh.
    } finally {
      loadingCustomers = false;
    }
  }

  void _filterCustomers() {
    if (!mounted) return;
    if (!phoneFocus.hasFocus) {
      if (suggestions.isNotEmpty) setState(() => suggestions = const []);
      return;
    }
    final query = _digits(phone.text);
    final next = query.length < 3
        ? const <CustomerSummary>[]
        : customers
            .where((customer) => customer.phone.startsWith(query))
            .take(6)
            .toList(growable: false);
    if (_sameSuggestions(next, suggestions)) return;
    setState(() => suggestions = next);
  }

  void _selectCustomer(CustomerSummary customer) {
    phone.value = TextEditingValue(
      text: customer.phone,
      selection: TextSelection.collapsed(offset: customer.phone.length),
    );
    if (customer.name.trim().isNotEmpty) name.text = customer.name.trim();
    phoneFocus.unfocus();
    setState(() => suggestions = const []);
  }

  Future<void> _save() async {
    final session = context.read<AppSession>();
    if (session.cart.isEmpty || saving) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    final soldLines = session.cart
        .map((line) => CartLine(product: line.product, quantity: line.quantity))
        .toList(growable: false);
    final customerName = name.text.trim();
    final customerPhone = _digits(phone.text);
    final requestId = 'sale-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

    setState(() => saving = true);
    try {
      final invoice = await context.read<InvoiceRepository>().create(
            lines: soldLines,
            payment: payment,
            customerName: customerName,
            customerPhone: customerPhone,
            taxRate: 0,
            clientRequestId: requestId,
          );

      if (!mounted) return;
      context.read<ProductCatalog>().applySale(soldLines);
      session.clearCart();
      HapticFeedback.mediumImpact();
      context.go('/invoice/${invoice.id}');
    } on ApiException catch (e) {
      if (!e.isNetworkError) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        return;
      }

      await context.read<OfflineSaleQueue>().enqueue(
            lines: soldLines,
            payment: payment,
            customerName: customerName,
            customerPhone: customerPhone,
            taxRate: 0,
          );
      if (!mounted) return;
      context.read<ProductCatalog>().applySale(soldLines);
      session.clearCart();
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('انقطع الاتصال. حفظنا البيع في قائمة المزامنة ولم نفقد العملية.'),
          duration: Duration(seconds: 4),
        ),
      );
      context.go('/home');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    final offline = context.watch<OfflineSaleQueue>();
    final isDeferred = payment == PaymentType.deferred;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إكمال البيع'),
        actions: [
          if (offline.pendingCount > 0)
            TextButton.icon(
              onPressed: () => context.push('/sync'),
              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
              label: Text('${offline.pendingCount}'),
            ),
        ],
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 145),
          children: [
            _CheckoutHero(session: session, payment: payment),
            const SizedBox(height: 22),
            const _SectionTitle('المنتجات', 'راجع الكمية قبل إتمام الفاتورة'),
            const SizedBox(height: 10),
            if (session.cart.isEmpty)
              const _EmptyCart()
            else
              ...session.cart.map((line) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _CartLineCard(line: line, session: session),
                  )),
            const SizedBox(height: 18),
            const _SectionTitle('طريقة الدفع', 'اختر نوع الفاتورة'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _PaymentCard(
                    selected: payment == PaymentType.cash,
                    icon: Icons.payments_rounded,
                    title: 'نقدي',
                    subtitle: 'مدفوع الآن',
                    onTap: () => setState(() => payment = PaymentType.cash),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PaymentCard(
                    selected: payment == PaymentType.deferred,
                    icon: Icons.schedule_rounded,
                    title: 'آجل',
                    subtitle: 'يبقى كدين',
                    onTap: () => setState(() => payment = PaymentType.deferred),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _SectionTitle(
              'بيانات العميل',
              isDeferred ? 'رقم الجوال مطلوب لحفظ الدين' : 'اختيارية، لكنها تبني سجل العميل',
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: const Color(0xFFE5E8EE)),
                boxShadow: ZShadow.card,
              ),
              child: Column(
                children: [
                  TextFormField(
                    controller: name,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'اسم العميل',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: phone,
                    focusNode: phoneFocus,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(9),
                    ],
                    decoration: InputDecoration(
                      labelText: isDeferred ? 'رقم الجوال *' : 'رقم الجوال',
                      hintText: '771234567',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      suffixIcon: loadingCustomers
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : null,
                    ),
                    validator: (value) {
                      final normalized = _digits(value ?? '');
                      if (!isDeferred && normalized.isEmpty) return null;
                      return RegExp(r'^7\d{8}$').hasMatch(normalized)
                          ? null
                          : 'استخدم رقمًا يمنيًا من 9 أرقام يبدأ بـ7';
                    },
                  ),
                  if (phoneFocus.hasFocus && _digits(phone.text).length < 3 && phone.text.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    const Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text('اكتب أول 3 أرقام لعرض العملاء المطابقين.', style: TextStyle(fontSize: 10.5, color: ZColors.subtle)),
                    ),
                  ],
                  if (suggestions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _CustomerSuggestions(items: suggestions, onSelected: _selectCustomer),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            _InvoiceSummary(session: session, payment: payment),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 13),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE5E8EE))),
            boxShadow: [BoxShadow(color: Color(0x101A3C34), blurRadius: 24, offset: Offset(0, -7))],
          ),
          child: FilledButton.icon(
            onPressed: saving || session.cart.isEmpty ? null : _save,
            icon: saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(isDeferred ? Icons.receipt_long_rounded : Icons.check_circle_rounded),
            label: Text(
              saving
                  ? 'جارٍ حفظ الفاتورة...'
                  : '${isDeferred ? 'حفظ كبيع آجل' : 'إتمام البيع'} • ${session.cartSubtotal.toStringAsFixed(0)} ر.ي',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckoutHero extends StatelessWidget {
  const _CheckoutHero({required this.session, required this.payment});
  final AppSession session;
  final PaymentType payment;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(23),
          gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF1A3C34), ZColors.green]),
          boxShadow: ZShadow.float,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 46, height: 46, decoration: BoxDecoration(color: ZColors.yellow, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.shopping_bag_rounded, color: ZColors.green)),
                const SizedBox(width: 11),
                Expanded(child: Text(payment == PaymentType.cash ? 'بيع نقدي' : 'بيع آجل', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900))),
                Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: const Color(0x18FFFFFF), borderRadius: BorderRadius.circular(99)), child: Text('${session.cartCount} قطعة', style: const TextStyle(color: ZColors.yellow, fontSize: 10.5, fontWeight: FontWeight.w900))),
              ],
            ),
            const SizedBox(height: 18),
            const Text('الإجمالي', style: TextStyle(color: Color(0xFFC5D7D2), fontSize: 10.5)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text('${session.cartSubtotal.toStringAsFixed(0)} ر.ي', style: const TextStyle(color: Colors.white, fontSize: 31, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.subtitle);
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ZColors.green)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10.5, color: ZColors.subtle)),
        ],
      );
}

class _CartLineCard extends StatelessWidget {
  const _CartLineCard({required this.line, required this.session});
  final CartLine line;
  final AppSession session;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E8EE)), boxShadow: ZShadow.card),
        child: Row(
          children: [
            Container(width: 52, height: 52, decoration: BoxDecoration(color: ZColors.greenSoft, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.inventory_2_outlined, color: ZColors.green)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(line.product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('${line.total.toStringAsFixed(0)} ر.ي', style: const TextStyle(color: ZColors.green, fontWeight: FontWeight.w900)),
              ]),
            ),
            Container(
              decoration: BoxDecoration(color: ZColors.surfaceSoft, borderRadius: BorderRadius.circular(99)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(onPressed: () => session.decrement(line), visualDensity: VisualDensity.compact, icon: const Icon(Icons.remove_rounded, size: 17)),
                Text('${line.quantity}', style: const TextStyle(fontWeight: FontWeight.w900)),
                IconButton(onPressed: () => session.increment(line), visualDensity: VisualDensity.compact, icon: const Icon(Icons.add_rounded, size: 17)),
              ]),
            ),
          ],
        ),
      );
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.selected, required this.icon, required this.title, required this.subtitle, required this.onTap});
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected ? ZColors.green : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? ZColors.gold : const Color(0xFFE5E8EE)),
              boxShadow: selected ? ZShadow.float : ZShadow.card,
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: selected ? ZColors.yellow : ZColors.green),
              const SizedBox(height: 11),
              Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: selected ? Colors.white : ZColors.text)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 10.5, color: selected ? const Color(0xFFC5D7D2) : ZColors.muted)),
            ]),
          ),
        ),
      );
}

class _CustomerSuggestions extends StatelessWidget {
  const _CustomerSuggestions({required this.items, required this.onSelected});
  final List<CustomerSummary> items;
  final ValueChanged<CustomerSummary> onSelected;
  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: ZColors.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E8EE))),
        child: Column(
          children: items.map((customer) => ListTile(
            dense: true,
            onTap: () => onSelected(customer),
            leading: CircleAvatar(backgroundColor: ZColors.greenSoft, foregroundColor: ZColors.green, child: Text(customer.initial)),
            title: Text(customer.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Directionality(textDirection: TextDirection.ltr, child: Text(customer.phone, textAlign: TextAlign.left)),
            trailing: customer.hasDebt ? Text('${customer.outstandingAmount.toStringAsFixed(0)} ر.ي', style: const TextStyle(fontSize: 10, color: ZColors.danger, fontWeight: FontWeight.w800)) : null,
          )).toList(),
        ),
      );
}

class _InvoiceSummary extends StatelessWidget {
  const _InvoiceSummary({required this.session, required this.payment});
  final AppSession session;
  final PaymentType payment;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E8EE)), boxShadow: ZShadow.card),
        child: Column(children: [
          _SummaryRow(label: 'عدد القطع', value: '${session.cartCount}'),
          const SizedBox(height: 9),
          _SummaryRow(label: 'طريقة الدفع', value: payment.label),
          const Padding(padding: EdgeInsets.symmetric(vertical: 13), child: Divider()),
          _SummaryRow(label: 'الإجمالي', value: '${session.cartSubtotal.toStringAsFixed(0)} ر.ي', strong: true),
        ]),
      );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.strong = false});
  final String label;
  final String value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(label, style: TextStyle(color: strong ? ZColors.text : ZColors.muted, fontWeight: strong ? FontWeight.w900 : FontWeight.w500))),
        Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontSize: strong ? 19 : 13, color: strong ? ZColors.green : ZColors.text, fontWeight: FontWeight.w900)))),
      ]);
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 30),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E8EE))),
        child: const Column(children: [Icon(Icons.shopping_bag_outlined, size: 38, color: ZColors.subtle), SizedBox(height: 8), Text('السلة فارغة', style: TextStyle(fontWeight: FontWeight.w900))]),
      );
}

String _digits(String value) => value.replaceAll(RegExp(r'\D'), '');

bool _sameSuggestions(List<CustomerSummary> a, List<CustomerSummary> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index].phone != b[index].phone) return false;
  }
  return true;
}
