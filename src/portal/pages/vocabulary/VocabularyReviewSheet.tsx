import { PrintDoc } from "@/portal/pages/academics/PrintDoc";
import { printReference } from "@/portal/lib/letterhead";
import type { VocabularyCourse, VocabularyLesson, VocabularyWord } from "@/portal/lib/vocabulary";

/**
 * Printable review sheet for one lesson's word bank.
 * Reuses the shared centred letterhead so the sheet leaves the college with the
 * same official identity as every other printed document.
 */
export function VocabularyReviewSheet({
  lesson, course, words, onClose,
}: {
  lesson: VocabularyLesson;
  course: VocabularyCourse | undefined;
  words: readonly VocabularyWord[];
  onClose: () => void;
}) {
  const levels = Array.from(new Set(
    words.map((word) => word.hsk_level).filter((level): level is number => typeof level === "number"),
  )).sort((a, b) => a - b);
  const withExamples = words.filter((word) => word.example_zh).length;

  return <PrintDoc
    title="كشف مراجعة المفردات"
    subtitle={`${course?.title ?? "مقرر"} · الدرس ${lesson.position}: ${lesson.title} — ${words.length} مفردة`}
    onClose={onClose}
  >
    <div className="sheet-summary">
      <div><span>المقرر</span><strong>{course?.title ?? "—"}</strong></div>
      <div><span>الدرس</span><strong>{lesson.title}</strong></div>
      <div><span>عدد المفردات</span><strong>{words.length}</strong></div>
      <div><span>مستوى HSK</span><strong>{levels.length ? levels.map((level) => `HSK ${level}`).join(" · ") : "غير محدد"}</strong></div>
    </div>

    <div className="report-section">
      <strong className="report-heading">قائمة المفردات للتدريب الكتابي ({words.length} مفردة)</strong>
      <div className="table-scroll">
        <table className="sheet-table vocab-sheet-table">
          <thead>
            <tr>
              <th className="sheet-col-index">#</th>
              <th>المفردة</th>
              <th>البينيين</th>
              <th>المعنى</th>
              <th>النوع</th>
              <th>HSK</th>
              <th>الجملة التوضيحية</th>
              <th className="vocab-sheet-practice">تدريب كتابي</th>
            </tr>
          </thead>
          <tbody>
            {words.map((word, index) => <tr key={word.id}>
              <td className="sheet-col-index">{index + 1}</td>
              <td><strong className="vocab-sheet-hanzi">{word.hanzi}</strong></td>
              <td dir="ltr">{word.pinyin}</td>
              <td>{word.meaning_ar}</td>
              <td>{word.part_of_speech ?? "—"}</td>
              <td>{word.hsk_level ?? "—"}</td>
              <td>
                {word.example_zh ? <>
                  <span className="vocab-sheet-example">{word.example_zh}</span>
                  {word.example_ar && <span className="sheet-sub">{word.example_ar}</span>}
                </> : <span className="muted">—</span>}
              </td>
              <td className="vocab-sheet-practice" />
            </tr>)}
          </tbody>
        </table>
      </div>
    </div>

    <p className="sheet-note">
      طريقة الاستخدام: يقرأ الطالب المفردة والبينيين بصوت عالٍ، ثم يكتبها ثلاث مرات في خانة التدريب،
      بعد ذلك يغطي عمود المعنى ويسمّي المفردة من الذاكرة. يعيد المعلم توزيع الكشف أسبوعياً لمتابعة الإتقان.
      {" "}مرجع الكشف: {printReference("VOC")} · {withExamples} من {words.length} مفردة بجملة توضيحية.
    </p>

    <div className="receipt-signatures">
      <div><span>إعداد المعلم / قسم اللغة الصينية</span></div>
      <div><span>اعتماد الشؤون الأكاديمية</span></div>
    </div>
  </PrintDoc>;
}