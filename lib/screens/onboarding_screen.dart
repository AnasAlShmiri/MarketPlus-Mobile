import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_theme.dart';
import '../core/onboarding_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.preferences,
    required this.authenticated,
  });

  final OnboardingPreferences preferences;
  final bool authenticated;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _page = 0;
  bool _finishing = false;

  static const _pages = <_OnboardingData>[
    _OnboardingData(
      title: 'بيع أسرع بالباركود',
      subtitle:
          'وجّه الكاميرا نحو الباركود، أضف المنتجات للسلة، وأغلق الفاتورة خلال ثوانٍ.',
      icon: Icons.qr_code_scanner_rounded,
      accent: ZColors.yellow,
      points: [
        'مسح سريع للباركود',
        'سلة واضحة وسهلة التعديل',
        'فاتورة جاهزة للطباعة والمشاركة',
      ],
    ),
    _OnboardingData(
      title: 'كل متجرك في مكان واحد',
      subtitle:
          'تابع المنتجات والمخزون والعملاء والديون والتقارير بدون التنقل بين أنظمة مختلفة.',
      icon: Icons.dashboard_customize_rounded,
      accent: ZColors.greenSoft,
      points: [
        'إدارة المخزون والأسعار',
        'متابعة الديون والسداد',
        'تقارير تساعدك على اتخاذ القرار',
      ],
    ),
    _OnboardingData(
      title: 'مصمم للعمل اليومي',
      subtitle:
          'حسابات بصلاحيات واضحة، مزامنة موثوقة، ومشاركة الفواتير عبر واتساب بسهولة.',
      icon: Icons.verified_user_rounded,
      accent: Color(0xFFDDE8FF),
      points: [
        'حساب مدير وحساب كاشير',
        'حماية من تكرار العمليات المالية',
        'مشاركة الفاتورة مع العميل',
      ],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);

    final saved = await widget.preferences.markCompleted();
    if (!mounted) return;

    if (!saved) {
      setState(() => _finishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حفظ إعداد البداية. حاول مرة أخرى.')),
      );
      return;
    }

    context.go(widget.authenticated ? '/home' : '/login');
  }

  Future<void> _next() async {
    if (_page == _pages.length - 1) {
      await _finish();
      return;
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lastPage = _page == _pages.length - 1;

    return Scaffold(
      backgroundColor: ZColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: Row(
                children: [
                  const _MiniBrand(),
                  const Spacer(),
                  TextButton(
                    onPressed: _finishing ? null : _finish,
                    child: const Text(
                      'تخطي',
                      style: TextStyle(
                        color: ZColors.greenMid,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (context, index) => _OnboardingPage(data: _pages[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: index == _page ? 26 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: index == _page
                              ? ZColors.green
                              : const Color(0xFFD8DEDB),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _finishing ? null : _next,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_finishing)
                          const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        else ...[
                          Text(lastPage ? 'ابدأ الآن' : 'التالي'),
                          const SizedBox(width: 8),
                          Icon(
                            lastPage
                                ? Icons.rocket_launch_rounded
                                : Icons.arrow_back_rounded,
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _OnboardingData data;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        children: [
          _FeatureIllustration(data: data),
          const SizedBox(height: 30),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 27,
              height: 1.35,
              fontWeight: FontWeight.w900,
              color: ZColors.green,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 11),
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.75,
              color: ZColors.subtle,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          ...data.points.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E8EE)),
                  boxShadow: ZShadow.card,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: ZColors.successSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: ZColors.success,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        point,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: ZColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureIllustration extends StatelessWidget {
  const _FeatureIllustration({required this.data});

  final _OnboardingData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE5E8EE)),
        boxShadow: ZShadow.float,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 24,
            left: 26,
            child: _DecorativeChip(
              icon: Icons.inventory_2_outlined,
              color: ZColors.greenSoft,
            ),
          ),
          Positioned(
            right: 24,
            bottom: 28,
            child: _DecorativeChip(
              icon: Icons.receipt_long_rounded,
              color: const Color(0xFFFFF3CF),
            ),
          ),
          Positioned(
            right: 35,
            top: 31,
            child: Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: ZColors.yellow,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Container(
            width: 142,
            height: 142,
            decoration: BoxDecoration(
              color: data.accent,
              borderRadius: BorderRadius.circular(42),
            ),
            child: Icon(data.icon, size: 72, color: ZColors.green),
          ),
          Positioned(
            left: 42,
            bottom: 34,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: ZColors.green,
                borderRadius: BorderRadius.circular(99),
                boxShadow: ZShadow.card,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded, color: ZColors.yellow, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'سريع وسهل',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DecorativeChip extends StatelessWidget {
  const _DecorativeChip({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: ZColors.greenMid, size: 25),
      );
}

class _MiniBrand extends StatelessWidget {
  const _MiniBrand();

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: ZColors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              size: 22,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 9),
          const Text(
            'ماركت بلس',
            style: TextStyle(
              color: ZColors.green,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );
}

class _OnboardingData {
  const _OnboardingData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.points,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<String> points;
}
