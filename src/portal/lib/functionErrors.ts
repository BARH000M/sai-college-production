/** Read only the status and allowlisted error classification; never echo response bodies. */
export async function functionFailure(error: unknown, endpoint: string): Promise<Error> {
  const context = error && typeof error === "object" && "context" in error ? error.context : null;
  const response = context instanceof Response ? context : null;
  const status = response?.status;
  let permissionDenied = false;
  if (response) {
    try {
      const body: unknown = await response.clone().json();
      if (body && typeof body === "object" && "message" in body) {
        permissionDenied = typeof body.message === "string" && /^permission denied for (table|schema) [a-z_]+$/.test(body.message);
      }
    } catch { /* Gateways can return HTML or an empty body. */ }
  }
  const reason = status === 401 ? "انتهت الجلسة أو تعذر التحقق منها؛ سجل الدخول مجدداً."
    : status === 403 ? "لا تملك صلاحية تنفيذ هذا الإجراء."
    : status === 404 ? "الخدمة أو السجل المطلوب غير متاح؛ راجع مسؤول النظام."
    : status === 422 ? "تعذر اعتماد البيانات؛ تحقق من تأكيد الحساب والحقول المطلوبة."
    : permissionDenied ? "صلاحيات قاعدة بيانات الخدمة غير مكتملة؛ يلزم إصلاح الخادم."
    : status && status >= 500 ? "تعذر تنفيذ العملية على الخادم؛ راجع مسؤول النظام."
    : status ? "رفض الخادم الطلب؛ تحقق من البيانات والصلاحيات."
    : "تعذر الاتصال بالخدمة؛ تحقق من الشبكة ثم أعد المحاولة.";
  return new Error(`${endpoint}${status ? ` (HTTP ${status})` : ""}: ${reason}${permissionDenied ? " [database_permission_denied]" : ""}`);
}
