import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/access.dart';
import '../data/admissions_repository.dart';
import 'components.dart';

class LiveAdmissionsScreen extends StatefulWidget {
  const LiveAdmissionsScreen({super.key, required this.roles, this.repository});

  final Set<Role> roles;
  final AdmissionsData? repository;

  @override
  State<LiveAdmissionsScreen> createState() => _LiveAdmissionsScreenState();
}

class _LiveAdmissionsScreenState extends State<LiveAdmissionsScreen> {
  late final AdmissionsData _repository =
      widget.repository ?? AdmissionsRepository();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _enquiries = [];
  String? _branchId;
  String _statusFilter = '';
  String _search = '';
  String? _error;
  bool _loadingBranches = true;
  bool _loadingEnquiries = false;
  bool _hasMore = false;
  String? _updatingId;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    try {
      final branches = await _repository.loadBranches();
      if (!mounted) return;
      setState(() {
        _branches = branches;
        _branchId = branches.isEmpty ? null : '${branches.first['id']}';
        _loadingBranches = false;
      });
      if (_branchId != null) await _loadEnquiries(reset: true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _errorMessage(error);
        _loadingBranches = false;
      });
    }
  }

  Future<void> _loadEnquiries({required bool reset}) async {
    final branchId = _branchId;
    if (branchId == null || _loadingEnquiries) return;
    final page = reset ? 0 : _page;
    setState(() {
      _loadingEnquiries = true;
      _error = null;
      if (reset) {
        _enquiries = [];
        _page = 0;
        _hasMore = false;
      }
    });
    try {
      final rows = await _repository.loadEnquiries(
        branchId: branchId,
        offset: page * admissionsPageSize,
        status: _statusFilter.isEmpty ? null : _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        _enquiries = [..._enquiries, ...rows];
        _page = page + 1;
        _hasMore = rows.length == admissionsPageSize;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _loadingEnquiries = false);
    }
  }

  Future<void> _changeBranch(String? branchId) async {
    if (branchId == null) return;
    setState(() => _branchId = branchId);
    await _loadEnquiries(reset: true);
  }

  Future<void> _changeStatus(
    Map<String, dynamic> enquiry,
    String status,
  ) async {
    final id = '${enquiry['id']}';
    setState(() {
      _updatingId = id;
      _error = null;
    });
    try {
      await _repository.updateStatus(id, status);
      if (!mounted) return;
      await _loadEnquiries(reset: true);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم تحديث حالة الطلب.')));
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _updatingId = null);
    }
  }

  Future<void> _enroll(Map<String, dynamic> enquiry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنشاء سجل طالب'),
        content: const Text(
          'سيُنشأ سجل طالب مرتبط بهذا الطلب. لن يُنشأ حساب دخول أو رابط ولي أمر تلقائيًا.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد التسجيل'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final id = '${enquiry['id']}';
    setState(() {
      _updatingId = id;
      _error = null;
    });
    try {
      final student = await _repository.enroll(id);
      if (!mounted) return;
      await _loadEnquiries(reset: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إنشاء سجل الطالب ${student['admission_no']}.'),
          ),
        );
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _updatingId = null);
    }
  }

  Future<void> _chooseStatus(Map<String, dynamic> enquiry) async {
    final currentStatus = '${enquiry['status']}';
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('اختر الحالة الجديدة'),
        children: [
          for (final entry in editableAdmissionStatuses.entries)
            if (entry.key != currentStatus)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, entry.key),
                child: Text(entry.value),
              ),
        ],
      ),
    );
    if (selected != null && mounted) await _changeStatus(enquiry, selected);
  }

  String _errorMessage(Object error) => error is PostgrestException
      ? 'رفضت قاعدة البيانات الطلب: ${error.message}'
      : 'تعذر تحميل بيانات القبول أو تحديثها: $error';

  List<Map<String, dynamic>> get _visibleEnquiries {
    final term = _search.trim().toLowerCase();
    if (term.isEmpty) return _enquiries;
    return _enquiries.where((row) {
      final searchable = [
        row['application_no'],
        row['applicant_full_name'],
        row['guardian_name'],
        row['phone'],
        row['email'],
      ].whereType<Object>().join(' ').toLowerCase();
      return searchable.contains(term);
    }).toList();
  }

  void _showDetails(Map<String, dynamic> enquiry) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تفاصيل طلب القبول'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detail('رقم الطلب', enquiry['application_no']),
              _detail('اسم المتقدم', enquiry['applicant_full_name']),
              _detail('اسم ولي الأمر', enquiry['guardian_name']),
              _detail('الهاتف', enquiry['phone']),
              _detail('البريد الإلكتروني', enquiry['email']),
              _detail('البرنامج', enquiry['preferred_program']),
              _detail('المستوى', enquiry['preferred_level']),
              _detail('ملاحظات', enquiry['notes']),
              _detail(
                'تاريخ التقديم',
                enquiry['created_at'] == null
                    ? null
                    : DateTime.tryParse(
                        '${enquiry['created_at']}',
                      )?.toLocal().toString(),
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
  }

  Widget _detail(String label, Object? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Text(
      '$label: ${value == null || '$value'.trim().isEmpty ? '—' : value}',
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!Access.manages(widget.roles, PageId.admissions)) {
      return const EmptyPanel('لا تملك صلاحية إدارة طلبات القبول.');
    }
    if (_loadingBranches) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _branches.isEmpty) {
      return EmptyPanel(_error!, retry: _loadBranches);
    }
    if (_branches.isEmpty) {
      return const EmptyPanel('لا توجد فروع متاحة لهذا الحساب.');
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const SectionHeading('طلبات القبول والتسجيل'),
        const Text(
          'تعرض هذه الشاشة الطلبات التي تسمح بها صلاحيات الفرع في Supabase.',
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _branchId,
          decoration: const InputDecoration(labelText: 'الفرع'),
          items: [
            for (final branch in _branches)
              DropdownMenuItem(
                value: '${branch['id']}',
                child: Text('${branch['name'] ?? 'فرع'}'),
              ),
          ],
          onChanged: _loadingEnquiries ? null : _changeBranch,
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _statusFilter,
          decoration: const InputDecoration(labelText: 'تصفية حسب الحالة'),
          items: [
            const DropdownMenuItem(value: '', child: Text('كل الحالات')),
            for (final entry in admissionStatusLabels.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: _loadingEnquiries
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() => _statusFilter = value);
                  _loadEnquiries(reset: true);
                },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: 'بحث بالاسم أو الهاتف أو الرقم المرجعي',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: 'مسح البحث',
              onPressed: () {
                _searchController.clear();
                setState(() => _search = '');
              },
              icon: const Icon(Icons.clear),
            ),
          ),
          onChanged: (value) => setState(() => _search = value),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          SaiCard(
            child: Column(
              children: [
                Text(_error!, textAlign: TextAlign.center),
                TextButton(
                  onPressed: () => _loadEnquiries(reset: true),
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ],
        if (_loadingEnquiries && _enquiries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (!_loadingEnquiries && _error == null && _visibleEnquiries.isEmpty)
          const SaiCard(
            child: Text(
              'لا توجد طلبات مطابقة في هذا الفرع. لن تظهر بيانات تجريبية هنا.',
              textAlign: TextAlign.center,
            ),
          ),
        for (final enquiry in _visibleEnquiries)
          SaiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${enquiry['applicant_full_name'] ?? 'متقدم'}',
                  style: const TextStyle(
                    color: ink,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${enquiry['application_no'] ?? ''}  •  '
                  '${admissionStatusLabels['${enquiry['status']}'] ?? enquiry['status'] ?? ''}',
                  textDirection: TextDirection.rtl,
                ),
                if (enquiry['phone'] != null)
                  Text('${enquiry['phone']}', textDirection: TextDirection.ltr),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.start,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showDetails(enquiry),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('التفاصيل'),
                    ),
                    TextButton.icon(
                      onPressed: _updatingId == null
                          ? () => _chooseStatus(enquiry)
                          : null,
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(
                        _updatingId == enquiry['id']
                            ? 'جارٍ التحديث...'
                            : 'تحديث الحالة',
                      ),
                    ),
                    if ('${enquiry['status']}' == 'accepted' &&
                        (widget.roles.contains(Role.super_admin) ||
                            widget.roles.contains(Role.admin)))
                      FilledButton.icon(
                        onPressed: _updatingId == null
                            ? () => _enroll(enquiry)
                            : null,
                        icon: const Icon(Icons.how_to_reg_outlined),
                        label: const Text('إنشاء سجل طالب'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        if (_loadingEnquiries && _enquiries.isNotEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_hasMore && !_loadingEnquiries)
          Center(
            child: TextButton(
              onPressed: () => _loadEnquiries(reset: false),
              child: const Text('تحميل طلبات إضافية'),
            ),
          ),
      ],
    );
  }
}
