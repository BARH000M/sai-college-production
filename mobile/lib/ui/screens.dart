import 'package:flutter/material.dart';

import '../core/access.dart';
import '../core/branding.dart';
import '../data/curriculum.dart';
import '../data/demo_school.dart';
import '../data/demo_workspace.dart';
import '../data/repository.dart';
import 'class_screens.dart';
import 'components.dart';
import 'learning_screens.dart';
import 'printing.dart';
import 'records_screen.dart';

const features = <PageId, (String, IconData)>{
  PageId.home: ('الرئيسية', Icons.home_rounded),
  PageId.systems: ('أنظمة الكلية', Icons.grid_view_rounded),
  PageId.learning: ('تعلم اللغة الصينية', Icons.translate_rounded),
  PageId.courses: ('المقررات والدروس', Icons.menu_book_rounded),
  PageId.classes: ('الصفوف', Icons.groups_rounded),
  PageId.lesson: ('تفاصيل الدرس', Icons.play_lesson_outlined),
  PageId.profile: ('الملف الشخصي', Icons.person_outline_rounded),
  PageId.notifications: ('الإشعارات', Icons.notifications_outlined),
  PageId.admissions: ('القبول والتسجيل', Icons.how_to_reg_rounded),
  PageId.staff: ('شؤون الموظفين', Icons.badge_outlined),
  PageId.finance: ('الرسوم والمالية', Icons.receipt_long_outlined),
  PageId.library: ('المكتبة الرقمية', Icons.local_library_outlined),
  PageId.exams: ('الاختبارات والنتائج', Icons.assessment_outlined),
  PageId.reports: ('التقارير والإحصاءات', Icons.bar_chart_rounded),
  PageId.attendance: ('الحضور والغياب', Icons.fact_check_outlined),
  PageId.schedule: ('الجدول الدراسي', Icons.calendar_month_outlined),
  PageId.assignments: ('الواجبات', Icons.assignment_outlined),
  PageId.content: ('استوديو المحتوى', Icons.edit_document),
  PageId.users: ('إدارة الحسابات', Icons.admin_panel_settings_outlined),
};

const _favoritePages = <Role, List<PageId>>{
  Role.super_admin: [
    PageId.courses,
    PageId.classes,
    PageId.users,
    PageId.reports,
  ],
  Role.admin: [PageId.courses, PageId.classes, PageId.staff, PageId.reports],
  Role.teacher: [
    PageId.classes,
    PageId.attendance,
    PageId.assignments,
    PageId.exams,
  ],
  Role.accountant: [PageId.finance, PageId.reports],
  Role.receptionist: [PageId.admissions, PageId.classes],
  Role.librarian: [PageId.library, PageId.systems],
  Role.student: [
    PageId.courses,
    PageId.classes,
    PageId.assignments,
    PageId.schedule,
  ],
  Role.parent: [
    PageId.schedule,
    PageId.attendance,
    PageId.exams,
    PageId.finance,
  ],
  Role.content_editor: [PageId.content, PageId.courses],
};

class CollegeShell extends StatefulWidget {
  const CollegeShell({
    super.key,
    required this.account,
    required this.onSignOut,
    this.demo,
  });
  final Account account;
  final Future<void> Function() onSignOut;
  final DemoWorkspace? demo;

  @override
  State<CollegeShell> createState() => _CollegeShellState();
}

class _CollegeShellState extends State<CollegeShell> {
  PageId page = PageId.home;
  final scaffold = GlobalKey<ScaffoldState>();
  bool working = false;
  Set<Role> get roles => widget.account.roles;
  DemoWorkspace? get demo => widget.demo;
  bool can(PageId target) => Access.allows(roles, target);
  String get learnerId =>
      roles.contains(Role.student) || roles.contains(Role.parent)
      ? DemoSchool.studentId
      : (demo?.role.name ?? '');
  LearningContext get learning => (demo: demo, learnerId: learnerId);
  List<PageId> get favorites => <PageId>{
    for (final role in Role.values)
      if (roles.contains(role)) ..._favoritePages[role]!,
  }.where(can).toList();

