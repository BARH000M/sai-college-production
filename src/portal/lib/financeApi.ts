import { supabase } from "./supabase";
import { normalizeYER, validateFinancePayment, type FinancePaymentMethod } from "./finance";

export type FeeGroup = {
  id: string; branch_id: string; academic_session_id: string; name: string;
  description: string | null; amount: number; due_date: string; is_active: boolean;
};
export type FeeAssignment = {
  id: string; fee_group_id: string; student_id: string; branch_id: string;
  academic_session_id: string; class_id: string; original_amount: number;
  discount_amount: number; final_amount: number; due_date: string; status: string; balance: number;
};
export type FinancePayment = {
  id: string; assignment_id: string; amount: number; currency: string; method: FinancePaymentMethod;
  transaction_reference: string | null; receipt_number: string; posted_at: string;
  voided_at: string | null; void_reason: string | null;
};
export type FinanceRefund = {
  id: string; amount: number; method: FinancePaymentMethod; reference: string | null;
  refund_number: string; reason: string; issued_at: string;
};
export type FinanceAudit = {
  id: number; actor_id: string; action: string; entity_id: string; details: Record<string, unknown>; created_at: string;
};

async function rpcRows<T>(name: string, args: Record<string, string> = {}): Promise<T[]> {
  const rows: T[] = [];
  const seen = new Set<string>();
  let expectedTotal: number | undefined;
  let total: number;
  do {
    const result = await supabase.rpc(name, args, { count: "exact" })
      .range(rows.length, rows.length + 999);
    if (result.error) throw new Error(result.error.message);
    if (!Array.isArray(result.data) || result.count === null) throw new Error("تعذر تحميل السجلات وعددها.");
    total = result.count;
    if (expectedTotal !== undefined && total !== expectedTotal) throw new Error("تغيرت السجلات أثناء التحميل؛ أعد تحميل الصفحة.");
    expectedTotal = total;
    for (const row of result.data) {
      if (!row || typeof row !== "object" || !("id" in row) || (typeof row.id !== "string" && typeof row.id !== "number")) {
        throw new Error("استجابة السجلات غير صالحة.");
      }
      const id = String(row.id);
      if (seen.has(id)) throw new Error("تغيرت السجلات أثناء التحميل؛ أعد تحميل الصفحة.");
      seen.add(id);
    }
    if (rows.length + result.data.length > total) throw new Error("عدد السجلات غير متسق؛ أعد تحميل الصفحة.");
    if (!result.data.length && rows.length < total) throw new Error("تعذر تحميل جميع السجلات.");
    rows.push(...result.data);
  } while (rows.length < total);
  return rows;
}

async function mutate(name: string, args: Record<string, string | boolean | null>, expectsId = false): Promise<string | null> {
  const { data, error } = await supabase.rpc(name, args);
  if (error) throw new Error(error.message);
  if ((expectsId && (typeof data !== "string" || !data)) || (!expectsId && data !== null)) {
    throw new Error("استجابة العملية غير صالحة؛ تحقق من السجل قبل إعادة المحاولة.");
  }
  return data;
}

export const loadFeeGroups = () => rpcRows<FeeGroup>("sai_finance_groups");
export const loadFeeAssignments = () => rpcRows<FeeAssignment>("sai_finance_assignments");
export const loadFinancePayments = (assignment: string) => rpcRows<FinancePayment>("sai_finance_payments", { wanted_assignment: assignment });
export const loadFinanceRefunds = (payment: string) => rpcRows<FinanceRefund>("sai_finance_refunds", { wanted_payment: payment });
export const loadFinanceAudit = (branch: string) => rpcRows<FinanceAudit>("sai_finance_audit", { wanted_branch: branch });

export function saveFeeGroup(draft: {
  id: string; branch: string; session: string; name: string; description: string;
  amount: string; due: string; active: boolean;
}) {
  return mutate("sai_finance_save_group", {
    wanted_id: draft.id || null, wanted_branch: draft.branch, wanted_session: draft.session,
    wanted_name: draft.name, wanted_description: draft.description || null,
    wanted_amount: normalizeYER(draft.amount), wanted_due: draft.due, wanted_active: draft.active,
  }, true);
}
export function assignFee(group: string, student: string, discount: string, due: string) {
  return mutate("sai_finance_assign", {
    wanted_group: group, wanted_student: student, wanted_discount: normalizeYER(discount), wanted_due: due || null,
  }, true);
}
export function postFinancePayment(assignment: string, amount: string, method: FinancePaymentMethod, reference: string, key: string) {
  const error = validateFinancePayment(amount, method, reference);
  if (error) throw new Error(error);
  return mutate("sai_finance_pay", {
    wanted_assignment: assignment, wanted_amount: normalizeYER(amount), wanted_method: method,
    wanted_reference: reference.trim() || null, wanted_key: key,
  }, true);
}
export const voidFinancePayment = (payment: string, reason: string) =>
  mutate("sai_finance_void", { wanted_payment: payment, wanted_reason: reason });
export const waiveFee = (assignment: string, reason: string) =>
  mutate("sai_finance_waive", { wanted_assignment: assignment, wanted_reason: reason }, true);
export const cancelFee = (assignment: string, reason: string) =>
  mutate("sai_finance_cancel", { wanted_assignment: assignment, wanted_reason: reason });
export function refundFinancePayment(payment: string, amount: string, method: FinancePaymentMethod, reference: string, reason: string, key: string) {
  const error = validateFinancePayment(amount, method, reference);
  if (error) throw new Error(error);
  return mutate("sai_finance_refund", {
    wanted_payment: payment, wanted_amount: normalizeYER(amount), wanted_method: method,
    wanted_reference: reference.trim() || null, wanted_reason: reason.trim(), wanted_key: key,
  }, true);
}
