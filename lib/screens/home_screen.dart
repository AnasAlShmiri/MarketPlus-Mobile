import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../data/repositories.dart';
import '../state/app_session.dart';
import '../state/product_catalog.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    final catalog = context.watch<ProductCatalog>();
    final user = session.user;
    final isAdmin = user?.isAdmin == true;
    final name = (user?.fullName.trim().isNotEmpty ?? false)
        ? user!.fullName.trim()
        : (isAdmin ? 'المدير' : 'الكاشير');

    return RefreshIndicator(
      onRefresh: () async {
        try {
          await context.read<ProductCatalog>().synchronize(force: true);
        } catch (_) {}
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 112),
        children: [
          _Greeting(name: name, isAdmin: isAdmin),
          if (session.catalogWarning != null) ...[
            const SizedBox(height: 12),
            _WarningCard(message: session.catalogWarning!),
          ],
          const SizedBox(height: 18),
          _SaleHero(
            productCount: catalog.count,
            cartCount: session.cartCount,
            onTap: () => context.go('/sale'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickTile(
                  icon: Icons.inventory_2_rounded,
                  label: 'المنتجات',
                  value: '${catalog.count}',
                  hint: 'صنف جاهز',
                  accent: const Color(0xFFE8F1EE),
                  onTap: () => context.go('/products'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickTile(
                  icon: Icons.shopping_bag_rounded,
                  label: 'السلة',
                  value: '${session.cartCount}',
                  hint: session.cartCount == 0 ? 'فارغة الآن' : 'جاهزة للإتمام',
                  accent: const Color(0xFFFFF2C8),
                  onTap: () => context.push('/cart'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          _SectionTitle(
            title: isAdmin ? 'نبض المتجر' : 'اختصارات سريعة',
            subtitle: isAdmin ? 'ملخص حي لأهم الأرقام' : 'كل ما تحتاجه قريب منك',
          ),
          const SizedBox(height: 12),
          if (isAdmin)
            FutureBuilder<Map<String, dynamic>>(
              future: context.read<DashboardRepository>().stats(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const _MetricsSkeleton();
                }
                if (snap.hasError) {
                  return const _InfoCard(
                    icon: Icons.insights_outlined,
                    title: 'المؤشرات غير متاحة الآن',
                    subtitle: 'البيع والمنتجات يعملان بشكل طبيعي.',
                  );
                }
                final data = snap.data ?? const <String, dynamic>{};
                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.18,
                  children: [
                    _Metric(
                      label: 'إجمالي المبيعات',
                      value: _money(data['totalSales']),
                      icon: Icons.payments_rounded,
                      tone: _MetricTone.green,
                    ),
                    _Metric(
                      label: 'الفواتير',
                      value: '${data['totalInvoices'] ?? '—'}',
                      icon: Icons.receipt_long_rounded,
                      tone: _MetricTone.gold,
                    ),
                    _Metric(
                      label: 'الرصيد الآجل',
                      value: _money(data['totalDebts']),
                      icon: Icons.account_balance_wallet_rounded,
                      tone: _MetricTone.red,
                    ),
                    _Metric(
                      label: 'المنتجات',
                      value: '${data['totalProducts'] ?? catalog.count}',
                      icon: Icons.inventory_2_rounded,
                      tone: _MetricTone.mint,
                    ),
                  ],
                );
              },
            )
          else ...[
            _ActionRow(
              icon: Icons.account_balance_wallet_rounded,
              title: 'متابعة الديون',
              subtitle: 'اعرف من عليه رصيد وما المتبقي بدقة',
              onTap: () => context.go('/debts'),
            ),
            const SizedBox(height: 10),
            _ActionRow(
              icon: Icons.search_rounded,
              title: 'ابحث عن منتج',
              subtitle: 'بالاسم أو رقم الباركود في لحظات',
              onTap: () => context.go('/products'),
            ),
          ],
          const SizedBox(height: 22),
          _ReadinessStrip(catalog: catalog),
        ],
      ),
    );
  }

  static String _money(dynamic value) {
    if (value is num) return '${value.toStringAsFixed(0)} ر.ي';
    return value == null ? '—' : '$value ر.ي';
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.isAdmin});

  final String name;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أهلًا، $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  isAdmin
                      ? 'تحكم كامل في البيع، المخزون والديون.'
                      : 'كل شيء جاهز لعملية بيع سريعة.',
                  style: const TextStyle(
                    color: ZColors.muted,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: const Color(0xFFE5E8EE)),
              boxShadow: ZShadow.card,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, size: 8, color: ZColors.success),
                const SizedBox(width: 6),
                Text(
                  isAdmin ? 'مدير' : 'كاشير',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: ZColors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ZColors.warningSurface,
          borderRadius: BorderRadius.circular(ZRadius.md),
          border: Border.all(color: const Color(0xFFE9C349)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: ZColors.yellowText, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: ZColors.yellowText,
                ),
              ),
            ),
          ],
        ),
      );
}

