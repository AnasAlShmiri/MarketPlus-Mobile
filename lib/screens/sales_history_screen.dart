import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../data/models.dart';
import '../data/operations_models.dart';
import '../data/repositories.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final search = TextEditingController();
  Timer? debounce;
  Future<SalesHistoryPage>? future;
  PaymentType? payment;
  int? status;
  _SalesRange range = _SalesRange.today;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= _load();
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  DateTime? get from {
    final now = DateTime.now();
    return switch (range) {
      _SalesRange.all => null,
      _SalesRange.today => DateTime(now.year, now.month, now.day),
      _SalesRange.week => DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6)),
      _SalesRange.month => DateTime(now.year, now.month, 1),
    };
  }

  DateTime? get to => range == _SalesRange.all ? null : DateTime.now();

  Future<SalesHistoryPage> _load() => context.read<InvoiceRepository>().history(
        query: search.text,
        from: from,
        to: to,
        payment: payment,
        status: status,
        pageSize: 100,
      );

  void reload() => setState(() => future = _load());

  void onSearch(String _) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 280), reload);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('سجل المبيعات')),
        body: RefreshIndicator(
          onRefresh: () async {
            final next = _load();
            setState(() => future = next);
            await next;
          },
          child: FutureBuilder<SalesHistoryPage>(
            future: future,
            builder: (context, snap) {
              final data = snap.data;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
                children: [
                  _SalesHero(summary: data?.summary, count: data?.totalCount ?? 0),
                  const SizedBox(height: 14),
                  TextField(
                    controller: search,
                    onChanged: onSearch,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'رقم الفاتورة، اسم العميل أو رقم الجوال',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: search.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                search.clear();
                                reload();
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FilterBar(
                    range: range,
                    payment: payment,
                    status: status,
                    onRange: (value) {
                      range = value;
                      reload();
                    },
                    onPayment: (value) {
                      payment = value;
                      reload();
                    },
                    onStatus: (value) {
                      status = value;
                      reload();
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'الفواتير',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ZColors.green),
                        ),
                      ),
                      if (data != null)
                        Text('${data.totalCount} فاتورة', style: const TextStyle(fontSize: 11, color: ZColors.subtle)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (snap.connectionState == ConnectionState.waiting && data == null)
                    const _LoadingSales()
                  else if (snap.hasError && data == null)
                    _EmptySales(
                      icon: Icons.cloud_off_rounded,
                      title: 'تعذر تحميل سجل المبيعات',
                      subtitle: '${snap.error}',
                    )
                  else if (data == null || data.items.isEmpty)
                    const _EmptySales(
                      icon: Icons.receipt_long_outlined,
                      title: 'لا توجد فواتير مطابقة',
                      subtitle: 'غيّر البحث أو الفلاتر لعرض عمليات أخرى.',
                    )
                  else
                    ...data.items.map(
                      (invoice) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SaleCard(
                          invoice: invoice,
                          onTap: () => context.push('/invoice/${invoice.id}'),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      );
}

class _SalesHero extends StatelessWidget {
  const _SalesHero({required this.summary, required this.count});
  final SalesHistorySummary? summary;
  final int count;

  @override
  Widget build(BuildContext context) {
    final value = summary;
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: ZColors.yellow, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.receipt_long_rounded, color: ZColors.green),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('سجل المبيعات', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                    SizedBox(height: 2),
                    Text('كل عملية بيع في مكان واحد', style: TextStyle(color: Color(0xFFC5D7D2), fontSize: 10.5)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(color: const Color(0x18FFFFFF), borderRadius: BorderRadius.circular(99)),
                child: Text('$count', style: const TextStyle(color: ZColors.yellow, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('إجمالي المبيعات', style: TextStyle(color: Color(0xFFC5D7D2), fontSize: 10.5)),
          const SizedBox(height: 2),
          Text(
            '${(value?.totalSales ?? 0).toStringAsFixed(0)} ر.ي',
            style: const TextStyle(color: Colors.white, fontSize: 29, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _MiniStat(label: 'نقدي', value: value?.cashSales ?? 0)),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat(label: 'آجل', value: value?.deferredSales ?? 0)),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat(label: 'متبقي', value: value?.outstanding ?? 0)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0x13FFFFFF),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0x14FFFFFF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFFC5D7D2), fontSize: 9.5)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text('${value.toStringAsFixed(0)} ر.ي', style: const TextStyle(color: ZColors.yellow, fontSize: 12, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.range,
    required this.payment,
    required this.status,
    required this.onRange,
    required this.onPayment,
    required this.onStatus,
  });
  final _SalesRange range;
  final PaymentType? payment;
  final int? status;
  final ValueChanged<_SalesRange> onRange;
  final ValueChanged<PaymentType?> onPayment;
  final ValueChanged<int?> onStatus;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _SalesRange.values.map((item) => Padding(
                padding: const EdgeInsetsDirectional.only(end: 7),
                child: ChoiceChip(
                  label: Text(item.label),
                  selected: range == item,
                  onSelected: (_) => onRange(item),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<PaymentType?>(
                  initialValue: payment,
                  decoration: const InputDecoration(labelText: 'الدفع', isDense: true),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('الكل')),
                    DropdownMenuItem(value: PaymentType.cash, child: Text('نقدي')),
                    DropdownMenuItem(value: PaymentType.deferred, child: Text('آجل')),
                  ],
                  onChanged: onPayment,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'الحالة', isDense: true),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('الكل')),
                    DropdownMenuItem(value: 1, child: Text('معلقة')),
                    DropdownMenuItem(value: 2, child: Text('مدفوعة')),
                    DropdownMenuItem(value: 3, child: Text('جزئية')),
                  ],
                  onChanged: onStatus,
                ),
              ),
            ],
          ),
        ],
      );
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({required this.invoice, required this.onTap});
  final Invoice invoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = (invoice.customerName ?? '').trim().isEmpty ? 'بيع بدون اسم عميل' : invoice.customerName!.trim();
    final status = switch (invoice.status) { 2 => 'مدفوعة', 3 => 'جزئية', 4 => 'ملغاة', _ => 'معلقة' };
    final statusColor = switch (invoice.status) { 2 => ZColors.success, 3 => ZColors.yellowText, 4 => ZColors.danger, _ => ZColors.muted };
    return Material(
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
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: ZColors.greenSoft, borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.receipt_rounded, color: ZColors.green),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                    const SizedBox(height: 3),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        invoice.number,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.left,
                        style: const TextStyle(fontSize: 9.5, color: ZColors.subtle),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(DateFormat('yyyy/MM/dd • HH:mm').format(invoice.createdAt.toLocal()), style: const TextStyle(fontSize: 10, color: ZColors.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${invoice.total.toStringAsFixed(0)} ر.ي', style: const TextStyle(fontWeight: FontWeight.w900, color: ZColors.green)),
                  const SizedBox(height: 5),
                  Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingSales extends StatelessWidget {
  const _LoadingSales();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 56),
        child: Center(child: CircularProgressIndicator()),
      );
}

class _EmptySales extends StatelessWidget {
  const _EmptySales({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 42),
        child: Column(
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(color: ZColors.greenSoft, borderRadius: BorderRadius.circular(18)),
              child: Icon(icon, size: 30, color: ZColors.green),
            ),
            const SizedBox(height: 11),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, color: ZColors.muted)),
          ],
        ),
      );
}

enum _SalesRange {
  today('اليوم'),
  week('7 أيام'),
  month('هذا الشهر'),
  all('الكل');

  const _SalesRange(this.label);
  final String label;
}
