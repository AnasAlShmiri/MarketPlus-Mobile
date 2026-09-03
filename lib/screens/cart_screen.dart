import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_theme.dart';
import '../data/models.dart';
import '../data/repositories.dart';
import '../state/app_session.dart';
import '../state/product_catalog.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  static const _savedCustomersKey = 'zimmati.saved-customers.v1';
  static const _maxSavedCustomers = 120;

  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final phone = TextEditingController();
  final phoneFocus = FocusNode();

  PaymentType payment = PaymentType.cash;
  bool saving = false;
  List<_SavedCustomer> savedCustomers = const [];
  List<_SavedCustomer> phoneSuggestions = const [];

  @override
  void initState() {
    super.initState();
    phone.addListener(_refreshPhoneSuggestions);
    phoneFocus.addListener(_handlePhoneFocusChange);
    _loadSavedCustomers();
  }

  @override
  void dispose() {
    phone.removeListener(_refreshPhoneSuggestions);
    phoneFocus.removeListener(_handlePhoneFocusChange);
    phoneFocus.dispose();
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCustomers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_savedCustomersKey) ?? const <String>[];
      final loaded = <_SavedCustomer>[];

      for (final item in raw) {
        try {
          final decoded = jsonDecode(item);
          if (decoded is! Map) continue;
          final customer = _SavedCustomer.fromJson(Map<String, dynamic>.from(decoded));
          if (customer.phone.isNotEmpty) loaded.add(customer);
        } catch (_) {
          // Ignore one corrupt entry instead of breaking checkout.
        }
      }

      if (!mounted) return;
      setState(() => savedCustomers = loaded);
      _refreshPhoneSuggestions();
    } catch (_) {
      // Remembered customers are a convenience feature; checkout must still work.
    }
  }

  Future<void> _rememberCustomer() async {
    final normalizedPhone = _digitsOnly(phone.text);
    if (!RegExp(r'^7\d{8}$').hasMatch(normalizedPhone)) return;

    _SavedCustomer? previous;
    for (final item in savedCustomers) {
      if (item.phone == normalizedPhone) {
        previous = item;
        break;
      }
    }

    final typedName = name.text.trim();
    final remembered = _SavedCustomer(
      phone: normalizedPhone,
      name: typedName.isNotEmpty ? typedName : (previous?.name ?? ''),
    );

    final next = <_SavedCustomer>[
      remembered,
      ...savedCustomers.where((item) => item.phone != normalizedPhone),
    ].take(_maxSavedCustomers).toList(growable: false);

    if (mounted) {
      setState(() {
        savedCustomers = next;
        phoneSuggestions = const [];
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _savedCustomersKey,
        next.map((item) => jsonEncode(item.toJson())).toList(growable: false),
      );
    } catch (_) {
      // Do not fail an already-created invoice because local autocomplete storage failed.
    }
  }

  void _handlePhoneFocusChange() {
    if (!mounted) return;
    if (!phoneFocus.hasFocus) {
      if (phoneSuggestions.isNotEmpty) setState(() => phoneSuggestions = const []);
      return;
    }
    _refreshPhoneSuggestions();
  }

  void _refreshPhoneSuggestions() {
    if (!mounted || !phoneFocus.hasFocus) return;
    final query = _digitsOnly(phone.text);
    final next = query.length < 3
        ? const <_SavedCustomer>[]
        : savedCustomers
            .where((item) => item.phone.startsWith(query))
            .take(5)
            .toList(growable: false);

    if (_sameSuggestions(phoneSuggestions, next)) return;
    setState(() => phoneSuggestions = next);
  }

  void _selectSavedCustomer(_SavedCustomer customer) {
    phone.value = TextEditingValue(
      text: customer.phone,
      selection: TextSelection.collapsed(offset: customer.phone.length),
    );
    if (customer.name.isNotEmpty) name.text = customer.name;
    phoneFocus.unfocus();
    setState(() => phoneSuggestions = const []);
  }

  Future<void> save() async {
    final session = context.read<AppSession>();
    final invoices = context.read<InvoiceRepository>();
    final catalog = context.read<ProductCatalog>();

    if (session.cart.isEmpty || saving) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    final soldLines = session.cart
        .map((line) => CartLine(product: line.product, quantity: line.quantity))
        .toList(growable: false);

    setState(() => saving = true);
    try {
      final invoice = await invoices.create(
        lines: soldLines,
        payment: payment,
        customerName: name.text,
        customerPhone: phone.text,
        taxRate: 0,
      );

      if (!mounted) return;
      await _rememberCustomer();
      catalog.applySale(soldLines);
      session.clearCart();

      if (!mounted) return;
      context.go('/invoice/${invoice.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    final isDeferred = payment == PaymentType.deferred;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إكمال البيع'),
        actions: [
          if (session.cart.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: ZColors.greenSoft,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${session.cartCount} قطعة',
                    style: const TextStyle(
                      color: ZColors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 150),
          children: [
            _CheckoutHero(session: session, payment: payment),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'المنتجات',
              trailing: session.cart.isEmpty ? null : '${session.cart.length} صنف',
            ),
            const SizedBox(height: 10),
            if (session.cart.isEmpty)
              const _EmptyCart()
            else
              ...session.cart.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CartLineCard(line: line, session: session),
                ),
              ),
            const SizedBox(height: 22),
            const _SectionHeader(
              title: 'طريقة الدفع',
              subtitle: 'اختر كيف سيتم إغلاق الفاتورة',
            ),
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
            _SectionHeader(
              title: 'بيانات العميل',
              subtitle: isDeferred
                  ? 'مطلوبة لتتبع الدين بدقة'
                  : 'اختيارية ويمكن إرسال الفاتورة بها',
              trailing: isDeferred ? 'مطلوبة' : 'اختيارية',
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(9),
                    ],
                    decoration: InputDecoration(
                      labelText: isDeferred ? 'رقم جوال العميل *' : 'رقم جوال العميل',
                      hintText: '771234567',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      suffixIcon: savedCustomers.isEmpty
                          ? null
                          : const Tooltip(
                              message: 'الأرقام المستخدمة سابقًا محفوظة على هذا الجهاز',
                              child: Icon(Icons.history_rounded),
                            ),
                    ),
                    validator: (value) {
                      final cleaned = _digitsOnly(value ?? '');
                      if (!isDeferred && cleaned.isEmpty) return null;
                      if (!RegExp(r'^7\d{8}$').hasMatch(cleaned)) {
                        return 'استخدم رقمًا يمنيًا من 9 أرقام يبدأ بـ7';
                      }
                      return null;
                    },
                  ),
                  if (phoneSuggestions.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    _PhoneSuggestions(
                      query: _digitsOnly(phone.text),
                      suggestions: phoneSuggestions,
                      onSelected: _selectSavedCustomer,
                    ),
                  ] else if (phoneFocus.hasFocus && phone.text.isNotEmpty && phone.text.length < 3) ...[
                    const SizedBox(height: 7),
                    const Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        'اكتب أول 3 أرقام لعرض الأرقام المستخدمة سابقًا.',
                        style: TextStyle(fontSize: 10.5, color: ZColors.subtle),
                      ),
                    ),
                  ],
                  if (isDeferred) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: ZColors.warningSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_outlined, size: 18, color: ZColors.yellowText),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'رقم الجوال هو المفتاح الذي يجمع ديون العميل وفواتيره.',
                              style: TextStyle(
                                fontSize: 10.8,
                                height: 1.45,
                                color: ZColors.yellowText,
                                fontWeight: FontWeight.w700,
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
            const SizedBox(height: 22),
            const _SectionHeader(
              title: 'ملخص الفاتورة',
              subtitle: 'راجع الأرقام قبل الحفظ',
            ),
            const SizedBox(height: 10),
            _InvoiceSummary(session: session, payment: payment),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 11, 20, 13),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE5E8EE))),
            boxShadow: [
              BoxShadow(
                color: Color(0x101A3C34),
                blurRadius: 24,
                offset: Offset(0, -7),
              ),
            ],
          ),
          child: FilledButton(
            onPressed: saving || session.cart.isEmpty ? null : save,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (saving)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                else
                  Icon(
                    isDeferred
                        ? Icons.receipt_long_rounded
                        : Icons.check_circle_rounded,
                    size: 20,
                  ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    saving
                        ? 'نحفظ الفاتورة...'
                        : isDeferred
                            ? 'حفظ كبيع آجل • ${session.cartSubtotal.toStringAsFixed(0)} ر.ي'
                            : 'إتمام البيع • ${session.cartSubtotal.toStringAsFixed(0)} ر.ي',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _PhoneSuggestions extends StatelessWidget {
  const _PhoneSuggestions({
    required this.query,
    required this.suggestions,
    required this.onSelected,
  });

  final String query;
  final List<_SavedCustomer> suggestions;
  final ValueChanged<_SavedCustomer> onSelected;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E8EE)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x141A3C34),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, size: 17, color: ZColors.green),
                  const SizedBox(width: 7),
                  const Expanded(
                    child: Text(
                      'أرقام سابقة مطابقة',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: ZColors.green,
                      ),
                    ),
                  ),
                  Text(
                    '${suggestions.length}',
                    style: const TextStyle(fontSize: 10, color: ZColors.subtle),
                  ),
                ],
              ),
            ),
            const Divider(),
            ...suggestions.asMap().entries.map((entry) {
              final customer = entry.value;
              return Column(
                children: [
                  InkWell(
                    onTap: () => onSelected(customer),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: ZColors.greenSoft,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Icon(Icons.person_rounded, size: 18, color: ZColors.green),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: _HighlightedPhone(phone: customer.phone, query: query),
                                ),
                                if (customer.name.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    customer.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10.8, color: ZColors.muted),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(Icons.north_west_rounded, size: 17, color: ZColors.subtle),
                        ],
                      ),
                    ),
                  ),
                  if (entry.key != suggestions.length - 1)
                    const Divider(indent: 58),
                ],
              );
            }),
          ],
        ),
      );
}

