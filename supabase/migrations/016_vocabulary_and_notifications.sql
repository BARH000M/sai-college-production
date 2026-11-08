-- 016_vocabulary_and_notifications.sql
-- Vocabulary word bank, per-student study progress, and the per-account
-- notification read marker used by the unified notifications centre.

create table if not exists public.learning_vocabulary (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.learning_courses(id) on delete cascade,
  lesson_id uuid references public.learning_lessons(id) on delete set null,
  hanzi text not null,
  pinyin text not null,
  meaning_ar text not null,
  meaning_en text,
  part_of_speech text,
  example_zh text,
  example_ar text,
  hsk_level integer,
  position integer not null default 1,
  is_published boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists learning_vocabulary_course_idx
  on public.learning_vocabulary (course_id, position);
create index if not exists learning_vocabulary_lesson_idx
  on public.learning_vocabulary (lesson_id, position);

create table if not exists public.learning_vocab_progress (
  vocabulary_id uuid not null references public.learning_vocabulary(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  status text not null default 'learning' check (status in ('learning', 'known')),
  review_count integer not null default 0 check (review_count >= 0),
  last_reviewed_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (vocabulary_id, student_id)
);

create index if not exists learning_vocab_progress_student_idx
  on public.learning_vocab_progress (student_id);

create table if not exists public.notification_reads (
  user_id uuid primary key references auth.users(id) on delete cascade,
  seen_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.learning_vocabulary enable row level security;
alter table public.learning_vocab_progress enable row level security;
alter table public.notification_reads enable row level security;

-- Word bank: everyone signed in reads published words, course managers see drafts too.
drop policy if exists learning_vocabulary_select on public.learning_vocabulary;
create policy learning_vocabulary_select on public.learning_vocabulary
  for select to authenticated
  using (is_published or public.sai_learning_can_manage_course(course_id));

drop policy if exists learning_vocabulary_write on public.learning_vocabulary;
create policy learning_vocabulary_write on public.learning_vocabulary
  for all to authenticated
  using (public.sai_learning_can_manage_course(course_id))
  with check (public.sai_learning_can_manage_course(course_id));

-- Study progress: readable by the people who may read the student record,
-- writable only by that student's own account.
drop policy if exists learning_vocab_progress_select on public.learning_vocab_progress;
create policy learning_vocab_progress_select on public.learning_vocab_progress
  for select to authenticated
  using (public.sai_security_can_read_student(student_id));

drop policy if exists learning_vocab_progress_write on public.learning_vocab_progress;
create policy learning_vocab_progress_write on public.learning_vocab_progress
  for all to authenticated
  using (public.sai_learning_own_student(student_id))
  with check (public.sai_learning_own_student(student_id));

-- Read marker: a row belongs to exactly one signed-in account.
drop policy if exists notification_reads_select_self on public.notification_reads;
create policy notification_reads_select_self on public.notification_reads
  for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists notification_reads_insert_self on public.notification_reads;
create policy notification_reads_insert_self on public.notification_reads
  for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists notification_reads_update_self on public.notification_reads;
create policy notification_reads_update_self on public.notification_reads
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- Seed the word bank, linked to the lessons of the two live courses.
-- Idempotent: a word is only inserted when the course does not have it yet.
with source (
  hanzi, pinyin, meaning_ar, meaning_en, part_of_speech, example_zh, example_ar,
  hsk_level, position, course_title, lesson_title
) as (
  values
    ('你好', 'nǐ hǎo', 'مرحباً', 'hello', 'تعبير', '你好，老师！', 'مرحباً يا أستاذ!', 1, 1, 'اللغة الصينية — المستوى الأول', 'التعريف بالنفس والتحية'),
    ('我叫', 'wǒ jiào', 'اسمي', 'my name is', 'تعبير', '我叫艾哈迈德。', 'اسمي أحمد.', 1, 2, 'اللغة الصينية — المستوى الأول', 'التعريف بالنفس والتحية'),
    ('老师', 'lǎoshī', 'معلّم', 'teacher', 'اسم', '老师很好。', 'المعلم لطيف.', 1, 3, 'اللغة الصينية — المستوى الأول', 'التعريف بالنفس والتحية'),
    ('学生', 'xuésheng', 'طالب', 'student', 'اسم', '我是学生。', 'أنا طالب.', 1, 4, 'اللغة الصينية — المستوى الأول', 'التعريف بالنفس والتحية'),
    ('谢谢', 'xièxie', 'شكراً', 'thank you', 'تعبير', '谢谢你帮我。', 'شكراً لمساعدتك لي.', 1, 5, 'اللغة الصينية — المستوى الأول', 'التعريف بالنفس والتحية'),
    ('再见', 'zàijiàn', 'إلى اللقاء', 'goodbye', 'تعبير', '老师，再见！', 'إلى اللقاء يا أستاذ!', 1, 6, 'اللغة الصينية — المستوى الأول', 'التعريف بالنفس والتحية'),

    ('妈', 'mā', 'أم', 'mother', 'اسم', '妈妈在家。', 'أمي في المنزل.', 1, 1, 'اللغة الصينية — المستوى الأول', 'النغمات الأربع والنطق الأول'),
    ('麻', 'má', 'قنب / كتان', 'hemp', 'اسم', '这是麻布。', 'هذا قماش من الكتان.', 1, 2, 'اللغة الصينية — المستوى الأول', 'النغمات الأربع والنطق الأول'),
    ('马', 'mǎ', 'حصان', 'horse', 'اسم', '那匹马很快。', 'ذلك الحصان سريع.', 1, 3, 'اللغة الصينية — المستوى الأول', 'النغمات الأربع والنطق الأول'),
    ('骂', 'mà', 'يوبّخ / يسبّ', 'to scold', 'فعل', '不要骂人。', 'لا توبّخ الآخرين.', 2, 4, 'اللغة الصينية — المستوى الأول', 'النغمات الأربع والنطق الأول'),

    ('一', 'yī', 'واحد', 'one', 'عدد', '我有一个哥哥。', 'لدي أخ واحد أكبر مني.', 1, 1, 'اللغة الصينية — المستوى الأول', 'الأرقام والأسرة'),
    ('二', 'èr', 'اثنان', 'two', 'عدد', '我们班有二十二个学生。', 'في صفّنا اثنان وعشرون طالباً.', 1, 2, 'اللغة الصينية — المستوى الأول', 'الأرقام والأسرة'),
    ('三', 'sān', 'ثلاثة', 'three', 'عدد', '我家有三口人。', 'أسرتي من ثلاثة أفراد.', 1, 3, 'اللغة الصينية — المستوى الأول', 'الأرقام والأسرة'),
    ('爸爸', 'bàba', 'أب', 'father', 'اسم', '爸爸是工程师。', 'أبي مهندس.', 1, 4, 'اللغة الصينية — المستوى الأول', 'الأرقام والأسرة'),
    ('妈妈', 'māma', 'أم', 'mother', 'اسم', '妈妈做饭很好吃。', 'طبخ أمي لذيذ جداً.', 1, 5, 'اللغة الصينية — المستوى الأول', 'الأرقام والأسرة'),
    ('哥哥', 'gēge', 'أخ أكبر', 'elder brother', 'اسم', '哥哥在大学学习。', 'أخي الأكبر يدرس في الجامعة.', 1, 6, 'اللغة الصينية — المستوى الأول', 'الأرقام والأسرة'),
    ('家', 'jiā', 'منزل / أسرة', 'home', 'اسم', '我的家很近。', 'منزلي قريب.', 1, 7, 'اللغة الصينية — المستوى الأول', 'الأرقام والأسرة'),

    ('教室', 'jiàoshì', 'قاعة الدرس', 'classroom', 'اسم', '教室很大。', 'قاعة الدرس كبيرة.', 1, 1, 'اللغة الصينية — المستوى الأول', 'حوار قصير: في الصف'),
    ('书', 'shū', 'كتاب', 'book', 'اسم', '这是我的中文书。', 'هذا كتابي في اللغة الصينية.', 1, 2, 'اللغة الصينية — المستوى الأول', 'حوار قصير: في الصف'),
    ('哪里', 'nǎlǐ', 'أين', 'where', 'استفهام', '洗手间在哪里？', 'أين دورة المياه؟', 1, 3, 'اللغة الصينية — المستوى الأول', 'حوار قصير: في الصف'),
    ('在', 'zài', 'في / عند', 'at, in', 'حرف جر', '我在教室里。', 'أنا في قاعة الدرس.', 1, 4, 'اللغة الصينية — المستوى الأول', 'حوار قصير: في الصف'),
    ('请', 'qǐng', 'من فضلك / تفضّل', 'please', 'تعبير', '请再说一次。', 'من فضلك أعد مرة أخرى.', 1, 5, 'اللغة الصينية — المستوى الأول', 'حوار قصير: في الصف'),

    ('出口', 'chūkǒu', 'تصدير', 'export', 'اسم', '我们的出口增加了。', 'زادت صادراتنا هذا العام.', 2, 1, 'أساسيات التجارة الدولية', 'مصطلحات التجارة والشحن'),
    ('进口', 'jìnkǒu', 'استيراد', 'import', 'اسم', '这批货从中国进口。', 'هذه الشحنة مستوردة من الصين.', 2, 2, 'أساسيات التجارة الدولية', 'مصطلحات التجارة والشحن'),
    ('合同', 'hétong', 'عقد', 'contract', 'اسم', '请签合同。', 'من فضلك وقّع العقد.', 2, 3, 'أساسيات التجارة الدولية', 'مصطلحات التجارة والشحن'),
    ('发票', 'fāpiào', 'فاتورة', 'invoice', 'اسم', '发票已经发出。', 'أُرسلت الفاتورة بالفعل.', 2, 4, 'أساسيات التجارة الدولية', 'مصطلحات التجارة والشحن'),
    ('运输', 'yùnshū', 'نقل / شحن', 'transport', 'اسم', '运输费用是多少？', 'كم تكلفة الشحن؟', 2, 5, 'أساسيات التجارة الدولية', 'مصطلحات التجارة والشحن'),
    ('客户', 'kèhù', 'عميل', 'client', 'اسم', '客户很满意。', 'العميل راضٍ جداً.', 2, 6, 'أساسيات التجارة الدولية', 'مصطلحات التجارة والشحن')
)
insert into public.learning_vocabulary (
  course_id, lesson_id, hanzi, pinyin, meaning_ar, meaning_en, part_of_speech,
  example_zh, example_ar, hsk_level, position, is_published
)
select
  c.id, l.id, s.hanzi, s.pinyin, s.meaning_ar, s.meaning_en, s.part_of_speech,
  s.example_zh, s.example_ar, s.hsk_level, s.position, true
from source s
join public.learning_courses c on c.title = s.course_title
left join public.learning_lessons l on l.course_id = c.id and l.title = s.lesson_title
where not exists (
  select 1 from public.learning_vocabulary v
  where v.course_id = c.id and v.hanzi = s.hanzi and v.pinyin = s.pinyin
);