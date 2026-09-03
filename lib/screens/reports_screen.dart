import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../data/operations_models.dart';
import '../data/repositories.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _ReportRange range = _ReportRange.today;
  Future<ReportSummary>? future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= _load();
  }

  ({DateTime? from, DateTime? to}) get dates {
    final now = DateTime.now();
    return switch (range) {
      _ReportRange.today => (from: DateTime(now.year, now.month, now.day), to: now),
      _ReportRange.week => (from: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6)), to: now),
      _ReportRange.month => (from: DateTime(now.year, now.month, 1), to: now),
      _ReportRange.all => (from: null, to: null),
    };
  }

  Future<ReportSummary> _load() {
    final selected = dates;
    return context.read<ReportRepository>().summary(from: selected.from, to: selected.to);
  }

  void reload() => setState(() => future = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('التقارير')),
        body: RefreshIndicator(
          onRefresh: () async {
            final next = _load();
            setState(() => future = next);
            await next;
          },
          child: FutureBuilder<ReportSummary>(
            future: future,
            builder: (context, snap) {
              final report = snap.data;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
                children: [
                  _ReportHero(report: report),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _ReportRange.values.map((item) => Padding(
                        padding: const EdgeInsetsDirectional.only(end: 7),
                        child: ChoiceChip(
                          label: Text(item.label),
                          selected: range == item,
                          onSelected: (_) {
                            range = item;
                            reload();
                          },
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (snap.connectionState == ConnectionState.waiting && report == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 70),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (snap.hasError && report == null)
                    _ReportMessage(icon: Icons.cloud_off_rounded, title: 'تعذر إعداد التقرير', subtitle: '${snap.error}')
                  else if (report != null) ...[
                    _MetricsGrid(report: report),
                    const SizedBox(height: 24),
                    const _Title('أكثر المنتجات مبيعًا', 'مرتب حسب عدد القطع في الفترة'),
                    const SizedBox(height: 10),
                    _TopProducts(items: report.list('topProducts')),
                    const SizedBox(height: 24),
                    const _Title('تنبيهات المخزون', 'المنتجات التي تحتاج انتباهك'),
                    const SizedBox(height: 10),
                    _LowStock(items: report.list('lowStock')),
                    const SizedBox(height: 24),
                    const _Title('آخر التحصيلات', 'دفعات الديون المسجلة في الفترة'),
                    const SizedBox(height: 10),
                    _Collections(items: report.list('recentCollections')),
                    const SizedBox(height: 24),
                    _CloseoutCard(report: report),
                  ],
                ],
              );
            },
          ),
        ),
      );
}

class _ReportHero extends StatelessWidget {
  const _ReportHero({required this.report});
  final ReportSummary? report;

  @override
  Widget build(BuildContext context) => Container(
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
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: ZColors.yellow, borderRadius: BorderRadius.circular(15)),
                  child: const Icon(Icons.insights_rounded, color: ZColors.green),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('نبض تجارتك', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                      SizedBox(height: 2),
                      Text('المبيعات والتحصيل والمخزون في نظرة واحدة', style: TextStyle(color: Color(0xFFC5D7D2), fontSize: 10.5)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text('إجمالي المبيعات', style: TextStyle(fontSize: 10.5, color: Color(0xFFC5D7D2))),
            const SizedBox(height: 2),
            Text(
              '${(report?.number('totalSales') ?? 0).toStringAsFixed(0)} ر.ي',
              style: const TextStyle(color: Colors.white, fontSize: 31, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _HeroValue(label: 'النقد المتوقع', value: report?.number('expectedCash') ?? 0)),
                const SizedBox(width: 8),
                Expanded(child: _HeroValue(label: 'الرصيد المتبقي', value: report?.number('allOutstanding') ?? 0)),
              ],
            ),
          ],
        ),
      );
}

class _HeroValue extends StatelessWidget {
  const _HeroValue({required this.label, required this.value});
  final String label;
  final double value;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0x13FFFFFF), borderRadius: BorderRadius.circular(13)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 9.5, color: Color(0xFFC5D7D2))),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text('${value.toStringAsFixed(0)} ر.ي', style: const TextStyle(color: ZColors.yellow, fontSize: 14, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.report});
  final ReportSummary report;

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.25,
        children: [
          _Metric(label: 'نقدي', value: '${report.number('cashSales').toStringAsFixed(0)} ر.ي', icon: Icons.payments_rounded, tone: ZColors.successSoft),
          _Metric(label: 'آجل', value: '${report.number('deferredSales').toStringAsFixed(0)} ر.ي', icon: Icons.schedule_rounded, tone: ZColors.warningSurface),
          _Metric(label: 'تحصيل ديون', value: '${report.number('collectedDebt').toStringAsFixed(0)} ر.ي', icon: Icons.savings_rounded, tone: ZColors.greenSoft),
          _Metric(label: 'الفواتير', value: '${report.integer('invoiceCount')}', icon: Icons.receipt_long_rounded, tone: ZColors.surfaceSoft),
          _Metric(label: 'متوسط الفاتورة', value: '${report.number('averageInvoice').toStringAsFixed(0)} ر.ي', icon: Icons.functions_rounded, tone: ZColors.surfaceSoft),
          _Metric(label: 'مخزون منخفض', value: '${report.integer('lowStockCount')}', icon: Icons.warning_amber_rounded, tone: ZColors.warningSurface),
        ],
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon, required this.tone});
  final String label;
  final String value;
  final IconData icon;
  final Color tone;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E8EE)), boxShadow: ZShadow.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 37, height: 37, decoration: BoxDecoration(color: tone, borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 19, color: ZColors.green)),
            const Spacer(),
            Text(label, style: const TextStyle(fontSize: 10.5, color: ZColors.muted)),
            const SizedBox(height: 2),
            FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ZColors.green))),
          ],
        ),
      );
}

