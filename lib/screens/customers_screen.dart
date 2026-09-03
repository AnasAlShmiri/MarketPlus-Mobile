import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../data/models.dart';
import '../data/repositories.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final search = TextEditingController();
  Future<List<CustomerSummary>>? future;
  String query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= context.read<CustomerRepository>().all();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    final next = context.read<CustomerRepository>().all();
    setState(() => future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CustomerSummary>>(
      future: future,
      builder: (context, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        final customers = snap.data ?? const <CustomerSummary>[];
        final normalized = query.trim().toLowerCase();
        final filtered = customers.where((customer) {
          if (normalized.isEmpty) return true;
          return customer.displayName.toLowerCase().contains(normalized) ||
              customer.phone.contains(normalized);
        }).toList(growable: false);
        final totalOutstanding = customers.fold<double>(
          0,
          (sum, customer) => sum + customer.outstandingAmount,
        );
        final withDebt = customers.where((customer) => customer.hasDebt).length;

        return RefreshIndicator(
          onRefresh: refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                sliver: SliverList.list(
                  children: [
                    Text('العملاء', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    const Text(
                      'كل عميل وفواتيره ورصيده في مكان واحد.',
                      style: TextStyle(fontSize: 12.5, color: ZColors.muted),
                    ),
                    const SizedBox(height: 18),
                    _CustomersHero(
                      customerCount: customers.length,
                      withDebt: withDebt,
                      totalOutstanding: totalOutstanding,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: search,
                      onChanged: (value) => setState(() => query = value),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'ابحث بالاسم أو رقم الجوال',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'مسح البحث',
                                onPressed: () {
                                  search.clear();
                                  setState(() => query = '');
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'دليل العملاء',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: ZColors.green,
                            ),
                          ),
                        ),
                        if (!loading)
                          Text(
                            '${filtered.length} عميل',
                            style: const TextStyle(fontSize: 10.5, color: ZColors.subtle),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snap.hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _CustomerEmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'تعذر تحميل العملاء',
                    subtitle: 'تأكد من تشغيل الخادم ثم اسحب للأسفل للمحاولة مرة أخرى.',
                    actionLabel: 'إعادة المحاولة',
                    onAction: refresh,
                  ),
                )
              else if (customers.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _CustomerEmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'لا يوجد عملاء بعد',
                    subtitle: 'عند إنشاء فاتورة برقم جوال سيظهر العميل هنا تلقائيًا.',
                  ),
                )
              else if (filtered.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _CustomerEmptyState(
                    icon: Icons.person_search_rounded,
                    title: 'لا توجد نتيجة مطابقة',
                    subtitle: 'جرّب اسمًا آخر أو جزءًا مختلفًا من رقم الجوال.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 112),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final customer = filtered[index];
                      return _CustomerCard(
                        customer: customer,
                        onTap: () => context.push(
                          '/customer/${Uri.encodeComponent(customer.phone)}',
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class CustomerDetailsScreen extends StatefulWidget {
  const CustomerDetailsScreen({super.key, required this.phone});

  final String phone;

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  Future<CustomerDetails>? future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= context.read<CustomerRepository>().byPhone(widget.phone);
  }

  Future<void> refresh() async {
    final next = context.read<CustomerRepository>().byPhone(widget.phone);
    setState(() => future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('تفاصيل العميل')),
        body: FutureBuilder<CustomerDetails>(
          future: future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError || snap.data == null) {
              return _CustomerEmptyState(
                icon: Icons.person_off_outlined,
                title: 'تعذر تحميل ملف العميل',
                subtitle: 'أعد المحاولة بعد التأكد من الاتصال بالخادم.',
                actionLabel: 'إعادة المحاولة',
                onAction: refresh,
              );
            }

            final details = snap.data!;
            final customer = details.summary;
            return RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
                children: [
                  _CustomerProfileHero(customer: customer),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          label: 'إجمالي المشتريات',
                          value: _money(customer.totalPurchases, customer.currencySymbol),
                          icon: Icons.shopping_bag_rounded,
                          background: ZColors.greenSoft,
                          foreground: ZColors.green,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricCard(
                          label: 'الرصيد المتبقي',
                          value: _money(customer.outstandingAmount, customer.currencySymbol),
                          icon: Icons.account_balance_wallet_rounded,
                          background: customer.hasDebt ? ZColors.dangerSoft : ZColors.successSoft,
                          foreground: customer.hasDebt ? ZColors.danger : ZColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _ActivityStrip(customer: customer),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'سجل الفواتير',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: ZColors.green,
                          ),
                        ),
                      ),
                      Text(
                        '${details.invoices.length} فاتورة',
                        style: const TextStyle(fontSize: 10.5, color: ZColors.subtle),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...details.invoices.map(
                    (invoice) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _InvoiceHistoryCard(
                        invoice: invoice,
                        onTap: () => context.push('/invoice/${invoice.id}'),
                      ),
                    ),
                  ),
                  if (customer.hasDebt) ...[
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => context.go('/debts'),
                      icon: const Icon(Icons.account_balance_wallet_rounded),
                      label: const Text('فتح الديون والتحصيل'),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      );
}

class _CustomersHero extends StatelessWidget {
  const _CustomersHero({
    required this.customerCount,
    required this.withDebt,
    required this.totalOutstanding,
  });

  final int customerCount;
  final int withDebt;
  final double totalOutstanding;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
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
              top: -54,
              start: -42,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x14FFFFFF)),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: ZColors.yellow,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(Icons.groups_rounded, color: ZColors.green),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'قاعدة عملائك',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFDDEAE6),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$customerCount عميل مسجل من الفواتير',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _HeroStat(label: 'عليهم رصيد', value: '$withDebt'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _HeroStat(
                        label: 'إجمالي المتبقي',
                        value: '${totalOutstanding.toStringAsFixed(0)} ر.ي',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0x13FFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x18FFFFFF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFFC5D7D2))),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: ZColors.yellow,
                ),
              ),
            ),
          ],
        ),
      );
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer, required this.onTap});

  final CustomerSummary customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E8EE)),
              boxShadow: ZShadow.card,
            ),
            child: Row(
              children: [
                _Avatar(initial: customer.initial, hasDebt: customer.hasDebt),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          customer.phone,
                          textAlign: TextAlign.left,
                          style: const TextStyle(fontSize: 11.5, color: ZColors.muted),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${customer.invoiceCount} فاتورة • آخر نشاط ${_shortDate(customer.latestActivityAt)}',
                        style: const TextStyle(fontSize: 10.5, color: ZColors.subtle),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: customer.hasDebt ? ZColors.dangerSoft : ZColors.successSoft,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        customer.hasDebt
                            ? '${customer.outstandingAmount.toStringAsFixed(0)} ${customer.currencySymbol}'
                            : 'مسدد',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: customer.hasDebt ? ZColors.danger : ZColors.success,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Icon(Icons.chevron_left_rounded, color: ZColors.subtle),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class _CustomerProfileHero extends StatelessWidget {
  const _CustomerProfileHero({required this.customer});
  final CustomerSummary customer;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF1A3C34), ZColors.green],
          ),
          boxShadow: ZShadow.float,
        ),
        child: Row(
          children: [
            Container(
              width: 66,
              height: 66,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ZColors.yellow,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x55FFFFFF), width: 2),
              ),
              child: Text(
                customer.initial,
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  color: ZColors.green,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            customer.phone,
                            textAlign: TextAlign.left,
                            style: const TextStyle(fontSize: 12, color: Color(0xFFDDEAE6)),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'نسخ رقم الجوال',
                        style: IconButton.styleFrom(
                          foregroundColor: ZColors.yellow,
                          backgroundColor: const Color(0x18FFFFFF),
                        ),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: customer.phone));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم نسخ رقم الجوال.')),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    customer.hasDebt
                        ? '${customer.openInvoiceCount} فاتورة بانتظار السداد'
                        : 'لا يوجد رصيد مستحق حاليًا',
                    style: TextStyle(
                      fontSize: 10.8,
                      fontWeight: FontWeight.w800,
                      color: customer.hasDebt ? ZColors.yellow : const Color(0xFFC5D7D2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ActivityStrip extends StatelessWidget {
  const _ActivityStrip({required this.customer});
  final CustomerSummary customer;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E8EE)),
          boxShadow: ZShadow.card,
        ),
        child: Row(
          children: [
            Expanded(
              child: _ActivityItem(
                label: 'عدد الفواتير',
                value: '${customer.invoiceCount}',
                icon: Icons.receipt_long_rounded,
              ),
            ),
            Container(width: 1, height: 38, color: const Color(0xFFE5E8EE)),
            Expanded(
              child: _ActivityItem(
                label: 'أول شراء',
                value: _shortDate(customer.firstPurchaseAt),
                icon: Icons.event_available_rounded,
              ),
            ),
            Container(width: 1, height: 38, color: const Color(0xFFE5E8EE)),
            Expanded(
              child: _ActivityItem(
                label: 'آخر نشاط',
                value: _shortDate(customer.latestActivityAt),
                icon: Icons.history_rounded,
              ),
            ),
          ],
        ),
      );
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, size: 18, color: ZColors.green),
          const SizedBox(height: 5),
          Text(value, maxLines: 1, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, style: const TextStyle(fontSize: 9.5, color: ZColors.subtle)),
        ],
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E8EE)),
          boxShadow: ZShadow.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, size: 19, color: foreground),
            ),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontSize: 10.5, color: ZColors.muted)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                value,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: foreground),
              ),
            ),
          ],
        ),
      );
}