class _HighlightedPhone extends StatelessWidget {
  const _HighlightedPhone({required this.phone, required this.query});

  final String phone;
  final String query;

  @override
  Widget build(BuildContext context) {
    final prefixLength = query.length > phone.length ? phone.length : query.length;
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 13,
          letterSpacing: .35,
          color: ZColors.text,
          fontWeight: FontWeight.w700,
        ),
        children: [
          TextSpan(
            text: phone.substring(0, prefixLength),
            style: const TextStyle(color: ZColors.green, fontWeight: FontWeight.w900),
          ),
          TextSpan(text: phone.substring(prefixLength)),
        ],
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
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF1A3C34), ZColors.green],
          ),
          boxShadow: ZShadow.float,
        ),
        child: Stack(
          children: [
            PositionedDirectional(
              top: -40,
              start: -30,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x12FFFFFF)),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: ZColors.yellow,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.shopping_bag_rounded, color: ZColors.green),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ملخص البيع',
                            style: TextStyle(
                              color: Color(0xFFDDEAE6),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            payment == PaymentType.cash ? 'بيع نقدي' : 'بيع آجل',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0x1FFFFFFF),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${session.cartCount} قطعة',
                        style: const TextStyle(
                          color: ZColors.yellow,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'الإجمالي',
                  style: TextStyle(color: Color(0xFFC5D7D2), fontSize: 11.5),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    '${session.cartSubtotal.toStringAsFixed(0)} ر.ي',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 31,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: ZColors.green,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 10.5, color: ZColors.subtle),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: ZColors.surfaceSoft,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                trailing!,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: ZColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      );
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E8EE)),
          boxShadow: ZShadow.card,
        ),
        child: const Column(
          children: [
            Icon(Icons.shopping_bag_outlined, size: 42, color: ZColors.subtle),
            SizedBox(height: 10),
            Text('السلة فارغة', style: TextStyle(fontWeight: FontWeight.w900)),
            SizedBox(height: 4),
            Text(
              'ارجع لشاشة البيع وامسح أول منتج.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: ZColors.muted),
            ),
          ],
        ),
      );
}

