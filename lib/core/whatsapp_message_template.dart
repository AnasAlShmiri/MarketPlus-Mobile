import 'package:shared_preferences/shared_preferences.dart';

class WhatsAppMessageTemplate {
  WhatsAppMessageTemplate._();

  static const storageKey = 'marketplus.whatsapp.invoice-template.v1';
  static const maxLength = 2000;

  static const defaultTemplate = '''مرحبًا {customer}،
فاتورتكم {invoice}
التاريخ: {date}

{items}

الإجمالي: {total} {currency}
طريقة الدفع: {payment}
{debt}
شكرًا لتعاملكم معنا.''';

  static const placeholders = <String>[
    '{customer}',
    '{phone}',
    '{invoice}',
    '{date}',
    '{items}',
    '{total}',
    '{currency}',
    '{payment}',
    '{paid}',
    '{remaining}',
    '{debt}',
  ];

  static Future<String> load({SharedPreferences? preferences}) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final stored = prefs.getString(storageKey);
    if (stored == null) return defaultTemplate;

    final normalized = normalize(stored);
    return validate(normalized) == null ? normalized : defaultTemplate;
  }

  static Future<void> save(
    String template, {
    SharedPreferences? preferences,
  }) async {
    final normalized = normalize(template);
    final error = validate(normalized);
    if (error != null) throw ArgumentError(error);

    final prefs = preferences ?? await SharedPreferences.getInstance();
    final saved = await prefs.setString(storageKey, normalized);
    if (!saved) throw StateError('تعذر حفظ قالب رسالة واتساب.');
  }

  static Future<void> reset({SharedPreferences? preferences}) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final removed = await prefs.remove(storageKey);
    if (!removed && prefs.containsKey(storageKey)) {
      throw StateError('تعذر إعادة قالب رسالة واتساب للوضع الافتراضي.');
    }
  }

  static String render(String template, Map<String, String> values) {
    var result = template;
    for (final entry in values.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }

    return result
        .replaceAll(RegExp(r'\n[ \t]+\n'), '\n\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static String normalize(String template) =>
      template.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();

  static String? validate(String template) {
    if (template.trim().isEmpty) return 'قالب رسالة واتساب لا يمكن أن يكون فارغًا.';
    if (template.length > maxLength) {
      return 'قالب رسالة واتساب يجب ألا يتجاوز $maxLength حرف.';
    }
    return null;
  }
}
