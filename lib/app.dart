import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/app_theme.dart';
import 'core/onboarding_preferences.dart';
import 'screens/app_shell.dart';
import 'screens/checkout_screen.dart';
import 'screens/customer_form_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/customers_screen_v2.dart';
import 'screens/debts_screen.dart';
import 'screens/home_screen.dart';
import 'screens/inventory_management_screen.dart';
import 'screens/invoice_screen_v2.dart';
import 'screens/login_screen.dart';
import 'screens/offline_sync_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/products_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/sale_screen.dart';
import 'screens/sales_history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'state/app_session.dart';

class MarketPlusApp extends StatefulWidget {
  const MarketPlusApp({
    super.key,
    required this.session,
    required this.preferences,
  });

  final AppSession session;
  final SharedPreferences preferences;

  @override
  State<MarketPlusApp> createState() => _MarketPlusAppState();
}

class _MarketPlusAppState extends State<MarketPlusApp> {
  late final OnboardingPreferences onboardingPreferences =
      OnboardingPreferences(widget.preferences);

  late final GoRouter router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: widget.session,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isStartup = location == '/splash' || location == '/onboarding';
      if (isStartup) return null;

      final onLogin = location == '/login';
      if (!widget.session.authenticated && !onLogin) return '/login';
      if (widget.session.authenticated && onLogin) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => SplashScreen(
          onboardingCompleted: onboardingPreferences.isCompleted,
          authenticated: widget.session.authenticated,
        ),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => OnboardingScreen(
          preferences: onboardingPreferences,
          authenticated: widget.session.authenticated,
        ),
      ),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/sale', builder: (_, __) => const SaleScreen()),
          GoRoute(path: '/products', builder: (_, __) => const ProductsScreen()),
          GoRoute(path: '/customers', builder: (_, __) => const CustomersScreenV2()),
          GoRoute(path: '/debts', builder: (_, __) => const DebtsScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),
      GoRoute(path: '/cart', builder: (_, __) => const CheckoutScreen()),
      GoRoute(path: '/sales', builder: (_, __) => const SalesHistoryScreen()),
      GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
      GoRoute(path: '/inventory', builder: (_, __) => const InventoryManagementScreen()),
      GoRoute(path: '/sync', builder: (_, __) => const OfflineSyncScreen()),
      GoRoute(path: '/customer/new', builder: (_, __) => const CustomerFormScreen()),
      GoRoute(
        path: '/customer/:phone/edit',
        builder: (context, state) => CustomerFormScreen(
          existingPhone: Uri.decodeComponent(state.pathParameters['phone'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/customer/:phone',
        builder: (context, state) => CustomerDetailsScreen(
          phone: Uri.decodeComponent(state.pathParameters['phone'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/invoice/:id',
        builder: (context, state) => InvoiceScreenV2(
          id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'ماركت بلس',
        theme: buildMarketPlusTheme(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      );
}
