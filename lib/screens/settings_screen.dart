import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/whatsapp_message_template.dart';
import '../state/app_session.dart';
import '../state/product_catalog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _whatsappTemplate = WhatsAppMessageTemplate.defaultTemplate;
  bool _loadingTemplate = true;

  @override
  void initState() {
    super.initState();
    _loadWhatsAppTemplate();
  }

  Future<void> _loadWhatsAppTemplate() async {
    try {
      final template = await WhatsAppMessageTemplate.load();
      if (!mounted) return;
      setState(() {
        _whatsappTemplate = template;
        _loadingTemplate = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingTemplate = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    final catalog = context.watch<ProductCatalog>();
    final user = session.user;
    final name = (user?.fullName.trim().isNotEmpty ?? false)
        ? user!.fullName.trim()
        : 'المستخدم';
    final email = (user?.email.trim().isNotEmpty ?? false)
        ? user!.email.trim()
        : 'لا يوجد بريد مسجل';
    final role = user?.isAdmin == true ? 'مدير النظام' : 'كاشير';
    final firstLetter = name.isNotEmpty ? name[0] : 'ذ';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 112),
      children: [
        Text('حسابي', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text(
          'بياناتك الأساسية وحالة التطبيق في مكان واحد.',
          style: TextStyle(color: ZColors.muted, fontSize: 12.5),
        ),
        const SizedBox(height: 18),
        _ProfileHero(
          firstLetter: firstLetter,
          name: name,
          email: email,
          role: role,
          isAdmin: user?.isAdmin == true,
        ),
        const SizedBox(height: 14),
        _StoreStatusCard(catalog: catalog),
        const SizedBox(height: 26),
        const Text(
          'المشاركة',
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
            color: ZColors.green,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'خصص النص الذي يفتح مع واتساب عند إرسال فاتورة للعميل.',
          style: TextStyle(fontSize: 10.8, color: ZColors.subtle),
        ),
        const SizedBox(height: 10),
        _WhatsAppTemplateCard(
          template: _whatsappTemplate,
          loading: _loadingTemplate,
          onTap: _loadingTemplate ? null : _editWhatsAppTemplate,
        ),
        const SizedBox(height: 26),
        const Text(
          'الجلسة',
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
            color: ZColors.green,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'يمكنك إنهاء الجلسة الحالية بأمان من هذا الجهاز.',
          style: TextStyle(fontSize: 10.8, color: ZColors.subtle),
        ),
        const SizedBox(height: 10),
        _LogoutCard(onTap: () => _confirmLogout(context)),
      ],
    );
  }

  Future<void> _editWhatsAppTemplate() async {
    final controller = TextEditingController(text: _whatsappTemplate);
    String? validationError;

    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.chat_rounded, color: ZColors.green),
              SizedBox(width: 10),
              Expanded(child: Text('قالب رسالة واتساب')),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'اكتب الرسالة كما تريدها. اضغط على أي متغير لإضافته في موضع المؤشر.',
                    style: TextStyle(fontSize: 11.5, color: ZColors.muted),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    minLines: 8,
                    maxLines: 14,
                    maxLength: WhatsAppMessageTemplate.maxLength,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: InputDecoration(
                      hintText: WhatsAppMessageTemplate.defaultTemplate,
                      errorText: validationError,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'المتغيرات المتاحة',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: ZColors.text,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: WhatsAppMessageTemplate.placeholders
                        .map(
                          (token) => ActionChip(
                            label: Text(token),
                            onPressed: () => _insertToken(controller, token),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '{debt} يضيف المدفوع والمتبقي تلقائيًا للفواتير الآجلة فقط.',
                    style: TextStyle(fontSize: 10.3, color: ZColors.subtle),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.text = WhatsAppMessageTemplate.defaultTemplate;
                controller.selection = TextSelection.collapsed(
                  offset: controller.text.length,
                );
                setDialogState(() => validationError = null);
              },
              child: const Text('إعادة الافتراضي'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              onPressed: () {
                final normalized = WhatsAppMessageTemplate.normalize(
                  controller.text,
                );
                final error = WhatsAppMessageTemplate.validate(normalized);
                if (error != null) {
                  setDialogState(() => validationError = error);
                  return;
                }
                Navigator.pop(dialogContext, normalized);
              },
              icon: const Icon(Icons.save_rounded),
              label: const Text('حفظ القالب'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    if (selected == null || !mounted) return;

    try {
      await WhatsAppMessageTemplate.save(selected);
      if (!mounted) return;
      setState(() => _whatsappTemplate = selected);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ قالب رسالة واتساب.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حفظ قالب رسالة واتساب الآن.')),
      );
    }
  }

  static void _insertToken(TextEditingController controller, String token) {
    final selection = controller.selection;
    final start = selection.isValid ? selection.start : controller.text.length;
    final end = selection.isValid ? selection.end : controller.text.length;
    final text = controller.text.replaceRange(start, end, token);
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: start + token.length),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: ZColors.danger),
            SizedBox(width: 10),
            Text('تسجيل الخروج'),
          ],
        ),
        content: const Text(
          'سيتم إنهاء جلستك على هذا الجهاز فقط. يمكنك تسجيل الدخول مرة أخرى في أي وقت.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ZColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AppSession>().logout();
    }
  }
}

