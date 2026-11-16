import 'package:flutter_test/flutter_test.dart';
import 'package:sai_approved_mobile/data/finance_repository.dart';

void main() {
  test(
    'YER matches web and PostgreSQL half-up rounding and numeric limits',
    () {
      expect(financeAmount('2.345'), '2.35');
      expect(financeAmount('2.3449'), '2.34');
      expect(financeAmount('0001.2'), '1.20');
      expect(financeAmount('9999999999.994'), '9999999999.99');
      for (final value in [
        '',
        '-1',
        'NaN',
        '1e2',
        '.5',
        '1.',
        '1,000',
        '9999999999.995',
      ]) {
        expect(() => financeAmount(value), throwsFormatException);
      }
    },
  );
}
