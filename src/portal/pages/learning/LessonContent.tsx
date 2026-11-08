import { useEffect, useState } from "react";
import {
  isLessonContentKind, lessonContentLabels, lessonMediaAccept, lessonMediaUrl,
  saveLessonContent, saveLessonMedia, uploadLessonMedia,
  type LearningLesson, type LessonContentKind, type UploadedLessonMedia,
} from "@/portal/lib/learning";

const message = (error: unknown) => (error instanceof Error ? error.message : String(error));

function embedUrl(url: string): string | null {
  const youtube = url.match(/(?:youtube\.com\/(?:watch\?v=|embed\/|shorts\/)|youtu\.be\/)([A-Za-z0-9_-]{6,})/);
  if (youtube) return `https://www.youtube-nocookie.com/embed/${youtube[1]}`;
  const vimeo = url.match(/vimeo\.com\/(\d+)/);
  if (vimeo) return `https://player.vimeo.com/video/${vimeo[1]}`;
  return null;
}

function isDirectVideo(url: string): boolean {
  return /\.(mp4|webm|ogg)(\?|#|$)/i.test(url);
}

type FileKind = "video" | "audio" | "image" | "pdf" | "other";

function fileKindOf(name: string): FileKind {
  const ext = name.includes(".") ? name.split(".").pop()?.toLowerCase() ?? "" : "";
  if (["mp4", "webm", "ogv", "mov", "m4v"].includes(ext)) return "video";
  if (["mp3", "m4a", "wav", "ogg", "aac"].includes(ext)) return "audio";
  if (["png", "jpg", "jpeg", "webp"].includes(ext)) return "image";
  if (ext === "pdf") return "pdf";
  return "other";
}

function contentKindForFile(name: string): LessonContentKind {
  const kind = fileKindOf(name);
  if (kind === "video") return "video";
  if (kind === "audio") return "audio";
  return "link";
}

function formatSize(bytes: number): string {
  if (bytes >= 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} ميجابايت`;
  return `${Math.max(1, Math.round(bytes / 1024))} كيلوبايت`;
}

export function LessonContent({
  lesson, canManage, onSaved,
}: {
  lesson: LearningLesson;
  canManage: boolean;
  onSaved: () => void;
}) {
  const detected: LessonContentKind = isLessonContentKind(lesson.content_kind) ? lesson.content_kind : "none";
  const [editing, setEditing] = useState(false);
  const [kind, setKind] = useState<LessonContentKind>(detected);
  const [url, setUrl] = useState(lesson.content_url ?? "");
  const [body, setBody] = useState(lesson.content_body ?? "");
  const [file, setFile] = useState<File | null>(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const [mediaUrl, setMediaUrl] = useState("");
  const [mediaError, setMediaError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    setMediaUrl("");
    setMediaError(null);
    if (!lesson.content_path) return () => { active = false; };
    lessonMediaUrl(lesson.content_path)
      .then((signed) => { if (active) setMediaUrl(signed); })
      .catch((failure: unknown) => { if (active) setMediaError(message(failure)); });
    return () => { active = false; };
  }, [lesson.content_path]);

  const paragraphs = (lesson.content_body ?? "")
    .split(/\n{2,}/)
    .map((entry) => entry.trim())
    .filter(Boolean);
  const embed = lesson.content_url ? embedUrl(lesson.content_url) : null;
  const uploadedKind = lesson.content_path ? fileKindOf(lesson.content_file_name ?? lesson.content_path) : "other";

  function startEditing() {
    setKind(lesson.content_path ? contentKindForFile(lesson.content_file_name ?? "") : detected);
    setUrl(lesson.content_url ?? "");
    setBody(lesson.content_body ?? "");
    setFile(null);
    setError(null);
    setNotice(null);
    setEditing(true);
  }

  async function handleSave() {
    if (saving) return;
    setSaving(true);
    setError(null);
    setNotice(null);
    try {
      if (file) {
        const uploaded: UploadedLessonMedia = await uploadLessonMedia(lesson.id, file);
        await saveLessonMedia(lesson.id, contentKindForFile(uploaded.fileName), uploaded);
        setNotice("رُفع الملف إلى مساحة التخزين وحُفظ في الدرس.");
      } else if (lesson.content_path && kind !== "reading" && kind !== "none" && !url.trim()) {
        setEditing(false);
        return;
      } else {
        await saveLessonContent(lesson.id, kind, url, body);
        setNotice("حُفظ محتوى الدرس.");
      }
      setFile(null);
      setEditing(false);
      onSaved();
    } catch (failure) {
      setError(message(failure));
    } finally {
      setSaving(false);
    }
  }

  return <div className="learn-lesson-panel">
    {!editing && <>
      <div className="learn-lesson-panel-head">
        <span className="learn-tag">{lessonContentLabels[detected]}</span>
        {lesson.content_path && <span className="learn-file-chip" title={lesson.content_file_name ?? ""}>
          <i className="ri-attachment-2" aria-hidden="true" />
          {lesson.content_file_name ?? "ملف مرفوع"}
        </span>}
        {lesson.content_updated_at && <small className="learn-meta">
          آخر تحديث: {new Date(lesson.content_updated_at).toLocaleDateString("ar-EG")}
        </small>}
        {canManage && <button type="button" className="text-button" onClick={startEditing}>
          {detected === "none" && !lesson.content_path ? "إضافة محتوى" : "تعديل المحتوى"}
        </button>}
      </div>

      {lesson.content_path && mediaError && <p className="error-box" role="alert">
        تعذر فتح الملف المرفوع: {mediaError}
      </p>}

      {lesson.content_path && !mediaError && !mediaUrl && <p className="data-note">جارٍ تجهيز رابط الملف...</p>}

      {lesson.content_path && mediaUrl && uploadedKind === "video" && <div className="learn-video">
        <video className="learn-video-native" controls preload="metadata" src={mediaUrl}>
          متصفحك لا يدعم تشغيل الفيديو.
        </video>
      </div>}

      {lesson.content_path && mediaUrl && uploadedKind === "audio" && <audio className="learn-audio" controls preload="metadata" src={mediaUrl}>
        متصفحك لا يدعم تشغيل الصوت.
      </audio>}

      {lesson.content_path && mediaUrl && uploadedKind === "image" && <div className="learn-image">
        <img src={mediaUrl} alt={`مادة درس ${lesson.title}`} title={`${lesson.title} — مادة الدرس`} />
      </div>}

      {lesson.content_path && mediaUrl && uploadedKind !== "video" && uploadedKind !== "audio" && uploadedKind !== "image" && <p>
        <a className="kpi-link" href={mediaUrl} target="_blank" rel="noreferrer">
          فتح الملف المرفق{lesson.content_file_name ? ` (${lesson.content_file_name})` : ""}
        </a>
      </p>}

      {!lesson.content_path && detected === "reading" && paragraphs.length > 0 && <div className="learn-content-body">
        {paragraphs.map((paragraph, index) => <p key={index}>{paragraph}</p>)}
      </div>}

      {!lesson.content_path && detected === "video" && lesson.content_url && (embed
        ? <div className="learn-video">
            <iframe
              src={embed}
              title={`فيديو درس ${lesson.title}`}
              allow="accelerometer; encrypted-media; picture-in-picture; fullscreen"
              allowFullScreen
              referrerPolicy="strict-origin-when-cross-origin"
            />
          </div>
        : isDirectVideo(lesson.content_url)
          ? <video className="learn-video-native" controls preload="metadata" src={lesson.content_url}>
              متصفحك لا يدعم تشغيل الفيديو.
            </video>
          : <p className="data-note">
              تعذّر تضمين هذا الرابط كفيديو. <a className="kpi-link" href={lesson.content_url} target="_blank" rel="noreferrer">فتح الرابط في نافذة جديدة</a>
            </p>)}

      {!lesson.content_path && detected === "audio" && lesson.content_url && <audio className="learn-audio" controls preload="metadata" src={lesson.content_url}>
        متصفحك لا يدعم تشغيل الصوت.
      </audio>}

      {!lesson.content_path && detected === "link" && lesson.content_url && <p>
        <a className="kpi-link" href={lesson.content_url} target="_blank" rel="noreferrer">فتح المادة المرتبطة</a>
      </p>}

      {!lesson.content_path && detected === "none" && <p className="data-note">
        لم يُرفق محتوى لهذا الدرس بعد.{canManage ? " ارفع فيديو أو ملفاً أو أضف مادة قراءة ليبدأ الطالب منها." : " سيظهر هنا فور إضافته من المعلم."}
      </p>}

      {notice && <p className="success-box" role="status">{notice}</p>}
    </>}

    {editing && <div className="learn-content-form">
      {lesson.content_path && <p className="data-note">
        الملف الحالي: <strong>{lesson.content_file_name ?? "ملف مرفوع"}</strong>. ارفع ملفاً جديداً لاستبداله،
        أو اترك الحقل فارغاً واحفظ للاحتفاظ به.
      </p>}

      <label>رفع ملف من الجهاز
        <input
          type="file"
          accept={lessonMediaAccept}
          onChange={(event) => {
            const picked = event.target.files?.[0] ?? null;
            setFile(picked);
            setError(null);
            if (picked) setKind(contentKindForFile(picked.name));
          }}
        />
        <small className="data-note">
          الفيديو (MP4/WebM) والصوت (MP3/M4A/WAV) وPDF والصور — بحد أقصى ١٠٠ ميجابايت للملف.
        </small>
      </label>

      {file && <p className="learn-upload-note">
        <i className="ri-upload-cloud-2-line" aria-hidden="true" />
        سيُرفع «{file.name}» ({formatSize(file.size)}) إلى مساحة التخزين عند الحفظ.
      </p>}

      {!file && <label>أو استخدم رابطاً خارجياً
        <select value={kind} onChange={(event) => setKind(event.target.value as LessonContentKind)}>
          {(Object.keys(lessonContentLabels) as LessonContentKind[]).map((key) => (
            <option key={key} value={key}>{lessonContentLabels[key]}</option>
          ))}
        </select>
      </label>}

      {!file && kind !== "none" && kind !== "reading" && <label>الرابط
        <input
          dir="ltr"
          value={url}
          placeholder={kind === "video" ? "https://www.youtube.com/watch?v=..." : "https://..."}
          onChange={(event) => setUrl(event.target.value)}
        />
        <small className="data-note">
          {kind === "video"
            ? "روابط يوتيوب وفيميو تُضمَّن داخل الصفحة، وملفات MP4 تُشغَّل مباشرة."
            : kind === "audio"
              ? "استخدم رابطاً مباشراً لملف صوتي (mp3 أو m4a)."
              : "سيُفتح الرابط في نافذة جديدة للطالب."}
        </small>
      </label>}

      {!file && kind === "reading" && <label>مادة القراءة
        <textarea
          rows={8}
          value={body}
          maxLength={8000}
          placeholder="اكتب نص الدرس، وافصل بين الفقرات بسطر فارغ."
          onChange={(event) => setBody(event.target.value)}
        />
        <small className="data-note">{body.trim().length} / 8000 حرف</small>
      </label>}

      {error && <p className="error-box" role="alert">تعذر حفظ المحتوى: {error}</p>}

      <div className="actions">
        <button type="button" className="button primary" disabled={saving} onClick={() => void handleSave()}>
          {saving ? (file ? "جارٍ الرفع..." : "جارٍ الحفظ...") : file ? "رفع الملف وحفظه" : "حفظ المحتوى"}
        </button>
        <button type="button" className="button secondary" disabled={saving} onClick={() => { setFile(null); setEditing(false); }}>إلغاء</button>
      </div>
    </div>}
  </div>;
}