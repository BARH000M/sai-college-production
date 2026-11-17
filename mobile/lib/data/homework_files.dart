import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const homeworkFileBucket = 'homework-files';
const homeworkFileExtensions = [
  'pdf',
  'txt',
  'doc',
  'docx',
  'xls',
  'xlsx',
  'png',
  'jpg',
  'jpeg',
];
const homeworkFileLimit = 20 * 1024 * 1024;

Future<PlatformFile?> pickHomeworkFile() async {
  return FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: homeworkFileExtensions,
  );
}

String homeworkFileMimeType(PlatformFile file) {
  switch (file.extension?.toLowerCase()) {
    case 'pdf':
      return 'application/pdf';
    case 'txt':
      return 'text/plain';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'xls':
      return 'application/vnd.ms-excel';
    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    default:
      throw const FormatException('صيغة الملف غير مدعومة.');
  }
}

String validateHomeworkFile(PlatformFile file) {
  final size = file.lengthSync();
  if (size != null && (size == 0 || size > homeworkFileLimit)) {
    throw const FormatException('يجب اختيار ملف صالح لا يتجاوز ٢٠ ميجابايت.');
  }
  return homeworkFileMimeType(file);
}

Future<String> uploadHomeworkFile(String folder, PlatformFile file) async {
  final mimeType = validateHomeworkFile(file);
  final bytes = await file.readAsBytes();
  if (bytes.isEmpty || bytes.length > homeworkFileLimit) {
    throw const FormatException('يجب اختيار ملف صالح لا يتجاوز ٢٠ ميجابايت.');
  }
  final safeName = file.name
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (safeName.isEmpty) throw const FormatException('اسم الملف غير صالح.');
  final path = '$folder/${DateTime.now().millisecondsSinceEpoch}-$safeName';
  await Supabase.instance.client.storage
      .from(homeworkFileBucket)
      .uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          cacheControl: '3600',
          upsert: false,
          contentType: mimeType,
        ),
      );
  return path;
}

Future<String> homeworkSignedUrl(String path) async {
  return Supabase.instance.client.storage
      .from(homeworkFileBucket)
      .createSignedUrl(path, 300);
}
