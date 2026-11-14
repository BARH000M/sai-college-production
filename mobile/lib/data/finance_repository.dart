import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const financeMethods = {
  'cash': 'نقداً',
  'bank_transfer': 'تحويل بنكي',
  'wallet': 'محفظة',
  'card': 'بطاقة',
};

String financeAmount(String value) {
  final match = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(value.trim());
  if (match == null) throw const FormatException('المبلغ غير صالح');
  final fraction = (match[2] ?? '').padRight(3, '0');
  final cents =
      BigInt.parse(match[1]!) * BigInt.from(100) +
      BigInt.parse(fraction.substring(0, 2)) +
      (int.parse(fraction[2]) >= 5 ? BigInt.one : BigInt.zero);
  if (cents > BigInt.from(999999999999)) {
    throw const FormatException('المبلغ يتجاوز الحد المسموح');
  }
  return '${cents ~/ BigInt.from(100)}.${(cents % BigInt.from(100)).toString().padLeft(2, '0')}';
}

class FinanceRepository {
  FinanceRepository(this.client);
  final SupabaseClient client;
  String get _pendingKey {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('يلزم تسجيل الدخول');
    return 'sai.finance.payment.${user.id}';
  }

  Future<List<Map<String, dynamic>>> rows(
    String name, [
    Map<String, dynamic>? params,
  ]) async {
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};
    int? expected;
    while (true) {
      final response = await client
          .rpc(name, params: params)
          .select()
          .range(result.length, result.length + 999)
          .count(CountOption.exact);
      final page = List<Map<String, dynamic>>.from(response.data);
      expected ??= response.count;
      if (response.count != expected) {
        throw StateError('تغيرت السجلات أثناء التحميل؛ أعد المحاولة');
      }
      for (final row in page) {
        if (row['id'] == null || !seen.add('${row['id']}')) {
          throw StateError('سجلات غير متسقة');
        }
      }
      result.addAll(page);
      if (result.length > expected ||
          (page.isEmpty && result.length < expected)) {
        throw StateError('سجلات غير مكتملة');
      }
      if (result.length == expected) return result;
    }
  }

  Future<Map<String, dynamic>?> pending() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_pendingKey);
    if (value == null) return null;
    final data = Map<String, dynamic>.from(jsonDecode(value) as Map);
    for (final key in [
      'wanted_assignment',
      'wanted_amount',
      'wanted_method',
      'wanted_key',
    ]) {
      if (data[key] is! String || (data[key] as String).isEmpty) {
        throw StateError('محاولة دفع محفوظة غير صالحة');
      }
    }
    _validate(
      data['wanted_amount'] as String,
      data['wanted_method'] as String,
      data['wanted_reference'] as String? ?? '',
    );
    return data;
  }

  void _validate(String amount, String method, String reference) {
    if (financeAmount(amount) == '0.00' ||
        !financeMethods.containsKey(method) ||
        (method != 'cash' && reference.trim().isEmpty)) {
      throw const FormatException('تحقق من المبلغ وطريقة الدفع والمرجع');
    }
  }

  Future<void> clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove(_pendingKey)) {
      throw StateError('تعذر إزالة محاولة الدفع');
    }
  }

  Future<String> pay(
    String assignment,
    String amount,
    String method,
    String reference,
  ) async {
    // Persist the exact request BEFORE sending. A retry after timeout or restart
    // uses the same server idempotency key, including on another invoice screen.
    var request = await pending();
    if (request != null && request['wanted_assignment'] != assignment) {
      throw StateError(
        'تحقق من محاولة الدفع المحفوظة على الفاتورة الأخرى أولاً',
      );
    }
    if (request == null) {
      _validate(amount, method, reference);
      final random = Random.secure();
      final bytes = List.generate(16, (_) => random.nextInt(256));
      bytes[6] = (bytes[6] & 15) | 64;
      bytes[8] = (bytes[8] & 63) | 128;
      final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      request = {
        'wanted_assignment': assignment,
        'wanted_amount': financeAmount(amount),
        'wanted_method': method,
        'wanted_reference': reference.trim().isEmpty ? null : reference.trim(),
        'wanted_key':
            '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}',
      };
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(_pendingKey, jsonEncode(request))) {
        throw StateError('تعذر حفظ محاولة الدفع؛ لم ترسل');
      }
    }
    final id = await client.rpc('sai_finance_pay', params: request);
    if (id is! String || id.isEmpty) {
      throw StateError('تعذر تأكيد الدفعة؛ تحقق من السجل قبل إعادة المحاولة');
    }
    await clearPending();
    return id;
  }
}
