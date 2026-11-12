import 'package:flutter_test/flutter_test.dart';
import 'package:sai_approved_mobile/core/branding.dart';
import 'package:sai_approved_mobile/data/repository.dart';

void main() {
  test('Android/iOS client targets the one approved Supabase project', () {
    expect(backendUrl, 'https://aeryusbrulqdxjdynwfh.supabase.co');
    expect(backendUrl.startsWith('https://'), isTrue);
  });

  test('Yemen SAI official identity is retained', () {
    expect(appDisplayName, 'Yemen SAI');
    expect(collegeArabic, 'كلية ساي التعليمية اليمنية الصينية');
    expect(collegeChinese, '也门赛艾教育学院');
  });
}