class _InvoiceHistoryCard extends StatelessWidget {
  const _InvoiceHistoryCard({required this.invoice, required this.onTap});
  final Invoice invoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final deferred = invoice.paymentType == 2;
    final hasBalance = deferred && invoice.remainingAmount > 0;
    final statusLabel = hasBalance
        ? (invoice.paidAmount > 0 ? 'مدفوع جزئيًا' : 'آجل')
        : 'مدفوعة';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E8EE)),
            boxShadow: ZShadow.card,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: hasBalance ? ZColors.warningSurface : ZColors.successSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  hasBalance ? Icons.schedule_rounded : Icons.receipt_long_rounded,
                  color: hasBalance ? ZColors.yellowText : ZColors.success,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        _compactInvoice(invoice.number),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.left,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_shortDate(invoice.createdAt)} • $statusLabel',
                      style: const TextStyle(fontSize: 10.5, color: ZColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${invoice.total.toStringAsFixed(0)} ر.ي',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: ZColors.green),
                  ),
                  if (hasBalance) ...[
                    const SizedBox(height: 3),
                    Text(
                      'متبقي ${invoice.remainingAmount.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 9.5, color: ZColors.danger, fontWeight: FontWeight.w800),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_left_rounded, size: 20, color: ZColors.subtle),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, required this.hasDebt});
  final String initial;
  final bool hasDebt;

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF234E43), ZColors.green],
              ),
              shape: BoxShape.circle,
            ),
            child: Text(
              initial,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: ZColors.yellow),
            ),
          ),
          PositionedDirectional(
            end: -1,
            bottom: -1,
            child: Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: hasDebt ? ZColors.danger : ZColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
              ),
            ),
          ),
        ],
      );
}

class _CustomerEmptyState extends StatelessWidget {
  const _CustomerEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: ZColors.greenSoft,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(icon, size: 32, color: ZColors.green),
              ),
              const SizedBox(height: 14),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, height: 1.55, color: ZColors.muted),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => onAction!(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      );
}

String _shortDate(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year}';
}

String _money(double value, String symbol) => '${value.toStringAsFixed(0)} $symbol';

String _compactInvoice(String value) {
  if (value.length <= 22) return value;
  return '${value.substring(0, 13)}…${value.substring(value.length - 6)}';
}
