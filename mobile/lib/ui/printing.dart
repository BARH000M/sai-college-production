import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/branding.dart';
import 'components.dart';

class PrintColumn {
  const PrintColumn(this.title, {this.flex = 1, this.ltr = false});
  final String title;
  final double flex;
  final bool ltr;
}

class CollegeReport {
  const CollegeReport({
    required this.title,
    required this.columns,
    required this.rows,
    required this.preview,
    this.subtitle = '',
    this.signature = false,
  });
  final String title, subtitle;
  final bool preview, signature;
  final List<PrintColumn> columns;
  final List<List<String>> rows;
}

/// Let Flutter shape Arabic and Chinese before placing the print artwork in
/// the PDF. The font and logo come from the app bundle, so printing works offline.
Future<Uint8List> buildCollegePdf(CollegeReport report) async {
  const paper = PdfPageFormat.a4;
  const margin = 38.0;
  const scale = 3.0;
  final width = paper.width - 2 * margin;
  final weights = report.columns.fold(0.0, (sum, c) => sum + c.flex);
  final widths = report.columns.map((c) => c.flex * width / weights).toList();
  final now = DateTime.now();
  final date =
      '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  final asset = await rootBundle.load(logoAsset);
  final codec = await ui.instantiateImageCodec(
    asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
    targetWidth: 240,
  );
  final logo = (await codec.getNextFrame()).image;
  codec.dispose();
  try {
    final pdf = pw.Document(title: report.title, author: collegeArabic);
    final rows = report.rows.isEmpty
        ? [List.filled(report.columns.length, '—')]
        : report.rows;
    var cursor = 0;
    var pageNumber = 0;
    while (cursor < rows.length) {
      pageNumber++;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(scale);
      canvas.drawColor(Colors.white, BlendMode.src);
      canvas.drawRect(
        Rect.fromLTWH(margin, 24, width, 3),
        Paint()..color = darkRed,
      );
      canvas.drawImageRect(
        logo,
        Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
        Rect.fromLTWH((paper.width - 56) / 2, 38, 56, 56),
        Paint()..filterQuality = FilterQuality.high,
      );
      void center(
        String value,
        double y,
        double size, {
        Color color = ink,
        bool bold = false,
        bool ltr = false,
      }) {
        _paintText(
          canvas,
          value,
          Rect.fromLTWH(margin, y, width, 30),
          size,
          center: true,
          color: color,
          bold: bold,
          ltr: ltr,
          maxLines: 1,
        );
      }

      center(collegeArabic, 99, 17, color: darkRed, bold: true);
      center(collegeChinese, 126, 14, color: darkRed, ltr: true);
      center(collegeWebsite, 151, 10, ltr: true);
      center(collegeEmail, 166, 10, ltr: true);
      center('$collegePhone  |  $collegeLandline', 181, 10, ltr: true);
      canvas.drawRect(
        Rect.fromLTWH(margin, 204, width, 1),
        Paint()..color = gold,
      );
      center(report.title, 218, 20, color: darkRed, bold: true);
      center(
        report.subtitle.isEmpty
            ? 'تاريخ الإصدار \u2066$date\u2069'
            : '\u2068${report.subtitle}\u2069  •  \u2066$date\u2069',
        251,
        10,
      );
      if (report.preview) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(margin, 273, width, 23),
            const Radius.circular(5),
          ),
          Paint()..color = const Color(0xFFFBEDEB),
        );
        center(
          'نسخة تجريبية • بيانات توضيحية',
          274,
          10,
          bold: true,
          color: darkRed,
        );
      }
      var y = report.preview ? 309.0 : 283.0;
      canvas.drawRect(
        Rect.fromLTWH(margin, y, width, 29),
        Paint()..color = darkRed,
      );
      var x = paper.width - margin;
      for (var col = 0; col < report.columns.length; col++) {
        x -= widths[col];
        _paintText(
          canvas,
          report.columns[col].title,
          Rect.fromLTWH(x + 7, y + 5, widths[col] - 14, 21),
          11,
          bold: true,
          color: Colors.white,
          center: report.columns[col].ltr,
          maxLines: 1,
        );
      }
      y += 29;
      while (cursor < rows.length) {
        final row = rows[cursor];
        final painters = [
          for (var col = 0; col < report.columns.length; col++)
            _text(
              col < row.length ? row[col] : '—',
              11,
              widths[col] - 14,
              ltr: report.columns[col].ltr,
              center: report.columns[col].ltr,
              maxLines: 16,
            ),
        ];
        final rowHeight = painters.fold(
          26.0,
          (height, painter) => math.max(height, painter.height + 14),
        );
        if (y + rowHeight > paper.height - 98) {
          for (final painter in painters) {
            painter.dispose();
          }
          break;
        }
        if (cursor.isEven) {
          canvas.drawRect(
            Rect.fromLTWH(margin, y, width, rowHeight),
            Paint()..color = const Color(0xFFFAF5F0),
          );
        }
        x = paper.width - margin;
        for (var col = 0; col < painters.length; col++) {
          x -= widths[col];
          painters[col].paint(canvas, Offset(x + 7, y + 7));
          painters[col].dispose();
        }
        y += rowHeight;
        canvas.drawLine(
          Offset(margin, y),
          Offset(paper.width - margin, y),
          Paint()..color = const Color(0xFFE9DED6),
        );
        cursor++;
      }
      if (report.signature && cursor == rows.length) {
        center(
          'الموظف المختص __________________     الاعتماد __________________',
          paper.height - 79,
          10,
        );
      }
      canvas.drawLine(
        Offset(margin, paper.height - 49),
        Offset(paper.width - margin, paper.height - 49),
        Paint()..color = gold,
      );
      center(
        'صفحة $pageNumber  •  $collegeArabic',
        paper.height - 41,
        9,
        color: darkRed,
      );
      final picture = recorder.endRecording();
      final page = await picture.toImage(
        (paper.width * scale).ceil(),
        (paper.height * scale).ceil(),
      );
      picture.dispose();
      final bytes = await page.toByteData(format: ui.ImageByteFormat.png);
      page.dispose();
      if (bytes == null) throw StateError('تعذر تجهيز الصفحة للطباعة.');
      final image = pw.MemoryImage(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      pdf.addPage(
        pw.Page(
          pageFormat: paper,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(
            image,
            fit: pw.BoxFit.fill,
            width: paper.width,
            height: paper.height,
          ),
        ),
      );
    }
    return await pdf.save();
  } finally {
    logo.dispose();
  }
}

