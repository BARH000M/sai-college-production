export const financePaymentMethods = ["cash", "bank_transfer", "wallet", "card"] as const;
export type FinancePaymentMethod = typeof financePaymentMethods[number];

export class FinanceAmountError extends Error {}

export function financePermissions(roles: readonly string[]) {
  const superAdmin = roles.includes("super_admin");
  const accountant = roles.includes("accountant");
  const admin = roles.includes("admin");
  const receptionist = roles.includes("receptionist");
  return {
    view: superAdmin || accountant || admin || receptionist || roles.includes("student") || roles.includes("parent"),
    manageGroups: superAdmin || accountant || admin,
    assignFees: superAdmin || accountant || admin,
    postPayment: superAdmin || accountant || admin || receptionist,
    waive: superAdmin || accountant,
    void: superAdmin || accountant,
    refund: superAdmin,
  };
}

export function isFinancePaymentMethod(value: string): value is FinancePaymentMethod {
  return financePaymentMethods.some((method) => method === value);
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
