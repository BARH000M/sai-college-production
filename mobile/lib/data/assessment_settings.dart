class AssessmentSettings {
  const AssessmentSettings({
    required this.startsAt,
    required this.dueAt,
    required this.timeLimitMinutes,
    required this.attemptLimit,
    required this.passingScore,
    required this.randomizeQuestions,
  });

  final DateTime? startsAt;
  final DateTime? dueAt;
  final int? timeLimitMinutes;
  final int attemptLimit;
  final double passingScore;
  final bool randomizeQuestions;

  factory AssessmentSettings.fromInput({
    required String startsAt,
    required String dueAt,
    required String timeLimitMinutes,
    required String attemptLimit,
    required String passingScore,
    required bool randomizeQuestions,
  }) {
    final start = startsAt.trim().isEmpty ? null : DateTime.tryParse(startsAt);
    final end = dueAt.trim().isEmpty ? null : DateTime.tryParse(dueAt);
    final duration = timeLimitMinutes.trim().isEmpty
        ? null
        : int.tryParse(timeLimitMinutes);
    final attempts = int.tryParse(attemptLimit);
    final threshold = double.tryParse(passingScore);

    if ((startsAt.trim().isNotEmpty && start == null) ||
        (dueAt.trim().isNotEmpty && end == null)) {
      throw const FormatException('موعد التقييم غير صالح.');
    }
    if (start != null && end != null && !start.isBefore(end)) {
      throw const FormatException('يجب أن يكون موعد الإغلاق بعد موعد البدء.');
    }
    if (timeLimitMinutes.trim().isNotEmpty &&
        (duration == null || duration < 1 || duration > 300)) {
      throw const FormatException('المدة يجب أن تكون بين دقيقة واحدة و٣٠٠ دقيقة.');
    }
    if (attempts == null || attempts < 1 || attempts > 10) {
      throw const FormatException('عدد المحاولات يجب أن يكون بين ١ و١٠.');
    }
    if (threshold == null || !threshold.isFinite || threshold < 0 || threshold > 100) {
      throw const FormatException('درجة الاجتياز يجب أن تكون بين صفر و١٠٠ بالمئة.');
    }
    return AssessmentSettings(
      startsAt: start?.toUtc(),
      dueAt: end?.toUtc(),
      timeLimitMinutes: duration,
      attemptLimit: attempts,
      passingScore: threshold,
      randomizeQuestions: randomizeQuestions,
    );
  }

  Map<String, dynamic> toJson() => {
    'starts_at': startsAt?.toIso8601String(),
    'due_at': dueAt?.toIso8601String(),
    'time_limit_minutes': timeLimitMinutes,
    'attempt_limit': attemptLimit,
    'passing_score': passingScore,
    'randomize_questions': randomizeQuestions,
  };
}