TextPainter _text(
  String value,
  double size,
  double width, {
  Color color = ink,
  bool bold = false,
  bool center = false,
  bool ltr = false,
  int maxLines = 2,
}) => TextPainter(
  text: TextSpan(
    text: value,
    style: TextStyle(
      fontFamily: 'Cairo',
      fontFamilyFallback: const ['NotoSC'],
      color: color,
      fontSize: size,
      height: 1.35,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
    ),
  ),
  textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
  textAlign: center
      ? TextAlign.center
      : (ltr ? TextAlign.left : TextAlign.right),
  maxLines: maxLines,
  ellipsis: '…',
)..layout(minWidth: width, maxWidth: width);

void _paintText(
  Canvas canvas,
  String text,
  Rect rect,
  double size, {
  Color color = ink,
  bool bold = false,
  bool center = false,
  bool ltr = false,
  int maxLines = 2,
}) {
  final painter = _text(
    text,
    size,
    rect.width,
    color: color,
    bold: bold,
    center: center,
    ltr: ltr,
    maxLines: maxLines,
  );
  painter.paint(canvas, rect.topLeft);
  painter.dispose();
}

class PrintAction extends StatelessWidget {
  const PrintAction(this.report, {super.key});
  final CollegeReport report;

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    tooltip: 'معاينة وطباعة',
    icon: const Icon(Icons.print_outlined),
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ReportPreview(report: report)),
    ),
  );
}

class ReportPreview extends StatefulWidget {
  const ReportPreview({super.key, required this.report});
  final CollegeReport report;

  @override
  State<ReportPreview> createState() => _ReportPreviewState();
}

class _ReportPreviewState extends State<ReportPreview> {
  late final Future<Uint8List> _pdf = buildCollegePdf(widget.report);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('معاينة الطباعة'),
      backgroundColor: darkRed,
      foregroundColor: Colors.white,
    ),
    body: FutureBuilder<Uint8List>(
      future: _pdf,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: EmptyPanel(
                'تعذر تجهيز المستند. عُد إلى الشاشة ثم جرّب مرة أخرى.',
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return PdfPreview(
          build: (_) async => snapshot.data!,
          initialPageFormat: PdfPageFormat.a4,
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
          pdfFileName: 'SAI-report.pdf',
        );
      },
    ),
  );
}
