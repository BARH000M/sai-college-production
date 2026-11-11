import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_identity.dart';
import '../../core/app_role.dart';
import '../../core/sai_theme.dart';

class _Word {
  const _Word({
    required this.id,
    required this.lessonId,
    required this.hanzi,
    required this.pinyin,
    required this.meaningAr,
    required this.meaningEn,
    required this.partOfSpeech,
    required this.exampleZh,
    required this.exampleAr,
    required this.hskLevel,
  });

  final String id;
  final String? lessonId;
  final String hanzi;
  final String pinyin;
  final String meaningAr;
  final String? meaningEn;
  final String? partOfSpeech;
  final String? exampleZh;
  final String? exampleAr;
  final int? hskLevel;
}

class _Lesson {
  const _Lesson({required this.id, required this.title, required this.position});
  final String id;
  final String title;
  final int position;
}

class _BankData {
  const _BankData({required this.words, required this.lessons, required this.mastered});
  final List<_Word> words;
  final List<_Lesson> lessons;
  final Set<String> mastered;
}

/// Mobile mirror of the web word bank: the same course vocabulary, grouped by
/// lesson, with the learner's saved mastery marks read from the same table.
class VocabularyBankPage extends StatefulWidget {
  const VocabularyBankPage({super.key, required this.identity, required this.role});

  final AppIdentity identity;
  final AppRole role;

  @override
  State<VocabularyBankPage> createState() => _VocabularyBankPageState();
}

class _VocabularyBankPageState extends State<VocabularyBankPage> {
  late Future<_BankData> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_BankData> _load() async {
    final client = Supabase.instance.client;
    final words = await client
        .from('learning_vocabulary')
        .select('id,course_id,lesson_id,hanzi,pinyin,meaning_ar,meaning_en,part_of_speech,example_zh,example_ar,hsk_level,position,is_published')
        .order('position', ascending: true);
    final lessons = await client
        .from('learning_lessons')
        .select('id,course_id,title,position')
        .order('position', ascending: true);

    final parsedWords = (words as List).map((row) {
      final map = row as Map<String, dynamic>;
      return _Word(
        id: map['id'] as String,
        lessonId: map['lesson_id'] as String?,
        hanzi: (map['hanzi'] as String?) ?? '',
        pinyin: (map['pinyin'] as String?) ?? '',
        meaningAr: (map['meaning_ar'] as String?) ?? '',
        meaningEn: map['meaning_en'] as String?,
        partOfSpeech: map['part_of_speech'] as String?,
        exampleZh: map['example_zh'] as String?,
        exampleAr: map['example_ar'] as String?,
        hskLevel: (map['hsk_level'] as num?)?.toInt(),
      );
    }).toList();

    final parsedLessons = (lessons as List).map((row) {
      final map = row as Map<String, dynamic>;
      return _Lesson(
        id: map['id'] as String,
        title: (map['title'] as String?) ?? 'درس',
        position: (map['position'] as num?)?.toInt() ?? 0,
      );
    }).toList();

    final mastered = <String>{};
    if (widget.role == AppRole.student) {
      final student = await client
          .from('students')
          .select('id')
          .eq('user_id', widget.identity.userId)
          .maybeSingle();
      final studentId = student?['id'] as String?;
      if (studentId != null) {
        final rows = await client
            .from('learning_vocab_progress')
            .select('vocabulary_id,status')
            .eq('student_id', studentId)
            .eq('status', 'known');
        for (final row in rows as List) {
          final id = (row as Map<String, dynamic>)['vocabulary_id'];
          if (id is String) mastered.add(id);
        }
      }
    }

    return _BankData(words: parsedWords, lessons: parsedLessons, mastered: mastered);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بنك المفردات')),
      body: FutureBuilder<_BankData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error.toString(),
              onRetry: () => setState(() => _future = _load()),
            );
          }
          final data = snapshot.data;
          if (data == null || data.words.isEmpty) {
            return const Center(child: Text('لا توجد مفردات مسجلة بعد.', style: TextStyle(color: SaiColors.muted)));
          }
          return _buildBody(data);
        },
      ),
    );
  }

  Widget _buildBody(_BankData data) {
    final query = _query.trim().toLowerCase();
    final filtered = data.words.where((word) {
      if (query.isEmpty) return true;
      return word.hanzi.contains(query) ||
          word.pinyin.toLowerCase().contains(query) ||
          word.meaningAr.contains(query) ||
          (word.meaningEn ?? '').toLowerCase().contains(query);
    }).toList();

    final groups = <String?, List<_Word>>{};
    for (final word in filtered) {
      groups.putIfAbsent(word.lessonId, () => <_Word>[]).add(word);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(
            hintText: 'ابحث بالحرف أو البينيين أو المعنى',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.translate, color: SaiColors.red),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${filtered.length} مفردة · ${data.mastered.length} متقنة',
                    style: const TextStyle(color: SaiColors.muted, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 26),
            child: Center(child: Text('لا توجد مفردات تطابق البحث.', style: TextStyle(color: SaiColors.muted))),
          ),
        ...groups.entries.map((entry) {
          final lesson = data.lessons.where((row) => row.id == entry.key).toList();
          final title = entry.key == null
              ? 'مفردات عامة للمقرر'
              : lesson.isEmpty
                  ? 'درس'
                  : 'الدرس ${lesson.first.position}: ${lesson.first.title}';
          return _LessonGroup(title: title, words: entry.value, mastered: data.mastered);
        }),
      ],
    );
  }
}

class _LessonGroup extends StatelessWidget {
  const _LessonGroup({required this.title, required this.words, required this.mastered});

  final String title;
  final List<_Word> words;
  final Set<String> mastered;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: SaiColors.navy, fontSize: 14)),
          subtitle: Text('${words.length} مفردة', style: const TextStyle(fontSize: 11.5, color: SaiColors.muted)),
          children: words.map((word) => _WordTile(word: word, mastered: mastered.contains(word.id))).toList(),
        ),
      ),
    );
  }
}

class _WordTile extends StatelessWidget {
  const _WordTile({required this.word, required this.mastered});

  final _Word word;
  final bool mastered;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(word.hanzi, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(word.pinyin, style: const TextStyle(color: SaiColors.red, fontSize: 12.5)),
                    Text(word.meaningAr, style: const TextStyle(fontSize: 12.5, color: SaiColors.navy)),
                  ],
                ),
              ),
              if (mastered) const Icon(Icons.verified, size: 18, color: SaiColors.success),
              if (word.hskLevel != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: Text('HSK ${word.hskLevel}', style: const TextStyle(fontSize: 10.5, color: SaiColors.muted)),
                ),
            ],
          ),
          if (word.exampleZh != null && word.exampleZh!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: SaiColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: SaiColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(word.exampleZh!, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    if (word.exampleAr != null && word.exampleAr!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(word.exampleAr!, style: const TextStyle(fontSize: 11.5, color: SaiColors.muted)),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 42, color: SaiColors.red),
            const SizedBox(height: 12),
            Text('تعذر تحميل المفردات\n$message', textAlign: TextAlign.center, style: const TextStyle(color: SaiColors.muted, height: 1.7)),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }
}