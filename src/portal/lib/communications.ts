import { supabase } from "./supabase";

export const announcementAudiences = {
  all: "الجميع",
  staff: "الموظفون",
  teachers: "المعلمون",
  parents: "أولياء الأمور",
  students: "الطلاب",
} as const;

export type AnnouncementAudience = keyof typeof announcementAudiences;

export type Announcement = {
  id: string;
  branch_id: string | null;
  title: string;
  body: string;
  audience: AnnouncementAudience;
  is_published: boolean;
  published_at: string | null;
  expires_at: string | null;
  published_by: string;
  created_at: string;
};

export type AnnouncementDraft = {
  title: string;
  body: string;
  audience: AnnouncementAudience;
  branch_id: string;
  expires_at: string;
};

export function isAudience(value: string): value is AnnouncementAudience {
  return Object.prototype.hasOwnProperty.call(announcementAudiences, value);
}

export function communicationsPermissions(roles: readonly string[]) {
  const superAdmin = roles.includes("super_admin");
  const admin = roles.includes("admin");
  const editor = roles.includes("content_editor");
  return {
    canManage: superAdmin || admin || editor,
    canPublish: superAdmin || admin || editor,
  };
}

export function emptyAnnouncementDraft(branch = ""): AnnouncementDraft {
  return { title: "", body: "", audience: "all", branch_id: branch, expires_at: "" };
}

export function validateAnnouncementDraft(draft: AnnouncementDraft): string | null {
  if (!draft.title.trim()) return "عنوان الإعلان مطلوب.";
  if (draft.title.trim().length > 160) return "العنوان طويل جداً (الحد 160 حرفاً).";
  if (!draft.body.trim()) return "نص الإعلان مطلوب.";
  if (draft.body.trim().length > 4000) return "نص الإعلان طويل جداً (الحد 4000 حرف).";
  if (!isAudience(draft.audience)) return "الجمهور المستهدف غير صالح.";
  if (draft.expires_at && new Date(draft.expires_at).getTime() <= Date.now()) {
    return "تاريخ الانتهاء يجب أن يكون في المستقبل.";
  }
  return null;
}

function message(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

const columns = "id,branch_id,title,body,audience,is_published,published_at,expires_at,published_by,created_at";

export async function loadAnnouncements(): Promise<Announcement[]> {
  const result = await supabase.from("announcements")
    .select(columns)
    .order("published_at", { ascending: false, nullsFirst: false })
    .order("created_at", { ascending: false })
    .limit(120);
  if (result.error) throw new Error(result.error.message);
  return (result.data ?? []) as Announcement[];
}

export async function loadReadAnnouncementIds(userId: string): Promise<Set<string>> {
  const result = await supabase.from("announcement_reads")
    .select("announcement_id").eq("user_id", userId);
  if (result.error) throw new Error(result.error.message);
  const rows = (result.data ?? []) as { announcement_id: string }[];
  return new Set(rows.map((row) => row.announcement_id));
}

export async function markAnnouncementRead(announcementId: string, userId: string): Promise<void> {
  const result = await supabase.from("announcement_reads")
    .upsert({ announcement_id: announcementId, user_id: userId }, { onConflict: "announcement_id,user_id" });
  if (result.error) throw new Error(result.error.message);
}

export async function createAnnouncement(draft: AnnouncementDraft, userId: string, publish: boolean): Promise<void> {
  const invalid = validateAnnouncementDraft(draft);
  if (invalid) throw new Error(invalid);
  const result = await supabase.from("announcements").insert({
    branch_id: draft.branch_id || null,
    title: draft.title.trim(),
    body: draft.body.trim(),
    audience: draft.audience,
    is_published: publish,
    published_at: publish ? new Date().toISOString() : null,
    expires_at: draft.expires_at ? new Date(draft.expires_at).toISOString() : null,
    published_by: userId,
  }).select("id");
  if (result.error) throw new Error(result.error.message);
  if (!result.data?.length) throw new Error("لم يُنشر الإعلان؛ قد لا تملك صلاحية هذا الفرع.");
}

export async function setAnnouncementPublished(id: string, publish: boolean): Promise<void> {
  const result = await supabase.from("announcements").update({
    is_published: publish,
    published_at: publish ? new Date().toISOString() : null,
  }).eq("id", id).select("id");
  if (result.error) throw new Error(result.error.message);
  if (!result.data?.length) throw new Error("لم تتغير حالة الإعلان؛ قد لا تملك الصلاحية.");
}

export async function deleteAnnouncement(id: string): Promise<void> {
  const result = await supabase.from("announcements").delete().eq("id", id).select("id");
  if (result.error) throw new Error(message(result.error));
  if (!result.data?.length) throw new Error("لم يُحذف الإعلان؛ قد لا تملك الصلاحية.");
}

export type AnnouncementDeliverySummary = {
  announcementId: string;
  total: number;
  sent: number;
  failed: number;
  skipped: number;
  configured: boolean;
  message?: string;
};

export type AnnouncementDeliveryCounts = { sent: number; failed: number; skipped: number };

/**
 * Asks the trusted edge function to email a published announcement to the
 * people its audience and branch allow. The function verifies the caller's
 * session, sends through Resend, and writes every attempt to the delivery log.
 */
export async function sendAnnouncementEmail(announcementId: string): Promise<AnnouncementDeliverySummary> {
  const { data, error } = await supabase.functions.invoke("announcement-email", {
    body: { announcementId },
  });
  if (error) {
    let detail = error.message;
    const context = (error as unknown as { context?: { json?: () => Promise<unknown> } }).context;
    if (context?.json) {
      try {
        const parsed = await context.json() as { message?: string } | null;
        if (parsed?.message) detail = parsed.message;
      } catch {
        // Fall back to the transport message when the body is not JSON.
      }
    }
    throw new Error(detail);
  }
  const payload = data as (AnnouncementDeliverySummary & { error?: string }) | null;
  if (!payload) throw new Error("لم يصل رد من خدمة البريد؛ تحقق من نشر الوظيفة.");
  if (payload.error) throw new Error(payload.message ?? payload.error);
  return payload;
}

export async function loadAnnouncementDeliveryCounts(): Promise<Map<string, AnnouncementDeliveryCounts>> {
  const result = await supabase.from("announcement_deliveries")
    .select("announcement_id,status")
    .limit(2000);
  if (result.error) throw new Error(result.error.message);
  const counts = new Map<string, AnnouncementDeliveryCounts>();
  ((result.data ?? []) as { announcement_id: string; status: string }[]).forEach((row) => {
    const current = counts.get(row.announcement_id) ?? { sent: 0, failed: 0, skipped: 0 };
    if (row.status === "sent") current.sent += 1;
    else if (row.status === "failed") current.failed += 1;
    else current.skipped += 1;
    counts.set(row.announcement_id, current);
  });
  return counts;
}