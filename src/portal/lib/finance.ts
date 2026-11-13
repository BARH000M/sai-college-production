export const financePaymentMethods = ["cash", "bank_transfer", "wallet", "card"] as const;
export type FinancePaymentMethod = typeof financePaymentMethods[number];
export type PendingFinancePayment = {
  assignment: string; amount: string; method: FinancePaymentMethod; reference: string; key: string;
};
export type PendingFinanceRefund = PendingFinancePayment & { payment: string; reason: string };

export function parsePendingFinanceRefund(value: string): PendingFinanceRefund {
  const payment = parsePendingFinancePayment(value);
  const parsed: unknown = JSON.parse(value);
  if (typeof parsed !== "object" || parsed === null
    || !("payment" in parsed) || typeof parsed.payment !== "string" || !parsed.payment
    || !("reason" in parsed) || typeof parsed.reason !== "string" || !parsed.reason.trim()) {
    throw new Error("تعذر قراءة محاولة الاسترداد المحفوظة؛ تحقق من السجل قبل إعادة المحاولة.");
  }
  return { ...payment, payment: parsed.payment, reason: parsed.reason };
}

export class FinanceAmountError extends Error {}

export function financePermissions(roles: readonly string[]) {
  const superAdmin = roles.includes("super_admin");
  const accountant = roles.includes("accountant");
  const admin = roles.includes("admin");
  return {
    view: superAdmin || accountant || admin || roles.includes("student") || roles.includes("parent"),
    manageGroups: superAdmin || accountant || admin,
    assignFees: superAdmin || accountant || admin,
    postPayment: superAdmin || accountant || admin,
    waive: superAdmin || accountant,
    void: superAdmin || accountant,
    refund: superAdmin,
  };
}

export function isFinancePaymentMethod(value: string): value is FinancePaymentMethod {
  return financePaymentMethods.some((method) => method === value);
}

export function parsePendingFinancePayment(value: string): PendingFinancePayment {
  const parsed: unknown = JSON.parse(value);
  if (typeof parsed !== "object" || parsed === null
    || !("assignment" in parsed) || typeof parsed.assignment !== "string" || !parsed.assignment
    || !("amount" in parsed) || typeof parsed.amount !== "string"
    || !("method" in parsed) || typeof parsed.method !== "string" || !isFinancePaymentMethod(parsed.method)
    || !("reference" in parsed) || typeof parsed.reference !== "string"
    || !("key" in parsed) || typeof parsed.key !== "string" || !parsed.key
    || validateFinancePayment(parsed.amount, parsed.method, parsed.reference)) {
    throw new Error("تعذر قراءة محاولة الدفع المحفوظة؛ تواصل مع المسؤول قبل تسجيل دفعة أخرى.");
  }
  return {
    assignment: parsed.assignment, amount: parsed.amount, method: parsed.method,
    reference: parsed.reference, key: parsed.key,
  };
}

// Keep amounts decimal throughout; binary floating-point cannot safely represent YER cents.
export function normalizeYER(value: string): string {
  const match = /^(\d+)(?:\.(\d+))?$/.exec(value.trim());
  if (!match) throw new FinanceAmountError("المبلغ غير صالح.");
  const fraction = (match[2] ?? "").padEnd(3, "0");
  const cents = BigInt(match[1]) * 100n + BigInt(fraction.slice(0, 2)) + (fraction[2] >= "5" ? 1n : 0n);
  if (cents > 999999999999n) throw new FinanceAmountError("المبلغ يتجاوز الحد المسموح.");
  return `${cents / 100n}.${String(cents % 100n).padStart(2, "0")}`;
}

export function validateFinancePayment(amount: string, method: string, reference: string): string | null {
  try {
    if (normalizeYER(amount) === "0.00") return "يجب أن يكون مبلغ الدفع أكبر من صفر.";
  } catch (error) {
    if (error instanceof FinanceAmountError) return error.message;
    throw error;
  }
  if (!isFinancePaymentMethod(method)) return "طريقة الدفع غير صالحة.";
  if (method !== "cash" && !reference.trim()) return "المرجع مطلوب لطريقة الدفع المختارة.";
  return null;
}

export function formatYER(value: string): string {
  const normalized = normalizeYER(value);
  const [whole, fraction] = normalized.split(".");
  return fraction === "00" ? `${whole} ر.ي` : `${whole}.${fraction.replace(/0$/, "")} ر.ي`;
}
