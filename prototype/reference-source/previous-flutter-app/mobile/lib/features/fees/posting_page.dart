import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api.dart';

class PostingPage extends StatefulWidget {
  const PostingPage({super.key, required this.api});
  final SchoolApi api;
  @override
  State<PostingPage> createState() => _PostingPageState();
}

class _PostingPageState extends State<PostingPage> {
  List<FeePayment> _pending = const [];
  List<FinanceAccount> _accounts = const [];
  FinanceAccount? _account;
  String _category = 'رسوم دراسية';
  bool _loading = true;
  bool _running = false;
  String? _error;
  int _done = 0;
  int _total = 0;
  int _posted = 0;
  final List<String> _failures = [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait(
          [widget.api.feePayments(onlyUnposted: true), widget.api.accounts()]);
      if (!mounted) return;
      final pending = results[0] as List<FeePayment>;
      final accounts = results[1] as List<FinanceAccount>;
      setState(() {
        _pending = pending;
        _accounts = accounts;
        _account = accounts.isEmpty ? null : accounts.first;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'تعذّر تحميل الدفعات';
        _loading = false;
      });
    }
  }

  Future<void> _runAll() async {
    final account = _account;
    if (account == null || _pending.isEmpty) return;
    final queue = List<FeePayment>.from(_pending);
    setState(() {
      _running = true;
      _done = 0;
      _total = queue.length;
      _posted = 0;
      _failures.clear();
    });
    for (final payment in queue) {
      try {
        await widget.api.postFeePayment(
            paymentId: payment.id, accountId: account.id, category: _category);
        if (mounted) setState(() => _posted += 1);
      } catch (e) {
        if (mounted) {
          setState(() => _failures.add(
              'وصل #${payment.id}: ${e is ApiException ? e.message : 'تعذّر الترحيل'}'));
        }
      }
      if (mounted) setState(() => _done += 1);
    }
    if (mounted) setState(() => _running = false);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 36),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: () => unawaited(_load()),
                        child: const Text('إعادة المحاولة')),
                  ])));
    }
    final value = _pending.fold<double>(0, (sum, p) => sum + p.amount);
    return RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text('ترحيل التحصيلات إلى دفتر الحسابات',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
              '${_pending.length} وصل بقيمة ${value.toStringAsFixed(0)} ر.ي بلا قيد',
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 16),
          if (_accounts.isEmpty)
            const Card(
                child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                        'لا يوجد حساب مالي نشط. أضف حساباً في دفتر المالية أولاً.',
                        style: TextStyle(fontSize: 12.5, height: 1.6))))
          else ...[
            DropdownButtonFormField<FinanceAccount>(
                value: _account,
                decoration: const InputDecoration(
                    labelText: 'الحساب المستلم', border: OutlineInputBorder()),
                items: _accounts
                    .map((a) => DropdownMenuItem(
                        value: a, child: Text('${a.name} · ${a.currency}')))
                    .toList(),
                onChanged: _running
                    ? null
                    : (picked) => setState(() => _account = picked)),
            const SizedBox(height: 12),
            TextFormField(
                initialValue: _category,
                enabled: !_running,
                decoration: const InputDecoration(
                    labelText: 'تصنيف الإيراد', border: OutlineInputBorder()),
                onChanged: (value) => _category = value),
            const SizedBox(height: 16),
            if (_running) ...[
              LinearProgressIndicator(
                  value: _total == 0 ? null : _done / _total),
              const SizedBox(height: 8),
              Text('جارٍ الترحيل $_done / $_total',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 12)
            ],
            FilledButton.icon(
                onPressed: _running || _pending.isEmpty
                    ? null
                    : () => unawaited(_runAll()),
                icon: Icon(
                    _running ? Icons.hourglass_top : Icons.play_circle_outline),
                label: Text(_pending.isEmpty
                    ? 'لا شيء بانتظار الترحيل'
                    : 'ترحيل ${_pending.length} تحصيلاً'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48))),
          ],
          if (_posted > 0 || _failures.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('مُرحّل $_posted · فاشل ${_failures.length}',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          const Text(
                              'المُرحّل لا يتكرر: إعادة التشغيل تُعيد القيد نفسه ولا تنشئ قيداً ثانياً.',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.black54,
                                  height: 1.5)),
                          ..._failures.take(6).map((message) => Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(message,
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF9A3412))))),
                        ]))),
          ],
        ]));
  }
}
