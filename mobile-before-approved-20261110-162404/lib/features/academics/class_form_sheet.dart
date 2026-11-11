import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/sai_theme.dart';
import '../../widgets/state_views.dart';
import 'class_models.dart';
import 'teacher_directory.dart';

class _NamedOption {
  const _NamedOption({required this.id, required this.name});

  final String id;
  final String name;
}

/// Bottom sheet that creates a class — or edits an existing one — so capacity
/// and the assigned teacher can be set straight from the phone.
class ClassFormSheet extends StatefulWidget {
  const ClassFormSheet(
      {super.key, this.existing, this.knownPrograms = const []});

  final SaiClass? existing;
  final List<String> knownPrograms;

  static Future<bool?> show(BuildContext context,
      {SaiClass? existing, List<String> knownPrograms = const []}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) =>
          ClassFormSheet(existing: existing, knownPrograms: knownPrograms),
    );
  }

  @override
  State<ClassFormSheet> createState() => _ClassFormSheetState();
}

class _ClassFormSheetState extends State<ClassFormSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _program = TextEditingController(
    text: widget.existing == null || widget.existing!.program == 'غير محدد'
        ? ''
        : widget.existing!.program,
  );

  late int _capacity = widget.existing?.capacity ?? 25;
  late bool _isActive = widget.existing?.isActive ?? true;
  String? _branchId;
  String? _sessionId;
  String? _teacherId;
  String? _teacherName;

  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _formError;

  List<_NamedOption> _branches = const [];
  List<_NamedOption> _sessions = const [];
  List<TeacherOption> _teachers = const [];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _branchId = widget.existing?.branchId;
    _sessionId = widget.existing?.sessionId;
    _teacherId = widget.existing?.teacherId;
    _teacherName = widget.existing?.teacherName;
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _program.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final client = Supabase.instance.client;
    try {
      final results = await Future.wait<Object>([
        client
            .from('branches')
            .select('id,name,is_active')
            .eq('is_active', true)
            .order('name'),
        client
            .from('academic_sessions')
            .select('id,name,is_active')
            .order('starts_on', ascending: false),
        loadTeacherDirectory(client),
      ]);

      final branches = (results[0] as List)
          .whereType<Map<String, dynamic>>()
          .map((row) => _NamedOption(
              id: row['id'] as String, name: (row['name'] as String?) ?? 'فرع'))
          .toList();
      final sessions = (results[1] as List)
          .whereType<Map<String, dynamic>>()
          .map((row) => _NamedOption(
              id: row['id'] as String,
              name: (row['name'] as String?) ?? 'فصل دراسي'))
          .toList();
      final teachers = (results[2] as List).cast<TeacherOption>();

      if (!mounted) return;
      setState(() {
        _branches = branches;
        _sessions = sessions;
        _teachers = teachers;
        _branchId ??= branches.isNotEmpty ? branches.first.id : null;
        _sessionId ??= sessions.isNotEmpty ? sessions.first.id : null;
        if (_teacherId != null) {
          for (final teacher in teachers) {
            if (teacher.userId == _teacherId) {
              _teacherName = teacher.displayName;
            }
          }
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError =
            'تعذّر تحميل الفروع والفصول. تحقق من الاتصال ثم أعد المحاولة.\n$error';
      });
    }
  }

  Future<void> _pickTeacher() async {
    if (_teachers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'لا تتوفر قائمة معلمين لهذا الحساب. يمكنك حفظ الصف بدون معلم وتعيينه لاحقاً.')),
      );
      return;
    }
    final selected = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (sheetContext) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final term = query.trim().toLowerCase();
            final filtered = _teachers
                .where((teacher) =>
                    term.isEmpty ||
                    teacher.displayName.toLowerCase().contains(term) ||
                    teacher.email.toLowerCase().contains(term))
                .toList();
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom),
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.62,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                          color: SaiColors.border,
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 6, 4),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text('اختيار معلم الصف',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: SaiColors.ink)),
                          ),
                          Text('${filtered.length} معلم',
                              style: const TextStyle(
                                  fontSize: 10, color: SaiColors.muted)),
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close,
                                size: 18, color: SaiColors.muted),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        onChanged: (value) =>
                            setSheetState(() => query = value),
                        style: const TextStyle(fontSize: 12.5),
                        decoration: const InputDecoration(
                          hintText: 'ابحث باسم المعلم أو بريده',
                          prefixIcon: Icon(Icons.search,
                              size: 18, color: SaiColors.muted),
                          prefixIconConstraints:
                              BoxConstraints(minWidth: 38, minHeight: 38),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: ListView(
                        children: [
                          if (term.isEmpty)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.person_off_outlined,
                                  size: 19, color: SaiColors.muted),
                              title: const Text('بدون معلم',
                                  style: TextStyle(
                                      fontSize: 12.5, color: SaiColors.ink)),
                              onTap: () => Navigator.of(sheetContext).pop(''),
                            ),
                          if (filtered.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 24),
                              child: Text('لا يوجد معلم مطابق لكلمة البحث.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 11.5, color: SaiColors.muted)),
                            )
                          else
                            ...filtered.map((teacher) => ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.person_outline,
                                      size: 19, color: SaiColors.maroon),
                                  title: Text(teacher.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          color: SaiColors.ink)),
                                  subtitle: teacher.email.isEmpty
                                      ? null
                                      : Text(teacher.email,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: SaiColors.muted)),
                                  trailing: _teacherId == teacher.userId
                                      ? const Icon(Icons.check_circle,
                                          size: 17, color: SaiColors.success)
                                      : null,
                                  onTap: () => Navigator.of(sheetContext)
                                      .pop(teacher.userId),
                                )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (selected == null) return;
    setState(() {
      if (selected.isEmpty) {
        _teacherId = null;
        _teacherName = null;
        return;
      }
      _teacherId = selected;
      _teacherName = _teachers
          .firstWhere((teacher) => teacher.userId == selected)
          .displayName;
    });
  }

  String? _validate() {
    if (_name.text.trim().isEmpty) return 'اكتب اسم الصف أولاً.';
    if (_name.text.trim().length > 80) {
      return 'اسم الصف طويل جداً (80 حرفاً كحد أقصى).';
    }
    if (_capacity < 1) return 'السعة يجب أن تكون أكبر من صفر.';
    if (_capacity > 500) return 'السعة القصوى 500 مقعد.';
    if (_branchId == null) return 'اختر الفرع.';
    if (_sessionId == null) return 'اختر الفصل الدراسي.';
    return null;
  }

  Future<void> _save() async {
    final validation = _validate();
    if (validation != null) {
      setState(() => _formError = validation);
      return;
    }
    setState(() {
      _saving = true;
      _formError = null;
    });

    final client = Supabase.instance.client;
    final program = _program.text.trim();
    final payload = <String, dynamic>{
      'branch_id': _branchId,
      'session_id': _sessionId,
      'name': _name.text.trim(),
      'program': program.isEmpty ? 'غير محدد' : program,
      'capacity': _capacity,
      'teacher_id': _teacherId,
      'is_active': _isActive,
    };

    try {
      if (_isEdit) {
        final updated = await client
            .from('classes')
            .update(payload)
            .eq('id', widget.existing!.id)
            .select('id');
        if ((updated as List).isEmpty) {
          throw Exception('لم يتم تحديث الصف. تحقق من صلاحية تعديل هذا الفرع.');
        }
      } else {
        await client.from('classes').insert(payload);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      final raw = error.toString();
      final friendly = raw.toLowerCase().contains('row-level security') ||
              raw.contains('42501')
          ? 'لا تملك صلاحية تعديل صفوف هذا الفرع. تواصل مع إدارة الكلية.'
          : raw.toLowerCase().contains('duplicate')
              ? 'يوجد صف بهذا الاسم في الفرع نفسه.'
              : raw;
      setState(() {
        _saving = false;
        _formError = friendly;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.9,
        child: Column(
          children: [
            _Header(isEdit: _isEdit),
            Expanded(
              child: _loading
                  ? const LoadingState()
                  : _loadError != null
                      ? ErrorState(message: _loadError!, onRetry: _load)
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                          children: [
                            const _FieldLabel('اسم الصف'),
                            TextField(
                              controller: _name,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(fontSize: 13),
                              decoration: const InputDecoration(
                                  hintText: 'مثال: صف HSK 2 — صباحي'),
                            ),
                            const SizedBox(height: 14),
                            const _FieldLabel('البرنامج / المسار'),
                            TextField(
                              controller: _program,
                              style: const TextStyle(fontSize: 13),
                              decoration: const InputDecoration(
                                  hintText: 'مثال: دبلوم اللغة الصينية'),
                            ),
                            if (widget.knownPrograms.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: widget.knownPrograms
                                    .where((program) => program != 'غير محدد')
                                    .take(6)
                                    .map((program) => InkWell(
                                          onTap: () => setState(
                                              () => _program.text = program),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: SaiColors.goldTint,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                  color: SaiColors.gold
                                                      .withValues(alpha: 0.3)),
                                            ),
                                            child: Text(program,
                                                style: const TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: SaiColors.ink)),
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ],
                            const SizedBox(height: 16),
                            const _FieldLabel('السعة (عدد المقاعد)'),
                            _CapacityStepper(
                              value: _capacity,
                              onChanged: (value) => setState(
                                  () => _capacity = value.clamp(1, 500)),
                            ),
                            const SizedBox(height: 16),
                            const _FieldLabel('معلم الصف'),
                            _TapField(
                              icon: Icons.person_outline,
                              text: _teacherName ?? 'بدون معلم',
                              onTap: _pickTeacher,
                              muted: _teacherName == null,
                            ),
                            const SizedBox(height: 16),
                            const _FieldLabel('الفرع'),
                            _OptionDropdown(
                              icon: Icons.apartment_outlined,
                              value: _branchId,
                              options: _branches,
                              hint: 'اختر الفرع',
                              onChanged: (value) =>
                                  setState(() => _branchId = value),
                            ),
                            const SizedBox(height: 16),
                            const _FieldLabel('الفصل الدراسي'),
                            _OptionDropdown(
                              icon: Icons.calendar_month_outlined,
                              value: _sessionId,
                              options: _sessions,
                              hint: 'اختر الفصل الدراسي',
                              onChanged: (value) =>
                                  setState(() => _sessionId = value),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: SaiColors.cream,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: SaiColors.border),
                              ),
                              child: Material(
                                type: MaterialType.transparency,
                                child: SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: _isActive,
                                  title: const Text('صف نشط',
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: SaiColors.ink)),
                                  subtitle: const Text(
                                      'الصفوف غير النشطة تظهر في السجلات لكنها لا تُسند للطلاب الجدد.',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: SaiColors.muted)),
                                  onChanged: (value) =>
                                      setState(() => _isActive = value),
                                ),
                              ),
                            ),
                            if (_formError != null) ...[
                              const SizedBox(height: 14),
                              NoteBanner(
                                  message: _formError!,
                                  color: SaiColors.danger,
                                  tint: SaiColors.dangerTint,
                                  icon: Icons.error_outline),
                            ],
                            const SizedBox(height: 10),
                            const NoteBanner(
                              message:
                                  'الطلاب لا يُضافون من هنا. أنشئ الصف أولاً ثم استخدم «استيراد الطلاب» أو سجل الطالب لإسناده إلى هذا الصف.',
                            ),
                          ],
                        ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: SaiColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _saving || _loading || _loadError != null
                          ? null
                          : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(_isEdit ? 'حفظ التعديلات' : 'إضافة الصف'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isEdit});

  final bool isEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      decoration: const BoxDecoration(
        color: SaiColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(bottom: BorderSide(color: SaiColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: SaiColors.maroon,
                borderRadius: BorderRadius.circular(10)),
            child: Icon(isEdit ? Icons.edit_outlined : Icons.add_home_outlined,
                size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEdit ? 'تعديل بيانات الصف' : 'إضافة صف جديد',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: SaiColors.ink)),
                const Text('السعة والمعلم يمكن ضبطهما من هنا مباشرة',
                    style: TextStyle(fontSize: 10, color: SaiColors.muted)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close, size: 20, color: SaiColors.muted),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: SaiColors.ink)),
      );
}

