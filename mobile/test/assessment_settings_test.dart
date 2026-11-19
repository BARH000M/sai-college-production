import 'package:flutter_test/flutter_test.dart';
import 'package:sai_approved_mobile/data/assessment_settings.dart';

void main() {
  test('assessment settings serialize an optional schedule and attempt limit', () {
    final settings = AssessmentSettings.fromInput(
      startsAt: '2026-11-18T10:00:00Z',
      dueAt: '2026-11-18T11:00:00Z',
      timeLimitMinutes: '30',
      attemptLimit: '2',
      passingScore: '75.5',
      randomizeQuestions: true,
    );

    expect(settings.toJson(), {
      'starts_at': '2026-11-18T10:00:00.000Z',
      'due_at': '2026-11-18T11:00:00.000Z',
      'time_limit_minutes': 30,
      'attempt_limit': 2,
      'passing_score': 75.5,
      'randomize_questions': true,
    });
  });

  test('assessment settings reject invalid date ordering and limits', () {
    AssessmentSettings parse({
      String startsAt = '',
      String dueAt = '',
      String timeLimitMinutes = '',
      String attemptLimit = '1',
      String passingScore = '70',
    }) => AssessmentSettings.fromInput(
      startsAt: startsAt,
      dueAt: dueAt,
      timeLimitMinutes: timeLimitMinutes,
      attemptLimit: attemptLimit,
      passingScore: passingScore,
      randomizeQuestions: false,
    );

    expect(
      () => parse(
        startsAt: '2026-11-18T11:00:00Z',
        dueAt: '2026-11-18T10:00:00Z',
      ),
      throwsFormatException,
    );
    expect(() => parse(timeLimitMinutes: '301'), throwsFormatException);
    expect(() => parse(attemptLimit: '0'), throwsFormatException);
    expect(() => parse(passingScore: '101'), throwsFormatException);
  });
}