class _SaleHero extends StatelessWidget {
  const _SaleHero({
    required this.productCount,
    required this.cartCount,
    required this.onTap,
  });

  final int productCount;
  final int cartCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            height: 210,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF1A3C34), ZColors.green],
              ),
            ),
            child: Stack(
              children: [
                const PositionedDirectional(
                  top: -44,
                  start: -24,
                  child: _DecorativeRing(size: 150, opacity: .08),
                ),
                const PositionedDirectional(
                  bottom: -54,
                  end: -30,
                  child: _DecorativeRing(size: 170, opacity: .07),
                ),
                PositionedDirectional(
                  top: 18,
                  end: 18,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: ZColors.yellow,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: ZColors.green,
                      size: 27,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0x1FFFFFFF),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: const Color(0x26FFFFFF)),
                        ),
                        child: const Text(
                          'نقطة البيع الذكية',
                          style: TextStyle(
                            color: Color(0xFFE4EEE9),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        'بيع أسرع،\nوحساب أوضح.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 27,
                          height: 1.2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                            decoration: BoxDecoration(
                              color: ZColors.yellow,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'ابدأ البيع',
                                  style: TextStyle(
                                    color: ZColors.green,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_back_rounded, size: 18, color: ZColors.green),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            cartCount > 0
                                ? '$cartCount في السلة'
                                : '$productCount منتج جاهز',
                            style: const TextStyle(
                              color: Color(0xFFC5D7D2),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _DecorativeRing extends StatelessWidget {
  const _DecorativeRing({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: opacity), width: 1.2),
        ),
      );
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String hint;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E8EE)),
              boxShadow: ZShadow.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: ZColors.green, size: 20),
                    ),
                    const Spacer(),
                    const Icon(Icons.north_west_rounded, size: 16, color: ZColors.subtle),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 24,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: ZColors.green,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ZColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: ZColors.subtle),
                ),
              ],
            ),
          ),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

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
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: ZColors.green,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10.5, color: ZColors.subtle),
                ),
              ],
            ),
          ),
          const Text(
            'اسحب للتحديث',
            style: TextStyle(fontSize: 10, color: ZColors.subtle),
          ),
        ],
      );
}

enum _MetricTone { green, gold, red, mint }

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
  });

  final String label;
  final String value;
  final IconData icon;
  final _MetricTone tone;

  Color get background => switch (tone) {
        _MetricTone.green => const Color(0xFFE8F1EE),
        _MetricTone.gold => const Color(0xFFFFF1C1),
        _MetricTone.red => ZColors.dangerSoft,
        _MetricTone.mint => const Color(0xFFEAF7F1),
      };

  Color get iconColor => switch (tone) {
        _MetricTone.green => ZColors.green,
        _MetricTone.gold => ZColors.yellowText,
        _MetricTone.red => ZColors.danger,
        _MetricTone.mint => ZColors.success,
      };

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
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const Spacer(),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
                ),
              ],
            ),
            const Spacer(),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: ZColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: ZColors.green,
                ),
              ),
            ),
          ],
        ),
      );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
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
                  decoration: BoxDecoration(
                    color: ZColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: ZColors.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: ZColors.text,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: ZColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: ZColors.green,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, size: 17, color: ZColors.yellow),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ReadinessStrip extends StatelessWidget {
  const _ReadinessStrip({required this.catalog});

  final ProductCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final ready = catalog.hasLocalData;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ready ? const Color(0xFFEAF7F1) : ZColors.warningSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ready ? const Color(0xFFCDE8DC) : const Color(0xFFE9C349),
        ),
      ),
      child: Row(
        children: [
          Icon(
            ready ? Icons.verified_rounded : Icons.sync_rounded,
            size: 19,
            color: ready ? ZColors.success : ZColors.yellowText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ready
                  ? '${catalog.count} منتج جاهز للبيع حتى مع بطء الشبكة.'
                  : 'يتم تجهيز بيانات المنتجات لأول استخدام.',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: ready ? ZColors.success : ZColors.yellowText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E8EE)),
          boxShadow: ZShadow.card,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: ZColors.surfaceSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: ZColors.green),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11.5, color: ZColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _MetricsSkeleton extends StatelessWidget {
  const _MetricsSkeleton();

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.18,
        children: List.generate(
          4,
          (_) => Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E8EE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: ZColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                const Spacer(),
                Container(width: 78, height: 9, color: ZColors.surfaceSoft),
                const SizedBox(height: 8),
                Container(width: 96, height: 18, color: ZColors.surfaceContainer),
              ],
            ),
          ),
        ),
      );
}
