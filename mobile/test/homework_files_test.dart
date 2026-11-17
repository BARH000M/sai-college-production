import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sai_approved_mobile/data/homework_files.dart';

final class _TestPlatformFile extends PlatformFile {
  _TestPlatformFile({
    required String name,
    required int size,
    required Uint8List? bytes,
  }) : super(name, size, bytes);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test('validates homework attachment types and MIME contracts', () {
    final pdf = _TestPlatformFile(
      name: 'assignment.pdf',
      size: 3,
      bytes: Uint8List.fromList([1, 2, 3]),
    );
    expect(validateHomeworkFile(pdf), 'application/pdf');
  });

  test('rejects empty or unsupported homework attachments', () {
    final empty = _TestPlatformFile(
      name: 'empty.pdf',
      size: 0,
      bytes: Uint8List(0),
    );
    expect(() => validateHomeworkFile(empty), throwsFormatException);

    final unsupported = _TestPlatformFile(
      name: 'script.exe',
      size: 3,
      bytes: Uint8List.fromList([1, 2, 3]),
    );
    expect(() => validateHomeworkFile(unsupported), throwsFormatException);
  });
}
