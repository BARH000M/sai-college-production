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
  });
  final Map<String, dynamic> assignment;
  final Set<Role> roles;
  @override
  State<FinanceDetail> createState() => _FinanceDetailState();
}

class _FinanceDetailState extends State<FinanceDetail> {
  late final repository = FinanceRepository(Supabase.instance.client);
  final amount = TextEditingController(), reference = TextEditingController();
  String method = 'cash';
  String? error;
  bool busy = false, ready = false, verified = false;
  Map<String, dynamic>? pending;
  List<Map<String, dynamic>> payments = [];

  bool get staff => Access.manages(widget.roles, PageId.finance);

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
    });
    try {
      final saved = staff ? await repository.pending() : null;
      final rows = await repository.rows('sai_finance_payments', {
        'wanted_assignment': widget.assignment['id'],
      });
      if (!mounted) return;
      setState(() {
        payments = rows;
        pending = saved;
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
          Text(
            '${widget.assignment['student_name']} · ${widget.assignment['group_name']}',
          ),
          Text('مرجع الفاتورة: ${widget.assignment['id']}'),
          PrintAction(CollegeReport(
            title: 'فاتورة رسوم الطالب', subtitle: '${widget.assignment['id']}', preview: false,
            columns: const [PrintColumn('البيان'), PrintColumn('التفاصيل', flex: 2)],
            rows: [
              ['الطالب', '${widget.assignment['student_name']}'],
              ['الرقم الأكاديمي', '${widget.assignment['admission_no'] ?? ''}'],
              ['الرسوم', '${widget.assignment['group_name']}'],
              ['الاستحقاق', '${widget.assignment['due_date']}'],
              ['المبلغ الأصلي', '${widget.assignment['original_amount']} ر.ي'],
              ['الخصم', '${widget.assignment['discount_amount']} ر.ي'],
              ['الصافي', '${widget.assignment['final_amount']} ر.ي'],
            ],
          )),
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
                trailing: PrintAction(_receipt(payment)),
              ),
            ),
          if (ready && payments.isEmpty)
            const Text('لا توجد دفعات لهذه الفاتورة.'),
          if (staff) ...[
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
              onPressed: busy || !ready || otherInvoice ? null : _pay,
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
