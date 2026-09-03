import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../data/repositories.dart';

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key, this.existingPhone});
  final String? existingPhone;

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final phone = TextEditingController();
  final notes = TextEditingController();
  bool loading = false;
  bool saving = false;

  bool get editing => (widget.existingPhone ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (editing) {
      phone.text = widget.existingPhone!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final customer = await context.read<CustomerRepository>().byPhone(widget.existingPhone!);
      if (!mounted) return;
      name.text = customer.summary.name;
      phone.text = customer.summary.phone;
      notes.text = customer.summary.notes ?? '';
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _save() async {
    if (!(formKey.currentState?.validate() ?? false) || saving) return;
    setState(() => saving = true);
    try {
      final repository = context.read<CustomerRepository>();
      if (editing) {
        await repository.update(phone: widget.existingPhone!, name: name.text, notes: notes.text);
      } else {
        await repository.save(phone: phone.text, name: name.text, notes: notes.text);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ بيانات العميل.')));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(editing ? 'تعديل العميل' : 'عميل جديد')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF1A3C34), ZColors.green]),
                      boxShadow: ZShadow.float,
                    ),
                    child: Row(
                      children: [
                        Container(width: 48, height: 48, decoration: BoxDecoration(color: ZColors.yellow, borderRadius: BorderRadius.circular(15)), child: Icon(editing ? Icons.manage_accounts_rounded : Icons.person_add_alt_1_rounded, color: ZColors.green)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(editing ? 'تحديث ملف العميل' : 'إضافة إلى دليل العملاء', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 2), const Text('الاسم والرقم والملاحظات محفوظة مركزيًا.', style: TextStyle(color: Color(0xFFC5D7D2), fontSize: 10.5))])),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Form(
                    key: formKey,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFE5E8EE)), boxShadow: ZShadow.card),
                      child: Column(
                        children: [
                          TextFormField(controller: name, decoration: const InputDecoration(labelText: 'اسم العميل', prefixIcon: Icon(Icons.person_outline_rounded)), validator: (v) => (v ?? '').trim().length > 120 ? 'الاسم طويل جدًا' : null),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: phone,
                            enabled: !editing,
                            keyboardType: TextInputType.phone,
                            textDirection: TextDirection.ltr,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
                            decoration: const InputDecoration(labelText: 'رقم الجوال', hintText: '771234567', prefixIcon: Icon(Icons.phone_outlined)),
                            validator: (v) => RegExp(r'^7\d{8}$').hasMatch((v ?? '').trim()) ? null : 'استخدم رقمًا يمنيًا من 9 أرقام يبدأ بـ7',
                          ),
                          const SizedBox(height: 10),
                          TextFormField(controller: notes, maxLines: 4, maxLength: 500, decoration: const InputDecoration(labelText: 'ملاحظات', hintText: 'معلومات اختيارية عن العميل', alignLabelWithHint: true, prefixIcon: Icon(Icons.notes_rounded))),
                          const SizedBox(height: 8),
                          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: saving ? null : _save, icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded), label: Text(saving ? 'جارٍ الحفظ...' : 'حفظ العميل'))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      );
}
