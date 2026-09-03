import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../data/models.dart';
import '../data/repositories.dart';
import '../state/app_session.dart';

class CustomersScreenV2 extends StatefulWidget {
  const CustomersScreenV2({super.key});

  @override
  State<CustomersScreenV2> createState() => _CustomersScreenV2State();
}

class _CustomersScreenV2State extends State<CustomersScreenV2> {
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

  Future<void> openNew() async {
    final changed = await context.push<bool>('/customer/new');
    if (changed == true && mounted) await refresh();
  }

  Future<void> edit(CustomerSummary customer) async {
    final changed = await context.push<bool>('/customer/${Uri.encodeComponent(customer.phone)}/edit');
    if (changed == true && mounted) await refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AppSession>().user?.isAdmin == true;
    return Scaffold(
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(onPressed: openNew, icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('عميل جديد'))
          : null,
      body: RefreshIndicator(
        onRefresh: refresh,
        child: FutureBuilder<List<CustomerSummary>>(
          future: future,
          builder: (context, snap) {
            final all = snap.data ?? const <CustomerSummary>[];
            final needle = query.trim().toLowerCase();
            final items = all.where((customer) {
              if (needle.isEmpty) return true;
              return customer.displayName.toLowerCase().contains(needle) || customer.phone.contains(needle);
            }).toList(growable: false);
            final outstanding = all.fold<double>(0, (sum, item) => sum + item.outstandingAmount);
            final withDebt = all.where((item) => item.hasDebt).length;

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
              children: [
                Text('العملاء', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                const Text('دليل مركزي للعملاء يعمل على كل أجهزتك.', style: TextStyle(fontSize: 12.5, color: ZColors.muted)),
                const SizedBox(height: 16),
                _CustomerHero(count: all.length, withDebt: withDebt, outstanding: outstanding),
                const SizedBox(height: 14),
                TextField(
                  controller: search,
                  onChanged: (value) => setState(() => query = value),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم أو رقم الجوال',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: query.isEmpty ? null : IconButton(onPressed: () { search.clear(); setState(() => query = ''); }, icon: const Icon(Icons.close_rounded)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(children: [const Expanded(child: Text('دليل العملاء', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ZColors.green))), if (snap.data != null) Text('${items.length} عميل', style: const TextStyle(fontSize: 10.5, color: ZColors.subtle))]),
                const SizedBox(height: 10),
                if (snap.connectionState == ConnectionState.waiting && snap.data == null)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: CircularProgressIndicator()))
                else if (snap.hasError && snap.data == null)
                  _DirectoryMessage(icon: Icons.cloud_off_rounded, title: 'تعذر تحميل العملاء', subtitle: '${snap.error}')
                else if (all.isEmpty)
                  const _DirectoryMessage(icon: Icons.people_outline_rounded, title: 'لا يوجد عملاء بعد', subtitle: 'أضف عميلًا أو أنشئ أول فاتورة برقم جوال.')
                else if (items.isEmpty)
                  const _DirectoryMessage(icon: Icons.person_search_rounded, title: 'لا توجد نتيجة', subtitle: 'جرّب اسمًا أو رقمًا مختلفًا.')
                else
                  ...items.map((customer) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _CustomerCard(
                      customer: customer,
                      canEdit: isAdmin,
                      onTap: () => context.push('/customer/${Uri.encodeComponent(customer.phone)}'),
                      onEdit: () => edit(customer),
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

class _CustomerHero extends StatelessWidget {
  const _CustomerHero({required this.count, required this.withDebt, required this.outstanding});
  final int count;
  final int withDebt;
  final double outstanding;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF1A3C34), ZColors.green]), boxShadow: ZShadow.float),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: ZColors.yellow, borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.groups_rounded, color: ZColors.green)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('قاعدة عملائك', style: TextStyle(fontSize: 11, color: Color(0xFFC5D7D2))), const SizedBox(height: 2), Text('$count عميل', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white))]))]),
          const SizedBox(height: 16),
          Row(children: [Expanded(child: _HeroValue(label: 'عليهم رصيد', value: '$withDebt')), const SizedBox(width: 8), Expanded(child: _HeroValue(label: 'إجمالي المتبقي', value: '${outstanding.toStringAsFixed(0)} ر.ي'))]),
        ]),
      );
}

class _HeroValue extends StatelessWidget {
  const _HeroValue({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0x13FFFFFF), borderRadius: BorderRadius.circular(13)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 9.5, color: Color(0xFFC5D7D2))), const SizedBox(height: 3), FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: ZColors.yellow)))]));
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer, required this.canEdit, required this.onTap, required this.onEdit});
  final CustomerSummary customer;
  final bool canEdit;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E8EE)), boxShadow: ZShadow.card),
            child: Row(children: [
              CircleAvatar(radius: 23, backgroundColor: customer.hasDebt ? ZColors.warningSurface : ZColors.greenSoft, foregroundColor: customer.hasDebt ? ZColors.yellowText : ZColors.green, child: Text(customer.initial, style: const TextStyle(fontWeight: FontWeight.w900))),
              const SizedBox(width: 11),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(customer.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Directionality(textDirection: TextDirection.ltr, child: Text(customer.phone, textAlign: TextAlign.left, style: const TextStyle(fontSize: 11, color: ZColors.muted))), const SizedBox(height: 4), Text('${customer.invoiceCount} فاتورة • ${DateFormat('yyyy/MM/dd').format(customer.latestActivityAt.toLocal())}', style: const TextStyle(fontSize: 9.5, color: ZColors.subtle))])),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(customer.hasDebt ? '${customer.outstandingAmount.toStringAsFixed(0)} ر.ي' : 'مسدد', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: customer.hasDebt ? ZColors.danger : ZColors.success)), if (canEdit) IconButton(tooltip: 'تعديل العميل', visualDensity: VisualDensity.compact, onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 18))]),
            ]),
          ),
        ),
      );
}

class _DirectoryMessage extends StatelessWidget {
  const _DirectoryMessage({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 48), child: Column(children: [Container(width: 66, height: 66, decoration: BoxDecoration(color: ZColors.greenSoft, borderRadius: BorderRadius.circular(18)), child: Icon(icon, size: 30, color: ZColors.green)), const SizedBox(height: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, color: ZColors.muted))]));
}
