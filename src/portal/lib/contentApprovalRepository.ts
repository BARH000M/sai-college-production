import { supabase } from "./supabase";

export type ContentStatus =
  | "draft" | "submitted" | "changes_requested" | "approved" | "rejected" | "published" | "archived";
export type ContentType = "lesson" | "course" | "cms" | "media" | "assessment";

export type ContentComment = {
  id: string;
  content_id: string;
  author_id: string | null;
  body: string;
  created_at: string;
};

export type ContentHistoryEntry = {
  id: string;
  content_id: string;
  action: string;
  from_status: ContentStatus | null;
  to_status: ContentStatus | null;
  actor_id: string | null;
  note: string | null;
  created_at: string;
};

export type ContentItem = {
  id: string;
  title: string;
  title_en: string | null;
  title_zh: string | null;
  content_type: ContentType;
  status: ContentStatus;
  version: number;
  author_id: string;
  reviewer_id: string | null;
  rejection_reason: string | null;
  updated_at: string;
  branch_id: string | null;
};

export type ReviewerOption = { id: string; full_name: string };

const COLUMNS = [
  "id", "title", "title_en", "title_zh", "content_type", "status", "version",
  "author_id", "reviewer_id", "rejection_reason", "updated_at", "branch_id",
].join(",");

export type ContentDraft = {
  title: string;
  titleEn: string;
  titleZh: string;
  contentType: ContentType;
  summary: string;
  branchId: string;
};

export const CONTENT_STATUS_LABELS: Record<ContentStatus, string> = {
  draft: "مسودة",
  submitted: "بانتظار المراجعة",
  changes_requested: "مطلوب تعديل",
  approved: "معتمد",
  rejected: "مرفوض",
  published: "منشور",
  archived: "مؤرشف",
};

export const CONTENT_TYPE_LABELS: Record<ContentType, string> = {
  lesson: "درس",
  course: "مقرر",
  cms: "صفحة موقع",
  media: "وسائط",
  assessment: "تقييم",
};

export async function loadContentItems(): Promise<ContentItem[]> {
  const result = await supabase
    .from("sai_content_items")
    .select(COLUMNS)
    .order("updated_at", { ascending: false })
    .limit(300);
  if (result.error) throw new Error(result.error.message);
  return (result.data ?? []) as ContentItem[];
}

export async function loadContentComments(contentId: string): Promise<ContentComment[]> {
  const result = await supabase
    .from("sai_content_comments")
    .select("id,content_id,author_id,body,created_at")
    .eq("content_id", contentId)
    .order("created_at");
  if (result.error) throw new Error(result.error.message);
  return (result.data ?? []) as ContentComment[];
}

export async function loadContentHistory(contentId: string): Promise<ContentHistoryEntry[]> {
  const result = await supabase
    .from("sai_content_history")
    .select("id,content_id,action,from_status,to_status,actor_id,note,created_at")
    .eq("content_id", contentId)
    .order("created_at", { ascending: false });
  if (result.error) throw new Error(result.error.message);
  return (result.data ?? []) as ContentHistoryEntry[];
}

export async function loadReviewers(): Promise<ReviewerOption[]> {
  const result = await supabase
    .from("profiles")
    .select("id,full_name")
    .order("full_name")
    .limit(100);
  if (result.error) throw new Error(result.error.message);
  return (result.data ?? []) as ReviewerOption[];
}

export async function createContentDraft(
  draft: ContentDraft,
  authorId: string,
): Promise<ContentItem> {
  if (!draft.title.trim()) throw new Error("عنوان المحتوى مطلوب.");
  const result = await supabase
    .from("sai_content_items")
    .insert({
      title: draft.title.trim(),
      title_en: draft.titleEn.trim() || null,
      title_zh: draft.titleZh.trim() || null,
      content_type: draft.contentType,
      summary: draft.summary.trim() || null,
      branch_id: draft.branchId || null,
      author_id: authorId,
      status: "draft",
    })
    .select(COLUMNS)
    .limit(1);
  if (result.error || !result.data?.length) {
    throw new Error(result.error ? result.error.message : "تعذّر إنشاء المسودة.");
  }
  return (result.data as ContentItem[])[0];
}

export async function assignReviewer(contentId: string, reviewerId: string | null): Promise<void> {
  const result = await supabase
    .from("sai_content_items")
    .update({ reviewer_id: reviewerId, updated_at: new Date().toISOString() })
    .eq("id", contentId);
  if (result.error) throw new Error(result.error.message);
}

export async function addContentComment(contentId: string, body: string, authorId: string): Promise<void> {
  const text = body.trim();
  if (!text) throw new Error("اكتب نص التعليق.");
  const result = await supabase
    .from("sai_content_comments")
    .insert({ content_id: contentId, author_id: authorId, body: text });
  if (result.error) throw new Error(result.error.message);
}

/**
 * Applies an editorial transition through the authoritative RPC.
 *
 * The client never decides whether a transition is legal — the server does.
 * Any message returned here (including self-approval blocking) is surfaced to
 * the user unchanged so the policy is never silently overridden.
 */
export async function transitionContent(
  contentId: string,
  nextStatus: ContentStatus,
  note: string,
): Promise<{ id: string; status: ContentStatus; version: number }> {
  const result = await supabase.rpc("sai_content_transition", {
    p_content_id: contentId,
    p_next_status: nextStatus,
    p_note: note.trim() || null,
  });
  if (result.error) throw new Error(result.error.message);
  return result.data as { id: string; status: ContentStatus; version: number };
}