  void go(PageId target) {
    if (can(target)) setState(() => page = target);
  }

  Future<void> _changeRole(Role role) => _do(() => demo!.selectRole(role));

  Future<void> _do(Future<void> Function() operation) async {
    if (working) return;
    setState(() => working = true);
    try {
      await operation();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إتمام العملية. حاول مجدداً.')),
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 850;
    final tabs = [
      PageId.home,
      ...favorites.take(2),
      PageId.notifications,
      PageId.profile,
    ];
    final selected = tabs.indexOf(page);
    return Scaffold(
      key: scaffold,
      drawer: drawer(),
      body: BrandBody(
        child: Column(
          children: [
            SaiHeader(
              height: demo == null ? 99 : 142,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 21),
                child: Column(
                  children: [
                    if (demo != null) _previewBar(),
                    Expanded(
                      child: Row(
                        children: [
                          IconButton(
                            color: Colors.white,
                            tooltip: 'القائمة',
                            onPressed: () =>
                                scaffold.currentState!.openDrawer(),
                            icon: const Icon(Icons.menu),
                          ),
                          Expanded(
                            child: Text(
                              page == PageId.home
                                  ? 'مرحباً بك\n${widget.account.name}'
                                  : features[page]!.$1,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          IconButton(
                            color: Colors.white,
                            tooltip: page == PageId.home
                                ? 'عرض الإشعارات'
                                : 'العودة للرئيسية',
                            onPressed: () => go(
                              page == PageId.home
                                  ? PageId.notifications
                                  : PageId.home,
                            ),
                            icon: Icon(
                              page == PageId.home
                                  ? Icons.notifications_outlined
                                  : Icons.arrow_forward,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  if (wide)
                    NavigationRail(
                      selectedIndex: selected < 0 ? null : selected,
                      onDestinationSelected: (index) => go(tabs[index]),
                      labelType: NavigationRailLabelType.all,
                      destinations: [
                        for (final tab in tabs)
                          NavigationRailDestination(
                            icon: Icon(features[tab]!.$2),
                            label: Text(_tabName(tab)),
                          ),
                      ],
                    ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: pageBody(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              height: 68,
              backgroundColor: const Color(0xFFFFFCF9),
              indicatorColor: const Color(0xFFF9E2DD),
              selectedIndex: selected < 0 ? 0 : selected,
              onDestinationSelected: (index) => go(tabs[index]),
              destinations: [
                for (final tab in tabs)
                  NavigationDestination(
                    icon: Icon(features[tab]!.$2, size: 21),
                    label: _tabName(tab),
                  ),
              ],
            ),
    );
  }

  String _tabName(PageId tab) => switch (tab) {
    PageId.courses => 'المقررات',
    PageId.profile => 'حسابي',
    PageId.admissions => 'التسجيل',
    PageId.finance => 'المالية',
    PageId.reports => 'التقارير',
    PageId.content => 'المحتوى',
    PageId.schedule => 'الجدول',
    PageId.attendance => 'الحضور',
    PageId.library => 'المكتبة',
    PageId.systems => 'الأنظمة',
    _ => features[tab]!.$1,
  };

  Widget _previewBar() => SizedBox(
    height: 42,
    child: Row(
      children: [
        const Expanded(
          child: Padding(
            padding: EdgeInsetsDirectional.only(start: 10),
            child: Text(
              'معاينة • بيانات توضيحية',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFFFFE8E2),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        PopupMenuButton<Role>(
          tooltip: 'تبديل حساب المعاينة',
          enabled: !working,
          onSelected: _changeRole,
          itemBuilder: (_) => [
            for (final role in Role.values)
              PopupMenuItem(value: role, child: Text(roleLabels[role]!)),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  roleLabels[demo!.role]!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Icon(Icons.expand_more, color: Colors.white, size: 17),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget drawer() => Drawer(
    width: 320,
    backgroundColor: cream,
    child: BrandBody(
      child: Column(
        children: [
          const SaiHeader(height: 173, child: Center(child: Brand())),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              widget.account.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom + 8,
              ),
              children: [
                for (final target in [
                  PageId.profile,
                  PageId.systems,
                  ...favorites.where((target) => target != PageId.systems),
                ])
                  if (can(target))
                    ListTile(
                      leading: Icon(features[target]!.$2, color: red),
                      title: Text(features[target]!.$1),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () {
                        Navigator.pop(context);
                        go(target);
                      },
                    ),
                ListTile(
                  leading: const Icon(Icons.support_agent, color: red),
                  title: const Text('الدعم والمساعدة'),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (dialog) => AlertDialog(
                      title: const Text('تواصل مع الكلية'),
                      content: const Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(collegeArabic),
                          SizedBox(height: 10),
                          Text(
                            collegeWebsite,
                            textDirection: TextDirection.ltr,
                          ),
                          Text(collegeEmail, textDirection: TextDirection.ltr),
                          Text(collegePhone, textDirection: TextDirection.ltr),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialog),
                          child: const Text('إغلاق'),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: red),
                  title: const Text(
                    'تسجيل الخروج',
                    style: TextStyle(
                      color: darkRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: working
                      ? null
                      : () {
                          Navigator.pop(context);
                          _do(widget.onSignOut);
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget pageBody() {
    if (!can(page)) return const EmptyPanel('لا تملك صلاحية الوصول.');
    return switch (page) {
      PageId.home => home(),
      PageId.systems => systems(),
      PageId.learning => learningHome(),
      PageId.courses || PageId.lesson => CourseCatalog(learning: learning),
      PageId.classes => ClassesScreen(
        key: const ValueKey(PageId.classes),
        roles: roles,
        demo: demo,
      ),
      PageId.attendance when demo != null => ClassesScreen(
        key: const ValueKey(PageId.attendance),
        roles: roles,
        demo: demo,
        attendance: true,
      ),
      PageId.profile => profile(),
      _ =>
        demo == null
            ? list([
                const EmptyPanel(
                  'لا توجد بيانات متصلة لهذه الوحدة حالياً. يمكنك تجربة وظائفها من نسخة المعاينة.',
                ),
              ])
            : RecordsScreen(
                key: ValueKey(page),
                page: page,
                title: features[page]!.$1,
                icon: features[page]!.$2,
                roles: roles,
                demo: demo!,
              ),
    };
  }

  Widget list(List<Widget> children) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
    children: children,
  );

  int get completed => demo == null
      ? 0
      : courses
            .expand((course) => course.lessons)
            .where((lesson) => demo!.completed(learnerId, lesson.id))
            .length;
  int get lessonCount =>
      courses.fold(0, (total, course) => total + course.lessons.length);

  Widget home() => list([
    ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: const ReferenceArt(rect: ReferenceArt.campus, height: 140),
    ),
    const SizedBox(height: 12),
    if (demo != null && DemoSchool.administrator(roles))
      SaiCard(
        child: Row(
          children: [
            Expanded(
              child: _metric(
                '${DemoSchool.students.length}',
                'طلاب',
                Icons.people_outline,
              ),
            ),
            Expanded(
              child: _metric(
                '${DemoSchool.classes.length}',
                'صفوف',
                Icons.groups_outlined,
              ),
            ),
            Expanded(
              child: _metric('$lessonCount', 'دروس', Icons.menu_book_outlined),
            ),
          ],
        ),
      ),
    if (demo != null &&
        (roles.contains(Role.student) || roles.contains(Role.parent)))
      ProgressCard(
        value: completed / lessonCount,
        subtitle: '$completed من $lessonCount درساً',
      ),
    const SectionHeading('أدوات حسابك'),
    for (final target in favorites.where((target) => target != PageId.systems))
      Tile(features[target]!.$1, features[target]!.$2, onTap: () => go(target)),
    Tile(
      'أنظمة الكلية',
      Icons.grid_view_rounded,
      onTap: () => go(PageId.systems),
    ),
    if (can(PageId.learning))
      Tile(
        'تعلم اللغة الصينية',
        Icons.translate_rounded,
        onTap: () => go(PageId.learning),
      ),
  ]);

  Widget _metric(String count, String label, IconData icon) => Column(
    children: [
      Icon(icon, color: darkRed, size: 25),
      Text(
        count,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
      Text(label),
    ],
  );

  Widget systems() => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 640
          ? 4
          : (constraints.maxWidth >= 400 ? 3 : 2);
      final cardWidth =
          (constraints.maxWidth - 28 - 9 * (columns - 1)) / columns;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 9,
          runSpacing: 2,
          children: [
            for (final target in features.keys)
              if (![
                    PageId.home,
                    PageId.systems,
                    PageId.lesson,
                    PageId.profile,
                    PageId.notifications,
                  ].contains(target) &&
                  can(target))
                SizedBox(
                  width: cardWidth,
                  child: SaiCard(
                    padding: 10,
                    onTap: () => go(target),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        Icon(features[target]!.$2, color: darkRed, size: 31),
                        const SizedBox(height: 7),
                        Text(
                          features[target]!.$1,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      );
    },
  );

  Widget learningHome() => list([
    ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: const ReferenceArt(rect: ReferenceArt.temple, height: 146),
    ),
    const SizedBox(height: 12),
    const SectionHeading('تدرّب بالصينية'),
    for (final item in [
      ('القراءة والمفردات', Icons.menu_book_outlined, 0),
      ('الاستماع والتحدث', Icons.headphones_outlined, 1),
      ('الكتابة', Icons.draw_outlined, 2),
      ('مراجعة سريعة', Icons.quiz_outlined, 3),
    ])
      Tile(
        item.$1,
        item.$2,
        onTap: () => openLesson(
          context,
          courses.first.lessons.first,
          learning,
          initialTab: item.$3,
        ),
      ),
    if (demo != null)
      ProgressCard(
        value: completed / lessonCount,
        subtitle: '$completed من $lessonCount درساً',
      ),
    RedButton('استعرض جميع المقررات', onPressed: () => go(PageId.courses)),
  ]);

  Widget profile() {
    final details = [
      ['الاسم', widget.account.name],
      if (widget.account.email.isNotEmpty)
        ['البريد الإلكتروني', widget.account.email],
      ['الدور', roles.map((role) => roleLabels[role]!).join(' • ')],
      if (demo != null && roles.contains(Role.student))
        ['رقم القيد', DemoSchool.studentNumber],
      if (demo != null && roles.contains(Role.parent))
        ['الطالب المرتبط', DemoSchool.studentName],
      if (demo != null &&
          (roles.contains(Role.student) || roles.contains(Role.parent)))
        ['الدروس المكتملة', '$completed من $lessonCount'],
    ];
    return list([
      SectionHeading(
        'بيانات الحساب',
        action: PrintAction(
          CollegeReport(
            title: 'بيانات الحساب',
            preview: demo != null,
            columns: const [
              PrintColumn('البيان', flex: 1.3),
              PrintColumn('التفاصيل', flex: 3),
            ],
            rows: details,
          ),
        ),
      ),
      const Center(
        child: CircleAvatar(
          radius: 34,
          backgroundColor: Color(0xFFF9DED6),
          child: Icon(Icons.person_outline, color: darkRed, size: 38),
        ),
      ),
      const SizedBox(height: 12),
      for (final row in details)
        Tile(row[0], Icons.account_circle_outlined, subtitle: row[1]),
      if (demo != null &&
          (roles.contains(Role.student) || roles.contains(Role.parent)))
        ProgressCard(
          value: completed / lessonCount,
          subtitle: '$completed من $lessonCount درساً',
        ),
    ]);
  }
}
