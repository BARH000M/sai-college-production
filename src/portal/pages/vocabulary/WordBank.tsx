import { useState } from "react";
import {
  wordStatus, wordStatusLabels,
  type VocabularyCourse, type VocabularyLesson, type VocabularyProgress, type VocabularyWord,
} from "@/portal/lib/vocabulary";

export function WordBank({ words, courses, lessons, progress, learnerId }: {
  words: readonly VocabularyWord[];
  courses: readonly VocabularyCourse[];
  lessons: readonly VocabularyLesson[];
  progress: readonly VocabularyProgress[];
  learnerId: string | null;
}) {
  const [expanded, setExpanded] = useState<string | null>(null);
  const courseName = (id: string) => courses.find((row) => row.id === id)?.title ?? "مقرر";
  const lessonName = (id: string | null) => (id ? lessons.find((row) => row.id === id)?.title ?? "درس" : "غير مرتبطة بدرس");

  if (!words.length) {
    return <section className="panel"><p className="muted">لا توجد مفردات تطابق البحث أو التصفية الحالية.</p></section>;
  }

  return <section className="panel">
    <div className="page-heading">
      <div>
        <h2>بنك المفردات</h2>
        <p className="data-note">كل مفردة مرتبطة بدرس في المقرر. اضغط على المفردة لعرض الجملة التوضيحية والترجمة.</p>
      </div>
      <span className="lab-pill-count">{words.length} مفردة</span>
    </div>

    <div className="table-scroll">
      <table className="management-table vocab-table">
        <thead>
          <tr>
            <th>المفردة</th>
            <th>البينيين</th>
            <th>المعنى</th>
            <th>النوع</th>
            <th>الدرس المرتبط</th>
            <th>HSK</th>
            <th>الحالة</th>
            <th>التفاصيل</th>
          </tr>
        </thead>
        <tbody>
          {words.map((word) => {
            const status = wordStatus(progress, word.id, learnerId);
            const isOpen = expanded === word.id;
            return [
              <tr key={word.id} className={isOpen ? "vocab-row-open" : undefined}>
                <td><strong className="vocab-hanzi-cell">{word.hanzi}</strong></td>
                <td dir="ltr" className="vocab-pinyin-cell">{word.pinyin}</td>
                <td>{word.meaning_ar}</td>
                <td>{word.part_of_speech ?? "—"}</td>
                <td>
                  <strong className="vocab-lesson-cell">{lessonName(word.lesson_id)}</strong>
                  <small className="data-note">{courseName(word.course_id)}</small>
                </td>
                <td>{word.hsk_level ?? "—"}</td>
                <td>
                  <span className={`lab-status ${status === "known" ? "status-ok" : status === "learning" ? "status-warn" : "status-neutral"}`}>
                    {wordStatusLabels[status]}
                  </span>
                </td>
                <td>
                  <button className="button secondary" type="button" onClick={() => setExpanded(isOpen ? null : word.id)}>
                    {isOpen ? "إخفاء" : "عرض"}
                  </button>
                </td>
              </tr>,
              isOpen ? <tr key={`${word.id}-detail`} className="vocab-detail-row">
                <td colSpan={8}>
                  <div className="vocab-detail">
                    <div>
                      <span>المثال</span>
                      <p className="vocab-example-hanzi">{word.example_zh ?? "لا يوجد مثال مسجل."}</p>
                    </div>
                    <div>
                      <span>الترجمة</span>
                      <p>{word.example_ar ?? "لا توجد ترجمة مسجلة."}</p>
                    </div>
                    <div>
                      <span>المعنى بالإنجليزية</span>
                      <p dir="ltr">{word.meaning_en ?? "—"}</p>
                    </div>
                  </div>
                </td>
              </tr> : null,
            ];
          })}
        </tbody>
      </table>
    </div>
  </section>;
}