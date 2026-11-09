import 'dart:async';
import 'package:flutter/material.dart';
import '../../auth/profile.dart';
import '../../core/api.dart';
import '../../routing/app_role.dart';
import 'dashboard_spec.dart';

class RoleHomePage extends StatefulWidget {
  const RoleHomePage(
      {super.key,
      required this.api,
      required this.profile,
      required this.role});
  final SchoolApi api;
  final Profile profile;
  final AppRole role;
  @override
  State<RoleHomePage> createState() => _RoleHomePageState();
}

class _MetricState {
  _MetricState({this.value, this.error});
  final String? value;
  final String? error;
}

class _RoleHomePageState extends State<RoleHomePage> {
  late List<StatSpec> _specs;
  final Map<int, _MetricState> _values = {};
  bool _loading = true;
  int _loadGeneration = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _specs =
        specsFor(role: widget.role, api: widget.api, profile: widget.profile);
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _error = null;
      _values.clear();
    });
    await Future.wait(_specs.asMap().entries.map((entry) async {
      try {
        final value = await entry.value.load();
        if (!mounted || generation != _loadGeneration) return;
        setState(() => _values[entry.key] = _MetricState(value: value));
      } on ApiException catch (e) {
        if (!mounted || generation != _loadGeneration) return;
        setState(() => _values[entry.key] = _MetricState(error: e.message));
      } catch (_) {
        if (!mounted || generation != _loadGeneration) return;
        setState(() =>
            _values[entry.key] = _MetricState(error: 'تعذّر تحميل هذا المؤشر'));
      }
    }));
    if (!mounted || generation != _loadGeneration) return;
    final allFailed =
        _values.isNotEmpty && _values.values.every((v) => v.error != null);
    setState(() {
      _loading = false;
      _error = allFailed ? 'تعذّر تحميل كل المؤشرات — تحقق من الاتصال' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _values.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text('أهلاً ${widget.profile.fullName}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(roleNote(widget.role, widget.profile),
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 16),
          if (_error != null) _ErrorBanner(message: _error!, onRetry: _load),
          if (_error != null) const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(1);
            final columns = constraints.maxWidth < 340 || scale > 1.4
                ? 1
                : constraints.maxWidth > 800 ? 4 : 2;
            return GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: ((constraints.maxWidth - (columns - 1) * 12) / columns) /
                (185 + (scale > 1 ? (scale - 1) * 135 : 0)),
            children: _specs.asMap().entries.map((entry) {
              final spec = entry.value;
              final state = _values[entry.key];
              return _StatCard(
                  label: spec.label,
                  icon: spec.icon,
                  hint: spec.hint,
                  value: state?.value,
                  failed: state?.error != null,
                  alert: spec.alertWhenPositive &&
                      state?.value != null &&
                      state?.value != '0');
            }).toList(),
          );
          }),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text('دورك: ${widget.role.label}',
                  style: const TextStyle(fontSize: 14)),
              subtitle: Text(
                  widget.role.isFamily
                      ? 'بياناتك محصورة في حسابك على مستوى قاعدة البيانات.'
                      : 'البيانات محصورة في مؤسستك على مستوى قاعدة البيانات.',
                  style: const TextStyle(fontSize: 11)),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
              'كل رقم أعلاه مقروء من الخادم عند فتح الشاشة أو عند السحب للتحديث — لا يوجد تخزين محلي يعرض رقماً قديماً كأنه حالي.',
              style: TextStyle(fontSize: 10, color: Colors.black45),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFFDF2EC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE8C4AE))),
      child: Row(children: [
        const Icon(Icons.cloud_off_outlined,
            size: 18, color: Color(0xFF9A3412)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(message,
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF9A3412)))),
        TextButton(
            onPressed: () => unawaited(onRetry()),
            child:
                const Text('إعادة المحاولة', style: TextStyle(fontSize: 12))),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label,
      required this.icon,
      required this.value,
      this.hint,
      this.failed = false,
      this.alert = false});
  final String label;
  final IconData icon;
  final String? value;
  final String? hint;
  final bool failed;
  final bool alert;
  @override
  Widget build(BuildContext context) {
    final tone = alert ? const Color(0xFF9A3412) : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color:
                  alert ? const Color(0xFFE8C4AE) : const Color(0xFFE9E3DA))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: tone),
        const Spacer(),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 2),
        Text(failed ? '—' : (value ?? '…'),
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: failed
                    ? Colors.black38
                    : (alert ? tone : const Color(0xFF1B1B1B)))),
        if (failed)
          const Text('تعذّر التحميل',
              style: TextStyle(fontSize: 10, color: Color(0xFF9A3412)))
        else if (hint != null)
          Text(hint!,
              style: const TextStyle(fontSize: 10, color: Colors.black45)),
      ]),
    );
  }
}
