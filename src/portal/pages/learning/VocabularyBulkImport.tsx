import { useMemo, useState } from "react";
import {
  bulkCreateVocabularyWords, parseVocabularyText, vocabularyImportColumns, vocabularyImportLimit,
  type VocabularyWord,
} from "@/portal/lib/vocabulary";
import type { LearningLesson } from "@/portal/lib/learning";

const message = (error: unknown) => (error instanceof Error ? error.message : String(error));

const sample = [
  "你好 | nǐ hǎo | مرحباً | hello | عبارة | HSK 1",
  "谢谢 | xiè xie | شكراً | thank you | فعل | HSK 1",
  "老师 | lǎo shī | معلم | teacher | اسم | HSK 2 | 我的老师很好。 | معلمي طيب.",
].join("\n");

/**
 * Paste a whole list of words instead of typing them one by one.
 * Every line is previewed and validated before the batch is written, so a bad
 * line never blocks the rest of the list.
 */
export function VocabularyBulkImport({
  courseId, lessons, existingHanzi, onImported, onCancel,
}: {
  courseId: string;
  lessons: readonly LearningLesson[];
  existingHanzi: readonly string[];
  onImported: (rows: VocabularyWord[]) => void;
  onCancel: () => void;
}) {
  const [text, setText] = useState("");
  const [lessonId, setLessonId] = useState("");
  const [isPublished, setIsPublished] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const existing = useMemo(
    () => new Set(existingHanzi.map((hanzi) => hanzi.trim()).filter(Boolean)),
    [existingHanzi],
  );

  const parsed = useMemo(
    () => parseVocabularyText(text, { courseId, lessonId: lessonId || null, isPublished }),
    [text, courseId, lessonId, isPublished],
  );

  const duplicates = useMemo(
    () => parsed.filter((row) => row.word && existing.has(row.word.hanzi)),
    [parsed, existing],
  );
  const invalid = useMemo(() => parsed.filter((row) => row.error), [parsed]);
  const ready = useMemo(
    () => parsed.filter((row) => row.word && !existing.has(row.word.hanzi)),
    [parsed, existing],
  );

  async function handleImport() {
    if (saving || !ready.length) return;
    setSaving(true);
    setError(null);
    try {
      const saved = await bulkCreateVocabularyWords(ready.map((row) => row.word as NonNullable<typeof row.word>));
      onImported(saved);
    } catch (failure) {
      setError(message(failure));
    } finally {
      setSaving(false);
    }
  }

  return <section className="vocab-bulk" aria-label="استيراد مفردات دفعة واحدة">
    <div className="vocab-bulk-head">
      <div>
        <strong>استيراد مفردات من قائمة</strong>
        <p className="data-note">
          الصق قائمة من Excel أو من الكتاب، سطر لكل مفردة. الترتيب: {vocabularyImportColumns.join(" · ")}.
          الأعمدة الإلزامية هي الثلاثة الأولى فقط.
        </p>
      </div>
      <span className="lab-tag">حتى {vocabularyImportLimit} مفردة</span>
    </div>

    <div className="vocab-bulk-grid">
      <label className="vocab-bulk-text">النص
        <textarea
          rows={8}
          value={text}
          dir="ltr"
          spellCheck={false}
          placeholder={sample}
          onChange={(event) => setText(event.target.value)}
        />
      </label>

      <div className="vocab-bulk-side">
        <label>الدرس المرتبط بكل السطور
          <select value={lessonId} onChange={(event) => setLessonId(event.target.value)}>
            <option value="">بدون درس (مفردات عامة للمقرر)</option>
            {lessons.map((lesson) => <option key={lesson.id} value={lesson.id}>
              {lesson.position}. {lesson.title}
            </option>)}
          </select>
        </label>

        <label className="vocab-bulk-check">
          <input
            type="checkbox"
            checked={isPublished}
            onChange={(event) => setIsPublished(event.target.checked)}
          />
          نشر المفردات فور الاستيراد
        </label>

        <dl className="vocab-bulk-tally">
          <div><dt>أسطر صالحة</dt><dd>{ready.length}</dd></div>
          <div><dt>أسطر بها خطأ</dt><dd>{invalid.length}</dd></div>
          <div><dt>مكرّرة</dt><dd>{duplicates.length}</dd></div>
        </dl>

        <button
          className="button secondary"
          type="button"
          onClick={() => setText(sample)}
        >
          <i className="ri-file-copy-line" aria-hidden="true"></i> إدراج مثال
        </button>
        <button
          className="button secondary"
          type="button"
          onClick={() => setText("")}
          disabled={!text}
        >
          <i className="ri-eraser-line" aria-hidden="true"></i> تفريغ النص
        </button>
      </div>
    </div>

    {parsed.length > 0 && <div className="vocab-bulk-preview">
      <div className="vocab-bulk-preview-head">
        <strong>معاينة الأسطر قبل الحفظ</strong>
        <small className="data-note">
          الأسطر المكرّرة لن تُضاف مرة أخرى. صحّح الأسطر المعلّمة ثم أعد الاستيراد.
        </small>
      </div>
      <div className="table-scroll">
        <table className="management-table vocab-bulk-table">
          <thead>
            <tr>
              <th>سطر</th>
              <th>المفردة</th>
              <th>البينيين</th>
              <th>المعنى</th>
              <th>HSK</th>
              <th>الحالة</th>
            </tr>
          </thead>
          <tbody>
            {parsed.map((row) => {
              const duplicate = !!row.word && existing.has(row.word.hanzi);
              const status = row.error ? "خطأ" : duplicate ? "مكرّرة" : "جاهزة";
              const statusClass = row.error ? "status-danger" : duplicate ? "status-warn" : "status-ok";
              return <tr key={row.line} className={row.error ? "vocab-bulk-row-error" : undefined}>
                <td>{row.line}</td>
                <td>{row.word?.hanzi || "—"}</td>
                <td dir="ltr">{row.word?.pinyin || "—"}</td>
                <td>{row.word?.meaningAr || "—"}</td>
                <td>{row.word?.hskLevel ?? "—"}</td>
                <td>
                  <span className={`lab-status ${statusClass}`}>{status}</span>
                  {row.error && <small className="vocab-bulk-error">{row.error}</small>}
                </td>
              </tr>;
            })}
          </tbody>
        </table>
      </div>
    </div>}

    {error && <p className="error-box" role="alert">تعذر استيراد القائمة: {error}</p>}

    <div className="actions">
      <button
        className="button primary"
        type="button"
        disabled={saving || !ready.length}
        onClick={() => void handleImport()}
      >
        {saving ? "جارٍ الاستيراد..." : `استيراد ${ready.length} مفردة`}
      </button>
      <button className="button secondary" type="button" disabled={saving} onClick={onCancel}>
        إلغاء
      </button>
    </div>
  </section>;
}