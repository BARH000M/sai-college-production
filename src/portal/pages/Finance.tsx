import { useCallback, useEffect, useRef, useState, type FormEvent } from "react";
import {
  financePermissions, formatYER, normalizeYER, parsePendingFinancePayment, parsePendingFinanceRefund, validateFinancePayment,
  type FinancePaymentMethod, type PendingFinancePayment, type PendingFinanceRefund,
} from "../lib/finance";
import {
  assignFee, cancelFee, loadFeeAssignments, loadFeeGroups, loadFinanceAudit,
  loadFinancePayments, loadFinanceRefunds, postFinancePayment, refundFinancePayment,
  saveFeeGroup, voidFinancePayment, waiveFee,
  type FeeAssignment, type FeeGroup, type FinanceAudit, type FinancePayment, type FinanceRefund,
} from "../lib/financeApi";
import { loadReportBranches, loadReportSessions, type ReportOption } from "../lib/reports";
import { supabase } from "../lib/supabase";
import { PaymentReceipt } from "./finance/PaymentReceipt";

const methods: { value: FinancePaymentMethod; label: string }[] = [
  { value: "cash", label: "نقداً" }, { value: "bank_transfer", label: "تحويل بنكي" },
  { value: "wallet", label: "محفظة" }, { value: "card", label: "بطاقة" },
];
const statuses: Record<string, string> = {
  unpaid: "غير مدفوع", partial: "مدفوع جزئياً", paid: "مدفوع", waived: "معفى", cancelled: "ملغى",
};
const emptyGroup = { id: "", branch: "", session: "", name: "", description: "", amount: "", due: "", active: true };
type FinanceStudent = {
  id: string; full_name: string; admission_no: string; branch_id: string; class_id: string | null;
};
function message(error: unknown) { return error instanceof Error ? error.message : String(error); }
function amount(value: number) { return formatYER(String(value)); }

