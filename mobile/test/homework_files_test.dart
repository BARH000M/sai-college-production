import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sai_approved_mobile/data/homework_files.dart';

void main() {
  test('validates homework attachment types and MIME contracts', () {
    final pdf = PlatformFile(
      name: 'assignment.pdf',
      size: 3,
      bytes: Uint8List.fromList([1, 2, 3]),
    );
    expect(validateHomeworkFile(pdf), 'application/pdf');
  });

  test('rejects empty or unsupported homework attachments', () {
    final empty = PlatformFile(name: 'empty.pdf', size: 0, bytes: Uint8List(0));
    expect(() => validateHomeworkFile(empty), throwsFormatException);

    final unsupported = PlatformFile(
      name: 'script.exe',
      size: 3,
      bytes: Uint8List.fromList([1, 2, 3]),
    );
    expect(() => validateHomeworkFile(unsupported), throwsFormatException);
  });
}
