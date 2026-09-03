import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_theme.dart';
import '../data/models.dart';
import '../data/repositories.dart';
import '../state/app_session.dart';

class InvoiceScreenV2 extends StatefulWidget {
  const InvoiceScreenV2({super.key, required this.id});
  final int id;

  @override
  State<InvoiceScreenV2> createState() => _InvoiceScreenV2State();
}

class _InvoiceScreenV2State extends State<InvoiceScreenV2> {
  Future<Invoice>? future;
  bool working = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= context.read<InvoiceRepository>().byId(widget.id);
  }

  Future<void> reload() async {
    final next = context.read<InvoiceRepository>().byId(widget.id);
    setState(() => future = next);
    await next;
  }

  String message(Invoice invoice) {
    final items = invoice.items
        .map((item) => '• ${item.name} × ${item.quantity} — ${item.total.toStringAsFixed(0)} ر.ي')
        .join('\n');
    final date = DateFormat('yyyy/MM/dd – HH:mm').format(invoice.createdAt.toLocal());
    return 'مرحبًا ${invoice.customerName ?? 'عزيزنا'}،\n'
        'فاتورتكم ${invoice.number}\n'
        'التاريخ: $date\n\n'
        '$items\n\n'
        'الإجمالي: ${invoice.total.toStringAsFixed(0)} ر.ي\n'
        '${invoice.paymentType == 2 ? 'طريقة الدفع: آجل' : 'طريقة الدفع: نقدي'}\n'
        'شكرًا لتعاملكم معنا.';
  }

  Future<void> sendWhatsApp(Invoice invoice) async {
    try {
      final phone = invoice.customerPhone;
      if (phone == null || phone.isEmpty) return;
      final url = await context.read<WhatsAppRepository>().buildLink(phone, message(invoice));
      final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح واتساب على الجهاز.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<Uint8List> buildPdf(Invoice invoice) async {
    final fonts = await _loadPdfFonts();
    final document = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fonts.regular,
        bold: fonts.bold,
        fontFallback: [fonts.fallback],
      ),
    );
    final localDate = DateFormat('yyyy/MM/dd • HH:mm').format(invoice.createdAt.toLocal());

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        textDirection: pw.TextDirection.rtl,
        header: (_) => pw.Column(
          children: [
            pw.Text('ماركت بلس | Market Plus', style: _pdfStyle(fonts, bold: true, size: 22)),
            pw.SizedBox(height: 4),
            pw.Text('فاتورة بيع', style: _pdfStyle(fonts, size: 12)),
            pw.Divider(),
          ],
        ),
        build: (_) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('رقم الفاتورة', style: _pdfStyle(fonts)),
              pw.Directionality(
                textDirection: pw.TextDirection.ltr,
                child: pw.Text(invoice.number, style: _pdfStyle(fonts, size: 9)),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          _pdfRow(fonts, 'التاريخ', localDate),
          if ((invoice.customerName ?? '').trim().isNotEmpty)
            _pdfRow(fonts, 'العميل', invoice.customerName!.trim()),
          if ((invoice.customerPhone ?? '').trim().isNotEmpty)
            _pdfRow(fonts, 'رقم الجوال', invoice.customerPhone!.trim()),
          pw.SizedBox(height: 18),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: .6),
            columnWidths: const {
              0: pw.FlexColumnWidth(4),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(2),
              3: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _pdfCell(fonts, 'الصنف', bold: true),
                  _pdfCell(fonts, 'الكمية', bold: true),
                  _pdfCell(fonts, 'السعر', bold: true),
                  _pdfCell(fonts, 'الإجمالي', bold: true),
                ],
              ),
              ...invoice.items.map(
                (item) => pw.TableRow(
                  children: [
                    _pdfCell(fonts, item.name),
                    _pdfCell(fonts, '${item.quantity}'),
                    _pdfCell(fonts, item.unitPrice.toStringAsFixed(0)),
                    _pdfCell(fonts, item.total.toStringAsFixed(0)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          _pdfRow(fonts, 'المجموع', '${invoice.subtotal.toStringAsFixed(0)} ر.ي'),
          if (invoice.tax > 0)
            _pdfRow(fonts, 'الضريبة', '${invoice.tax.toStringAsFixed(0)} ر.ي'),
          pw.Divider(),
          _pdfRow(
            fonts,
            'الإجمالي',
            '${invoice.total.toStringAsFixed(0)} ر.ي',
            bold: true,
            size: 16,
          ),
          if (invoice.paymentType == 2) ...[
            pw.SizedBox(height: 6),
            _pdfRow(fonts, 'المدفوع', '${invoice.paidAmount.toStringAsFixed(0)} ر.ي'),
            _pdfRow(
              fonts,
              'المتبقي',
              '${invoice.remainingAmount.toStringAsFixed(0)} ر.ي',
              bold: true,
            ),
          ],
          pw.SizedBox(height: 20),
          pw.Center(
            child: pw.Text(
              'شكرًا لتعاملكم معنا',
              style: _pdfStyle(fonts, size: 10),
            ),
          ),
        ],
      ),
    );
    return document.save();
  }

  Future<_InvoicePdfFonts> _loadPdfFonts() async {
    // Default PDF fonts do not contain Arabic glyphs. Use an Arabic-capable
    // primary font plus an explicit Arabic fallback on every PDF text style.
    final regular = await PdfGoogleFonts.tajawalRegular();
    final bold = await PdfGoogleFonts.tajawalBold();
    final fallback = await PdfGoogleFonts.notoSansArabicRegular();
    return _InvoicePdfFonts(regular: regular, bold: bold, fallback: fallback);
  }

  pw.TextStyle _pdfStyle(
    _InvoicePdfFonts fonts, {
    bool bold = false,
    double size = 10,
  }) =>
      pw.TextStyle(
        font: bold ? fonts.bold : fonts.regular,
        fontFallback: [fonts.fallback],
        fontSize: size,
      );

  pw.Widget _pdfRow(
    _InvoicePdfFonts fonts,
    String label,
    String value, {
    bool bold = false,
    double size = 10,
  }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: _pdfStyle(fonts, bold: bold, size: size)),
            pw.Text(value, style: _pdfStyle(fonts, bold: bold, size: size)),
          ],
        ),
      );

  pw.Widget _pdfCell(
    _InvoicePdfFonts fonts,
    String value, {
    bool bold = false,
  }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(value, style: _pdfStyle(fonts, bold: bold, size: 9)),
      );

  Future<void> sharePdf(Invoice invoice) async {
    setState(() => working = true);
    try {
      final bytes = await buildPdf(invoice);
      await SharePlus.instance.share(
        ShareParams(
          title: 'فاتورة ${invoice.number}',
          text: 'فاتورة ماركت بلس ${invoice.number}',
          files: [XFile.fromData(bytes, mimeType: 'application/pdf')],
          fileNameOverrides: ['market-plus-invoice-${invoice.id}.pdf'],
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إنشاء أو مشاركة PDF: $e')));
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> printPdf(Invoice invoice) async {
    setState(() => working = true);
    try {
      final bytes = await buildPdf(invoice);
      await Printing.layoutPdf(name: 'Market Plus Invoice ${invoice.id}', onLayout: (_) async => bytes);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذرت الطباعة: $e')));
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> voidInvoice(Invoice invoice) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إلغاء الفاتورة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('سيتم إلغاء الفاتورة وإرجاع أثر البيع إلى المخزون. هذه عملية إدارية موثقة.'),
            const SizedBox(height: 12),
            TextField(controller: reason, maxLength: 500, maxLines: 3, decoration: const InputDecoration(labelText: 'سبب الإلغاء', hintText: 'مثال: خطأ في عملية البيع')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('تراجع')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, reason.text.trim().length >= 3),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );
    final text = reason.text.trim();
    reason.dispose();
    if (confirmed != true || text.length < 3 || !mounted) return;

    setState(() => working = true);
    try {
      await context.read<InvoiceRepository>().voidInvoice(invoice.id, reason: text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إلغاء الفاتورة وتحديث المخزون.')));
      await reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AppSession>().user?.isAdmin == true;
    return Scaffold(
      appBar: AppBar(title: const Text('الفاتورة')),
      body: FutureBuilder<Invoice>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && snap.data == null) return const Center(child: CircularProgressIndicator());
          if (snap.hasError || snap.data == null) {
            return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('تعذر تحميل الفاتورة\n${snap.error ?? ''}', textAlign: TextAlign.center)));
          }
          final invoice = snap.data!;
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
              children: [
                _InvoiceHero(invoice: invoice),
                const SizedBox(height: 12),
                _ItemsCard(invoice: invoice),
                if (invoice.paymentType == 2) ...[
                  const SizedBox(height: 12),
                  _DebtCard(invoice: invoice),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: OutlinedButton.icon(onPressed: working ? null : () => sharePdf(invoice), icon: const Icon(Icons.ios_share_rounded), label: const Text('PDF'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(onPressed: working ? null : () => printPdf(invoice), icon: const Icon(Icons.print_outlined), label: const Text('طباعة'))),
                  ],
                ),
                if ((invoice.customerPhone ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  FilledButton.icon(onPressed: working ? null : () => sendWhatsApp(invoice), icon: const Icon(Icons.send_outlined), label: const Text('إرسال عبر واتساب')),
                ],
                if (isAdmin && !invoice.isVoided) ...[
                  const SizedBox(height: 18),
                  const Divider(),
                  const SizedBox(height: 8),
                  if (invoice.paymentType == 2 && invoice.paidAmount > 0)
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(color: ZColors.warningSurface, borderRadius: BorderRadius.circular(12)),
                      child: const Text('لا يمكن إلغاء فاتورة آجلة استلمنا منها دفعة؛ يلزم مسار استرداد مالي مستقل.', style: TextStyle(fontSize: 11, color: ZColors.yellowText)),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: working ? null : () => voidInvoice(invoice),
                      style: OutlinedButton.styleFrom(foregroundColor: ZColors.danger, side: const BorderSide(color: ZColors.danger)),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('إلغاء الفاتورة وإرجاع المخزون'),
                    ),
                ],
                const SizedBox(height: 10),
                TextButton.icon(onPressed: () => context.go('/home'), icon: const Icon(Icons.home_outlined), label: const Text('العودة للرئيسية')),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InvoicePdfFonts {
  const _InvoicePdfFonts({
    required this.regular,
    required this.bold,
    required this.fallback,
  });

  final pw.Font regular;
  final pw.Font bold;
  final pw.Font fallback;
}

class _InvoiceHero extends StatelessWidget {
  const _InvoiceHero({required this.invoice});
  final Invoice invoice;
  @override
  Widget build(BuildContext context) {
    final label = invoice.isVoided
        ? 'ملغاة'
        : invoice.isPaid
            ? 'مدفوعة'
            : invoice.isPartiallyPaid
                ? 'مدفوعة جزئيًا'
                : 'بانتظار السداد';
    final tone = invoice.isVoided ? ZColors.danger : invoice.isPaid ? ZColors.success : ZColors.yellowText;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF1A3C34), ZColors.green]), boxShadow: ZShadow.float),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: ZColors.yellow, borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.receipt_long_rounded, color: ZColors.green)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('فاتورة ماركت بلس', style: TextStyle(fontSize: 11, color: Color(0xFFC5D7D2))), const SizedBox(height: 2), Directionality(textDirection: TextDirection.ltr, child: Text(invoice.number, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.left, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)))])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)), child: Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: tone))),
        ]),
        const SizedBox(height: 18),
        const Text('الإجمالي', style: TextStyle(fontSize: 10.5, color: Color(0xFFC5D7D2))),
        const SizedBox(height: 2),
        Text('${invoice.total.toStringAsFixed(0)} ر.ي', style: const TextStyle(color: Colors.white, fontSize: 31, fontWeight: FontWeight.w900)),
        const SizedBox(height: 9),
        Text(DateFormat('yyyy/MM/dd • HH:mm').format(invoice.createdAt.toLocal()), style: const TextStyle(fontSize: 10, color: Color(0xFFC5D7D2))),
        if ((invoice.customerName ?? '').trim().isNotEmpty) ...[const SizedBox(height: 3), Text(invoice.customerName!, style: const TextStyle(color: ZColors.yellow, fontWeight: FontWeight.w800))],
      ]),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.invoice});
  final Invoice invoice;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFE5E8EE)), boxShadow: ZShadow.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تفاصيل الأصناف', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: ZColors.green)),
            const SizedBox(height: 10),
            ...invoice.items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text('${item.quantity} × ${item.unitPrice.toStringAsFixed(0)} ر.ي', style: const TextStyle(fontSize: 10, color: ZColors.muted))])),
                Text('${item.total.toStringAsFixed(0)} ر.ي', style: const TextStyle(fontWeight: FontWeight.w900, color: ZColors.green)),
              ]),
            )),
            const Divider(height: 22),
            Row(children: [const Expanded(child: Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.w900))), Text('${invoice.total.toStringAsFixed(0)} ر.ي', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ZColors.green))]),
          ],
        ),
      );
}

class _DebtCard extends StatelessWidget {
  const _DebtCard({required this.invoice});
  final Invoice invoice;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: ZColors.background, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E8EE))),
        child: Column(children: [
          Row(children: [const Expanded(child: Text('المدفوع', style: TextStyle(color: ZColors.muted))), Text('${invoice.paidAmount.toStringAsFixed(0)} ر.ي', style: const TextStyle(fontWeight: FontWeight.w900, color: ZColors.success))]),
          const SizedBox(height: 8),
          Row(children: [const Expanded(child: Text('المتبقي', style: TextStyle(color: ZColors.muted))), Text('${invoice.remainingAmount.toStringAsFixed(0)} ر.ي', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: ZColors.danger))]),
          if (invoice.payments.isNotEmpty) ...[
            const Divider(height: 22),
            Align(alignment: AlignmentDirectional.centerStart, child: Text('${invoice.payments.length} دفعة مسجلة', style: const TextStyle(fontSize: 10.5, color: ZColors.subtle))),
          ],
        ]),
      );
}
