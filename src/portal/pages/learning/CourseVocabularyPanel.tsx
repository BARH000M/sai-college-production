import { useCallback, useEffect, useMemo, useState } from "react";
import {
  deleteVocabularyWord, loadCourseVocabulary,
  type VocabularyWord,
} from "@/portal/lib/vocabulary";
import type { LearningCourse, LearningLesson } from "@/portal/lib/learning";
import { VocabularyWordForm } from "@/portal/pages/learning/VocabularyWordForm";
import { VocabularyBulkImport } from "@/portal/pages/learning/VocabularyBulkImport";
import { VocabularyReviewSheet } from "@/portal/pages/vocabulary/VocabularyReviewSheet";

const message = (error: unknown) => (error instanceof Error ? error.message : String(error));

/**
 * Word-bank editor shown inside the course screen for staff who manage content.
 * Writes go straight to learning_vocabulary through Row Level Security, so a
 * teacher can build the bank without ever opening SQL.
 */
export function CourseVocabularyPanel({
  course, lessons,
}: {
  course: LearningCourse;
  lessons: readonly LearningLesson[];
}) {
  const [words, setWords] = useState<VocabularyWord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [retry, setRetry] = useState(0);
  const [editorOpen, setEditorOpen] = useState(false);
  const [importOpen, setImportOpen] = useState(false);
  const [printLessonId, setPrintLessonId] = useState("");
  const [editing, setEditing] = useState<VocabularyWord | null>(null);
  const [confirmId, setConfirmId] = useState("");
  const [deletingId, setDeletingId] = useState("");
  const [notice, setNotice] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    setLoading(true);
    setError(null);
    loadCourseVocabulary(course.id)
      .then((rows) => { if (active) setWords(rows); })
      .catch((failure: unknown) => { if (active) { setWords([]); setError(message(failure)); } })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [course.id, retry]);

  const courseLessons = useMemo(
    () => [...lessons].sort((a, b) => a.position - b.position),
    [lessons],
  );
  const lessonName = useCallback(
    (id: string | null) => (id ? courseLessons.find((lesson) => lesson.id === id)?.title ?? "درس محذوف" : "عام للمقرر"),
    [courseLessons],
  );

  const published = words.filter((word) => word.is_published).length;
  const linked = words.filter((word) => word.lesson_id).length;

  const printGroups = useMemo(
    () => courseLessons
      .map((lesson) => ({ lesson, rows: words.filter((word) => word.lesson_id === lesson.id) }))
      .filter((group) => group.rows.length > 0),
    [courseLessons, words],
  );
  const printLesson = courseLessons.find((lesson) => lesson.id === printLessonId) ?? null;

  function refresh() { setRetry((value) => value + 1); }

  function startAdd() {
    setEditing(null);
    setEditorOpen(true);
    setImportOpen(false);
    setNotice(null);
    setActionError(null);
  }

  function startImport() {
    setEditorOpen(false);
    setEditing(null);
    setImportOpen(true);
    setNotice(null);
    setActionError(null);
  }

  function handleImported(rows: VocabularyWord[]) {
    setWords((current) => {
      const added = new Set(rows.map((row) => row.id));
      return [...current.filter((word) => !added.has(word.id)), ...rows]
        .sort((a, b) => a.position - b.position);
    });
    setImportOpen(false);
    setNotice(rows.length === 1
      ? `أُضيفت مفردة «${rows[0].hanzi}» من القائمة.`
      : `أُضيفت ${rows.length} مفردة من القائمة إلى بنك كلمات المقرر.`);
    setActionError(null);
  }

  function startEdit(word: VocabularyWord) {
    setEditing(word);
    setEditorOpen(true);
    setConfirmId("");
    setNotice(null);
    setActionError(null);
  }

  function handleSaved(row: VocabularyWord, created: boolean) {
    setWords((current) => {
      const rest = current.filter((word) => word.id !== row.id);
      return [...rest, row].sort((a, b) => a.position - b.position);
    });
    setEditorOpen(false);
    setEditing(null);
    setNotice(created ? `أُضيفت المفردة «${row.hanzi}» إلى بنك كلمات المقرر.` : `حُفظت تعديلات المفردة «${row.hanzi}».`);
    setActionError(null);
  }

  async function handleDelete(id: string) {
    if (deletingId) return;
    setDeletingId(id);
    setActionError(null);
    setNotice(null);
    try {
      await deleteVocabularyWord(id);
      setWords((current) => current.filter((word) => word.id !== id));
      setNotice("حُذفت المفردة من بنك الكلمات.");
      setConfirmId("");
    } catch (failure) {
      setActionError(message(failure));
    } finally {
      setDeletingId("");
    }
  }

  return <div className="course-vocab">
    <div className="page-heading course-vocab-head">
      <div>
        <h2><i className="ri-translate-2" aria-hidden="true"></i> مفردات المقرر</h2>
        <p className="data-note">
          بنك كلمات هذا المقرر، مرتبط بدروسه. أضف المفردة هنا فتظهر مباشرة في صفحة المفردات وبطاقات المراجعة.
        </p>
      </div>
      <div className="actions">
        <button className="button secondary" type="button" onClick={refresh} disabled={loading}>
          <i className="ri-refresh-line" aria-hidden="true"></i> تحديث
        </button>
        <button className="button secondary" type="button" onClick={startImport} disabled={loading}>
          <i className="ri-file-list-3-line" aria-hidden="true"></i> استيراد قائمة
        </button>
        <button className="button primary" type="button" onClick={startAdd} disabled={editorOpen && !editing}>
          <i className="ri-add-line" aria-hidden="true"></i> إضافة مفردة
        </button>
      </div>
    </div>

    <div className="vocab-editor-stats">
      <span><strong>{words.length}</strong> مفردة في البنك</span>
      <span><strong>{published}</strong> منشورة</span>
      <span><strong>{words.length - published}</strong> مسودة</span>
      <span><strong>{linked}</strong> مرتبطة بدروس</span>
    </div>

    {notice && <p className="success-box" role="status">{notice}</p>}
    {actionError && <p className="error-box" role="alert">{actionError}</p>}

    {editorOpen && <VocabularyWordForm
      key={editing?.id ?? "new"}
      courseId={course.id}
      lessons={courseLessons}
      word={editing}
      onSaved={handleSaved}
      onCancel={() => { setEditorOpen(false); setEditing(null); }}
    />}

    {importOpen && <VocabularyBulkImport
      courseId={course.id}
      lessons={courseLessons}
      existingHanzi={words.map((word) => word.hanzi)}
      onImported={handleImported}
      onCancel={() => setImportOpen(false)}
    />}

    {loading && <p className="muted" role="status">جارٍ تحميل مفردات المقرر...</p>}
    {error && <p className="error-box" role="alert">
      تعذر تحميل مفردات المقرر: {error}
      <button className="text-button" type="button" onClick={refresh}>إعادة المحاولة</button>
    </p>}

    {!loading && !error && (words.length === 0
      ? <p className="vocab-editor-empty">
        <i className="ri-book-open-line" aria-hidden="true"></i>
        لا توجد مفردات في هذا المقرر بعد. ابدأ بإضافة أول مفردة وربطها بدرس ليحصل الطالب على بطاقات مراجعة.
      </p>
      : <div className="table-scroll">
        <table className="management-table vocab-table vocab-editor-table">
          <thead>
            <tr>
              <th>#</th>
              <th>المفردة</th>
              <th>البينيين</th>
              <th>المعنى</th>
              <th>الدرس</th>
              <th>HSK</th>
              <th>الحالة</th>
              <th>إجراءات</th>
            </tr>
          </thead>
          <tbody>
            {words.map((word, index) => <tr key={word.id}>
              <td>{index + 1}</td>
              <td><strong className="vocab-hanzi-cell">{word.hanzi}</strong></td>
              <td dir="ltr" className="vocab-pinyin-cell">{word.pinyin}</td>
              <td>
                {word.meaning_ar}
                {word.meaning_en && <small className="data-note" dir="ltr">{word.meaning_en}</small>}
              </td>
              <td><span className="vocab-lesson-cell">{lessonName(word.lesson_id)}</span></td>
              <td>{word.hsk_level ?? "—"}</td>
              <td>
                <span className={`lab-status ${word.is_published ? "status-ok" : "status-warn"}`}>
                  {word.is_published ? "منشورة" : "مسودة"}
                </span>
              </td>
              <td>
                {confirmId === word.id
                  ? <div className="vocab-row-actions">
                    <button
                      className="button primary"
                      type="button"
                      disabled={deletingId === word.id}
                      onClick={() => void handleDelete(word.id)}
                    >{deletingId === word.id ? "جارٍ الحذف..." : "تأكيد الحذف"}</button>
                    <button className="button secondary" type="button" onClick={() => setConfirmId("")}>إلغاء</button>
                  </div>
                  : <div className="vocab-row-actions">
                    <button className="button secondary" type="button" onClick={() => startEdit(word)}>
                      <i className="ri-edit-line" aria-hidden="true"></i> تعديل
                    </button>
                    <button className="button secondary" type="button" onClick={() => setConfirmId(word.id)}>
                      <i className="ri-delete-bin-line" aria-hidden="true"></i> حذف
                    </button>
                  </div>}
              </td>
            </tr>)}
          </tbody>
        </table>
      </div>)}

    {!loading && !error && printGroups.length > 0 && <section className="vocab-print">
      <div className="vocab-print-head">
        <strong>
          <i className="ri-printer-line" aria-hidden="true"></i> كشوف مراجعة الدروس
        </strong>
        <small className="data-note">اطبع كشف الدرس مباشرة من هنا، بنفس الترويسة الرسمية وبخانة تدريب كتابي.</small>
      </div>
      <div className="vocab-print-grid">
        {printGroups.map((group) => <div className="vocab-print-card" key={group.lesson.id}>
          <span className="vocab-print-index">{group.lesson.position}</span>
          <div className="vocab-print-body">
            <strong>{group.lesson.title}</strong>
            <small className="data-note">
              {group.rows.length} مفردة · {group.rows.filter((word) => word.is_published).length} منشورة
            </small>
          </div>
          <button
            className="button secondary"
            type="button"
            onClick={() => setPrintLessonId(group.lesson.id)}
          >
            <i className="ri-printer-line" aria-hidden="true"></i> طباعة الكشف
          </button>
        </div>)}
      </div>
    </section>}

    <p className="data-note">
      تُحفظ المفردات في قاعدة البيانات مباشرة، وتتبع صلاحية إدارة المقرر. تغييراتك تُسجَّل باسم حسابك.
    </p>

    {printLesson && <VocabularyReviewSheet
      lesson={printLesson}
      course={course}
      words={words.filter((word) => word.lesson_id === printLesson.id)}
      onClose={() => setPrintLessonId("")}
    />}
  </div>;
}