class _WhatsAppTemplateCard extends StatelessWidget {
  const _WhatsAppTemplateCard({
    required this.template,
    required this.loading,
    required this.onTap,
  });

  final String template;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFD8E7E2)),
              boxShadow: ZShadow.card,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: ZColors.successSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: loading
                      ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.chat_rounded,
                          color: ZColors.success,
                          size: 21,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'قالب رسالة واتساب',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: ZColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        loading ? 'جارٍ تحميل القالب...' : template,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.8,
                          height: 1.45,
                          color: ZColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.edit_rounded, color: ZColors.green),
              ],
            ),
          ),
        ),
      );
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.firstLetter,
    required this.name,
    required this.email,
    required this.role,
    required this.isAdmin,
  });

  final String firstLetter;
  final String name;
  final String email;
  final String role;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF1D5245), ZColors.green],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x241A3C34),
              blurRadius: 32,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          children: [
            const PositionedDirectional(
              top: -84,
              start: -74,
              child: _DecorativeRing(size: 190),
            ),
            const PositionedDirectional(
              bottom: -96,
              end: -58,
              child: _DecorativeRing(size: 210),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: ZColors.yellow,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0x66FFFFFF),
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 22,
                              offset: Offset(0, 9),
                            ),
                          ],
                        ),
                        child: Text(
                          firstLetter,
                          style: const TextStyle(
                            fontSize: 30,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            color: ZColors.green,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                height: 1.25,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.left,
                                style: const TextStyle(
                                  color: Color(0xFFD5E3DF),
                                  fontSize: 11.2,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _ProfileBadge(
                        icon: isAdmin
                            ? Icons.admin_panel_settings_rounded
                            : Icons.point_of_sale_rounded,
                        label: role,
                      ),
                      const SizedBox(width: 8),
                      const _ProfileBadge(
                        icon: Icons.verified_rounded,
                        label: 'جلسة نشطة',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _DecorativeRing extends StatelessWidget {
  const _DecorativeRing({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x12FFFFFF), width: 1.2),
        ),
      );
}

class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Flexible(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0x16FFFFFF),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: const Color(0x24FFFFFF)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: ZColors.yellow),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _StoreStatusCard extends StatelessWidget {
  const _StoreStatusCard({required this.catalog});

  final ProductCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final ready = catalog.hasLocalData;
    final syncing = catalog.syncing;
    final syncedAt = catalog.lastSyncedAt;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E8EE)),
        boxShadow: ZShadow.card,
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: ready ? ZColors.successSoft : ZColors.warningSurface,
              borderRadius: BorderRadius.circular(15),
            ),
            child: syncing
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    ready ? Icons.cloud_done_rounded : Icons.cloud_sync_rounded,
                    color: ready ? ZColors.success : ZColors.yellowText,
                    size: 23,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  syncing
                      ? 'جاري تحديث بيانات المتجر'
                      : ready
                          ? 'التطبيق جاهز للبيع'
                          : 'البيانات تحتاج تحديثًا',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: ZColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ready
                      ? '${catalog.count} منتج${syncedAt == null ? '' : ' • آخر مزامنة ${_formatCompactDate(syncedAt)}'}'
                      : 'حدّث المنتجات قبل بدء البيع.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.8, color: ZColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'تحديث المنتجات',
            onPressed: syncing
                ? null
                : () async {
                    try {
                      await context.read<ProductCatalog>().synchronize(force: true);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم تحديث المنتجات.')),
                        );
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تعذر تحديث المنتجات الآن.')),
                        );
                      }
                    }
                  },
            style: IconButton.styleFrom(
              backgroundColor: ZColors.surfaceSoft,
              foregroundColor: ZColors.green,
            ),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  static String _formatCompactDate(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }
}

class _LogoutCard extends StatelessWidget {
  const _LogoutCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF0D3CF)),
              boxShadow: ZShadow.card,
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: ZColors.dangerSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: ZColors.danger,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تسجيل الخروج',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: ZColors.text,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'إنهاء الجلسة الحالية على هذا الجهاز',
                        style: TextStyle(fontSize: 10.8, color: ZColors.muted),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_left_rounded,
                  color: ZColors.subtle,
                ),
              ],
            ),
          ),
        ),
      );
}
