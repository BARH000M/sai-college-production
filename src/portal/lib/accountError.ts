/** Explain account fetch failures without treating them as missing roles. */
export function accountErrorMessage(errors: readonly (string | null)[]): string {
  const messages = [...new Set(errors.filter((error): error is string => !!error))];
  if (messages.some((message) => /failed to fetch|fetch failed|networkerror|network request failed|load failed|timeout|timed out/i.test(message))) {
    return "تعذر الاتصال بالخادم مؤقتاً لتحميل بيانات حسابك والتحقق من صلاحياتك. تحقق من اتصال الإنترنت ثم اضغط إعادة المحاولة. لا تحتاج إلى تسجيل الخروج.";
  }
  return "تعذر تحميل بيانات حسابك أو التحقق من صلاحياتك. أعد المحاولة، وإذا استمرت المشكلة فتواصل مع مسؤول النظام.";
}
