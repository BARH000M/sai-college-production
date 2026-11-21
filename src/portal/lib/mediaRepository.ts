import { supabase } from "./supabase";

export type MediaType = "image" | "audio" | "video" | "document";
export type MediaStatus = "draft" | "published" | "archived";

export type MediaAsset = {
  id: string;
  media_type: MediaType;
  title_ar: string;
  title_en: string | null;
  title_zh: string | null;
  category: string | null;
  course_id: string | null;
  lesson_id: string | null;
  branch_id: string | null;
  storage_bucket: string;
  storage_path: string;
  mime_type: string | null;
  size_bytes: number | null;
  status: MediaStatus;
  version: number;
  usage_count: number;
  created_at: string;
};

export type MediaDraft = {
  titleAr: string;
  titleEn: string;
  titleZh: string;
  type: MediaType;
  category: string;
  courseId: string;
  lessonId: string;
  branchId: string;
};

export type CourseOption = { id: string; title: string };

export const MEDIA_BUCKET = "media";
export const MAX_MEDIA_BYTES = 50 * 1024 * 1024;

const COLUMNS = [
  "id", "media_type", "title_ar", "title_en", "title_zh", "category",
  "course_id", "lesson_id", "branch_id", "storage_bucket", "storage_path",
  "mime_type", "size_bytes", "status", "version", "usage_count", "created_at",
].join(",");

const MIME_PREFIX: Record<MediaType, string> = {
  image: "image/",
  audio: "audio/",
  video: "video/",
  document: "",
};

function message(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

/** Validates a selected file against the catalogue contract. */
export function validateMediaFile(file: File | null, type: MediaType): string | null {
  if (!file) return "اختر ملفاً للرفع.";
  if (file.size <= 0) return "الملف فارغ أو غير صالح.";
  if (file.size > MAX_MEDIA_BYTES) return "الحد الأقصى للملف الواحد 50 ميغابايت.";
  const prefix = MIME_PREFIX[type];
  if (prefix && !file.type.startsWith(prefix)) {
    const labels: Record<MediaType, string> = {
      image: "صورة", audio: "ملف صوتي", video: "ملف فيديو", document: "مستند",
    };
    return `نوع الملف لا يطابق التصنيف المختار (${labels[type]}).`;
  }
  return null;
}

/** Object keys must be lowercase and free of spaces or traversal segments. */
function safeObjectName(name: string): string {
  const cleaned = name
    .toLowerCase()
    .replace(/[^a-z0-9._-]+/g, "-")
    .replace(/-{2,}/g, "-")
    .replace(/^[-.]+|[-.]+$/g, "");
  return (cleaned || "asset").slice(-120);
}

function newObjectId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
}

export async function loadCourseOptions(): Promise<CourseOption[]> {
  const result = await supabase
    .from("learning_courses")
    .select("id,title")
    .eq("is_active", true)
    .order("title")
    .limit(100);
  if (result.error) throw new Error(result.error.message);
  return (result.data ?? []) as CourseOption[];
}

export async function loadLessonOptions(courseId: string): Promise<CourseOption[]> {
  if (!courseId) return [];
  const result = await supabase
    .from("learning_lessons")
    .select("id,title")
    .eq("course_id", courseId)
    .order("position")
    .limit(200);
  if (result.error) throw new Error(result.error.message);
  return (result.data ?? []) as CourseOption[];
}

export async function loadMediaAssets(): Promise<MediaAsset[]> {
  const result = await supabase
    .from("sai_media_assets")
    .select(COLUMNS)
    .order("created_at", { ascending: false })
    .limit(500);
  if (result.error) throw new Error(result.error.message);
  return (result.data ?? []) as MediaAsset[];
}

/**
 * Uploads the binary to the private bucket and then writes the metadata row.
 *
 * If the metadata insert fails the uploaded object is removed again so the
 * bucket never keeps an orphaned binary that no catalogue row references.
 */
export async function uploadMediaAsset(
  file: File,
  draft: MediaDraft,
  onStateChange?: (state: "uploading" | "recording") => void,
): Promise<MediaAsset> {
  const invalid = validateMediaFile(file, draft.type);
  if (invalid) throw new Error(invalid);
  if (!draft.titleAr.trim()) throw new Error("العنوان العربي مطلوب.");

  const path = `${new Date().getFullYear()}/${newObjectId()}-${safeObjectName(file.name)}`;

  onStateChange?.("uploading");
  const upload = await supabase.storage.from(MEDIA_BUCKET).upload(path, file, {
    contentType: file.type || "application/octet-stream",
    upsert: false,
  });
  if (upload.error) {
    throw new Error(`تعذّر رفع الملف: ${upload.error.message}`);
  }

  onStateChange?.("recording");
  const insert = await supabase
    .from("sai_media_assets")
    .insert({
      media_type: draft.type,
      title_ar: draft.titleAr.trim(),
      title_en: draft.titleEn.trim() || null,
      title_zh: draft.titleZh.trim() || null,
      category: draft.category.trim() || null,
      course_id: draft.courseId || null,
      lesson_id: draft.lessonId || null,
      branch_id: draft.branchId || null,
      storage_bucket: MEDIA_BUCKET,
      storage_path: path,
      mime_type: file.type || null,
      size_bytes: file.size,
      status: "draft",
    })
    .select(COLUMNS)
    .limit(1);

  if (insert.error || !insert.data?.length) {
    await supabase.storage.from(MEDIA_BUCKET).remove([path]);
    throw new Error(insert.error ? `تعذّر حفظ بيانات الملف: ${insert.error.message}` : "تعذّر حفظ بيانات الملف.");
  }
  return (insert.data as MediaAsset[])[0];
}

export async function setMediaStatus(id: string, status: MediaStatus): Promise<void> {
  const result = await supabase
    .from("sai_media_assets")
    .update({ status, archived_at: status === "archived" ? new Date().toISOString() : null })
    .eq("id", id);
  if (result.error) throw new Error(result.error.message);
}

/** Short-lived signed URL. Never persist this value as a media identifier. */
export async function mediaSignedUrl(path: string, expiresIn = 300): Promise<string> {
  const result = await supabase.storage.from(MEDIA_BUCKET).createSignedUrl(path, expiresIn);
  if (result.error) throw new Error(message(result.error));
  return result.data.signedUrl;
}