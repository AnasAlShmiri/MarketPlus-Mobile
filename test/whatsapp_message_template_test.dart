import 'package:flutter_test/flutter_test.dart';
import 'package:marketplus_mobile/core/whatsapp_message_template.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('uses the default template when no custom value is stored', () async {
    final prefs = await SharedPreferences.getInstance();

    final template = await WhatsAppMessageTemplate.load(preferences: prefs);

    expect(template, WhatsAppMessageTemplate.defaultTemplate);
  });

  test('persists a custom template and renders known placeholders', () async {
    final prefs = await SharedPreferences.getInstance();
    const custom = 'فاتورة {invoice}\nالعميل: {customer}\nالمبلغ: {total} {currency}';

    await WhatsAppMessageTemplate.save(custom, preferences: prefs);
    final loaded = await WhatsAppMessageTemplate.load(preferences: prefs);
    final rendered = WhatsAppMessageTemplate.render(loaded, const {
      'invoice': 'INV-12',
      'customer': 'محمد',
      'total': '1500',
      'currency': 'ر.ي',
    });

    expect(loaded, custom);
    expect(rendered, 'فاتورة INV-12\nالعميل: محمد\nالمبلغ: 1500 ر.ي');
  });

  test('rejects blank and oversized templates', () {
    final oversized = List<String>.filled(
      WhatsAppMessageTemplate.maxLength + 1,
      'x',
    ).join();

    expect(WhatsAppMessageTemplate.validate('   '), isNotNull);
    expect(WhatsAppMessageTemplate.validate(oversized), isNotNull);
  });

  test('reset restores the default template', () async {
    final prefs = await SharedPreferences.getInstance();
    await WhatsAppMessageTemplate.save('رسالة مخصصة', preferences: prefs);

    await WhatsAppMessageTemplate.reset(preferences: prefs);

    expect(
      await WhatsAppMessageTemplate.load(preferences: prefs),
      WhatsAppMessageTemplate.defaultTemplate,
    );
  });
}
