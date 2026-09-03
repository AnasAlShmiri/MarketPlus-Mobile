import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/api_client.dart';
import 'data/repositories.dart';
import 'state/app_session.dart';
import 'state/offline_sale_queue.dart';
import 'state/product_catalog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final api = await ApiClient.create();
  final preferences = await SharedPreferences.getInstance();
  final auth = AuthRepository(api);
  final products = ProductRepository(api);
  final invoices = InvoiceRepository(api);
  final customers = CustomerRepository(api);
  final inventory = InventoryRepository(api);
  final reports = ReportRepository(api);
  final dashboard = DashboardRepository(api);
  final whatsapp = WhatsAppRepository(api);
  final catalog = ProductCatalog(products, preferences);
  await catalog.hydrate();

  final offlineQueue = OfflineSaleQueue(invoices, preferences);
  await offlineQueue.hydrate();

  final session = AppSession(auth, catalog);
  await session.restoreSession();
  if (session.authenticated && offlineQueue.hasPending) {
    unawaited(offlineQueue.syncAll());
  }

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: api),
        Provider.value(value: products),
        Provider.value(value: invoices),
        Provider.value(value: customers),
        Provider.value(value: inventory),
        Provider.value(value: reports),
        Provider.value(value: dashboard),
        Provider.value(value: whatsapp),
        ChangeNotifierProvider.value(value: catalog),
        ChangeNotifierProvider.value(value: offlineQueue),
        ChangeNotifierProvider.value(value: session),
      ],
      child: ZimmatiApp(session: session),
    ),
  );
}
