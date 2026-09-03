import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../data/models.dart';
import '../state/app_session.dart';
import '../state/product_catalog.dart';

class SaleScreen extends StatefulWidget {
  const SaleScreen({super.key});

  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen>
    with SingleTickerProviderStateMixin {
  static const MethodChannel _feedbackChannel = MethodChannel('marketplus/feedback');

  final barcodeController = TextEditingController();
  final Map<String, DateTime> _lastSeen = <String, DateTime>{};
  final Set<String> _remoteLookups = <String>{};
  late final AnimationController _scanLineController;
  late final MobileScannerController scanner = MobileScannerController(
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 120,
    cameraResolution: const Size(1280, 720),
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
    ],
    returnImage: false,
    autoZoom: true,
  );

  Product? _lastProduct;
  bool _lastProductAdded = false;
  double? _lastScanMs;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    barcodeController.dispose();
    unawaited(scanner.dispose());
    super.dispose();
  }

  bool _isStillSamePhysicalScan(String code) {
    final now = DateTime.now();
    final previousSeen = _lastSeen[code];
    _lastSeen[code] = now;

    if (_lastSeen.length > 80) {
      _lastSeen.removeWhere(
        (_, value) => now.difference(value) > const Duration(seconds: 20),
      );
    }

    return previousSeen != null &&
        now.difference(previousSeen) < const Duration(milliseconds: 650);
  }

  Future<void> _resolveAndAdd(String rawCode, {bool fromCamera = false}) async {
    final catalog = context.read<ProductCatalog>();
    final session = context.read<AppSession>();
    final code = catalog.normalizeBarcode(rawCode);
    if (code.isEmpty) return;
    if (fromCamera && _isStillSamePhysicalScan(code)) return;

    final watch = Stopwatch()..start();
    final cached = catalog.findByBarcode(code);
    if (cached != null) {
      _acceptProduct(cached, session, watch, source: 'memory');
      return;
    }

    if (_remoteLookups.contains(code)) return;
    _remoteLookups.add(code);
    if (mounted) setState(() {});
    try {
      final product = await catalog.resolveBarcode(code);
      if (!mounted) return;
      _acceptProduct(product, session, watch, source: 'api-fallback');
    } catch (_) {
      if (!mounted) return;
      watch.stop();
      setState(() {
        _lastProduct = null;
        _lastProductAdded = false;
        _lastScanMs = watch.elapsedMicroseconds / 1000;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ما لقينا منتجًا بهذا الباركود: $code')),
      );
    } finally {
      _remoteLookups.remove(code);
      if (mounted) setState(() {});
    }
  }

  Future<void> _playScanSuccessTone() async {
    try {
      await _feedbackChannel.invokeMethod<void>('scanSuccess');
    } catch (_) {
      await SystemSound.play(SystemSoundType.click);
    }
  }

  void _acceptProduct(
    Product product,
    AppSession session,
    Stopwatch watch, {
    required String source,
  }) {
    final added = session.addProduct(product);
    watch.stop();
    final elapsedMs = watch.elapsedMicroseconds / 1000;

    if (kDebugMode) {
      debugPrint(
        '[SCAN] barcode=${product.barcode} source=$source scan-to-cart=${elapsedMs.toStringAsFixed(2)}ms added=$added',
      );
    }

    if (added) {
      HapticFeedback.mediumImpact();
      unawaited(_playScanSuccessTone());
      barcodeController.clear();
    } else {
      HapticFeedback.heavyImpact();
    }

    if (!mounted) return;
    setState(() {
      _lastProduct = product;
      _lastProductAdded = added;
      _lastScanMs = elapsedMs;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    final catalog = context.watch<ProductCatalog>();
    final remoteBusy = _remoteLookups.isNotEmpty;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
          sliver: SliverList.list(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'بيع جديد',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'وجّه الكاميرا للباركود، وسيُضاف المنتج تلقائيًا.',
                          style: TextStyle(
                            color: ZColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _CatalogStateChip(catalog: catalog),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 310,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: ZColors.green,
                  borderRadius: BorderRadius.circular(ZRadius.hero),
                  boxShadow: ZShadow.float,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: scanner,
                      onDetect: (capture) {
                        if (capture.barcodes.isEmpty) return;
                        final value = capture.barcodes.first.rawValue;
                        if (value != null) {
                          unawaited(_resolveAndAdd(value, fromCamera: true));
                        }
                      },
                    ),
                    IgnorePointer(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x66000000),
                              Color(0x08000000),
                              Color(0x77000000),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 274,
                        height: 148,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: ZColors.yellow,
                            width: 1.8,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _scanLineController,
                            builder: (context, child) => Align(
                              alignment: Alignment(
                                0,
                                -0.78 + (_scanLineController.value * 1.56),
                              ),
                              child: child,
                            ),
                            child: Container(
                              width: 238,
                              height: 2,
                              decoration: BoxDecoration(
                                color: ZColors.yellow,
                                borderRadius: BorderRadius.circular(99),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x99FFD84A),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      top: 12,
                      end: 12,
                      child: Material(
                        color: const Color(0x9901261F),
                        borderRadius: BorderRadius.circular(14),
                        child: IconButton(
                          tooltip: 'تشغيل أو إيقاف الإضاءة',
                          onPressed: () => scanner.toggleTorch(),
                          icon: const Icon(
                            Icons.flashlight_on_outlined,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 18,
                      right: 18,
                      bottom: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_scanner_rounded,
                            color: ZColors.yellow,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'ضع الباركود داخل الإطار — ستسمع صوتًا عند نجاح المسح',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (remoteBusy)
                      PositionedDirectional(
                        top: 14,
                        start: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xAA01261F),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: ZColors.yellow,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'نبحث عن المنتج...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ZRadius.lg),
                  border: Border.all(color: const Color(0xFFE5E8EE)),
                  boxShadow: ZShadow.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.keyboard_alt_outlined,
                          color: ZColors.green,
                          size: 19,
                        ),
                        SizedBox(width: 7),
                        Text(
                          'ما انقرأ الباركود؟',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: ZColors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'اكتب الرقم يدويًا ثم اضغط إضافة.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: ZColors.muted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: barcodeController,
                            textDirection: TextDirection.ltr,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (value) => _resolveAndAdd(value),
                            decoration: const InputDecoration(
                              hintText: 'رقم الباركود',
                              prefixIcon: Icon(Icons.numbers_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 54,
                          height: 54,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: remoteBusy
                                ? null
                                : () => _resolveAndAdd(
                                      barcodeController.text,
                                    ),
                            child: const Icon(Icons.add_rounded),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_lastProduct != null) ...[
                const SizedBox(height: 14),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _ScanResultCard(
                    key: ValueKey(
                      '${_lastProduct!.id}-${session.cartCount}-${_lastScanMs?.round()}',
                    ),
                    product: _lastProduct!,
                    added: _lastProductAdded,
                    elapsedMs: _lastScanMs,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              _CartSummaryCard(session: session),
              if (session.cart.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...session.cart.reversed.take(3).map(
                      (line) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _QuickCartLine(line: line, session: session),
                      ),
                    ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CatalogStateChip extends StatelessWidget {
  const _CatalogStateChip({required this.catalog});

  final ProductCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final ready = catalog.hasLocalData;
    return Tooltip(
      message: ready
          ? '${catalog.count} منتج جاهز للبيع'
          : 'جاري تجهيز المنتجات',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: ready ? ZColors.successSoft : ZColors.warningSurface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: ready
                ? const Color(0xFFCDE8DC)
                : const Color(0xFFF2DE98),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ready
                  ? Icons.check_circle_rounded
                  : Icons.hourglass_top_rounded,
              size: 15,
              color: ready ? ZColors.success : ZColors.yellowText,
            ),
            const SizedBox(width: 5),
            Text(
              ready ? 'جاهز' : 'لحظة...',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: ready ? ZColors.success : ZColors.yellowText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanResultCard extends StatelessWidget {
  const _ScanResultCard({
    super.key,
    required this.product,
    required this.added,
    this.elapsedMs,
  });

  final Product product;
  final bool added;
  final double? elapsedMs;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: added ? ZColors.successSoft : ZColors.dangerSoft,
          borderRadius: BorderRadius.circular(ZRadius.lg),
          border: Border.all(
            color: added
                ? const Color(0xFFB9DFCF)
                : const Color(0xFFF1C5BE),
          ),
          boxShadow: ZShadow.card,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: added ? ZColors.mint : const Color(0xFFFFDAD4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                added
                    ? Icons.check_rounded
                    : Icons.info_outline_rounded,
                color: added ? ZColors.green : ZColors.danger,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    added
                        ? '${product.price.toStringAsFixed(0)} ر.ي • أضفناه إلى السلة'
                        : 'الكمية المتاحة لا تسمح بإضافة المزيد',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: ZColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (kDebugMode && elapsedMs != null)
              Text(
                '${elapsedMs!.toStringAsFixed(0)}ms',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: ZColors.subtle,
                ),
              ),
          ],
        ),
      );
}

class _CartSummaryCard extends StatelessWidget {
  const _CartSummaryCard({required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final hasItems = session.cartCount > 0;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ZRadius.xl),
      child: InkWell(
        borderRadius: BorderRadius.circular(ZRadius.xl),
        onTap: hasItems ? () => context.push('/cart') : null,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ZRadius.xl),
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [ZColors.greenActive, ZColors.green],
            ),
            boxShadow: ZShadow.float,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: ZColors.yellow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: ZColors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasItems
                          ? '${session.cartCount} ${session.cartCount == 1 ? 'عنصر' : 'عناصر'} في السلة'
                          : 'السلة فارغة',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasItems
                          ? '${session.cartSubtotal.toStringAsFixed(0)} ر.ي • اضغط لإكمال الفاتورة'
                          : 'ابدأ بمسح أول منتج',
                      style: const TextStyle(
                        color: Color(0xFFDCE8E4),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasItems)
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0x1FFFFFFF),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    size: 19,
                    color: ZColors.yellow,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickCartLine extends StatelessWidget {
  const _QuickCartLine({required this.line, required this.session});

  final CartLine line;
  final AppSession session;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ZRadius.md),
          border: Border.all(color: const Color(0xFFE5E8EE)),
          boxShadow: ZShadow.card,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                line.product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => session.decrement(line),
              icon: const Icon(Icons.remove_circle_outline_rounded),
            ),
            SizedBox(
              width: 28,
              child: Text(
                '${line.quantity}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => session.increment(line),
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
          ],
        ),
      );
}
