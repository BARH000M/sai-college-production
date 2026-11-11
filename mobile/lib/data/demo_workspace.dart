import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/access.dart';

class DemoWorkspace extends ChangeNotifier {
  DemoWorkspace(this.preferences);

  final SharedPreferences preferences;
  static const _prefix = 'sai.preview.';

  bool get signedIn => preferences.getBool('${_prefix}signedIn') ?? false;
  Role get role => Role.values.firstWhere(
    (role) => role.name == preferences.getString('${_prefix}role'),
    orElse: () => Role.super_admin,
  );

  Future<void> setSignedIn(bool value) async {
    if (!await preferences.setBool('${_prefix}signedIn', value)) {
      throw StateError('تعذر حفظ حالة المعاينة على الجهاز.');
    }
    notifyListeners();
  }

  Future<void> selectRole(Role role) => save('role', role.name);

  String value(String key, [String fallback = '']) =>
      preferences.getString('$_prefix$key') ?? fallback;

  Future<void> save(String key, String value) async {
    if (!await preferences.setString('$_prefix$key', value)) {
      throw StateError('تعذر حفظ التغيير على الجهاز.');
    }
    notifyListeners();
  }

  bool completed(String learnerId, String lessonId) =>
      value('lesson.$learnerId.$lessonId') == 'done';

  Future<void> complete(String learnerId, String lessonId) =>
      save('lesson.$learnerId.$lessonId', 'done');
}
