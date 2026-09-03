import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.onboardingCompleted,
    required this.authenticated,
  });

  final bool onboardingCompleted;
  final bool authenticated;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.9, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();

    _navigationTimer = Timer(const Duration(milliseconds: 1350), () {
      if (!mounted) return;
      if (!widget.onboardingCompleted) {
        context.go('/onboarding');
      } else {
        context.go(widget.authenticated ? '/home' : '/login');
      }
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
            top: -90,
            right: -70,
            child: _GlowBubble(size: 260, color: Color(0x28C5EADF)),
          ),
          const Positioned(
            bottom: -120,
            left: -80,
            child: _GlowBubble(size: 300, color: Color(0x1CFED65B)),
          ),
          SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(34),
                          border: Border.all(color: const Color(0xFFE6EBE8)),
                          boxShadow: ZShadow.float,
                        ),
                        child: const Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.storefront_rounded,
                              size: 58,
                              color: ZColors.green,
                            ),
                            Positioned(
                              right: 20,
                              bottom: 19,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: ZColors.yellow,
                                  shape: BoxShape.circle,
                                ),
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: Icon(
                                    Icons.add_rounded,
                                    size: 20,
                                    color: ZColors.green,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'ماركت بلس',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                          color: ZColors.green,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Market Plus',
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 3.5,
                          color: ZColors.greenMid,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'مبيعات أسرع • مخزون أوضح • حسابات أدق',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: ZColors.subtle,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 38),
                      const SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: ZColors.green,
                          backgroundColor: ZColors.greenSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowBubble extends StatelessWidget {
  const _GlowBubble({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