export function Finance({ roles, userId }: { roles: readonly string[]; userId: string | null }) {
  const permissions = financePermissions(roles);
  const staff = permissions.postPayment;
  const [groups, setGroups] = useState<FeeGroup[]>([]);
  const [assignments, setAssignments] = useState<FeeAssignment[]>([]);
  const [payments, setPayments] = useState<FinancePayment[]>([]);
  const [refunds, setRefunds] = useState<FinanceRefund[]>([]);
  const refundRequest = useRef(0);
  const [refundsReady, setRefundsReady] = useState(false);
  const [audit, setAudit] = useState<FinanceAudit[]>([]);
  const [selected, setSelected] = useState("");
  const [selectedPayment, setSelectedPayment] = useState("");
  const [group, setGroup] = useState(emptyGroup);
  const [assignmentGroup, setAssignmentGroup] = useState("");
  const [student, setStudent] = useState("");
  const [discount, setDiscount] = useState("0");
  const [assignmentDue, setAssignmentDue] = useState("");
  const [paymentAmount, setPaymentAmount] = useState("");
  const [paymentMethod, setPaymentMethod] = useState<FinancePaymentMethod>("cash");
  const [reference, setReference] = useState("");
  const [pendingPayment, setPendingPayment] = useState<PendingFinancePayment | null>(null);
  const [pendingRefund, setPendingRefund] = useState<PendingFinanceRefund | null>(null);
  const [recoveryReady, setRecoveryReady] = useState(false);
  const [recoveryError, setRecoveryError] = useState<string | null>(null);
  const [verified, setVerified] = useState(false);
  const [reason, setReason] = useState("");
  const [refundAmount, setRefundAmount] = useState("");
  const [refundMethod, setRefundMethod] = useState<FinancePaymentMethod>("cash");
  const [refundReference, setRefundReference] = useState("");
  const [auditBranch, setAuditBranch] = useState("");
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const busyRef = useRef(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [version, setVersion] = useState(0);
  const [branches, setBranches] = useState<ReportOption[]>([]);
  const [sessions, setSessions] = useState<ReportOption[]>([]);
  const [students, setStudents] = useState<FinanceStudent[]>([]);
  const [receipt, setReceipt] = useState<{ payment: FinancePayment; assignment: FeeAssignment } | null>(null);
  const storageKey = `sai.finance.pending.${userId ?? ""}`;
  const refundStorageKey = `sai.finance.refund.pending.${userId ?? ""}`;

  useEffect(() => {
    let active = true;
    void Promise.all([loadReportBranches(), loadReportSessions()])
      .then(([branchRows, sessionRows]) => {
        if (!active) return;
        setBranches(branchRows);
        setSessions(sessionRows);
      })
      .catch((failure: unknown) => {
        if (active) setError(`تعذر تحميل الفروع والجلسات: ${message(failure)}`);
      });
    void supabase.from("students")
      .select("id,full_name,admission_no,branch_id,class_id")
      .order("full_name")
      .then((result) => {
        if (!active) return;
        if (result.error) { setError(`تعذر تحميل الطلاب: ${result.error.message}`); return; }
        setStudents((result.data ?? []) as FinanceStudent[]);
      });
    return () => { active = false; };
  }, []);

  useEffect(() => {
    setRecoveryReady(false); setPendingPayment(null); setPendingRefund(null); setRecoveryError(null);
    if (!staff) { setRecoveryReady(true); return; }
    if (!userId) { setRecoveryError("تعذر التحقق من الحساب؛ تسجيل الدفعات متوقف."); return; }
    try {
      const saved = sessionStorage.getItem(storageKey);
      if (saved) {
        const pending = parsePendingFinancePayment(saved);
        setPendingPayment(pending); setSelected(pending.assignment);
        setPaymentAmount(pending.amount); setPaymentMethod(pending.method); setReference(pending.reference);
      }
      if (permissions.refund) {
        const savedRefund = sessionStorage.getItem(refundStorageKey);
        if (savedRefund) {
          const pending = parsePendingFinanceRefund(savedRefund);
          if (saved && parsePendingFinancePayment(saved).assignment !== pending.assignment) {
            throw new Error("توجد محاولات دفع واسترداد غير مؤكدة لإسنادات مختلفة؛ تواصل مع المسؤول.");
          }
          setPendingRefund(pending); setSelected(pending.assignment);
          setRefundAmount(pending.amount); setRefundMethod(pending.method);
          setRefundReference(pending.reference); setReason(pending.reason);
        }
      }
      setRecoveryReady(true);
    } catch (failure) {
      setRecoveryError(`تعذر استعادة محاولة الدفع؛ تسجيل الدفعات متوقف: ${message(failure)}`);
    }
  }, [staff, storageKey, refundStorageKey, userId, permissions.refund]);

  useEffect(() => {
    let active = true;
    setLoading(true); setError(null);
    void Promise.all([loadFeeAssignments(), staff ? loadFeeGroups() : Promise.resolve([])])
      .then(([nextAssignments, nextGroups]) => {
        if (active) { setAssignments(nextAssignments); setGroups(nextGroups); }
      }).catch((failure: unknown) => { if (active) { setAssignments([]); setGroups([]); setError(message(failure)); } })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [staff, version]);

  useEffect(() => {
    let active = true;
    refundRequest.current += 1;
    setRefundsReady(false);
    setPayments([]); setSelectedPayment(""); setRefunds([]);
    if (selected) void loadFinancePayments(selected)
      .then((rows) => { if (active) setPayments(rows); })
      .catch((failure: unknown) => { if (active) setError(message(failure)); });
    return () => { active = false; refundRequest.current += 1; };
  }, [selected, version]);

  const perform = useCallback(async (action: () => Promise<unknown>, done: string) => {
    if (busyRef.current) return false;
    busyRef.current = true;
    setBusy(true); setError(null); setSuccess(null);
    try { await action(); setSuccess(done); setVersion((value) => value + 1); return true; }
    catch (failure) { setError(message(failure)); return false; }
    finally { busyRef.current = false; setBusy(false); }
  }, []);

  function submitGroup(event: FormEvent) {
    event.preventDefault();
    void perform(() => saveFeeGroup(group), "تم حفظ مجموعة الرسوم. لم تتغير الرسوم المسندة سابقاً.")
      .then((saved) => { if (saved) setGroup(emptyGroup); });
  }
  function editGroup(row: FeeGroup) {
    setGroup({ id: row.id, branch: row.branch_id, session: row.academic_session_id, name: row.name,
      description: row.description ?? "", amount: String(row.amount), due: row.due_date, active: row.is_active });
  }
  function submitAssignment(event: FormEvent) {
    event.preventDefault();
    void perform(() => assignFee(assignmentGroup, student, discount, assignmentDue), "تم إسناد الرسوم.")
      .then((saved) => { if (saved) { setStudent(""); setDiscount("0"); setAssignmentDue(""); } });
  }
  function submitPayment(event: FormEvent) {
    event.preventDefault();
    if (!recoveryReady || !userId || busyRef.current || pendingRefund) return;
    const validation = validateFinancePayment(paymentAmount, paymentMethod, reference);
    if (validation) { setError(validation); return; }
    const request = pendingPayment ?? {
      assignment: selected, amount: normalizeYER(paymentAmount), method: paymentMethod,
      reference: reference.trim(), key: crypto.randomUUID(),
    };
    try {
      sessionStorage.setItem(storageKey, JSON.stringify(request));
      setPendingPayment(request);
    } catch (failure) {
      setRecoveryReady(false); setRecoveryError(`تعذر حفظ محاولة الدفع؛ لم تُرسل: ${message(failure)}`); return;
    }
    void perform(() => postFinancePayment(request.assignment, request.amount, request.method, request.reference, request.key), "تم تسجيل الدفعة والإيصال.")
      .then((saved) => {
        if (!saved) return;
        try {
          sessionStorage.removeItem(storageKey);
          setPendingPayment(null); setPaymentAmount(""); setReference(""); setVerified(false);
        } catch (failure) {
          setError(`تم تسجيل الدفعة، لكن تعذر إزالة محاولة الدفع المحفوظة: ${message(failure)}`);
        }
      });
  }
  function clearPendingPayment() {
    if (!verified || !pendingPayment) return;
    try {
      sessionStorage.removeItem(storageKey); setPendingPayment(null); setVerified(false);
    } catch (failure) { setError(`تعذر إزالة محاولة الدفع المحفوظة: ${message(failure)}`); }
  }
  function submitRefund(event: FormEvent) {
    event.preventDefault();
    if (!recoveryReady || !userId || busyRef.current || pendingPayment || (!pendingRefund && (!refundsReady || !selectedPayment))) return;
    const validation = validateFinancePayment(refundAmount, refundMethod, refundReference);
    if (validation || !reason.trim()) { setError(validation ?? "سبب الاسترداد مطلوب."); return; }
    const request = pendingRefund ?? {
      assignment: selected, payment: selectedPayment, amount: normalizeYER(refundAmount),
      method: refundMethod, reference: refundReference.trim(), reason: reason.trim(), key: crypto.randomUUID(),
    };
    try {
      sessionStorage.setItem(refundStorageKey, JSON.stringify(request));
      setPendingRefund(request);
    } catch (failure) {
      setRecoveryReady(false); setRecoveryError(`تعذر حفظ محاولة الاسترداد؛ لم تُرسل: ${message(failure)}`); return;
    }
    void perform(() => refundFinancePayment(request.payment, request.amount, request.method, request.reference, request.reason, request.key), "تم تسجيل الاسترداد.")
      .then((saved) => {
        if (!saved) return;
        try {
          sessionStorage.removeItem(refundStorageKey);
          setPendingRefund(null); setRefundAmount(""); setRefundReference(""); setReason(""); setVerified(false);
        } catch (failure) {
          setRecoveryError(`تم تسجيل الاسترداد، لكن تعذر إزالة المحاولة المحفوظة: ${message(failure)}`);
        }
      });
  }
  function clearPendingRefund() {
    if (!verified || !pendingRefund) return;
    try {
      sessionStorage.removeItem(refundStorageKey); setPendingRefund(null); setVerified(false);
    } catch (failure) { setRecoveryError(`تعذر إزالة محاولة الاسترداد المحفوظة: ${message(failure)}`); }
  }
  function showRefunds(id: string) {
    const request = ++refundRequest.current;
    setRefundsReady(false);
    setSelectedPayment(id); setRefunds([]);
    void loadFinanceRefunds(id).then((rows) => {
      if (request === refundRequest.current) { setRefunds(rows); setRefundsReady(true); }
    }).catch((failure: unknown) => {
      if (request === refundRequest.current) setError(message(failure));
    });
  }
  function showAudit(event: FormEvent) {
    event.preventDefault(); setAudit([]); setError(null);
    void loadFinanceAudit(auditBranch).then(setAudit).catch((failure: unknown) => setError(message(failure)));
  }
  const selectedGroup = groups.find((row) => row.id === assignmentGroup) ?? null;
  const eligibleStudents = selectedGroup
    ? students.filter((row) => row.branch_id === selectedGroup.branch_id)
    : [];
  const studentById = (id: string) => students.find((row) => row.id === id) ?? null;
  const methodSelect = (value: FinancePaymentMethod, change: (value: FinancePaymentMethod) => void, disabled = false) =>
    <select disabled={disabled} value={value} onChange={(event) => {
      const method = methods.find((entry) => entry.value === event.target.value);
      if (method) change(method.value);
    }}>{methods.map((entry) => <option key={entry.value} value={entry.value}>{entry.label}</option>)}</select>;

  return <main className="workspace">
    <div className="page-heading"><div><p className="eyebrow">كلية ساي</p><h1>الرسوم والمالية</h1>
      <p className="muted">المبالغ بالريال اليمني. العمليات والسجلات محمية على الخادم.</p></div></div>
    {error && <p className="error-box" role="alert">تعذر تنفيذ العملية: {error}</p>}
    {recoveryError && <p className="error-box" role="alert">{recoveryError}</p>}
    {success && <p className="success-box" role="status">{success}</p>}
    {loading && <p role="status">جارٍ تحميل السجلات...</p>}
    {permissions.manageGroups && <section className="panel management-detail">
      <h2>{group.id ? "تعديل مجموعة الرسوم" : "مجموعة رسوم جديدة"}</h2>
      <p className="muted">اختر الفرع والجلسة الأكاديمية. تغييرات المجموعة لا تعدل الرسوم المسندة سابقاً.</p>
      <form className="management-form" onSubmit={submitGroup}>
        <label>الفرع<span className="vocab-required"> *</span><select required value={group.branch} disabled={!!group.id || busy} onChange={(e) => setGroup({ ...group, branch: e.target.value })}>
          <option value="">{branches.length ? "اختر الفرع" : "لا توجد فروع متاحة"}</option>
          {branches.map((row) => <option key={row.id} value={row.id}>{row.name}</option>)}
        </select></label>
        <label>الجلسة الأكاديمية<span className="vocab-required"> *</span><select required value={group.session} disabled={!!group.id || busy} onChange={(e) => setGroup({ ...group, session: e.target.value })}>
          <option value="">{sessions.length ? "اختر الجلسة" : "لا توجد جلسات متاحة"}</option>
          {sessions.map((row) => <option key={row.id} value={row.id}>{row.name}</option>)}
        </select></label>
        <label>اسم المجموعة<input required value={group.name} onChange={(e) => setGroup({ ...group, name: e.target.value })} /></label>
        <label>الوصف<input value={group.description} onChange={(e) => setGroup({ ...group, description: e.target.value })} /></label>
        <label>المبلغ<input required inputMode="decimal" value={group.amount} onChange={(e) => setGroup({ ...group, amount: e.target.value })} /></label>
        <label>تاريخ الاستحقاق<input required type="date" value={group.due} onChange={(e) => setGroup({ ...group, due: e.target.value })} /></label>
        <label>الحالة<select value={group.active ? "active" : "inactive"} onChange={(e) => setGroup({ ...group, active: e.target.value === "active" })}><option value="active">نشطة</option><option value="inactive">غير نشطة</option></select></label>
        <div className="actions"><button className="button primary" disabled={busy}>حفظ المجموعة</button>
          {group.id && <button type="button" className="button secondary" onClick={() => setGroup(emptyGroup)}>إلغاء التعديل</button>}</div>
      </form>
      <ul>{groups.map((row) => <li key={row.id}>{row.name} — {amount(row.amount)} — {row.is_active ? "نشطة" : "غير نشطة"}{" "}
        <button className="text-button" type="button" onClick={() => editGroup(row)}>تعديل</button></li>)}</ul>
    </section>}
    {permissions.assignFees && <section className="panel management-detail"><h2>إسناد رسوم لطالب</h2>
      <form className="management-form" onSubmit={submitAssignment}>
        <label>مجموعة الرسوم<select required value={assignmentGroup} onChange={(e) => setAssignmentGroup(e.target.value)}>
          <option value="">اختر المجموعة</option>{groups.filter((row) => row.is_active).map((row) => <option key={row.id} value={row.id}>{row.name} — {branches.find((branch) => branch.id === row.branch_id)?.name ?? "فرع"}</option>)}
        </select></label>
        <label>الطالب<span className="vocab-required"> *</span><select required value={student} onChange={(e) => setStudent(e.target.value)}>
          <option value="">{selectedGroup ? (eligibleStudents.length ? "اختر الطالب" : "لا يوجد طلاب في فرع المجموعة") : "اختر مجموعة الرسوم أولاً"}</option>
          {eligibleStudents.map((row) => <option key={row.id} value={row.id}>{row.full_name} · {row.admission_no}</option>)}
        </select></label>
        <label>الخصم الثابت<input required inputMode="decimal" value={discount} onChange={(e) => setDiscount(e.target.value)} /></label>
        <label>تاريخ استحقاق خاص (اختياري)<input type="date" value={assignmentDue} onChange={(e) => setAssignmentDue(e.target.value)} /></label>
        <div className="actions"><button className="button primary" disabled={busy}>إسناد الرسوم</button></div>
      </form>
    </section>}
    <section className="panel management-detail"><h2>الأرصدة والرسوم المسندة</h2>
      {!loading && !error && assignments.length === 0 && <p>لا توجد رسوم متاحة.</p>}
      <div className="table-scroll"><table className="management-table"><thead><tr><th>الطالب</th><th>المجموعة</th><th>الاستحقاق</th><th>الحالة</th><th>الرصيد</th><th>التفاصيل</th></tr></thead>
        <tbody>{assignments.map((row) => <tr key={row.id}><td>{studentById(row.student_id)?.full_name ?? "طالب"}<span className="learn-meta">{studentById(row.student_id)?.admission_no ?? ""}</span></td><td>{groups.find((entry) => entry.id === row.fee_group_id)?.name ?? row.fee_group_id}</td>
          <td>{row.due_date}</td><td>{statuses[row.status] ?? row.status}</td><td>{amount(row.balance)}</td>
          <td><button className="text-button" type="button" disabled={(!!pendingPayment && pendingPayment.assignment !== row.id) || (!!pendingRefund && pendingRefund.assignment !== row.id)} onClick={() => setSelected(row.id)}>عرض الدفعات</button></td></tr>)}</tbody></table></div>
    </section>
    {selected && <section className="panel management-detail"><h2>الدفعات والإيصالات</h2>
      {permissions.postPayment && <form className="management-form" onSubmit={submitPayment}>
        <label>المبلغ<input required disabled={!!pendingPayment} inputMode="decimal" value={paymentAmount} onChange={(e) => setPaymentAmount(e.target.value)} /></label>
        <label>طريقة الدفع{methodSelect(paymentMethod, setPaymentMethod, !!pendingPayment)}</label>
        <label>مرجع المعاملة<input required={paymentMethod !== "cash"} disabled={!!pendingPayment} value={reference} onChange={(e) => setReference(e.target.value)} /></label>
        <div className="actions"><button className="button primary" disabled={busy || !recoveryReady || !!pendingRefund}>{pendingPayment ? "إعادة محاولة الدفع" : "تسجيل الدفعة"}</button></div>
        <p className="data-note">تُحفظ محاولة الدفع في هذا التبويب لإعادة المحاولة بالمفتاح والبيانات نفسها بعد فقدان الاتصال أو تحديث الصفحة.</p>
      </form>}
      {pendingPayment && <div className="notice"><p>توجد محاولة دفع غير مؤكدة لهذا الإسناد. تحقق من الإيصالات قبل حذف المحاولة.</p>
        <label><input type="checkbox" checked={verified} onChange={(e) => setVerified(e.target.checked)} /> تحققت من الإيصالات وأريد إزالة المحاولة المحفوظة</label>
        <button type="button" className="button secondary" disabled={!verified || busy} onClick={clearPendingPayment}>إزالة المحاولة بعد التحقق</button>
      </div>}
      {(permissions.waive || permissions.assignFees) && <div className="management-form">
        <label>سبب الإعفاء أو الإلغاء<input disabled={!!pendingRefund} value={reason} onChange={(e) => setReason(e.target.value)} /></label>
        <div className="actions">
          {permissions.waive && <button className="button secondary" disabled={busy || !!pendingPayment || !!pendingRefund || !reason.trim()} onClick={() => void perform(() => waiveFee(selected, reason), "تم الإعفاء من الرصيد المتبقي.")}>إعفاء الرصيد</button>}
          {permissions.assignFees && <button className="button secondary" disabled={busy || !!pendingPayment || !!pendingRefund || !reason.trim()} onClick={() => void perform(() => cancelFee(selected, reason), "تم إلغاء الرسوم المسندة.")}>إلغاء الإسناد</button>}
        </div></div>}
      <div className="table-scroll"><table className="management-table"><thead><tr><th>الإيصال</th><th>المبلغ</th><th>الطريقة</th><th>المرجع</th><th>الحالة</th><th>الإجراءات</th></tr></thead>
        <tbody>{payments.map((row) => <tr key={row.id}><td>{row.receipt_number}</td><td>{amount(row.amount)}</td><td>{methods.find((m) => m.value === row.method)?.label}</td>
          <td>{row.transaction_reference ?? "—"}</td><td>{row.voided_at ? `ملغاة: ${row.void_reason}` : "مرحلة"}</td>
          <td><div className="homework-admin">
            <button className="button secondary quick-action" type="button" onClick={() => {
              const assignment = assignments.find((entry) => entry.id === row.assignment_id);
              if (assignment) setReceipt({ payment: row, assignment });
            }}><i className="ri-printer-line" aria-hidden="true"></i> إيصال</button>
            {permissions.void && !row.voided_at && <button className="text-button" disabled={busy || !!pendingPayment || !!pendingRefund || reason.trim().length < 10}
            onClick={() => void perform(() => voidFinancePayment(row.id, reason), "تم إلغاء الدفعة واستعادة الرصيد.")}>إلغاء الدفعة</button>}
            {(permissions.refund || roles.includes("accountant")) && row.voided_at && <button className="text-button" disabled={!!pendingRefund && pendingRefund.payment !== row.id} onClick={() => showRefunds(row.id)}>الاستردادات</button>}
          </div></td></tr>)}</tbody></table></div>
      {permissions.void && <p className="data-note">لإلغاء دفعة أدخل سبباً لا يقل عن 10 أحرف في حقل السبب أعلاه.</p>}
      {(selectedPayment || pendingRefund) && <div><h2>الاستردادات</h2>
        {refunds.map((row) => <p key={row.id}>{row.refund_number} — {amount(row.amount)} — {row.reason}</p>)}
        {permissions.refund && <form className="management-form" onSubmit={submitRefund}>
          <label>مبلغ الاسترداد<input required disabled={!!pendingRefund} inputMode="decimal" value={refundAmount} onChange={(e) => setRefundAmount(e.target.value)} /></label>
          <label>الطريقة{methodSelect(refundMethod, setRefundMethod, !!pendingRefund)}</label>
          <label>مرجع الاسترداد<input required={refundMethod !== "cash"} disabled={!!pendingRefund} value={refundReference} onChange={(e) => setRefundReference(e.target.value)} /></label>
          <label>السبب<input required disabled={!!pendingRefund} value={reason} onChange={(e) => setReason(e.target.value)} /></label>
          <div className="actions"><button className="button primary" disabled={busy || !recoveryReady || !!pendingPayment || (!pendingRefund && !refundsReady)}>{pendingRefund ? "إعادة محاولة الاسترداد" : "تسجيل الاسترداد"}</button></div>
        </form>}</div>}
      {pendingRefund && <div className="notice"><p>توجد محاولة استرداد غير مؤكدة للدفعة {pendingRefund.payment}. تحقق من سجل الاستردادات قبل حذفها.</p>
        <label><input type="checkbox" checked={verified} onChange={(e) => setVerified(e.target.checked)} /> تحققت من الاستردادات وأريد إزالة المحاولة المحفوظة</label>
        <button type="button" className="button secondary" disabled={!verified || busy} onClick={clearPendingRefund}>إزالة المحاولة بعد التحقق</button>
      </div>}
    </section>}
    {(roles.includes("super_admin") || roles.includes("accountant")) && <section className="panel management-detail">
      <h2>سجل التدقيق المالي</h2><form className="management-form" onSubmit={showAudit}>
        <label>الفرع<select required value={auditBranch} onChange={(e) => setAuditBranch(e.target.value)}>
          <option value="">اختر الفرع</option>
          {branches.map((row) => <option key={row.id} value={row.id}>{row.name}</option>)}
        </select></label>
        <div className="actions"><button className="button secondary">عرض السجل</button></div></form>
      {audit.map((entry) => <p key={entry.id}>{entry.created_at} — {entry.action} — {entry.entity_id} — {entry.actor_id} — {JSON.stringify(entry.details)}</p>)}
    </section>}
    {receipt && <PaymentReceipt
      payment={receipt.payment}
      assignment={receipt.assignment}
      studentName={studentById(receipt.assignment.student_id)?.full_name ?? "—"}
      admissionNo={studentById(receipt.assignment.student_id)?.admission_no ?? "—"}
      group={groups.find((row) => row.id === receipt.assignment.fee_group_id) ?? null}
      branchName={branches.find((row) => row.id === receipt.assignment.branch_id)?.name ?? ""}
      onClose={() => setReceipt(null)}
    />}
  </main>;
}
