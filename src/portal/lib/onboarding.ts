export type OnboardingChecks = {
  activeBranchMembership: boolean | null;
  studentRecordVisible: boolean | null;
  verifiedParentLinkVisible: boolean | null;
  assignedClassVisible: boolean | null;
};

const BRANCH_SCOPED_ROLES = new Set([
  "admin", "teacher", "accountant", "receptionist", "librarian", "content_editor",
]);

export function onboardingNotices(
  roles: readonly string[],
  emailConfirmed: boolean,
  checks: OnboardingChecks,
  checkError: string | null,
): string[] {
  const notices: string[] = [];
  if (!emailConfirmed) notices.push("لم يظهر البريد الإلكتروني مؤكداً في جلسة الحساب.");
  if (roles.some((role) => BRANCH_SCOPED_ROLES.has(role)) && checks.activeBranchMembership === false) {
    notices.push("لا تظهر عضوية فرع نشطة لهذا الحساب.");
  }
  if (roles.includes("student") && checks.studentRecordVisible === false) {
    notices.push("لا يظهر سجل طالب مرتبط يمكن لهذه الجلسة الوصول إليه.");
  }
  if (roles.includes("parent") && checks.verifiedParentLinkVisible === false) {
    notices.push("لا تظهر علاقة طالب موثقة يمكن لهذه الجلسة الوصول إليها.");
  }
  if (roles.includes("teacher") && checks.assignedClassVisible === false) {
    notices.push("لا يظهر صف نشط مسند لهذا المعلم ضمن نطاقه الحالي.");
  }
  if (checkError) notices.push("تعذر التحقق من اكتمال الربط مؤقتاً؛ لم يتم تغيير أي بيانات. أعد المحاولة لاحقاً.");
  return notices;
}
