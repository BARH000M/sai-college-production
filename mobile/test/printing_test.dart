import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sai_approved_mobile/data/curriculum.dart';
import 'package:sai_approved_mobile/ui/printing.dart';

void main() {
  testWidgets(
    'A4 lesson report lays out Arabic and Chinese over multiple pages',
    (tester) async {
      final result = await tester.runAsync(() async {
        await FontLoader('Cairo').addAndLoad('assets/fonts/Cairo.ttf');
        await FontLoader('NotoSC').addAndLoad('assets/fonts/NotoSansSC.otf');
        final report = CollegeReport(
          title: 'دليل المفردات • اللغة الصينية',
          subtitle: 'المستوى الأساسي A0',
          columns: const [
            PrintColumn('الكلمة', ltr: true),
            PrintColumn('النطق', ltr: true),
            PrintColumn('المعنى', flex: 2),
          ],
          rows: [
            for (final lesson in courses[1].lessons)
              for (final word in lesson.words)
                [word.hanzi, word.pinyin, word.arabic],
          ],
          preview: true,
          signature: true,
        );
        final bytes = await buildCollegePdf(report);
        const sample = String.fromEnvironment('SAI_PRINT_SAMPLE');
        if (sample.isNotEmpty) await File(sample).writeAsBytes(bytes);
        return latin1.decode(bytes);
      });
      expect(result, startsWith('%PDF-'));
      expect(result, contains('/Count 2'));
    },
  );
}

extension on FontLoader {
  Future<void> addAndLoad(String path) {
    addFont(rootBundle.load(path));
    return load();
  }
}
