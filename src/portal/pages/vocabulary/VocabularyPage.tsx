import { useEffect, useMemo, useState } from "react";
import {
  loadVocabularyWorkspace, vocabularySummary, wordStatus,
  type VocabularyProgress, type VocabularyProgressStatus, type VocabularyWorkspace,
} from "@/portal/lib/vocabulary";
import { LabPage, LabStats, LabTabs } from "@/portal/pages/labs/LabShell";
import { Flashcards } from "@/portal/pages/vocabulary/Flashcards";
import { WordBank } from "@/portal/pages/vocabulary/WordBank";

type Tab = "bank" | "cards" | "lessons";

const errorText = (error: unknown) => (error instanceof Error ? error.message : String(error));

export function VocabularyPage({ roles }: { roles: readonly string[] }) {
  const [data, setData] = useState<VocabularyWorkspace | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [retry, setRetry] = useState(0);
  const [tab, setTab] = useState<Tab>("bank");
  const [search, setSearch] = useState("");
  const [courseId, setCourseId] = useState("");
  const [lessonId, setLessonId] = useState("");

  useEffect(() => {
    let active = true;
    setLoading(true);
    setError(null);
    void loadVocabularyWorkspace()
      .then((workspace) => { if (active) setData(workspace); })
      .catch((failure: unknown) => { if (active) { setData(null); setError(errorText(failure)); } })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [retry]);

  const isLearner = roles.includes("student") || roles.includes("parent");
  const words = data?.words ?? [];
  const courses = data?.courses ?? [];
  const lessons = data?.lessons ?? [];
  const progress = data?.progress ?? [];
  const learnerId = data?.learnerId ?? null;

  const query = search.trim().toLowerCase();
  const inCourse = useMemo(
    () => words.filter((word) => !courseId || word.course_id === courseId),
    [words, courseId],
  );
  const filtered = useMemo(() => inCourse.filter((word) => {
    if (!query) return true;
    return word.hanzi.includes(query)
      || word.pinyin.toLowerCase().includes(query)
      || word.meaning_ar.includes(query)
      || (word.meaning_en ?? "").toLowerCase().includes(query)
      || (word.example_zh ?? "").includes(query);
  }), [inCourse, query]);

  const cardWords = useMemo(
    () => (lessonId ? filtered.filter((word) => word.lesson_id === lessonId) : filtered),
    [filtered, lessonId],
  );

  const summary = vocabularySummary(cardWords, progress, learnerId);

  function handleSaved(wordId: string, status: VocabularyProgressStatus, reviewCount: number) {
    if (!learnerId) return;
    setData((current) => {
      if (!current) return current;
      const rest = current.progress.filter((row) => !(row.vocabulary_id === wordId && row.student_id === learnerId));
      const next: VocabularyProgress = {
        vocabulary_id: wordId,
        student_id: learnerId,
        status,
        review_count: reviewCount,
        last_reviewed_at: new Date().toISOString(),
      };
      return { ...current, progress: [...rest, next] };
    });
  }

  function chooseCourse(value: string) {
    setCourseId(value);
    setLessonId("");
  }

  const lessonGroups = useMemo(() => lessons
    .filter((lesson) => !courseId || lesson.course_id === courseId)
    .map((lesson) => ({
      lesson,
      course: courses.find((course) => course.id === lesson.course_id),
      rows: filtered.filter((word) => word.lesson_id === lesson.id),
    }))
    .filter((group) => group.rows.length > 0), [lessons, courses, courseId, filtered]);

  const courseLessons = lessons.filter((lesson) => !courseId || lesson.course_id === courseId);

  return <LabPage
    eyebrow="تعلم اللغة الصينية"
    title="بنك المفردات والبطاقات"
    intro="مفردات مرتبطة بدروس المقررات، مع بطاقات مراجعة تُسجّل ما أتقنته وتعيد المفردات الصعبة إلى قائمتك."
    badge={`${words.length} مفردة`}
  >
    {loading && <p className="muted" role="status">جارٍ تحميل بنك المفردات...</p>}
    {error && <p className="error-box" role="alert">تعذر تحميل المفردات: {error} <button className="text-button" onClick={() => setRetry((value) => value + 1)}>إعادة المحاولة</button></p>}

    {!loading && !error && data && <>
      <LabStats items={[
        { label: "مفردات البنك", value: String(words.length), detail: "متاحة لحسابك" },
        { label: "مرتبطة بدروس", value: String(summary.linked), detail: "داخل المقررات" },
        { label: "أتقنتها", value: learnerId ? String(summary.known) : "—", detail: learnerId ? `من ${words.length} مفردة` : "يتطلب حساب طالب" },
        { label: "قيد المراجعة", value: learnerId ? String(summary.learning) : "—", detail: learnerId ? "بحاجة إلى تثبيت" : "يتطلب حساب طالب" },
      ]} />

      {isLearner && !learnerId && <p className="notice" role="status">
        هذا الحساب غير مرتبط بسجل طالب بعد، لذلك يمكنك استعراض المفردات والمراجعة دون حفظ التقدم. يُحفظ التقدم تلقائياً بعد ربط حساب الطالب.
      </p>}

      <div className="context-card">
        <label>البحث
          <span className="lab-search">
            <i className="ri-search-line" aria-hidden="true"></i>
            <input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="汉字 أو بينيين أو معنى" />
          </span>
        </label>
        <label>المقرر
          <select value={courseId} onChange={(event) => chooseCourse(event.target.value)}>
            <option value="">كل المقررات</option>
            {courses.map((course) => <option key={course.id} value={course.id}>{course.title}</option>)}
          </select>
        </label>
        <label>الدرس
          <select value={lessonId} onChange={(event) => setLessonId(event.target.value)} disabled={!courseLessons.length}>
            <option value="">كل الدروس</option>
            {courseLessons.map((lesson) => <option key={lesson.id} value={lesson.id}>{lesson.title}</option>)}
          </select>
        </label>
        <div className="actions" style={{ alignSelf: "end" }}>
          <button className="button secondary" type="button" onClick={() => { setSearch(""); setCourseId(""); setLessonId(""); }}>
            <i className="ri-filter-off-line" aria-hidden="true"></i> مسح التصفية
          </button>
        </div>
      </div>

      <LabTabs
        label="أقسام المفردات"
        value={tab}
        onChange={setTab}
        tabs={[
          { id: "bank", label: "بنك المفردات", icon: "ri-book-open-line" },
          { id: "cards", label: "بطاقات المراجعة", icon: "ri-stack-line" },
          { id: "lessons", label: "حسب الدرس", icon: "ri-file-list-3-line" },
        ]}
      />

      {tab === "bank" && <WordBank
        words={cardWords}
        courses={courses}
        lessons={lessons}
        progress={progress}
        learnerId={learnerId}
      />}

      {tab === "cards" && <Flashcards
        words={cardWords}
        progress={progress}
        learnerId={learnerId}
        onSaved={handleSaved}
      />}

      {tab === "lessons" && <section className="panel">
        <div className="page-heading">
          <div><h2>المفردات حسب الدرس</h2><p className="data-note">كل مجموعة تخص درساً فعلياً في المقرر، ويمكن بدء مراجعتها مباشرة.</p></div>
          <span className="lab-pill-count">{lessonGroups.length} درس</span>
        </div>
        {!lessonGroups.length
          ? <p className="muted">لا توجد دروس تحتوي مفردات مطابقة للتصفية الحالية.</p>
          : <ul className="section-list">
            {lessonGroups.map((group) => {
              const known = learnerId
                ? group.rows.filter((word) => wordStatus(progress, word.id, learnerId) === "known").length
                : 0;
              const percent = learnerId ? Math.round((known / group.rows.length) * 100) : 0;
              return <li key={group.lesson.id} className="section-row">
                <div className="section-row-main">
                  <strong>{group.lesson.title}</strong>
                  <span className="data-note">{group.course?.title ?? "مقرر"}{group.course?.level ? ` · ${group.course.level}` : ""}</span>
                </div>
                <div className="section-row-bar">
                  <span className="learn-bar"><span style={{ width: `${percent}%` }} /></span>
                  <small>{learnerId ? `${known} من ${group.rows.length} متقنة` : `${group.rows.length} مفردة · التقدم غير متاح`}</small>
                </div>
                <button
                  className="button secondary"
                  type="button"
                  onClick={() => { setLessonId(group.lesson.id); setTab("cards"); }}
                >
                  <i className="ri-stack-line" aria-hidden="true"></i> دراسة البطاقات
                </button>
              </li>;
            })}
          </ul>}
      </section>}
    </>}
  </LabPage>;
}