import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/access.dart';
import '../data/finance_repository.dart';
import 'printing.dart';

class FinanceDetail extends StatefulWidget {
  const FinanceDetail({
    super.key,
    required this.assignment,
    required this.roles,
    this.repository,
  });
  final Map<String, dynamic> assignment;
  final Set<Role> roles;
  final FinanceRepository? repository;
  @override
  State<FinanceDetail> createState() => _FinanceDetailState();
}

class _FinanceDetailState extends State<FinanceDetail> {
  late final repository =
      widget.repository ?? FinanceRepository(Supabase.instance.client);
  final amount = TextEditingController(), reference = TextEditingController();
  String method = 'cash';
  String? error;
  bool busy = false, ready = false, verified = false;
  Map<String, dynamic>? pending;
  Map<String, dynamic>? refundRequest;
  List<Map<String, dynamic>> payments = [];
  late Map<String, dynamic> invoice = {...widget.assignment};

  bool get staff => Access.manages(widget.roles, PageId.finance);
  bool get accountant =>
      widget.roles.contains(Role.accountant) ||
      widget.roles.contains(Role.super_admin);

  Future<void> _audit() async {
    if (busy || !ready) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final rows = await repository.rows('sai_finance_audit', {
        'wanted_branch': invoice['branch_id'],
      });
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('سجل التدقيق المالي للفرع'),
          content: SizedBox(
            width: 600,
            child: ListView(
              shrinkWrap: true,
              children: [
                if (rows.isEmpty) const Text('لا توجد عمليات مسجلة'),
                for (final row in rows)
                  ListTile(
                    title: Text('${row['action']} · ${row['created_at']}'),
                    subtitle: Text(
                      '${row['actor_id']}\n${row['entity_id']}\n${row['details']}',
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      );
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _refunds(String payment) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final rows = await repository.rows('sai_finance_refunds', {
        'wanted_payment': payment,
      });
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('الاستردادات'),
          content: SizedBox(
            width: 500,
            child: ListView(
              shrinkWrap: true,
              children: [
                if (rows.isEmpty) const Text('لا توجد استردادات مسجلة'),
                for (final row in rows)
                  ListTile(
                    title: Text(
                      '${row['refund_number']} · ${row['amount']} ر.ي',
                    ),
                    subtitle: Text('${row['reason']} · ${row['issued_at']}'),
                    trailing: PrintAction(
                      CollegeReport(
                        title: 'سند استرداد رسوم',
                        subtitle: '${row['refund_number']}',
                        preview: false,
                        columns: const [
                          PrintColumn('البيان'),
                          PrintColumn('التفاصيل', flex: 2),
                        ],
                        rows: [
                          ['مرجع الدفعة', payment],
                          ['المبلغ', '${row['amount']} ر.ي'],
                          ['السبب', '${row['reason']}'],
                          [
                            'الطريقة',
                            financeMethods[row['method']] ?? '${row['method']}',
                          ],
                          ['المرجع', '${row['reference'] ?? '—'}'],
                          ['التاريخ', '${row['issued_at']}'],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      );
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _refund(String payment) async {
    var value = '', reference = '', reason = '', method = 'cash';
    final saved = refundRequest;
    if (saved == null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, change) => AlertDialog(
            title: const Text('استرداد دفعة ملغاة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'المبلغ بالريال اليمني',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (text) => value = text,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: method,
                    items: [
                      for (final entry in financeMethods.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                    ],
                    onChanged: (text) => change(() => method = text!),
                  ),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'مرجع المعاملة',
                    ),
                    onChanged: (text) => reference = text,
                  ),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'سبب الاسترداد',
                    ),
                    onChanged: (text) => reason = text,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('رجوع'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('تسجيل الاسترداد'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repository.refund(payment, value, method, reference, reason);
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) {
        final failure = error;
        await _load();
        if (mounted) {
          setState(() {
            busy = false;
            error = failure ?? error;
          });
        }
      }
    }
  }

  Future<void> _adjust(String action, String id) async {
    var enteredReason = '';
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد العملية المالية'),
        content: TextField(
          onChanged: (value) => enteredReason = value,
          decoration: InputDecoration(
            labelText: action == 'void'
                ? 'سبب إلغاء الدفعة (10 أحرف على الأقل)'
                : 'السبب مطلوب',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('رجوع'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, enteredReason),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (reason == null || !mounted || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repository.adjust(action, id, reason);
      if (mounted) await _load();
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    amount.dispose();
    reference.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      ready = false;
      error = null;
      payments = [];
    });
    try {
      final saved = staff ? await repository.pending() : null;
      final savedRefund = staff ? await repository.pendingRefund() : null;
      final rows = await repository.rows('sai_finance_payments', {
        'wanted_assignment': widget.assignment['id'],
      });
      final invoices = await repository.rows('sai_finance_assignments');
      final current = invoices
          .where((row) => row['id'] == widget.assignment['id'])
          .firstOrNull;
      if (current == null) {
        throw StateError('الفاتورة لم تعد متاحة لهذا الحساب');
      }
      if (!mounted) return;
      setState(() {
        payments = rows;
        invoice = {...widget.assignment, ...current};
        pending = saved;
        refundRequest = savedRefund;
        ready = true;
        if (saved != null) {
          amount.text = '${saved['wanted_amount']}';
          method = '${saved['wanted_method']}';
          reference.text = saved['wanted_reference'] as String? ?? '';
        }
      });
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    }
  }

  Future<void> _pay() async {
    if (busy || !ready) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repository.pay(
        '${widget.assignment['id']}',
        amount.text,
        method,
        reference.text,
      );
      if (!mounted) return;
      amount.clear();
      reference.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تسجيل الدفعة والإيصال')));
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) {
        // Always recover the durable request, including after an ambiguous RPC error.
        final failure = error;
        await _load();
        if (mounted) {
          setState(() {
            busy = false;
            error = failure ?? error;
          });
        }
      }
    }
  }

  CollegeReport _receipt(Map<String, dynamic> payment) => CollegeReport(
    title: 'إيصال سداد رسوم',
    subtitle: '${payment['receipt_number']}',
    preview: false,
    signature: true,
    columns: const [PrintColumn('البيان'), PrintColumn('التفاصيل', flex: 2)],
    rows: [
      ['الطالب', '${widget.assignment['student_name']}'],
      ['الرقم الأكاديمي', '${widget.assignment['admission_no'] ?? ''}'],
      ['الرسوم', '${widget.assignment['group_name']}'],
      ['مرجع الفاتورة', '${widget.assignment['id']}'],
      ['تاريخ السداد', '${payment['posted_at']}'],
      ['المبلغ', '${payment['amount']} ر.ي'],
      ['الطريقة', financeMethods[payment['method']] ?? '${payment['method']}'],
      ['مرجع المعاملة', '${payment['transaction_reference'] ?? '—'}'],
      [
        'الحالة',
        payment['voided_at'] == null
            ? 'مرحّلة'
            : 'ملغاة: ${payment['void_reason']}',
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    final otherInvoice =
        pending != null &&
        pending!['wanted_assignment'] != widget.assignment['id'];
    return Scaffold(
      appBar: AppBar(title: const Text('الدفعات والإيصالات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (refundRequest != null) ...[
            Text(
              'توجد محاولة استرداد محفوظة للدفعة ${refundRequest!['wanted_payment']}. راجع السجل أو أعد المحاولة بالبيانات نفسها.',
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () => _refunds('${refundRequest!['wanted_payment']}'),
              child: const Text('مراجعة سجل الاستردادات'),
            ),
            if (widget.roles.contains(Role.super_admin))
              TextButton(
                onPressed: busy
                    ? null
                    : () => _refund('${refundRequest!['wanted_payment']}'),
                child: const Text('إعادة محاولة الاسترداد'),
              ),
            CheckboxListTile(
              value: verified,
              onChanged: busy
                  ? null
                  : (value) => setState(() => verified = value ?? false),
              title: const Text(
                'راجعت السجل وتحققت من نتيجة الاسترداد قبل حذف المحاولة',
              ),
            ),
            TextButton(
              onPressed: busy || !verified
                  ? null
                  : () async {
                      try {
                        await repository.clearPendingRefund();
                        if (mounted) {
                          setState(() => verified = false);
                          await _load();
                        }
                      } catch (failure) {
                        if (mounted) setState(() => error = '$failure');
                      }
                    },
              child: const Text('إزالة محاولة الاسترداد بعد التحقق'),
            ),
          ],
          Text(
            '${widget.assignment['student_name']} · ${widget.assignment['group_name']}',
          ),
          Text('مرجع الفاتورة: ${widget.assignment['id']}'),
          if (ready)
            Text(
              'الرصيد الحالي: ${invoice['balance']} ر.ي · الحالة: ${financeStatuses[invoice['status']] ?? invoice['status']}',
            ),
          if (ready)
            PrintAction(
              CollegeReport(
                title: 'فاتورة رسوم الطالب',
                subtitle: '${widget.assignment['id']}',
                preview: false,
                columns: const [
                  PrintColumn('البيان'),
                  PrintColumn('التفاصيل', flex: 2),
                ],
                rows: [
                  ['الطالب', '${widget.assignment['student_name']}'],
                  [
                    'الرقم الأكاديمي',
                    '${widget.assignment['admission_no'] ?? ''}',
                  ],
                  ['الرسوم', '${widget.assignment['group_name']}'],
                  ['الاستحقاق', '${widget.assignment['due_date']}'],
                  [
                    'المبلغ الأصلي',
                    '${widget.assignment['original_amount']} ر.ي',
                  ],
                  ['الخصم', '${widget.assignment['discount_amount']} ر.ي'],
                  ['الصافي', '${widget.assignment['final_amount']} ر.ي'],
                  ['الرصيد الحالي', '${invoice['balance']} ر.ي'],
                  [
                    'الحالة',
                    '${financeStatuses[invoice['status']] ?? invoice['status']}',
                  ],
                ],
              ),
            ),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          if (!ready)
            const Text(
              'تعذر تحميل سجل الدفعات أو جارٍ تحميله؛ التسجيل متوقف حتى التحقق.',
            ),
          TextButton(
            onPressed: busy ? null : _load,
            child: const Text('تحديث السجل'),
          ),
          for (final payment in payments)
            Card(
              child: ListTile(
                title: Text(
                  '${payment['receipt_number']} · ${payment['amount']} ر.ي',
                ),
                subtitle: Text(
                  '${payment['posted_at']}\n${financeMethods[payment['method']]} · ${payment['transaction_reference'] ?? '—'}\n${payment['voided_at'] == null ? 'مرحّلة' : 'ملغاة: ${payment['void_reason']}'}',
                ),
                trailing: Wrap(
                  children: [
                    PrintAction(_receipt(payment)),
                    if (accountant && payment['voided_at'] == null)
                      IconButton(
                        tooltip: 'إلغاء الدفعة',
                        icon: const Icon(Icons.cancel_outlined),
                        onPressed:
                            busy ||
                                !ready ||
                                pending != null ||
                                refundRequest != null
                            ? null
                            : () => _adjust('void', '${payment['id']}'),
                      ),
                    if (accountant && payment['voided_at'] != null)
                      IconButton(
                        tooltip: 'الاستردادات',
                        icon: const Icon(Icons.history),
                        onPressed: busy
                            ? null
                            : () => _refunds('${payment['id']}'),
                      ),
                    if (widget.roles.contains(Role.super_admin) &&
                        payment['voided_at'] != null)
                      IconButton(
                        tooltip: 'استرداد دفعة',
                        icon: const Icon(Icons.currency_exchange),
                        onPressed:
                            busy ||
                                !ready ||
                                pending != null ||
                                refundRequest != null
                            ? null
                            : () => _refund('${payment['id']}'),
                      ),
                  ],
                ),
              ),
            ),
          if (ready && payments.isEmpty)
            const Text('لا توجد دفعات لهذه الفاتورة.'),
          if (staff) ...[
            if (accountant)
              TextButton(
                onPressed: busy || !ready ? null : _audit,
                child: const Text('سجل التدقيق المالي للفرع'),
              ),
            if (ready && invoice['status'] != 'cancelled')
              Wrap(
                children: [
                  if (accountant && (invoice['balance'] as num) > 0)
                    TextButton(
                      onPressed:
                          busy || pending != null || refundRequest != null
                          ? null
                          : () => _adjust('waive', '${invoice['id']}'),
                      child: const Text('إعفاء الرصيد'),
                    ),
                  if (!payments.any((payment) => payment['voided_at'] == null))
                    TextButton(
                      onPressed:
                          busy || pending != null || refundRequest != null
                          ? null
                          : () => _adjust('cancel', '${invoice['id']}'),
                      child: const Text('إلغاء الإسناد'),
                    ),
                ],
              ),
            if (pending != null)
              Text(
                'توجد محاولة دفع محفوظة${otherInvoice ? ' للفاتورة ${pending!['wanted_assignment']}' : ''}. إعادة المحاولة تستخدم البيانات والمفتاح نفسيهما.',
              ),
            TextField(
              controller: amount,
              enabled: pending == null && !busy,
              decoration: const InputDecoration(
                labelText: 'المبلغ بالريال اليمني',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            DropdownButtonFormField<String>(
              key: ValueKey(method),
              initialValue: method,
              decoration: const InputDecoration(labelText: 'طريقة الدفع'),
              items: [
                for (final entry in financeMethods.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: pending != null || busy
                  ? null
                  : (value) => setState(() => method = value!),
            ),
            TextField(
              controller: reference,
              enabled: pending == null && !busy,
              decoration: const InputDecoration(
                labelText: 'مرجع المعاملة (مطلوب للدفع الإلكتروني)',
              ),
            ),
            FilledButton(
              onPressed:
                  busy ||
                      !ready ||
                      otherInvoice ||
                      refundRequest != null ||
                      (pending == null &&
                          (invoice['status'] == 'cancelled' ||
                              (invoice['balance'] as num) <= 0))
                  ? null
                  : _pay,
              child: Text(
                busy
                    ? 'جارٍ التسجيل...'
                    : pending == null
                    ? 'تسجيل الدفعة'
                    : 'إعادة محاولة الدفع',
              ),
            ),
            if (pending != null && !otherInvoice) ...[
              CheckboxListTile(
                value: verified,
                onChanged: busy
                    ? null
                    : (value) => setState(() => verified = value ?? false),
                title: const Text(
                  'راجعت الإيصالات وتحققت من نتيجة المحاولة قبل حذفها',
                ),
              ),
              TextButton(
                onPressed: !verified || busy
                    ? null
                    : () async {
                        try {
                          await repository.clearPending();
                          if (mounted) {
                            setState(() => verified = false);
                            await _load();
                          }
                        } catch (failure) {
                          if (mounted) setState(() => error = '$failure');
                        }
                      },
                child: const Text('إزالة المحاولة بعد التحقق'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
