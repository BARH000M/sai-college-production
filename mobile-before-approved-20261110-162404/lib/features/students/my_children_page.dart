import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_identity.dart';
import '../../core/sai_theme.dart';
import '../../widgets/state_views.dart';
import 'student_stats.dart';

class _Child {
  const _Child({
    required this.id,
    required this.name,
    required this.admissionNo,
    required this.className,
    required this.stats,
  });

  final String id;
  final String name;
  final String admissionNo;
  final String className;
  final StudentStats stats;
}

/// Screen 5 of the mockup: the guardian's linked children with their live
/// attendance, grades, lessons and announcements.
class MyChildrenPage extends StatefulWidget {
  const MyChildrenPage({super.key, required this.identity});

  final AppIdentity identity;

  @override
  State<MyChildrenPage> createState() => _MyChildrenPageState();
}

class _MyChildrenPageState extends State<MyChildrenPage> {
  late Future<List<_Child>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_Child>> _load() async {
    final client = Supabase.instance.client;
    final links = await client
        .from('parent_student_links')
        .select('student_id')
        .eq('parent_user_id', widget.identity.userId)
        .not('verified_at', 'is', null);

    final ids = <String>[];
    for (final row in links as List) {
      final id = (row as Map<String, dynamic>)['student_id'];
      if (id is String && !ids.contains(id)) ids.add(id);
    }
    if (ids.isEmpty) return const <_Child>[];

    final classRows = await client.from('classes').select('id,name');
    final classNames = <String, String>{};
    for (final row in classRows as List) {
      final map = row as Map<String, dynamic>;
      final id = map['id'];
      if (id is String) classNames[id] = (map['name'] as String?) ?? '';
    }

    final studentRows = await client.from('students').select('id,full_name,admission_no,class_id').inFilter('id', ids);
    final statsList = await Future.wait(ids.map((id) => loadStudentStats(client, id)));
    final statsById = <String, StudentStats>{};
    for (var i = 0; i < ids.length; i++) {
      statsById[ids[i]] = statsList[i];
    }

    final children = <_Child>[];
    for (final row in studentRows as List) {
      final map = row as Map<String, dynamic>;
      final id = map['id'] as String;
      final classId = map['class_id'] as String?;
      children.add(_Child(
        id: id,
        name: (map['full_name'] as String?)?.trim().isNotEmpty == true ? (map['full_name'] as String).trim() : 'طالب',
        admissionNo: (map['admission_no'] as String?) ?? '—',
        className: classId == null ? 'غير مسجل في صف' : (classNames[classId] ?? 'غير مسجل في صف'),
        stats: statsById[id] ?? StudentStats.empty,
      ));
    }
    children.sort((a, b) => a.name.compareTo(b.name));
    return children;
  }

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final firstName = widget.identity.fullName.trim().split(RegExp(r'\s+')).first;
    return FutureBuilder<List<_Child>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const LoadingState();
        if (snapshot.hasError) {
          return ErrorState(message: '${snapshot.error}', onRetry: _retry);
        }
        final children = snapshot.data ?? const <_Child>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 26),
          children: [
            _GreetingBlock(name: firstName, subtitle: 'أبناؤك المرتبطون بحسابك فقط (${children.length})'),
            const SizedBox(height: 14),
            if (children.isEmpty)
              const EmptyState(
                icon: Icons.family_restroom_outlined,
                title: 'لا يوجد أبناء مرتبطون بعد',
                message: 'يتم ربط حسابك بأبنائك من قِبل إدارة الكلية. راجع الاستقبال إذا كان الربط مطلوبًا.',
              )
            else
              ...children.map((child) => Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: _ChildCard(child: child),
                  )),
          ],
        );
      },
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.child});

  final _Child child;

  @override
  Widget build(BuildContext context) {
    final initial = child.name.trim().isEmpty ? 'ط' : child.name.trim().substring(0, 1);
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SaiColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: SaiColors.creamDeep,
                child: Text(initial, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: SaiColors.ink)),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(child.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: SaiColors.ink)),
                    const SizedBox(height: 1),
                    Text('${child.admissionNo} · ${child.className}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: SaiColors.muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left, size: 18, color: SaiColors.muted),
            ],
          ),
          const SizedBox(height: 10),
          StudentMetricRow(stats: child.stats),
        ],
      ),
    );
  }
}

class _GreetingBlock extends StatelessWidget {
  const _GreetingBlock({required this.name, required this.subtitle});

  final String name;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('مرحبًا، $name', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: SaiColors.ink)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 10.5, color: SaiColors.muted)),
            ],
          ),
        ),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: SaiColors.goldTint, borderRadius: BorderRadius.circular(11)),
          child: const Icon(Icons.workspace_premium_outlined, size: 18, color: SaiColors.gold),
        ),
      ],
    );
  }
}