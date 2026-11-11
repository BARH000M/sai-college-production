import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/access.dart';
import '../data/repository.dart';
import 'components.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onPreview});
  final VoidCallback? onPreview;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController(), password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false, hidden = true;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> signIn() async {
    if (widget.onPreview != null) {
      widget.onPreview!();
      return;
    }
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email.text.trim(),
        password: password.text,
      );
    } on AuthException catch (_) {
      if (mounted) {
        setState(
          () => error = 'تعذر تسجيل الدخول. تحقق من البريد وكلمة المرور.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'تعذر الاتصال. تحقق من الإنترنت وحاول مجدداً.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> reset() async {
    if (email.text.trim().isEmpty) {
      setState(() => error = 'أدخل بريدك الإلكتروني أولاً.');
      return;
    }
    if (previewMode) {
      setState(
        () => error = 'استعادة كلمة المرور متاحة في وضع الاتصال الحقيقي.',
      );
      return;
    }
    setState(() => busy = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email.text.trim(),
      );
      if (mounted) {
        setState(() => error = 'إذا كان البريد مسجلاً فستصلك رسالة الاستعادة.');
      }
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر إرسال الرسالة. حاول لاحقاً.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SaiHeader(height: 190, child: Center(child: Brand())),
                const ReferenceArt(rect: ReferenceArt.campus, height: 155),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Transform.translate(
                    offset: const Offset(0, -20),
                    child: SaiCard(
                      padding: 20,
                      child: Form(
                        key: form,
                        child: Column(
                          children: [
                            const Text(
                              'تسجيل الدخول',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: darkRed,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: email,
                              keyboardType: TextInputType.emailAddress,
                              textDirection: TextDirection.ltr,
                              autofillHints: const [AutofillHints.username],
                              decoration: const InputDecoration(
                                hintText: 'البريد الإلكتروني',
                                prefixIcon: Icon(Icons.mail_outline),
                              ),
                              validator: (v) => v != null && v.contains('@')
                                  ? null
                                  : 'أدخل بريداً صحيحاً',
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: password,
                              obscureText: hidden,
                              autofillHints: const [AutofillHints.password],
                              decoration: InputDecoration(
                                hintText: 'كلمة المرور',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: 'إظهار كلمة المرور',
                                  onPressed: () =>
                                      setState(() => hidden = !hidden),
                                  icon: Icon(
                                    hidden
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (v) => v != null && v.isNotEmpty
                                  ? null
                                  : 'أدخل كلمة المرور',
                              onFieldSubmitted: (_) => busy ? null : signIn(),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: busy ? null : reset,
                                child: const Text('نسيت كلمة المرور؟'),
                              ),
                            ),
                            if (error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  error!,
                                  style: const TextStyle(color: red),
                                ),
                              ),
                            RedButton(
                              busy
                                  ? 'جارٍ الاتصال…'
                                  : previewMode
                                  ? 'معاينة التصميم'
                                  : 'دخول إلى النظام',
                              onPressed: busy ? null : signIn,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              previewMode
                                  ? 'معاينة فقط • جميع البيانات توضيحية'
                                  : 'تسجيل دخول آمن • كلية ساي',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

const pageTitles = <PageId, String>{
  PageId.home: 'الرئيسية',
  PageId.systems: 'أنظمة الكلية',
  PageId.learning: 'تعلم اللغة الصينية',
  PageId.courses: 'المقررات والدروس',
  PageId.classes: 'الصفوف',
  PageId.lesson: 'تفاصيل الدرس',
  PageId.profile: 'ملف الطالب',
  PageId.notifications: 'الإشعارات',
  PageId.admissions: 'القبول والتسجيل',
  PageId.staff: 'شؤون الموظفين',
  PageId.finance: 'الرسوم والمالية',
  PageId.library: 'المكتبة الرقمية',
  PageId.exams: 'الاختبارات والتقييم',
  PageId.reports: 'التقارير والإحصائيات',
};

class CollegeShell extends StatefulWidget {
  const CollegeShell({
    super.key,
    required this.account,
    required this.onSignOut,
  });
  final Account account;
  final VoidCallback onSignOut;
  @override
  State<CollegeShell> createState() => _CollegeShellState();
}

class _CollegeShellState extends State<CollegeShell> {
  PageId page = PageId.home;
  late Set<Role> roles = widget.account.roles;
  final scaffold = GlobalKey<ScaffoldState>();
  void go(PageId target) {
    if (Access.allows(roles, target)) setState(() => page = target);
  }

  void info(String title, String message) => showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('إغلاق'),
        ),
      ],
    ),
  );
  List<PageId> get tabs => [
    PageId.home,
    PageId.courses,
    PageId.classes,
    PageId.notifications,
    PageId.profile,
  ].where((p) => Access.allows(roles, p)).toList();
  IconData icon(PageId p) => switch (p) {
    PageId.home => Icons.home,
    PageId.courses => Icons.menu_book_outlined,
    PageId.classes => Icons.groups_outlined,
    PageId.notifications => Icons.notifications_outlined,
    PageId.profile => Icons.person_outline,
    _ => Icons.grid_view,
  };
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 850;
    final selected = tabs.indexOf(page);
    return Scaffold(
      key: scaffold,
      drawer: drawer(),
      body: SafeArea(
        child: Column(
          children: [
            if (previewMode)
              Container(
                width: double.infinity,
                color: const Color(0xFFFFE8AF),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'معاينة • بيانات توضيحية',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                    DropdownButton<Role>(
                      value: roles.first,
                      items: Role.values
                          .map(
                            (r) => DropdownMenuItem(
                              value: r,
                              child: Text(
                                r.name,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (r) {
                        if (r != null) {
                          setState(() {
                            roles = {r};
                            page = PageId.home;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            SaiHeader(
              height: 100,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 25),
                child: Row(
                  children: [
                    IconButton(
                      color: Colors.white,
                      tooltip: 'القائمة',
                      onPressed: () => scaffold.currentState!.openDrawer(),
                      icon: const Icon(Icons.menu),
                    ),
                    Expanded(
                      child: Text(
                        page == PageId.home
                            ? 'مرحباً بك\n${widget.account.name}'
                            : pageTitles[page]!,
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
                      tooltip: page == PageId.home ? 'الإشعارات' : 'العودة',
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
            ),
            Expanded(
              child: Row(
                children: [
                  if (wide)
                    NavigationRail(
                      selectedIndex: selected < 0 ? 0 : selected,
                      onDestinationSelected: (i) => go(tabs[i]),
                      labelType: NavigationRailLabelType.all,
                      destinations: tabs
                          .map(
                            (p) => NavigationRailDestination(
                              icon: Icon(icon(p)),
                              label: Text(pageTitles[p]!),
                            ),
                          )
                          .toList(),
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
              height: 72,
              backgroundColor: const Color(0xFFFFFCF9),
              indicatorColor: const Color(0xFFFFE5D8),
              selectedIndex: selected < 0 ? 0 : selected,
              onDestinationSelected: (i) => go(tabs[i]),
              destinations: tabs
                  .map(
                    (p) => NavigationDestination(
                      icon: Icon(icon(p), size: 23),
                      label: pageTitles[p]!,
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget drawer() => Drawer(
    width: 330,
    backgroundColor: cream,
    child: SafeArea(
      child: Column(
        children: [
          const SaiHeader(height: 180, child: Center(child: Brand())),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.account.name,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final p in [
                  PageId.profile,
                  PageId.systems,
                  PageId.learning,
                ])
                  if (Access.allows(roles, p))
                    ListTile(
                      leading: Icon(icon(p), color: red),
                      title: Text(pageTitles[p]!),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () {
                        Navigator.pop(context);
                        go(p);
                      },
                    ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined, color: red),
                  title: const Text('الإعدادات'),
                  onTap: () => info(
                    'الإعدادات',
                    'اللغة: العربية\nالمظهر: أحمر وذهبي\nالجلسة محفوظة على هذا الجهاز حتى تسجيل الخروج.',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.support_agent, color: red),
                  title: const Text('الدعم والمساعدة'),
                  onTap: () => info(
                    'الدعم والمساعدة',
                    'تواصل مع إدارة كلية ساي للمساعدة في الحساب والتسجيل.',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: red),
                  title: const Text('عن الكلية'),
                  onTap: () => info(
                    'كلية ساي',
                    'كلية ساي التعليمية اليمنية الصينية\n也门赛艾教育学院\nصنعاء — حدة',
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: red),
                  title: const Text(
                    'تسجيل الخروج',
                    style: TextStyle(color: red, fontWeight: FontWeight.bold),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    widget.onSignOut();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget list(List<Widget> children) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
    children: children,
  );
  Widget pageBody() {
    if (!Access.allows(roles, page)) {
      return const EmptyPanel('لا تملك صلاحية الوصول.');
    }
    return switch (page) {
      PageId.home => list([
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: const ReferenceArt(rect: ReferenceArt.campus, height: 145),
        ),
        const SizedBox(height: 12),
        if (roles.contains(Role.admin) || roles.contains(Role.super_admin))
          Row(
            children: [
              Expanded(
                child: Tile(
                  previewMode ? '542' : '—',
                  Icons.people_outline,
                  subtitle: 'إجمالي الطلاب',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Tile(
                  previewMode ? '28' : '—',
                  Icons.layers_outlined,
                  subtitle: 'إجمالي الصفوف',
                ),
              ),
            ],
          ),
        const Text(
          'هذا الأسبوع',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final pair in [('اختبار', '1'), ('واجبات', '2'), ('حصص', '3')])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: SaiCard(
                    padding: 10,
                    child: Column(
                      children: [
                        Text(
                          previewMode ? pair.$2 : '—',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(pair.$1),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        ProgressCard(value: previewMode ? 0.72 : null),
        Tile('أنظمة الكلية', Icons.grid_view, onTap: () => go(PageId.systems)),
        if (Access.allows(roles, PageId.learning))
          Tile(
            'تعلم اللغة الصينية',
            Icons.school_outlined,
            onTap: () => go(PageId.learning),
          ),
        if (!previewMode)
          const EmptyPanel(
            'المؤشرات والتقدم تحتاج ربط مصادر البيانات المعتمدة. لا تُعرض أرقام تجريبية في الوضع الحقيقي.',
          ),
      ]),
      PageId.systems => systems(),
      PageId.learning => learning(),
      PageId.courses => courses(),
      PageId.classes => ClassesScreen(preview: previewMode),
      PageId.lesson => LessonScreen(preview: previewMode),
      PageId.profile => list([
        const CircleAvatar(
          radius: 38,
          backgroundColor: Color(0xFFFFE7BC),
          child: Icon(Icons.person, size: 52, color: darkRed),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            widget.account.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        Center(
          child: Text(
            previewMode ? 'SAI-2026-007 • Grade 10 - B' : widget.account.email,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: roles
              .map(
                (r) => Chip(
                  label: Text(r.name),
                  backgroundColor: const Color(0xFFFFE3A3),
                ),
              )
              .toList(),
        ),
        ProgressCard(value: previewMode ? 0.72 : null),
        if (previewMode)
          SaiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'مستوى الأداء',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(
                  height: 130,
                  width: double.infinity,
                  child: CustomPaint(painter: PerformancePainter()),
                ),
                const Text(
                  'سبتمبر       أكتوبر       نوفمبر       ديسمبر',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
      ]),
      PageId.notifications => const NotificationsScreen(),
      _ => list([
        EmptyPanel(
          '${pageTitles[page]}\nتم تجهيز نقطة التنقل. يلزم ربط عمليات هذه الوحدة بالواجهات المعتمدة في النظام.',
        ),
      ]),
    };
  }

  Widget systems() {
    const entries = [
      (PageId.courses, Icons.menu_book_outlined),
      (PageId.learning, Icons.school_outlined),
      (PageId.admissions, Icons.person_add_alt),
      (PageId.classes, Icons.layers_outlined),
      (PageId.finance, Icons.account_balance_outlined),
      (PageId.staff, Icons.groups_outlined),
      (PageId.reports, Icons.bar_chart),
      (PageId.library, Icons.local_library_outlined),
      (PageId.exams, Icons.assignment_outlined),
    ];
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 10,
          runSpacing: 4,
          children: [
            for (final e in entries)
              if (Access.allows(roles, e.$1))
                SizedBox(
                  width:
                      (c.maxWidth -
                          28 -
                          10 * ((c.maxWidth > 650 ? 4 : 3) - 1)) /
                      (c.maxWidth > 650 ? 4 : 3),
                  child: SaiCard(
                    padding: 8,
                    onTap: () => go(e.$1),
                    child: Column(
                      children: [
                        const SizedBox(height: 14),
                        Icon(e.$2, size: 36, color: red),
                        const SizedBox(height: 10),
                        Text(
                          pageTitles[e.$1]!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget learning() => list([
    ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          const ReferenceArt(rect: ReferenceArt.temple, height: 180),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: cream.withValues(alpha: .9),
              padding: const EdgeInsets.all(12),
              child: const Text(
                'تعلم · تدرب · أتقن',
                style: TextStyle(
                  color: darkRed,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 12),
    Wrap(
      alignment: WrapAlignment.spaceEvenly,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in [
          ('الاستماع', Icons.headphones),
          ('القراءة', Icons.menu_book),
          ('التحدث', Icons.mic_none),
          ('الكتابة', Icons.edit_outlined),
        ])
          ActionChip(
            avatar: Icon(e.$2, color: red),
            label: Text(e.$1),
            onPressed: () => go(PageId.lesson),
          ),
      ],
    ),
    const SizedBox(height: 16),
    ProgressCard(value: previewMode ? 0.72 : null, title: 'مستواي الحالي'),
    RedButton('متابعة التعلم', onPressed: () => go(PageId.courses)),
    const SizedBox(height: 16),
    Tile(
      'المفردات والقواعد والمراجعة',
      Icons.translate,
      onTap: () => go(PageId.lesson),
    ),
  ]);
  Widget courses() => list([
    if (!previewMode)
      const EmptyPanel(
        'لم يتم ربط جدول المقررات والدروس بعد. بيانات الصفوف والحساب متصلة بشكل مستقل.',
      )
    else ...[
      const Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          'المقررات المتاحة • معاينة',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      for (final e in [
        ('P0', 'المستوى التمهيدي', 'الأساسيات والتعرف على اللغة'),
        ('A0', 'المستوى الأساسي', 'المفردات والجمل الأساسية'),
        ('SAI1', 'المستوى SAI1', 'محادثة يومية ومفردات شائعة'),
        ('SAI2', 'المستوى SAI2', 'قواعد وتطبيقات عملية'),
      ])
        SaiCard(
          onTap: () => go(PageId.lesson),
          padding: 10,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 64,
                  child: const ReferenceArt(
                    rect: ReferenceArt.temple,
                    height: 64,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.$2,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(e.$3, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              Chip(label: Text(e.$1)),
              const Icon(Icons.chevron_left),
            ],
          ),
        ),
    ],
  ]);
}

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key, required this.preview});
  final bool preview;
  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  late Future<List<Map<String, dynamic>>> future = loadClasses();
  Future<List<Map<String, dynamic>>> loadClasses() async => widget.preview
      ? [
          {
            'id': 'demo',
            'name': 'Grade 10 - B',
            'program': 'Chinese Language and Translation',
            'capacity': 28,
          },
        ]
      : await Repository().classes();
  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: EmptyPanel(
                'تعذر تحميل الصفوف. تحقق من الاتصال وصلاحيات الحساب.',
                retry: () => setState(() => future = loadClasses()),
              ),
            );
          }
          if (s.data!.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: EmptyPanel('لا توجد صفوف متاحة لحسابك.'),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final row in s.data!)
                Tile(
                  row['name'] as String,
                  Icons.school_outlined,
                  subtitle: row['program'] as String,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          RosterScreen(row: row, preview: widget.preview),
                    ),
                  ),
                ),
            ],
          );
        },
      );
}

class RosterScreen extends StatefulWidget {
  const RosterScreen({super.key, required this.row, required this.preview});
  final Map<String, dynamic> row;
  final bool preview;
  @override
  State<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends State<RosterScreen> {
  final selected = <String>{'a', 'c'};
  late Future<List<Map<String, dynamic>>> future = load();
  Future<List<Map<String, dynamic>>> load() async => widget.preview
      ? [
          {
            'id': 'a',
            'full_name': 'خالد فيصل اليافعي',
            'admission_no': 'SAI-2026-007',
          },
          {
            'id': 'b',
            'full_name': 'ليلى محمد العمري',
            'admission_no': 'SAI-2026-006',
          },
          {
            'id': 'c',
            'full_name': 'عمر حسن الصبري',
            'admission_no': 'SAI-2026-005',
          },
        ]
      : await Repository().students(widget.row['id'] as String);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: darkRed,
      foregroundColor: Colors.white,
      title: Text(
        'كشف طلاب الصف\n${widget.row['name']}',
        style: const TextStyle(fontSize: 17),
      ),
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) {
          return EmptyPanel(
            'تعذر تحميل طلاب الصف.',
            retry: () => setState(() => future = load()),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SaiCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.row['program'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  const Divider(),
                  Text('الصف: ${widget.row['name']}'),
                  Text('الطاقة الاستيعابية: ${widget.row['capacity']}'),
                  Text('عدد الطلاب المتاحين لحسابك: ${s.data!.length}'),
                ],
              ),
            ),
            if (widget.preview)
              const Text('تحديد الحضور للمعاينة فقط • لا يتم حفظه'),
            if (s.data!.isEmpty)
              const EmptyPanel('لا يوجد طلاب متاحون في هذا الصف.'),
            SaiCard(
              padding: 0,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    const Color(0xFFF3E2C6),
                  ),
                  columns: [
                    const DataColumn(label: Text('اسم الطالب')),
                    const DataColumn(label: Text('رقم القيد')),
                    if (widget.preview) const DataColumn(label: Text('الحضور')),
                  ],
                  rows: s.data!
                      .map(
                        (r) => DataRow(
                          cells: [
                            DataCell(Text(r['full_name'] as String)),
                            DataCell(Text(r['admission_no'] as String)),
                            if (widget.preview)
                              DataCell(
                                Checkbox(
                                  value: selected.contains(r['id']),
                                  onChanged: (v) => setState(() {
                                    if (v == true) {
                                      selected.add(r['id'] as String);
                                    } else {
                                      selected.remove(r['id']);
                                    }
                                  }),
                                ),
                              ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            if (widget.preview)
              Wrap(
                spacing: 10,
                children: [
                  Chip(label: Text('المسجلون: ${s.data!.length}')),
                  Chip(label: Text('الحاضرون: ${selected.length}')),
                  Chip(
                    label: Text(
                      'الغائبون: ${s.data!.length - selected.length}',
                    ),
                  ),
                ],
              ),
            if (!widget.preview)
              const EmptyPanel(
                'الكشف للقراءة فقط. إدخال الحضور يحتاج اعتماد واجهة الحضور وسياساتها.',
              ),
          ],
        );
      },
    ),
  );
}

class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.preview});
  final bool preview;
  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  int tab = 0;
  String? answer;
  bool reveal = false;
  @override
  Widget build(BuildContext context) {
    if (!widget.preview) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: EmptyPanel(
          'لم يتم ربط محتوى الدروس أو ملفات الصوت والفيديو بعد.',
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              const ReferenceArt(rect: ReferenceArt.wall, height: 190),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'SAI2 • الدرس 05',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: cream.withValues(alpha: .92),
                  padding: const EdgeInsets.all(10),
                  child: const Column(
                    children: [
                      Text(
                        '介绍我的家人',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('التعريف بأفراد أسرتي'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('التعلم')),
            ButtonSegment(value: 1, label: Text('التدريبات')),
            ButtonSegment(value: 2, label: Text('المصادر')),
          ],
          selected: {tab},
          onSelectionChanged: (s) => setState(() => tab = s.first),
        ),
        const SizedBox(height: 16),
        if (tab == 0) ...[
          Tile(
            'شاهد الفيديو التعليمي',
            Icons.play_circle_outline,
            subtitle: 'ملف الفيديو غير مرفق',
            onTap: () => message('أضف رابط فيديو معتمداً لتمكين التشغيل.'),
          ),
          Tile(
            'استمع إلى الحوار',
            Icons.headphones,
            subtitle: 'ملف الصوت غير مرفق',
            onTap: () => message('أضف ملف الحوار الصوتي لتمكين الاستماع.'),
          ),
          Tile(
            'تعرّف على المفردات',
            Icons.translate,
            subtitle: '家人 • jiārén • الأسرة',
            onTap: () => setState(() => reveal = !reveal),
          ),
          if (reveal)
            const SaiCard(
              child: Column(
                children: [
                  Text('爸爸  bàba  — الأب'),
                  Text('妈妈  māma  — الأم'),
                  Text('家人  jiārén  — أفراد الأسرة'),
                ],
              ),
            ),
          Tile(
            'تدرّب على النطق',
            Icons.mic_none,
            subtitle: 'خدمة تقييم الصوت غير متصلة',
            onTap: () => message('لم يتم ربط التسجيل أو تقييم النطق بعد.'),
          ),
          RedButton('بدء التدريب', onPressed: () => setState(() => tab = 1)),
        ],
        if (tab == 1)
          SaiCard(
            child: Column(
              children: [
                const Text(
                  'ما معنى 家人؟',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                for (final a in ['أفراد الأسرة', 'المدرسة', 'الكتاب'])
                  RadioListTile<String>(
                    title: Text(a),
                    value: a,
                    // ignore: deprecated_member_use
                    groupValue: answer,
                    // ignore: deprecated_member_use
                    onChanged: (v) => setState(() => answer = v),
                  ),
                if (answer != null)
                  Text(
                    answer == 'أفراد الأسرة'
                        ? 'إجابة صحيحة ✓'
                        : 'حاول مرة أخرى',
                    style: TextStyle(
                      color: answer == 'أفراد الأسرة' ? Colors.green : red,
                    ),
                  ),
              ],
            ),
          ),
        if (tab == 2)
          const SaiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مفردات الدرس',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  '家人 jiārén — أفراد الأسرة\n爸爸 bàba — الأب\n妈妈 māma — الأم\n这是我的家人。\nهؤلاء أفراد أسرتي.',
                ),
              ],
            ),
          ),
      ],
    );
  }

  void message(String text) => showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(text),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('حسناً'),
        ),
      ],
    ),
  );
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String filter = 'الكل';
  final read = <int>{};
  final rows = const [
    (
      'جدول الحصص الأسبوعي',
      'تم نشر جدول الأسبوع القادم.',
      'الأكاديمية',
      Icons.calendar_month,
    ),
    (
      'واجب جديد',
      'تم إضافة واجب في SAI2 — الدرس 5.',
      'الأكاديمية',
      Icons.assignment_outlined,
    ),
    ('إشعار رسوم', 'تذكير بسداد القسط الدراسي.', 'المالية', Icons.credit_card),
    (
      'إعلان مهم',
      'بدء التسجيل للفصل القادم.',
      'النظام',
      Icons.campaign_outlined,
    ),
  ];
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Wrap(
        spacing: 6,
        children: ['الكل', 'الأكاديمية', 'المالية', 'النظام']
            .map(
              (f) => ChoiceChip(
                label: Text(f),
                selected: filter == f,
                onSelected: (_) => setState(() => filter = f),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 14),
      if (!previewMode)
        const EmptyPanel('مصدر الإشعارات غير متصل بعد.')
      else
        for (var i = 0; i < rows.length; i++)
          if (filter == 'الكل' || filter == rows[i].$3)
            Tile(
              '${read.contains(i) ? '' : '● '}${rows[i].$1}',
              rows[i].$4,
              subtitle: rows[i].$2,
              onTap: () => setState(() => read.add(i)),
            ),
    ],
  );
}

class PerformancePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFFE9DBD1)
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(8, y), Offset(size.width - 8, y), grid);
    }
    final points = [
      Offset(10, size.height * .8),
      Offset(size.width * .25, size.height * .65),
      Offset(size.width * .5, size.height * .5),
      Offset(size.width * .75, size.height * .35),
      Offset(size.width - 10, size.height * .15),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = red
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    for (final p in points) {
      canvas.drawCircle(p, 5, Paint()..color = red);
    }
  }

  @override
  bool shouldRepaint(PerformancePainter oldDelegate) => false;
}
