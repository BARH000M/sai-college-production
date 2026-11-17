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
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: homeworkFileExtensions,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;
  return result.files.single;
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
  final bytes = file.bytes;
  if (bytes == null || bytes.isEmpty || bytes.length > homeworkFileLimit) {
    throw const FormatException('يجب اختيار ملف صالح لا يتجاوز ٢٠ ميجابايت.');
  }
  return homeworkFileMimeType(file);
}

Future<String> uploadHomeworkFile(String folder, PlatformFile file) async {
  final bytes = file.bytes;
  final mimeType = validateHomeworkFile(file);
  if (bytes == null) throw const FormatException('تعذر قراءة الملف المختار.');
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