class _CartLineCard extends StatelessWidget {
  const _CartLineCard({required this.line, required this.session});

  final CartLine line;
  final AppSession session;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E8EE)),
          boxShadow: ZShadow.card,
        ),
        child: Row(
          children: [
            _CartProductThumb(product: line.product),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${line.product.price.toStringAsFixed(0)} ر.ي للوحدة',
                    style: const TextStyle(fontSize: 10.5, color: ZColors.muted),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${line.total.toStringAsFixed(0)} ر.ي',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: ZColors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: ZColors.surfaceSoft,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: const Color(0xFFE5E8EE)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _QtyButton(
                    icon: Icons.remove_rounded,
                    onPressed: () => session.decrement(line),
                  ),
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${line.quantity}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  _QtyButton(
                    icon: Icons.add_rounded,
                    onPressed: () => session.increment(line),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _CartProductThumb extends StatelessWidget {
  const _CartProductThumb({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final resolved = _resolveImageUrl(product.imageUrl);
    final fallback = Container(
      color: ZColors.surfaceSoft,
      alignment: Alignment.center,
      child: const Icon(Icons.inventory_2_outlined, color: ZColors.greenMid),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 58,
        height: 58,
        child: resolved == null
            ? fallback
            : Image.network(
                resolved,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(icon, size: 17, color: ZColors.green),
      );
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

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
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected ? ZColors.green : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? ZColors.gold : const Color(0xFFE5E8EE),
                width: selected ? 1.3 : 1,
              ),
              boxShadow: selected ? ZShadow.float : ZShadow.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selected ? ZColors.yellow : ZColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: ZColors.green, size: 20),
                    ),
                    const Spacer(),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? ZColors.yellow : Colors.transparent,
                        border: Border.all(
                          color: selected ? ZColors.yellow : ZColors.line,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded, size: 14, color: ZColors.green)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: selected ? Colors.white : ZColors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.8,
                    color: selected ? const Color(0xFFC5D7D2) : ZColors.muted,
                  ),
                ),
              ],
            ),
          ),
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E8EE)),
          boxShadow: ZShadow.card,
        ),
        child: Column(
          children: [
            _SummaryRow(label: 'عدد القطع', value: '${session.cartCount}'),
            const SizedBox(height: 10),
            _SummaryRow(label: 'طريقة الدفع', value: payment.label),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(),
            ),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'الإجمالي',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${session.cartSubtotal.toStringAsFixed(0)} ر.ي',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: ZColors.green,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: ZColors.muted)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      );
}

class _SavedCustomer {
  const _SavedCustomer({required this.phone, required this.name});

  final String phone;
  final String name;

  factory _SavedCustomer.fromJson(Map<String, dynamic> json) => _SavedCustomer(
        phone: _digitsOnly('${json['phone'] ?? ''}'),
        name: '${json['name'] ?? ''}'.trim(),
      );

  Map<String, dynamic> toJson() => {'phone': phone, 'name': name};
}

String _digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

bool _sameSuggestions(List<_SavedCustomer> a, List<_SavedCustomer> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].phone != b[i].phone || a[i].name != b[i].name) return false;
  }
  return true;
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
