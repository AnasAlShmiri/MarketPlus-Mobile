import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../state/app_session.dart';
import '../state/offline_sale_queue.dart';
import '../state/product_catalog.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const paths = ['/home', '/sale', '/products', '/customers', '/debts'];

  @override
  Widget build(BuildContext context) {
    final index = paths.indexWhere((path) => location.startsWith(path));
    final showingAccount = location.startsWith('/settings');
    final session = context.watch<AppSession>();
    final catalog = context.watch<ProductCatalog>();
    final offline = context.watch<OfflineSaleQueue>();
    final cartCount = session.cartCount;
    final isAdmin = session.user?.isAdmin == true;
    final fullName = session.user?.fullName.trim() ?? '';
    final initial = fullName.isEmpty ? 'م' : fullName[0];

    return Scaffold(
      extendBody: false,
      appBar: AppBar(
        backgroundColor: ZColors.green,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 66,
        leadingWidth: 66,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFF1A3C34), ZColors.green],
            ),
            border: Border(bottom: BorderSide(color: Color(0x22FED65B), width: 1)),
          ),
        ),
        leading: showingAccount
            ? BackButton(color: Colors.white, onPressed: () => context.pop())
            : Padding(
                padding: const EdgeInsetsDirectional.only(start: 14),
                child: Center(
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => context.push('/settings'),
                      child: Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: ZColors.yellow,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0x55FFFFFF), width: 1.4),
                          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 5))],
                        ),
                        child: Text(initial, style: const TextStyle(color: ZColors.green, fontWeight: FontWeight.w900, fontSize: 18)),
                      ),
                    ),
                  ),
                ),
              ),
        titleSpacing: 7,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ماركت بلس', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(
              showingAccount
                  ? 'حسابك الشخصي'
                  : offline.pendingCount > 0
                      ? '${offline.pendingCount} عملية تنتظر المزامنة'
                      : catalog.syncing
                          ? 'نزامن بيانات المتجر...'
                          : catalog.hasLocalData
                              ? (isAdmin ? 'الإدارة • جاهز للعمل' : 'الكاشير • جاهز للعمل')
                              : (isAdmin ? 'الإدارة' : 'الكاشير'),
              style: TextStyle(
                fontSize: 10.2,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: offline.pendingCount > 0 ? ZColors.yellow : const Color(0xFFC5D7D2),
              ),
            ),
          ],
        ),
        actions: [
          if (!showingAccount && catalog.syncing)
            const Padding(
              padding: EdgeInsetsDirectional.only(end: 2),
              child: Center(child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: ZColors.yellow))),
            ),
          if (!showingAccount && (isAdmin || offline.pendingCount > 0))
            PopupMenuButton<String>(
              tooltip: 'المزيد',
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.grid_view_rounded),
                  if (offline.pendingCount > 0)
                    PositionedDirectional(
                      end: -6,
                      top: -6,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(color: ZColors.yellow, borderRadius: BorderRadius.circular(99)),
                        child: Text('${offline.pendingCount}', style: const TextStyle(color: ZColors.green, fontSize: 8.5, fontWeight: FontWeight.w900)),
                      ),
                    ),
                ],
              ),
              onSelected: (value) {
                switch (value) {
                  case 'sales':
                    context.push('/sales');
                  case 'reports':
                    context.push('/reports');
                  case 'inventory':
                    context.push('/inventory');
                  case 'customer':
                    context.push('/customer/new');
                  case 'sync':
                    context.push('/sync');
                }
              },
              itemBuilder: (_) => [
                if (isAdmin)
                  const PopupMenuItem(value: 'sales', child: ListTile(dense: true, leading: Icon(Icons.receipt_long_rounded), title: Text('سجل المبيعات'))),
                if (isAdmin)
                  const PopupMenuItem(value: 'reports', child: ListTile(dense: true, leading: Icon(Icons.insights_rounded), title: Text('التقارير'))),
                if (isAdmin)
                  const PopupMenuItem(value: 'inventory', child: ListTile(dense: true, leading: Icon(Icons.warehouse_rounded), title: Text('إدارة المخزون'))),
                if (isAdmin)
                  const PopupMenuItem(value: 'customer', child: ListTile(dense: true, leading: Icon(Icons.person_add_alt_1_rounded), title: Text('عميل جديد'))),
                if (offline.pendingCount > 0)
                  PopupMenuItem(value: 'sync', child: ListTile(dense: true, leading: const Icon(Icons.cloud_upload_rounded), title: const Text('المزامنة'), trailing: Text('${offline.pendingCount}'))),
              ],
            ),
          if (!showingAccount)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 10),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: cartCount == 0 ? 'السلة فارغة' : 'فتح السلة',
                    onPressed: () => context.push('/cart'),
                    style: IconButton.styleFrom(foregroundColor: Colors.white, backgroundColor: const Color(0x18FFFFFF), side: const BorderSide(color: Color(0x18FFFFFF))),
                    icon: const Icon(Icons.shopping_bag_outlined, size: 21),
                  ),
                  if (cartCount > 0)
                    PositionedDirectional(
                      start: -2,
                      top: -1,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: ZColors.yellow, borderRadius: BorderRadius.circular(99), border: Border.all(color: ZColors.green, width: 2)),
                        child: Text('$cartCount', style: const TextStyle(color: ZColors.green, fontSize: 9.5, fontWeight: FontWeight.w900)),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
      body: child,
      bottomNavigationBar: showingAccount
          ? null
          : DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE5E8EE))),
                boxShadow: [BoxShadow(color: Color(0x101A3C34), blurRadius: 24, offset: Offset(0, -7))],
              ),
              child: SafeArea(
                top: false,
                child: NavigationBar(
                  selectedIndex: index < 0 ? 0 : index,
                  onDestinationSelected: (selected) => context.go(paths[selected]),
                  destinations: const [
                    NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'الرئيسية'),
                    NavigationDestination(icon: Icon(Icons.qr_code_scanner_rounded), selectedIcon: Icon(Icons.qr_code_scanner_rounded), label: 'بيع'),
                    NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2_rounded), label: 'المنتجات'),
                    NavigationDestination(icon: Icon(Icons.people_outline_rounded), selectedIcon: Icon(Icons.people_rounded), label: 'العملاء'),
                    NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: 'الديون'),
                  ],
                ),
              ),
            ),
    );
  }
}