class _CapacityStepper extends StatelessWidget {
  const _CapacityStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SaiColors.border),
      ),
      child: Row(
        children: [
          _StepButton(icon: Icons.remove, onTap: () => onChanged(value - 1)),
          Expanded(
            child: Column(
              children: [
                Text('$value',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: SaiColors.ink)),
                const Text('مقعد',
                    style: TextStyle(fontSize: 9.5, color: SaiColors.muted)),
              ],
            ),
          ),
          _StepButton(icon: Icons.add, onTap: () => onChanged(value + 1)),
          const SizedBox(width: 6),
          Wrap(
            spacing: 5,
            children: [15, 20, 25, 30]
                .map((seat) => InkWell(
                      onTap: () => onChanged(seat),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: value == seat
                              ? SaiColors.maroonTint
                              : SaiColors.cream,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: value == seat
                                  ? SaiColors.maroon.withValues(alpha: 0.35)
                                  : SaiColors.border),
                        ),
                        child: Text('$seat',
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: value == seat
                                    ? SaiColors.maroon
                                    : SaiColors.muted)),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
            color: SaiColors.cream,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: SaiColors.border)),
        child: Icon(icon, size: 18, color: SaiColors.maroon),
      ),
    );
  }
}

class _TapField extends StatelessWidget {
  const _TapField(
      {required this.icon,
      required this.text,
      required this.onTap,
      this.muted = false});

  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SaiColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: SaiColors.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12.5,
                    color: muted ? SaiColors.muted : SaiColors.ink,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.expand_more, size: 18, color: SaiColors.muted),
          ],
        ),
      ),
    );
  }
}

class _OptionDropdown extends StatelessWidget {
  const _OptionDropdown({
    required this.icon,
    required this.value,
    required this.options,
    required this.hint,
    required this.onChanged,
  });

  final IconData icon;
  final String? value;
  final List<_NamedOption> options;
  final String hint;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final exists = options.any((option) => option.id == value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SaiColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: SaiColors.muted),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: exists ? value : null,
                isExpanded: true,
                hint: Text(hint,
                    style: const TextStyle(
                        fontSize: 12.5, color: SaiColors.muted)),
                icon: const Icon(Icons.expand_more,
                    size: 18, color: SaiColors.muted),
                style: const TextStyle(
                    fontSize: 12.5,
                    fontFamily: 'Cairo',
                    color: SaiColors.ink,
                    fontWeight: FontWeight.w600),
                items: options
                    .map((option) => DropdownMenuItem(
                        value: option.id,
                        child:
                            Text(option.name, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
