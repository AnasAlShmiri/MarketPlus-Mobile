import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Arabic invoice font stack builds an RTL PDF', () async {
    final regular = await PdfGoogleFonts.tajawalRegular();
    final bold = await PdfGoogleFonts.tajawalBold();
    final fallback = await PdfGoogleFonts.notoSansArabicRegular();

    final document = pw.Document(
      theme: pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        fontFallback: [fallback],
      ),
    );

    document.addPage(
      pw.Page(
        build: (_) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            children: [
              pw.Text(
                'ماركت بلس | Market Plus',
                style: pw.TextStyle(
                  font: bold,
                  fontFallback: [fallback],
                  fontSize: 18,
                ),
              ),
              pw.Text(
                'فاتورة بيع - الإجمالي 100 ر.ي',
                style: pw.TextStyle(
                  font: regular,
                  fontFallback: [fallback],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final bytes = await document.save();
    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(1000));
  });
}
