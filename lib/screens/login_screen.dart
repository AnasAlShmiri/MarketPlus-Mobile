import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../state/app_session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool obscure = true;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    await context.read<AppSession>().login(email.text, password.text);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    final media = MediaQuery.of(context);
    final compact = media.size.height < 760;

    return Scaffold(
      backgroundColor: ZColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _LoginBackdrop()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(18, compact ? 18 : 28, 18, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BrandHero(compact: compact),
                      SizedBox(height: compact ? 18 : 24),
                      _LoginCard(
                        formKey: formKey,
                        email: email,
                        password: password,
                        obscure: obscure,
                        busy: session.busy,
                        error: session.error,
                        onTogglePassword: () => setState(() => obscure = !obscure),
                        onSubmit: submit,
                      ),
                      const SizedBox(height: 16),
                      const _TrustFooter(),
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

class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop();

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 330,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0xFF1D5547), ZColors.green],
                ),
              ),
            ),
          ),
          const PositionedDirectional(
            top: -68,
            end: -82,
            child: _GlowOrb(size: 220, opacity: .08),
          ),
          const PositionedDirectional(
            top: 154,
            start: -58,
            child: _GlowOrb(size: 146, opacity: .055),
          ),
          Positioned(
            top: 292,
            left: 0,
            right: 0,
            child: Container(
              height: 80,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x0001261F), ZColors.background],
                ),
              ),
            ),
          ),
        ],
      );
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
          border: Border.all(color: Colors.white.withValues(alpha: opacity + .02)),
        ),
      );
}

class _BrandHero extends StatelessWidget {
  const _BrandHero({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            width: compact ? 64 : 72,
            height: compact ? 64 : 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ZColors.yellow,
              borderRadius: BorderRadius.circular(compact ? 20 : 22),
              border: Border.all(color: const Color(0x40FFFFFF)),
              boxShadow: const [
                BoxShadow(color: Color(0x26000000), blurRadius: 24, offset: Offset(0, 10)),
              ],
            ),
            child: Text(
              'م',
              style: TextStyle(
                color: ZColors.green,
                fontSize: compact ? 32 : 36,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(height: compact ? 12 : 15),
          Text(
            'ماركت بلس',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 30 : 34,
              height: 1.1,
              fontWeight: FontWeight.w900,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'إدارة متجرك، ببساطة ووضوح.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFE9F2EF),
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: compact ? 13 : 17),
          const Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _FeaturePill(icon: Icons.bolt_rounded, label: 'بيع أسرع'),
              _FeaturePill(icon: Icons.receipt_long_rounded, label: 'حساب أوضح'),
              _FeaturePill(icon: Icons.inventory_2_rounded, label: 'مخزون مرتب'),
            ],
          ),
        ],
      );
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0x18FFFFFF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x26FFFFFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: ZColors.yellow, size: 15),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.email,
    required this.password,
    required this.obscure,
    required this.busy,
    required this.error,
    required this.onTogglePassword,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final bool obscure;
  final bool busy;
  final String? error;
  final VoidCallback onTogglePassword;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFEFEFD),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFF0F1EE)),
          boxShadow: const [
            BoxShadow(color: Color(0x1601261F), blurRadius: 34, offset: Offset(0, 14)),
            BoxShadow(color: Color(0x08FFFFFF), blurRadius: 2, offset: Offset(0, -1)),
          ],
        ),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'مرحبًا بعودتك',
                          style: TextStyle(
                            fontSize: 23,
                            height: 1.25,
                            fontWeight: FontWeight.w900,
                            color: ZColors.green,
                            letterSpacing: -.25,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'سجّل الدخول وابدأ يومك من حيث توقفت.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4C8),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.storefront_rounded, color: ZColors.green, size: 21),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username, AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  hintText: 'name@example.com',
                  prefixIcon: _FieldIcon(icon: Icons.alternate_email_rounded),
                ),
                validator: (value) => (value ?? '').contains('@') ? null : 'أدخل بريدًا إلكترونيًا صحيحًا',
              ),
              const SizedBox(height: 13),
              TextFormField(
                controller: password,
                obscureText: obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) {
                  if (!busy) onSubmit();
                },
                decoration: InputDecoration(
                  labelText: 'كلمة المرور',
                  prefixIcon: const _FieldIcon(icon: Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: obscure ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
                    onPressed: onTogglePassword,
                    icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                ),
                validator: (value) => (value ?? '').isEmpty ? 'كلمة المرور مطلوبة' : null,
              ),
              if (error != null) ...[
                const SizedBox(height: 13),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ZColors.dangerSoft,
                    borderRadius: BorderRadius.circular(ZRadius.md),
                    border: Border.all(color: const Color(0xFFF0C8C4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: ZColors.danger, size: 20),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          error!,
                          style: const TextStyle(
                            color: ZColors.danger,
                            fontSize: 12.5,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 19),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: busy ? null : onSubmit,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (busy)
                        const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                        )
                      else
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: ZColors.yellow,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(Icons.arrow_back_rounded, color: ZColors.green, size: 17),
                        ),
                      const SizedBox(width: 10),
                      Text(busy ? 'جاري تسجيل الدخول...' : 'دخول إلى ماركت بلس'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: ZColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, size: 18, color: ZColors.greenMid),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'استخدم حساب المدير أو الكاشير المسجل في متجرك.',
                        style: TextStyle(fontSize: 11.5, height: 1.4, color: ZColors.muted, fontWeight: FontWeight.w600),
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

class _FieldIcon extends StatelessWidget {
  const _FieldIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(9),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: ZColors.greenSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: ZColors.green, size: 19),
        ),
      );
}

class _TrustFooter extends StatelessWidget {
  const _TrustFooter();

  @override
  Widget build(BuildContext context) => const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_user_outlined, size: 16, color: ZColors.muted),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              'دخول آمن إلى بيانات متجرك',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: ZColors.muted, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
}
