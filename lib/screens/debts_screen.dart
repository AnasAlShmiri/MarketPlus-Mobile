import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../data/models.dart';
import '../data/repositories.dart';
import '../state/app_session.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  late Future<List<Invoice>> future;
  final searchController = TextEditingController();
  bool initialized = false;
  String query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      initialized = true;
      future = context.read<InvoiceRepository>().debts();
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    setState(() => future = context.read<InvoiceRepository>().debts());
    await future;
  }

  List<Invoice> filterDebts(List<Invoice> debts) {
    final raw = query.trim();
    if (raw.isEmpty) return debts;

    final normalized = raw.toLowerCase();
    final compactQuery = _compactSearchValue(normalized);

    return debts.where((invoice) {
      final number = invoice.number.toLowerCase();
      final customer = (invoice.customerName ?? '').trim().toLowerCase();
      return number.contains(normalized) ||
          customer.contains(normalized) ||
          _compactSearchValue(number).contains(compactQuery);
    }).toList(growable: false);
  }

  Future<void> recordPartialPayment(Invoice invoice) async {
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل دفعة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'المتبقي ${invoice.remainingAmount.toStringAsFixed(0)} ر.ي',
              style: const TextStyle(color: ZColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'مبلغ الدفعة',
                suffixText: 'ر.ي',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value == null || value <= 0 || value > invoice.remainingAmount) {
                return;
              }
              Navigator.pop(dialogContext, value);
            },
            child: const Text('تسجيل'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null || !mounted) return;

    try {
      final updated = await context
          .read<InvoiceRepository>()
          .recordPayment(invoice.id, amount);
      if (!mounted) return;
      final message = updated.remainingAmount <= 0
          ? 'تم تحصيل الدين كاملًا.'
          : 'تم تسجيل الدفعة. المتبقي ${updated.remainingAmount.toStringAsFixed(0)} ر.ي.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      await refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> settle(Invoice invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد استلام كامل الرصيد'),
        content: Text(
          'هل استلمت ${invoice.remainingAmount.toStringAsFixed(0)} ر.ي المتبقية للفاتورة ${invoice.number}؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ليس الآن'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('نعم، تم السداد'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<InvoiceRepository>().settle(invoice.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل السداد الكامل بنجاح.')),
      );
      await refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AppSession>().user?.isAdmin == true;

    return FutureBuilder<List<Invoice>>(
      future: future,
      builder: (context, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        final debts = snap.data ?? const <Invoice>[];
        final filtered = filterDebts(debts);
        final total = debts.fold<double>(
          0,
          (sum, invoice) => sum + invoice.remainingAmount,
        );

        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
            children: [
              Text('الديون', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                isAdmin
                    ? 'تابع الرصيد وسجّل الدفعات بدون فقدان سجل التحصيل.'
                    : 'شاهد الفواتير التي ما زالت بانتظار السداد.',
                style: const TextStyle(color: ZColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _DebtSummary(total: total, count: debts.length),
              const SizedBox(height: 14),
              _DebtSearchField(
                controller: searchController,
                query: query,
                resultCount: filtered.length,
                totalCount: debts.length,
                onChanged: (value) => setState(() => query = value),
                onClear: () {
                  searchController.clear();
                  setState(() => query = '');
                },
              ),
              const SizedBox(height: 20),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(50),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snap.hasError)
                const _MessageState(
                  icon: Icons.cloud_off_outlined,
                  title: 'ما قدرنا نعرض الديون الآن',
                  subtitle: 'اسحب الشاشة للأسفل وحاول مرة أخرى.',
                )
              else if (debts.isEmpty)
                const _MessageState(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'ممتاز، ما في ديون مفتوحة',
                  subtitle: 'كل الفواتير الآجلة مسددة حاليًا.',
                )
              else if (filtered.isEmpty)
                _MessageState(
                  icon: Icons.search_off_rounded,
                  title: 'ما لقينا نتيجة',
                  subtitle: 'لا توجد فاتورة أو عميل يطابق «${query.trim()}».',
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        query.trim().isEmpty ? 'بانتظار السداد' : 'نتائج البحث',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: ZColors.green,
                        ),
                      ),
                    ),
                    Text(
                      '${filtered.length} فاتورة',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: ZColors.subtle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...filtered.map(
                  (invoice) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DebtCard(
                      invoice: invoice,
                      canCollect: isAdmin,
                      onOpen: () => context.push('/invoice/${invoice.id}'),
                      onPartial: () => recordPartialPayment(invoice),
                      onSettle: () => settle(invoice),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DebtSearchField extends StatelessWidget {
  const _DebtSearchField({
    required this.controller,
    required this.query,
    required this.resultCount,
    required this.totalCount,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final int resultCount;
  final int totalCount;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final searching = query.trim().isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: searching ? ZColors.green : const Color(0xFFE5E8EE),
          width: searching ? 1.3 : 1,
        ),
        boxShadow: ZShadow.card,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          hintText: 'ابحث برقم الفاتورة أو اسم العميل',
          hintStyle: const TextStyle(fontSize: 12, color: ZColors.subtle),
          prefixIcon: Container(
            margin: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: ZColors.greenSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.search_rounded, size: 20, color: ZColors.green),
          ),
          suffixIcon: searching
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: ZColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '$resultCount/$totalCount',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: ZColors.green,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'مسح البحث',
                      onPressed: onClear,
                      icon: const Icon(Icons.close_rounded, size: 19),
                    ),
                  ],
                )
              : null,
        ),
      ),
    );
  }
}

