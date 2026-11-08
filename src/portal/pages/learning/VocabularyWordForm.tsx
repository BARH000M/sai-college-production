import { useState, type FormEvent } from "react";
import {
  createVocabularyWord, partOfSpeechOptions, updateVocabularyWord,
  type VocabularyWord,
} from "@/portal/lib/vocabulary";
import type { LearningLesson } from "@/portal/lib/learning";

const message = (error: unknown) => (error instanceof Error ? error.message : String(error));

export function VocabularyWordForm({
  courseId, lessons, word, onSaved, onCancel,
}: {
  courseId: string;
  lessons: readonly LearningLesson[];
  word: VocabularyWord | null;
  onSaved: (row: VocabularyWord, created: boolean) => void;
  onCancel: () => void;
}) {
  const [hanzi, setHanzi] = useState(word?.hanzi ?? "");
  const [pinyin, setPinyin] = useState(word?.pinyin ?? "");
  const [meaningAr, setMeaningAr] = useState(word?.meaning_ar ?? "");
  const [meaningEn, setMeaningEn] = useState(word?.meaning_en ?? "");
  const [partOfSpeech, setPartOfSpeech] = useState(word?.part_of_speech ?? "");
  const [lessonId, setLessonId] = useState(word?.lesson_id ?? "");
  const [hskLevel, setHskLevel] = useState(word?.hsk_level ? String(word.hsk_level) : "");
  const [exampleZh, setExampleZh] = useState(word?.example_zh ?? "");
  const [exampleAr, setExampleAr] = useState(word?.example_ar ?? "");
  const [isPublished, setIsPublished] = useState(word ? word.is_published : true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (saving) return;
    setSaving(true);
    setError(null);
    try {
      const parsedHsk = hskLevel ? Number(hskLevel) : null;
      const input = {
        courseId,
        lessonId: lessonId || null,
        hanzi,
        pinyin,
        meaningAr,
        meaningEn,
        partOfSpeech,
        exampleZh,
        exampleAr,
        hskLevel: parsedHsk !== null && Number.isFinite(parsedHsk) ? parsedHsk : null,
        isPublished,
      };
      const saved = word
        ? await updateVocabularyWord(word.id, input)
        : await createVocabularyWord(input);
      onSaved(saved, !word);
    } catch (failure) {
      setError(message(failure));
    } finally {
      setSaving(false);
    }
  }

  return <form className="vocab-editor-form" onSubmit={handleSubmit}>
    <div className="vocab-editor-head">
      <strong>{word ? "تعديل المفردة" : "إضافة مفردة جديدة"}</strong>
      <span className="data-note">
        {word ? "التعديل يظهر فوراً لحسابات الطلاب في مقرر هذا الصف." : "ستُضاف المفردة إلى نهاية بنك كلمات هذا المقرر."}
      </span>
    </div>

    <div className="vocab-editor-grid">
      <label>المفردة (汉字) <span className="vocab-required">*</span>
        <input
          value={hanzi}
          maxLength={30}
          placeholder="مثال: 你好"
          onChange={(event) => setHanzi(event.target.value)}
          required
        />
      </label>
      <label>البينيين <span className="vocab-required">*</span>
        <input
          dir="ltr"
          value={pinyin}
          maxLength={60}
          placeholder="nǐ hǎo"
          onChange={(event) => setPinyin(event.target.value)}
          required
        />
      </label>
      <label>المعنى بالعربية <span className="vocab-required">*</span>
        <input
          value={meaningAr}
          maxLength={120}
          placeholder="مرحباً"
          onChange={(event) => setMeaningAr(event.target.value)}
          required
        />
      </label>
      <label>المعنى بالإنجليزية
        <input
          dir="ltr"
          value={meaningEn}
          maxLength={120}
          placeholder="hello"
          onChange={(event) => setMeaningEn(event.target.value)}
        />
      </label>
      <label>نوع الكلمة
        <select value={partOfSpeech} onChange={(event) => setPartOfSpeech(event.target.value)}>
          <option value="">غير محدد</option>
          {partOfSpeechOptions.map((option) => <option key={option} value={option}>{option}</option>)}
        </select>
      </label>
      <label>الدرس المرتبط
        <select value={lessonId} onChange={(event) => setLessonId(event.target.value)}>
          <option value="">بدون درس (مفردة عامة للمقرر)</option>
          {lessons.map((lesson) => <option key={lesson.id} value={lesson.id}>
            {lesson.position}. {lesson.title}
          </option>)}
        </select>
      </label>
      <label>مستوى HSK
        <select value={hskLevel} onChange={(event) => setHskLevel(event.target.value)}>
          <option value="">غير محدد</option>
          {[1, 2, 3, 4, 5, 6, 7, 8, 9].map((level) => <option key={level} value={level}>HSK {level}</option>)}
        </select>
      </label>
      <label className="vocab-editor-checkbox">
        <input type="checkbox" checked={isPublished} onChange={(event) => setIsPublished(event.target.checked)} />
        منشورة للطلاب
      </label>
      <label className="vocab-editor-wide">الجملة التوضيحية (中文)
        <textarea
          rows={2}
          value={exampleZh}
          maxLength={200}
          placeholder="你好，我叫 Ahmed。"
          onChange={(event) => setExampleZh(event.target.value)}
        />
        <small className="data-note">{exampleZh.trim().length} / 200 حرف</small>
      </label>
      <label className="vocab-editor-wide">ترجمة الجملة
        <textarea
          rows={2}
          value={exampleAr}
          maxLength={200}
          placeholder="مرحباً، اسمي أحمد."
          onChange={(event) => setExampleAr(event.target.value)}
        />
        <small className="data-note">{exampleAr.trim().length} / 200 حرف</small>
      </label>
    </div>

    {error && <p className="error-box" role="alert">تعذر حفظ المفردة: {error}</p>}

    <div className="actions">
      <button className="button primary" type="submit" disabled={saving}>
        {saving ? "جارٍ الحفظ..." : word ? "حفظ التعديل" : "إضافة المفردة"}
      </button>
      <button className="button secondary" type="button" disabled={saving} onClick={onCancel}>إلغاء</button>
    </div>
  </form>;
}