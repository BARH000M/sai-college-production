import { supabase } from "./supabase";

export type ReminderRunResult = {
  status: "sent" | "skipped" | "not_configured" | "error";
  candidates: number;
  sent: number;
  message: string;
};

type ReminderPayload = {
  ok?: unknown;
  skipped?: unknown;
  reason?: unknown;
  candidates?: unknown;
  applicantEmails?: unknown;
  sent?: unknown;
  teamDigest?: unknown;
  message?: unknown;
};

function count(value: unknown): number {
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function failureMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  const shape = error as { message?: unknown; context?: unknown } | null;
  if (shape && typeof shape.message === "string" && shape.message.trim()) return shape.message;
  return String(error);
}

function mapResult(payload: ReminderPayload | null, fallbackError: string | null): ReminderRunResult {
  if (fallbackError) {
    return { status: "error", candidates: 0, sent: 0, message: `تعذّر تشغيل التذكيرات: ${fallbackError}` };
  }
  if (!payload || payload.ok !== true) {
    const detail = payload && typeof payload.message === "string" ? payload.message : "استجابة غير متوقعة من الخادم.";
    return { status: "error", candidates: 0, sent: 0, message: `تعذّر تشغيل التذكيرات: ${detail}` };
  }
  const candidates = count(payload.candidates);
  const sent = payload.applicantEmails === undefined ? count(payload.sent) : count(payload.applicantEmails);
  if (payload.skipped === true) {
    return {
      status: "skipped",
      candidates,
      sent: 0,
      message: payload.reason === "ALREADY_RAN_TODAY"
        ? "تم تشغيل تذكيرات اليوم بالفعل، لذلك لم يُرسل شيء إضافي."
        : "لم تُرسل أي رسائل في هذه الجولة.",
    };
  }
  if (payload.reason === "EMAIL_NOT_CONFIGURED") {
    return {
      status: "not_configured",
      candidates,
      sent: 0,
      message: `تم العثور على ${candidates} طلبًا مستحقًا للتذكير، لكن إعداد البريد على الخادم غير مكتمل، لذلك لم تُرسل رسائل.`,
    };
  }
  if (!candidates) {
    return { status: "sent", candidates: 0, sent: 0, message: "لا توجد طلبات مستحقة للتذكير الآن — كل الطلبات تمت متابعتها." };
  }
  return {
    status: "sent",
    candidates,
    sent,
    message: sent
      ? `تم إرسال ${sent} تذكيرًا إلى المتقدمين من أصل ${candidates} طلبًا مستحقًا.`
      : `تمت معالجة ${candidates} طلبًا، لكن لم تُرسل رسائل (لا يوجد بريد للمتقدمين أو تعذّر الإرسال).`,
  };
}

export async function runAdmissionRemindersNow(): Promise<ReminderRunResult> {
  try {
    const response = await supabase.functions.invoke("admission-reminders", {
      body: { mode: "manual" },
    });
    if (response.error) {
      return {
        status: "error",
        candidates: 0,
        sent: 0,
        message: `تعذّر تشغيل التذكيرات: ${failureMessage(response.error)}`,
      };
    }
    const data = response.data as ReminderPayload | null;
    return mapResult(data, null);
  } catch (error) {
    return {
      status: "error",
      candidates: 0,
      sent: 0,
      message: `تعذّر تشغيل التذكيرات: ${failureMessage(error)}`,
    };
  }
}