class _DebtSummary extends StatelessWidget {
  const _DebtSummary({required this.total, required this.count});

  final double total;
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ZRadius.hero),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [ZColors.greenActive, ZColors.green],
          ),
          boxShadow: ZShadow.float,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: ZColors.yellow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: ZColors.green,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'إجمالي الرصيد المتبقي',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFDDEAE6),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0x1FFFFFFF),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$count فاتورة',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: ZColors.yellow,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '${total.toStringAsFixed(0)} ر.ي',
                style: const TextStyle(
                  fontSize: 30,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
}

class _DebtCard extends StatelessWidget {
  const _DebtCard({
    required this.invoice,
    required this.canCollect,
    required this.onOpen,
    required this.onPartial,
    required this.onSettle,
  });

  final Invoice invoice;
  final bool canCollect;
  final VoidCallback onOpen;
  final VoidCallback onPartial;
  final VoidCallback onSettle;

  @override
  Widget build(BuildContext context) {
    final customer = (invoice.customerName ?? '').trim().isEmpty
        ? 'عميل بدون اسم'
        : invoice.customerName!.trim();
    final phone = (invoice.customerPhone ?? '').trim().isEmpty
        ? 'بدون رقم جوال'
        : invoice.customerPhone!.trim();
    final paidRatio = invoice.total <= 0
        ? 0.0
        : (invoice.paidAmount / invoice.total).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ZRadius.lg),
        border: Border.all(color: const Color(0xFFE5E8EE)),
        boxShadow: ZShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: invoice.paidAmount > 0
                      ? ZColors.successSoft
                      : ZColors.warningSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  invoice.paidAmount > 0
                      ? Icons.savings_outlined
                      : Icons.schedule_rounded,
                  color: invoice.paidAmount > 0
                      ? ZColors.success
                      : ZColors.yellowText,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: ZColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ZColors.background,
              borderRadius: BorderRadius.circular(ZRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text(
                      'المتبقي',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: ZColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerEnd,
                        child: Text(
                          '${invoice.remainingAmount.toStringAsFixed(0)} ر.ي',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: ZColors.danger,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: paidRatio,
                    minHeight: 5,
                    backgroundColor: const Color(0xFFDFE5E2),
                    valueColor: const AlwaysStoppedAnimation<Color>(ZColors.gold),
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        invoice.paidAmount > 0
                            ? 'تم تحصيل ${invoice.paidAmount.toStringAsFixed(0)} من ${invoice.total.toStringAsFixed(0)} ر.ي'
                            : 'لم تُسجّل أي دفعة بعد',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: invoice.paidAmount > 0
                              ? ZColors.success
                              : ZColors.subtle,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        _compactInvoiceNumber(invoice.number),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: ZColors.subtle,
                          letterSpacing: .1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: const Text('عرض الفاتورة'),
          ),
          if (canCollect) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPartial,
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    label: const Text('دفعة'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onSettle,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('سداد كامل'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _compactInvoiceNumber(String value) {
  final number = value.trim();
  if (number.length <= 20) return number;
  return '${number.substring(0, 12)}…${number.substring(number.length - 5)}';
}

String _compactSearchValue(String value) =>
    value.replaceAll(RegExp(r'[\s\-_]'), '');

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 54),
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: ZColors.greenSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, size: 32, color: ZColors.green),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: ZColors.muted),
            ),
          ],
        ),
      );
}