class _Title extends StatelessWidget {
  const _Title(this.title, this.subtitle);
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

class _TopProducts extends StatelessWidget {
  const _TopProducts({required this.items});
  final List<Map<String, dynamic>> items;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _ReportMessage(icon: Icons.inventory_2_outlined, title: 'لا توجد مبيعات في الفترة', subtitle: 'ستظهر المنتجات الأكثر مبيعًا بعد تسجيل المبيعات.');
    return Column(
      children: List.generate(items.length, (index) {
        final item = items[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E8EE))),
          child: Row(
            children: [
              Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: index < 3 ? ZColors.yellow : ZColors.surfaceSoft, borderRadius: BorderRadius.circular(10)), child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w900, color: ZColors.green))),
              const SizedBox(width: 10),
              Expanded(child: Text('${item['name'] ?? 'منتج'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
              Text('${item['quantity'] ?? 0} قطعة', style: const TextStyle(fontSize: 11, color: ZColors.muted)),
            ],
          ),
        );
      }),
    );
  }
}

class _LowStock extends StatelessWidget {
  const _LowStock({required this.items});
  final List<Map<String, dynamic>> items;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _ReportMessage(icon: Icons.check_circle_outline_rounded, title: 'المخزون بحالة جيدة', subtitle: 'لا توجد منتجات تحت حد التنبيه الحالي.');
    return Column(
      children: items.take(8).map((item) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: ZColors.warningSurface, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: ZColors.yellowText),
            const SizedBox(width: 9),
            Expanded(child: Text('${item['name'] ?? 'منتج'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
            Text('${item['stockQuantity'] ?? 0} متبقي', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: ZColors.yellowText)),
          ],
        ),
      )).toList(),
    );
  }
}

class _Collections extends StatelessWidget {
  const _Collections({required this.items});
  final List<Map<String, dynamic>> items;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _ReportMessage(icon: Icons.savings_outlined, title: 'لا توجد تحصيلات في الفترة', subtitle: 'دفعات الديون الجديدة ستظهر هنا.');
    return Column(
      children: items.take(8).map((item) {
        final date = DateTime.tryParse('${item['createdAt'] ?? ''}')?.toLocal();
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E8EE))),
          child: Row(
            children: [
              Container(width: 38, height: 38, decoration: BoxDecoration(color: ZColors.successSoft, borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.savings_rounded, color: ZColors.success, size: 19)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item['customerName'] ?? 'عميل'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (date != null) Text(DateFormat('yyyy/MM/dd • HH:mm').format(date), style: const TextStyle(fontSize: 9.5, color: ZColors.subtle)),
                  ],
                ),
              ),
              Text('${(item['amount'] as num? ?? 0).toStringAsFixed(0)} ر.ي', style: const TextStyle(fontWeight: FontWeight.w900, color: ZColors.success)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _CloseoutCard extends StatelessWidget {
  const _CloseoutCard({required this.report});
  final ReportSummary report;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: ZColors.greenSoft, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFCEDFD9))),
        child: Row(
          children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: ZColors.green, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.lock_clock_rounded, color: ZColors.yellow)),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الإغلاق المالي المتوقع', style: TextStyle(fontWeight: FontWeight.w900, color: ZColors.green)),
                  const SizedBox(height: 2),
                  const Text('نقدي المبيعات + تحصيل الديون', style: TextStyle(fontSize: 10.5, color: ZColors.muted)),
                  const SizedBox(height: 5),
                  Text('${report.number('expectedCash').toStringAsFixed(0)} ر.ي', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: ZColors.green)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ReportMessage extends StatelessWidget {
  const _ReportMessage({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E8EE))),
        child: Column(
          children: [
            Icon(icon, size: 32, color: ZColors.green),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, color: ZColors.muted)),
          ],
        ),
      );
}

enum _ReportRange {
  today('اليوم'),
  week('7 أيام'),
  month('هذا الشهر'),
  all('الكل');

  const _ReportRange(this.label);
  final String label;
}
