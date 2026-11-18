-- Synthetic DDL/ACL fixture; no production records or credentials.
create role anon nologin; create role authenticated nologin;
    create role service_role nologin bypassrls;
    revoke create on schema public from public;
    create schema auth;
    create table auth.users(id uuid primary key default gen_random_uuid(),email text,
      email_confirmed_at timestamptz,phone_confirmed_at timestamptz,deleted_at timestamptz,
      banned_until timestamptz,raw_user_meta_data jsonb default '{}'::jsonb,
      created_at timestamptz default now());
    create function auth.uid() returns uuid language sql stable as
      $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    create function auth.role() returns text language sql stable as
      $$select nullif(current_setting('request.jwt.claim.role',true),'')$$;
    grant usage on schema auth to anon,authenticated,service_role;
    create schema storage;
    create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text,name text);
    alter table storage.objects enable row level security;
    create function storage.foldername(text) returns text[] language sql immutable as
      $$select string_to_array($1,'/')$$;
    grant usage on schema storage to authenticated,service_role;
    create schema private;
    grant usage on schema private to authenticated,service_role;
    set check_function_bodies=false;
    create type public.app_role as enum ('super_admin','admin','teacher','accountant','receptionist','librarian','student','parent','content_editor');
create sequence "public"."admissions_application_no_seq";
create sequence "public"."finance_receipt_seq";
create sequence "public"."finance_refund_seq";
create table "public"."academic_sessions" ("id" uuid default gen_random_uuid() not null,"name" text not null,"starts_on" date not null,"ends_on" date not null,"is_active" boolean default false not null);
create table "public"."admission_reminder_log" ("id" uuid default gen_random_uuid() not null,"enquiry_id" uuid not null,"reminder_kind" text default 'stale_new'::text not null,"sent_at" timestamp with time zone default now() not null);
create table "public"."admission_reminder_runs" ("run_date" date not null,"started_at" timestamp with time zone default now() not null,"sent_count" integer default 0 not null,"finished_at" timestamp with time zone);
create table "public"."admissions_enquiries" ("id" uuid default gen_random_uuid() not null,"branch_id" uuid not null,"academic_session_id" uuid not null,"application_no" text default ('SAI-APP-'::text || nextval('admissions_application_no_seq'::regclass)) not null,"applicant_full_name" text not null,"guardian_name" text,"phone" text,"email" text,"preferred_program" text,"preferred_level" text,"source" text,"notes" text,"status" text default 'new'::text not null,"assigned_to" uuid,"created_by" uuid default auth.uid() not null,"created_at" timestamp with time zone default now() not null,"updated_at" timestamp with time zone default now() not null,"closed_at" timestamp with time zone);
create table "public"."announcement_deliveries" ("id" uuid default gen_random_uuid() not null,"announcement_id" uuid not null,"recipient_user_id" uuid not null,"recipient_email" text not null,"status" text not null,"provider_message_id" text,"error" text,"attempted_at" timestamp with time zone default now() not null,"sent_at" timestamp with time zone);
create table "public"."announcement_reads" ("announcement_id" uuid not null,"user_id" uuid not null,"read_at" timestamp with time zone default now() not null);
create table "public"."announcements" ("id" uuid default gen_random_uuid() not null,"branch_id" uuid,"title" text not null,"body" text not null,"audience" text default 'all'::text not null,"is_published" boolean default false not null,"published_at" timestamp with time zone,"expires_at" timestamp with time zone,"published_by" uuid not null,"created_at" timestamp with time zone default now() not null,"updated_at" timestamp with time zone default now() not null);
create table "public"."attendance_records" ("id" uuid default gen_random_uuid() not null,"attendance_session_id" uuid not null,"student_id" uuid not null,"status" text not null,"note" text,"marked_by" uuid default auth.uid() not null,"marked_at" timestamp with time zone default now() not null,"updated_at" timestamp with time zone default now() not null);
create table "public"."attendance_sessions" ("id" uuid default gen_random_uuid() not null,"branch_id" uuid not null,"academic_session_id" uuid not null,"class_id" uuid not null,"attendance_date" date not null,"start_time" timestamp with time zone,"end_time" timestamp with time zone,"status" text default 'open'::text not null,"created_by" uuid default auth.uid() not null,"created_at" timestamp with time zone default now() not null,"updated_at" timestamp with time zone default now() not null);
create table "public"."audit_logs" ("id" uuid default gen_random_uuid() not null,"actor_user_id" uuid,"action" text not null,"entity_type" text not null,"entity_id" uuid,"metadata" jsonb default '{}'::jsonb not null,"created_at" timestamp with time zone default now() not null);
create table "public"."branch_memberships" ("user_id" uuid not null,"branch_id" uuid not null,"is_active" boolean default true not null);
create table "public"."branches" ("id" uuid default gen_random_uuid() not null,"name" text not null,"code" text not null,"address" text,"is_active" boolean default true not null,"created_at" timestamp with time zone default now() not null);
create table "public"."classes" ("id" uuid default gen_random_uuid() not null,"branch_id" uuid not null,"session_id" uuid not null,"name" text not null,"program" text not null,"capacity" integer default 20 not null,"teacher_id" uuid,"created_at" timestamp with time zone default now() not null,"is_active" boolean default true not null);
create table "public"."cms_news" ("id" uuid default gen_random_uuid() not null,"title_ar" text not null,"title_en" text default ''::text not null,"summary_ar" text default ''::text not null,"summary_en" text default ''::text not null,"tag_ar" text default 'أخبار'::text not null,"tag_en" text default 'News'::text not null,"image_url" text,"published_at" date default CURRENT_DATE not null,"is_published" boolean default true not null,"sort_order" integer default 0 not null,"created_at" timestamp with time zone default now() not null,"updated_at" timestamp with time zone default now() not null);
create table "public"."cms_programs" ("id" uuid default gen_random_uuid() not null,"title_ar" text not null,"title_en" text default ''::text not null,"summary_ar" text default ''::text not null,"summary_en" text default ''::text not null,"duration_ar" text default ''::text not null,"duration_en" text default ''::text not null,"icon" text default 'ri-book-open-line'::text not null,"is_published" boolean default true not null,"sort_order" integer default 0 not null,"created_at" timestamp with time zone default now() not null,"updated_at" timestamp with time zone default now() not null);
create table "public"."cms_site_content" ("key" text not null,"section" text default 'general'::text not null,"label_ar" text not null,"value_ar" text default ''::text not null,"value_en" text default ''::text not null,"sort_order" integer default 0 not null,"updated_at" timestamp with time zone default now() not null,"updated_by" uuid);
create table "public"."fee_assignments" ("id" uuid default gen_random_uuid() not null,"fee_group_id" uuid not null,"student_id" uuid not null,"branch_id" uuid not null,"academic_session_id" uuid not null,"class_id" uuid,"original_amount" numeric(12,2) not null,"discount_amount" numeric(12,2) not null,"final_amount" numeric(12,2) generated always as ((original_amount - discount_amount)) stored,"due_date" date not null,"cancelled_at" timestamp with time zone,"cancelled_by" uuid,"cancellation_reason" text,"created_by" uuid not null,"created_at" timestamp with time zone default now() not null);
create table "public"."fee_groups" ("id" uuid default gen_random_uuid() not null,"branch_id" uuid not null,"academic_session_id" uuid not null,"name" text not null,"description" text,"amount" numeric(12,2) not null,"currency" text default 'YER'::text not null,"due_date" date not null,"is_active" boolean default true not null,"created_by" uuid not null,"created_at" timestamp with time zone default now() not null,"updated_at" timestamp with time zone default now() not null);
create table "public"."fee_payments" ("id" uuid default gen_random_uuid() not null,"assignment_id" uuid not null,"branch_id" uuid not null,"amount" numeric(12,2) not null,"currency" text default 'YER'::text not null,"method" text not null,"transaction_reference" text,"idempotency_key" uuid not null,"receipt_number" text not null,"posted_by" uuid not null,"posted_at" timestamp with time zone default now() not null,"voided_at" timestamp with time zone,"voided_by" uuid,"void_reason" text);
create table "public"."fee_refunds" ("id" uuid default gen_random_uuid() not null,"idempotency_key" uuid not null,"payment_id" uuid not null,"branch_id" uuid not null,"amount" numeric(12,2) not null,"method" text not null,"reference" text,"refund_number" text not null,"reason" text not null,"issued_by" uuid not null,"issued_at" timestamp with time zone default now() not null);
create table "public"."fee_waivers" ("id" uuid default gen_random_uuid() not null,"assignment_id" uuid not null,"amount" numeric(12,2) not null,"reason" text not null,"waived_by" uuid not null,"waived_at" timestamp with time zone default now() not null);
create table "public"."finance_audit_log" ("id" bigint generated always as identity not null,"branch_id" uuid not null,"actor_id" uuid not null,"action" text not null,"entity_id" uuid not null,"details" jsonb not null,"created_at" timestamp with time zone default now() not null);
create table "public"."learning_courses" ("id" uuid default gen_random_uuid() not null,"branch_id" uuid not null,"session_id" uuid not null,"class_id" uuid not null,"title" text not null,"description" text,"level" text,"teacher_id" uuid,"is_active" boolean default true not null,"created_at" timestamp with time zone default now() not null);
create table "public"."learning_homework" ("id" uuid default gen_random_uuid() not null,"course_id" uuid not null,"title" text not null,"instructions" text,"due_at" timestamp with time zone not null,"max_score" integer default 100 not null,"position" integer default 1 not null,"is_published" boolean default true not null,"created_by" uuid,"created_at" timestamp with time zone default now() not null,"published_at" timestamp with time zone,"updated_at" timestamp with time zone default now() not null);
create table "public"."learning_homework_submissions" ("id" uuid default gen_random_uuid() not null,"homework_id" uuid not null,"student_id" uuid not null,"status" text default 'submitted'::text not null,"content" text,"submitted_at" timestamp with time zone default now() not null,"score" integer,"feedback" text,"graded_at" timestamp with time zone,"graded_by" uuid);
create table "public"."learning_inbox_reads" ("user_id" uuid not null,"seen_at" timestamp with time zone default now() not null,"updated_at" timestamp with time zone default now() not null);
create table "public"."learning_lesson_progress" ("lesson_id" uuid not null,"student_id" uuid not null,"status" text default 'not_started'::text not null,"updated_at" timestamp with time zone default now() not null);
create table "public"."learning_lessons" ("id" uuid default gen_random_uuid() not null,"course_id" uuid not null,"title" text not null,"summary" text,"kind" text default 'lesson'::text not null,"position" integer default 1 not null,"duration_minutes" integer default 45 not null,"is_published" boolean default true not null,"created_at" timestamp with time zone default now() not null,"content_kind" text default 'none'::text not null,"content_url" text,"content_body" text,"content_updated_at" timestamp with time zone,"content_path" text,"content_file_name" text);
create table "public"."learning_vocab_progress" ("vocabulary_id" uuid not null,"student_id" uuid not null,"status" text default 'learning'::text not null,"review_count" integer default 0 not null,"last_reviewed_at" timestamp with time zone,"updated_at" timestamp with time zone default now() not null);
create table "public"."learning_vocabulary" ("id" uuid default gen_random_uuid() not null,"course_id" uuid not null,"lesson_id" uuid,"hanzi" text not null,"pinyin" text not null,"meaning_ar" text not null,"meaning_en" text,"part_of_speech" text,"example_zh" text,"example_ar" text,"hsk_level" integer,"position" integer default 1 not null,"is_published" boolean default true not null,"created_at" timestamp with time zone default now() not null);
create table "public"."library_items" ("id" uuid default gen_random_uuid() not null,"branch_id" uuid not null,"title" text not null,"author" text,"category" text,"isbn" text,"shelf_code" text,"copies_total" integer default 1 not null,"copies_available" integer default 1 not null,"is_active" boolean default true not null,"created_by" uuid,"created_at" timestamp with time zone default now() not null,"updated_at" timestamp with time zone default now() not null);
create table "public"."library_loans" ("id" uuid default gen_random_uuid() not null,"item_id" uuid not null,"branch_id" uuid not null,"student_id" uuid not null,"issued_by" uuid not null,"issued_at" timestamp with time zone default now() not null,"due_date" date not null,"returned_at" timestamp with time zone,"returned_by" uuid,"notes" text);
create table "public"."notification_reads" ("user_id" uuid not null,"seen_at" timestamp with time zone default now() not null,"updated_at" timestamp with time zone default now() not null);
create table "public"."parent_student_links" ("parent_user_id" uuid not null,"student_id" uuid not null,"verified_at" timestamp with time zone,"verified_by" uuid);
create table "public"."profiles" ("id" uuid not null,"full_name" text not null,"email" text,"phone" text,"preferred_locale" text default 'ar'::text not null,"created_at" timestamp with time zone default now() not null,"updated_at" timestamp with time zone default now() not null);
create table "public"."sai_alumni" ("id" uuid default gen_random_uuid() not null,"branch_id" uuid not null,"title" text not null,"description" text,"student_id" uuid,"graduation_year" integer,"created_by" uuid,"created_at" timestamp with time zone default now() not null,"updated_at" timestamp with time zone default now() not null);
create table "public"."sai_certificates" ("id" uuid default gen_random_uuid() not null,"branch_id" uuid not null,"title" text not null,"description" text,"student_id" uuid,"serial_code" text,"issued_on" date,"created_by" uuid,"created_at" timestamp with time zone default now() not null,"updated_at" timestamp with time zone default now() not null);
create table "public"."sai_cms_pages" ("id" uuid default gen_random_uuid() not null,"branch_id" uuid not null,"title" text not null,"description" text,"slug" text,"body" text,"is_published" boolean default false not null,"created_by" uuid,"created_at" timestamp with time zone default now() not null,"updated_at" timestamp with time zone default now() not null);
create table "public"."sai_download_resources" ("id" uuid default gen_random_uuid() not null,"branch_id" uuid not null,"title" text not null,"description" text,"category" text,"storage_path" text,"is_published" boolean default false not null,"created_by" uuid,"created_at" timestamp with time zone default now() not null,"updated_at" timestamp with time zone default now() not null);
create table "public"."sai_housing_rooms" ("id" uuid default gen_random_uuid() not null,"branch_id" uuid not null,"title" text not null,"description" text,"building" text,"capacity" integer default 0 not null,"created_by" uuid,"created_at" timestamp with time zone default now() not null,"updated_at" timestamp with time zone default now() not null);
create table "public"."sai_inventory_items" ("id" uuid default gen_random_uuid() not null,"branch_id" uuid not null,"title" text not null,"description" text,"sku" text,"quantity" integer default 0 not null,"warehouse" text,"created_by" uuid,"created_at" timestamp with time zone default now() not null,"updated_at" timestamp with time zone default now() not null);
create table "public"."sai_student_portfolios" ("id" uuid default gen_random_uuid() not null,"branch_id" uuid not null,"title" text not null,"description" text,"student_id" uuid,"category" text,"created_by" uuid,"created_at" timestamp with time zone default now() not null,"updated_at" timestamp with time zone default now() not null);
create table "public"."sai_system_settings" ("category" text not null,"setting_key" text not null,"value_text" text default ''::text not null,"updated_by" uuid,"updated_at" timestamp with time zone default now() not null);
create table "public"."sai_system_settings_audit" ("id" bigint generated always as identity not null,"category" text not null,"setting_key" text not null,"action" text not null,"actor_user_id" uuid,"happened_at" timestamp with time zone default now() not null);
create table "public"."sai_transport_routes" ("id" uuid default gen_random_uuid() not null,"branch_id" uuid not null,"title" text not null,"description" text,"vehicle" text,"capacity" integer default 0 not null,"driver_name" text,"created_by" uuid,"created_at" timestamp with time zone default now() not null,"updated_at" timestamp with time zone default now() not null);
create table "public"."students" ("id" uuid default gen_random_uuid() not null,"user_id" uuid,"branch_id" uuid not null,"admission_no" text not null,"full_name" text not null,"date_of_birth" date,"class_id" uuid,"status" text default 'active'::text not null,"created_at" timestamp with time zone default now() not null);
create table "public"."user_roles" ("user_id" uuid not null,"role" app_role not null,"assigned_by" uuid,"assigned_at" timestamp with time zone default now() not null);
alter table "public"."academic_sessions" add constraint "academic_sessions_check" CHECK ((ends_on > starts_on));
alter table "public"."academic_sessions" add constraint "academic_sessions_name_key" UNIQUE (name);
alter table "public"."academic_sessions" add constraint "academic_sessions_pkey" PRIMARY KEY (id);
alter table "public"."admission_reminder_log" add constraint "admission_reminder_log_pkey" PRIMARY KEY (id);
alter table "public"."admission_reminder_log" add constraint "admission_reminder_log_unique" UNIQUE (enquiry_id, reminder_kind);
alter table "public"."admission_reminder_runs" add constraint "admission_reminder_runs_pkey" PRIMARY KEY (run_date);
alter table "public"."admissions_enquiries" add constraint "admissions_enquiries_applicant_full_name_check" CHECK ((length(btrim(applicant_full_name)) > 0));
alter table "public"."admissions_enquiries" add constraint "admissions_enquiries_application_no_key" UNIQUE (application_no);
alter table "public"."admissions_enquiries" add constraint "admissions_enquiries_pkey" PRIMARY KEY (id);
alter table "public"."admissions_enquiries" add constraint "admissions_enquiries_status_check" CHECK ((status = ANY (ARRAY['new'::text, 'contacted'::text, 'assessment'::text, 'accepted'::text, 'enrolled'::text, 'rejected'::text, 'withdrawn'::text])));
alter table "public"."announcement_deliveries" add constraint "announcement_deliveries_announcement_id_recipient_user_id_key" UNIQUE (announcement_id, recipient_user_id);
alter table "public"."announcement_deliveries" add constraint "announcement_deliveries_pkey" PRIMARY KEY (id);
alter table "public"."announcement_deliveries" add constraint "announcement_deliveries_status_check" CHECK ((status = ANY (ARRAY['sent'::text, 'failed'::text, 'skipped'::text])));
alter table "public"."announcement_reads" add constraint "announcement_reads_pkey" PRIMARY KEY (announcement_id, user_id);
alter table "public"."announcements" add constraint "announcements_audience_check" CHECK ((audience = ANY (ARRAY['all'::text, 'staff'::text, 'teachers'::text, 'parents'::text, 'students'::text])));
alter table "public"."announcements" add constraint "announcements_body_check" CHECK ((length(btrim(body)) > 0));
alter table "public"."announcements" add constraint "announcements_pkey" PRIMARY KEY (id);
alter table "public"."announcements" add constraint "announcements_title_check" CHECK ((length(btrim(title)) > 0));
alter table "public"."attendance_records" add constraint "attendance_records_attendance_session_id_student_id_key" UNIQUE (attendance_session_id, student_id);
alter table "public"."attendance_records" add constraint "attendance_records_pkey" PRIMARY KEY (id);
alter table "public"."attendance_records" add constraint "attendance_records_status_check" CHECK ((status = ANY (ARRAY['present'::text, 'absent'::text, 'late'::text, 'excused'::text])));
alter table "public"."attendance_sessions" add constraint "attendance_sessions_check" CHECK (((start_time IS NULL) OR (end_time IS NULL) OR (end_time >= start_time)));
alter table "public"."attendance_sessions" add constraint "attendance_sessions_class_id_attendance_date_key" UNIQUE (class_id, attendance_date);
alter table "public"."attendance_sessions" add constraint "attendance_sessions_pkey" PRIMARY KEY (id);
alter table "public"."attendance_sessions" add constraint "attendance_sessions_status_check" CHECK ((status = ANY (ARRAY['open'::text, 'closed'::text, 'cancelled'::text])));
alter table "public"."audit_logs" add constraint "audit_logs_pkey" PRIMARY KEY (id);
alter table "public"."branch_memberships" add constraint "branch_memberships_pkey" PRIMARY KEY (user_id, branch_id);
alter table "public"."branches" add constraint "branches_code_key" UNIQUE (code);
alter table "public"."branches" add constraint "branches_pkey" PRIMARY KEY (id);
alter table "public"."classes" add constraint "classes_capacity_check" CHECK ((capacity > 0));
alter table "public"."classes" add constraint "classes_pkey" PRIMARY KEY (id);
alter table "public"."cms_news" add constraint "cms_news_pkey" PRIMARY KEY (id);
alter table "public"."cms_programs" add constraint "cms_programs_pkey" PRIMARY KEY (id);
alter table "public"."cms_site_content" add constraint "cms_site_content_pkey" PRIMARY KEY (key);
alter table "public"."fee_assignments" add constraint "fee_assignments_check" CHECK (((discount_amount >= (0)::numeric) AND (discount_amount <= original_amount)));
alter table "public"."fee_assignments" add constraint "fee_assignments_check1" CHECK ((((cancelled_at IS NULL) AND (cancelled_by IS NULL) AND (cancellation_reason IS NULL)) OR ((cancelled_at IS NOT NULL) AND (cancelled_by IS NOT NULL) AND (length(btrim(cancellation_reason)) > 0))));
alter table "public"."fee_assignments" add constraint "fee_assignments_fee_group_id_student_id_key" UNIQUE (fee_group_id, student_id);
alter table "public"."fee_assignments" add constraint "fee_assignments_original_amount_check" CHECK ((original_amount >= (0)::numeric));
alter table "public"."fee_assignments" add constraint "fee_assignments_pkey" PRIMARY KEY (id);
alter table "public"."fee_groups" add constraint "fee_groups_amount_check" CHECK ((amount >= (0)::numeric));
alter table "public"."fee_groups" add constraint "fee_groups_currency_check" CHECK ((currency = 'YER'::text));
alter table "public"."fee_groups" add constraint "fee_groups_name_check" CHECK ((length(btrim(name)) > 0));
alter table "public"."fee_groups" add constraint "fee_groups_pkey" PRIMARY KEY (id);
alter table "public"."fee_payments" add constraint "fee_payments_amount_check" CHECK ((amount > (0)::numeric));
alter table "public"."fee_payments" add constraint "fee_payments_check" CHECK (((method = 'cash'::text) OR ((transaction_reference IS NOT NULL) AND (length(btrim(transaction_reference)) > 0))));
alter table "public"."fee_payments" add constraint "fee_payments_check1" CHECK ((((voided_at IS NULL) AND (voided_by IS NULL) AND (void_reason IS NULL)) OR ((voided_at IS NOT NULL) AND (voided_by IS NOT NULL) AND (length(btrim(void_reason)) >= 10))));
alter table "public"."fee_payments" add constraint "fee_payments_currency_check" CHECK ((currency = 'YER'::text));
alter table "public"."fee_payments" add constraint "fee_payments_idempotency_key_key" UNIQUE (idempotency_key);
alter table "public"."fee_payments" add constraint "fee_payments_method_check" CHECK ((method = ANY (ARRAY['cash'::text, 'bank_transfer'::text, 'wallet'::text, 'card'::text])));
alter table "public"."fee_payments" add constraint "fee_payments_pkey" PRIMARY KEY (id);
alter table "public"."fee_payments" add constraint "fee_payments_receipt_number_key" UNIQUE (receipt_number);
alter table "public"."fee_refunds" add constraint "fee_refunds_amount_check" CHECK ((amount > (0)::numeric));
alter table "public"."fee_refunds" add constraint "fee_refunds_idempotency_key_key" UNIQUE (idempotency_key);
alter table "public"."fee_refunds" add constraint "fee_refunds_method_check" CHECK ((method = ANY (ARRAY['cash'::text, 'bank_transfer'::text, 'wallet'::text, 'card'::text])));
alter table "public"."fee_refunds" add constraint "fee_refunds_pkey" PRIMARY KEY (id);
alter table "public"."fee_refunds" add constraint "fee_refunds_reason_check" CHECK ((length(btrim(reason)) > 0));
alter table "public"."fee_refunds" add constraint "fee_refunds_refund_number_key" UNIQUE (refund_number);
alter table "public"."fee_waivers" add constraint "fee_waivers_amount_check" CHECK ((amount > (0)::numeric));
alter table "public"."fee_waivers" add constraint "fee_waivers_pkey" PRIMARY KEY (id);
alter table "public"."fee_waivers" add constraint "fee_waivers_reason_check" CHECK ((length(btrim(reason)) > 0));
alter table "public"."finance_audit_log" add constraint "finance_audit_log_pkey" PRIMARY KEY (id);
alter table "public"."learning_courses" add constraint "learning_courses_pkey" PRIMARY KEY (id);
alter table "public"."learning_homework" add constraint "learning_homework_pkey" PRIMARY KEY (id);
alter table "public"."learning_homework_submissions" add constraint "learning_homework_submissions_homework_id_student_id_key" UNIQUE (homework_id, student_id);
alter table "public"."learning_homework_submissions" add constraint "learning_homework_submissions_pkey" PRIMARY KEY (id);
alter table "public"."learning_homework_submissions" add constraint "learning_homework_submissions_status_check" CHECK ((status = ANY (ARRAY['submitted'::text, 'graded'::text, 'returned'::text])));
alter table "public"."learning_inbox_reads" add constraint "learning_inbox_reads_pkey" PRIMARY KEY (user_id);
alter table "public"."learning_lesson_progress" add constraint "learning_lesson_progress_pkey" PRIMARY KEY (lesson_id, student_id);
alter table "public"."learning_lesson_progress" add constraint "learning_lesson_progress_status_check" CHECK ((status = ANY (ARRAY['not_started'::text, 'in_progress'::text, 'completed'::text])));
alter table "public"."learning_lessons" add constraint "learning_lessons_content_kind_check" CHECK ((content_kind = ANY (ARRAY['none'::text, 'video'::text, 'reading'::text, 'audio'::text, 'link'::text])));
alter table "public"."learning_lessons" add constraint "learning_lessons_kind_check" CHECK ((kind = ANY (ARRAY['lesson'::text, 'listening'::text, 'speaking'::text, 'vocabulary'::text, 'reading'::text, 'review'::text])));
alter table "public"."learning_lessons" add constraint "learning_lessons_pkey" PRIMARY KEY (id);
alter table "public"."learning_vocab_progress" add constraint "learning_vocab_progress_pkey" PRIMARY KEY (vocabulary_id, student_id);
alter table "public"."learning_vocab_progress" add constraint "learning_vocab_progress_review_count_check" CHECK ((review_count >= 0));
alter table "public"."learning_vocab_progress" add constraint "learning_vocab_progress_status_check" CHECK ((status = ANY (ARRAY['learning'::text, 'known'::text])));
alter table "public"."learning_vocabulary" add constraint "learning_vocabulary_pkey" PRIMARY KEY (id);
alter table "public"."library_items" add constraint "library_items_check" CHECK ((copies_available <= copies_total));
alter table "public"."library_items" add constraint "library_items_copies_available_check" CHECK ((copies_available >= 0));
alter table "public"."library_items" add constraint "library_items_copies_total_check" CHECK ((copies_total > 0));
alter table "public"."library_items" add constraint "library_items_pkey" PRIMARY KEY (id);
alter table "public"."library_items" add constraint "library_items_title_check" CHECK ((length(btrim(title)) > 0));
alter table "public"."library_loans" add constraint "library_loans_pkey" PRIMARY KEY (id);
alter table "public"."notification_reads" add constraint "notification_reads_pkey" PRIMARY KEY (user_id);
alter table "public"."parent_student_links" add constraint "parent_student_links_pkey" PRIMARY KEY (parent_user_id, student_id);
alter table "public"."profiles" add constraint "profiles_pkey" PRIMARY KEY (id);
alter table "public"."sai_alumni" add constraint "sai_alumni_graduation_year_check" CHECK (((graduation_year >= 1900) AND (graduation_year <= 2200)));
alter table "public"."sai_alumni" add constraint "sai_alumni_pkey" PRIMARY KEY (id);
alter table "public"."sai_alumni" add constraint "sai_alumni_title_check" CHECK (((length(btrim(title)) >= 1) AND (length(btrim(title)) <= 200)));
alter table "public"."sai_certificates" add constraint "sai_certificates_pkey" PRIMARY KEY (id);
alter table "public"."sai_certificates" add constraint "sai_certificates_title_check" CHECK (((length(btrim(title)) >= 1) AND (length(btrim(title)) <= 200)));
alter table "public"."sai_cms_pages" add constraint "sai_cms_pages_pkey" PRIMARY KEY (id);
alter table "public"."sai_cms_pages" add constraint "sai_cms_pages_title_check" CHECK (((length(btrim(title)) >= 1) AND (length(btrim(title)) <= 200)));
alter table "public"."sai_download_resources" add constraint "sai_download_resources_pkey" PRIMARY KEY (id);
alter table "public"."sai_download_resources" add constraint "sai_download_resources_title_check" CHECK (((length(btrim(title)) >= 1) AND (length(btrim(title)) <= 200)));
alter table "public"."sai_housing_rooms" add constraint "sai_housing_rooms_capacity_check" CHECK ((capacity >= 0));
alter table "public"."sai_housing_rooms" add constraint "sai_housing_rooms_pkey" PRIMARY KEY (id);
alter table "public"."sai_housing_rooms" add constraint "sai_housing_rooms_title_check" CHECK (((length(btrim(title)) >= 1) AND (length(btrim(title)) <= 200)));
alter table "public"."sai_inventory_items" add constraint "sai_inventory_items_pkey" PRIMARY KEY (id);
alter table "public"."sai_inventory_items" add constraint "sai_inventory_items_quantity_check" CHECK ((quantity >= 0));
alter table "public"."sai_inventory_items" add constraint "sai_inventory_items_title_check" CHECK (((length(btrim(title)) >= 1) AND (length(btrim(title)) <= 200)));
alter table "public"."sai_student_portfolios" add constraint "sai_student_portfolios_pkey" PRIMARY KEY (id);
alter table "public"."sai_student_portfolios" add constraint "sai_student_portfolios_title_check" CHECK (((length(btrim(title)) >= 1) AND (length(btrim(title)) <= 200)));
alter table "public"."sai_system_settings" add constraint "sai_settings_allowed_keys" CHECK ((((category = 'general'::text) AND (setting_key = ANY (ARRAY['college_name'::text, 'website_url'::text, 'contact_email'::text, 'contact_phone'::text, 'address'::text]))) OR ((category = 'sessions'::text) AND (setting_key = ANY (ARRAY['default_session_id'::text, 'registration_open'::text]))) OR ((category = 'notifications'::text) AND (setting_key = ANY (ARRAY['push_enabled'::text, 'digest_enabled'::text, 'quiet_hours'::text]))) OR ((category = 'sms'::text) AND (setting_key = ANY (ARRAY['enabled'::text, 'provider_name'::text, 'sender_name'::text]))) OR ((category = 'whatsapp'::text) AND (setting_key = ANY (ARRAY['enabled'::text, 'business_number'::text, 'template_namespace'::text]))) OR ((category = 'email'::text) AND (setting_key = ANY (ARRAY['enabled'::text, 'sender_address'::text, 'sender_name'::text]))) OR ((category = 'payments'::text) AND (setting_key = ANY (ARRAY['default_currency'::text, 'invoice_prefix'::text, 'enabled_methods'::text]))) OR ((category = 'printing'::text) AND (setting_key = ANY (ARRAY['paper_size'::text, 'header_text'::text, 'footer_text'::text]))) OR ((category = 'cms'::text) AND (setting_key = ANY (ARRAY['site_title'::text, 'default_locale'::text, 'public_notice'::text]))) OR ((category = 'backups'::text) AND (setting_key = ANY (ARRAY['retention_days'::text, 'alert_email'::text]))) OR ((category = 'languages'::text) AND (setting_key = ANY (ARRAY['default_locale'::text, 'enabled_locales'::text, 'timezone'::text]))) OR ((category = 'currencies'::text) AND (setting_key = ANY (ARRAY['base_currency'::text, 'enabled_currencies'::text]))) OR ((category = 'extensions'::text) AND (setting_key = ANY (ARRAY['enabled_module_ids'::text, 'enabled_plugin_ids'::text]))) OR ((category = 'custom_fields'::text) AND (setting_key = ANY (ARRAY['student_form_schema'::text, 'admissions_form_schema'::text]))) OR ((category = 'verification'::text) AND (setting_key = ANY (ARRAY['certificate_verification_enabled'::text, 'guardian_check_required'::text]))) OR ((category = 'updates'::text) AND (setting_key = ANY (ARRAY['release_channel'::text, 'maintenance_notice'::text])))));
alter table "public"."sai_system_settings" add constraint "sai_settings_boolean_values" CHECK (((setting_key <> ALL (ARRAY['enabled'::text, 'push_enabled'::text, 'digest_enabled'::text, 'registration_open'::text, 'certificate_verification_enabled'::text, 'guardian_check_required'::text])) OR (value_text = ANY (ARRAY['true'::text, 'false'::text]))));
alter table "public"."sai_system_settings" add constraint "sai_settings_value_limit" CHECK ((length(value_text) <= 2000));
alter table "public"."sai_system_settings" add constraint "sai_system_settings_pkey" PRIMARY KEY (category, setting_key);
alter table "public"."sai_system_settings_audit" add constraint "sai_system_settings_audit_action_check" CHECK ((action = ANY (ARRAY['INSERT'::text, 'UPDATE'::text, 'DELETE'::text])));
alter table "public"."sai_system_settings_audit" add constraint "sai_system_settings_audit_pkey" PRIMARY KEY (id);
alter table "public"."sai_transport_routes" add constraint "sai_transport_routes_capacity_check" CHECK ((capacity >= 0));
alter table "public"."sai_transport_routes" add constraint "sai_transport_routes_pkey" PRIMARY KEY (id);
alter table "public"."sai_transport_routes" add constraint "sai_transport_routes_title_check" CHECK (((length(btrim(title)) >= 1) AND (length(btrim(title)) <= 200)));
alter table "public"."students" add constraint "students_admission_no_key" UNIQUE (admission_no);
alter table "public"."students" add constraint "students_pkey" PRIMARY KEY (id);
alter table "public"."students" add constraint "students_status_check" CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text, 'graduated'::text, 'withdrawn'::text])));
alter table "public"."students" add constraint "students_user_id_key" UNIQUE (user_id);
alter table "public"."user_roles" add constraint "user_roles_pkey" PRIMARY KEY (user_id, role);
alter table "public"."admission_reminder_log" add constraint "admission_reminder_log_enquiry_id_fkey" FOREIGN KEY (enquiry_id) REFERENCES admissions_enquiries(id) ON DELETE CASCADE;
alter table "public"."admissions_enquiries" add constraint "admissions_enquiries_academic_session_id_fkey" FOREIGN KEY (academic_session_id) REFERENCES academic_sessions(id);
alter table "public"."admissions_enquiries" add constraint "admissions_enquiries_assigned_to_fkey" FOREIGN KEY (assigned_to) REFERENCES auth.users(id);
alter table "public"."admissions_enquiries" add constraint "admissions_enquiries_branch_id_fkey" FOREIGN KEY (branch_id) REFERENCES branches(id);
alter table "public"."admissions_enquiries" add constraint "admissions_enquiries_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id);
alter table "public"."announcement_deliveries" add constraint "announcement_deliveries_announcement_id_fkey" FOREIGN KEY (announcement_id) REFERENCES announcements(id) ON DELETE CASCADE;
alter table "public"."announcement_deliveries" add constraint "announcement_deliveries_recipient_user_id_fkey" FOREIGN KEY (recipient_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table "public"."announcement_reads" add constraint "announcement_reads_announcement_id_fkey" FOREIGN KEY (announcement_id) REFERENCES announcements(id) ON DELETE CASCADE;
alter table "public"."announcement_reads" add constraint "announcement_reads_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table "public"."announcements" add constraint "announcements_branch_id_fkey" FOREIGN KEY (branch_id) REFERENCES branches(id);
alter table "public"."announcements" add constraint "announcements_published_by_fkey" FOREIGN KEY (published_by) REFERENCES auth.users(id);
alter table "public"."attendance_records" add constraint "attendance_records_attendance_session_id_fkey" FOREIGN KEY (attendance_session_id) REFERENCES attendance_sessions(id);
alter table "public"."attendance_records" add constraint "attendance_records_marked_by_fkey" FOREIGN KEY (marked_by) REFERENCES auth.users(id);
alter table "public"."attendance_records" add constraint "attendance_records_student_id_fkey" FOREIGN KEY (student_id) REFERENCES students(id);
alter table "public"."attendance_sessions" add constraint "attendance_sessions_academic_session_id_fkey" FOREIGN KEY (academic_session_id) REFERENCES academic_sessions(id);
alter table "public"."attendance_sessions" add constraint "attendance_sessions_branch_id_fkey" FOREIGN KEY (branch_id) REFERENCES branches(id);
alter table "public"."attendance_sessions" add constraint "attendance_sessions_class_id_fkey" FOREIGN KEY (class_id) REFERENCES classes(id);
alter table "public"."attendance_sessions" add constraint "attendance_sessions_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id);
alter table "public"."audit_logs" add constraint "audit_logs_actor_user_id_fkey" FOREIGN KEY (actor_user_id) REFERENCES auth.users(id);
alter table "public"."branch_memberships" add constraint "branch_memberships_branch_id_fkey" FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE CASCADE;
alter table "public"."branch_memberships" add constraint "branch_memberships_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table "public"."classes" add constraint "classes_branch_id_fkey" FOREIGN KEY (branch_id) REFERENCES branches(id);
alter table "public"."classes" add constraint "classes_session_id_fkey" FOREIGN KEY (session_id) REFERENCES academic_sessions(id);
alter table "public"."classes" add constraint "classes_teacher_id_fkey" FOREIGN KEY (teacher_id) REFERENCES auth.users(id);
alter table "public"."cms_site_content" add constraint "cms_site_content_updated_by_fkey" FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table "public"."fee_assignments" add constraint "fee_assignments_academic_session_id_fkey" FOREIGN KEY (academic_session_id) REFERENCES academic_sessions(id);
alter table "public"."fee_assignments" add constraint "fee_assignments_branch_id_fkey" FOREIGN KEY (branch_id) REFERENCES branches(id);
alter table "public"."fee_assignments" add constraint "fee_assignments_cancelled_by_fkey" FOREIGN KEY (cancelled_by) REFERENCES auth.users(id);
alter table "public"."fee_assignments" add constraint "fee_assignments_class_id_fkey" FOREIGN KEY (class_id) REFERENCES classes(id);
alter table "public"."fee_assignments" add constraint "fee_assignments_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id);
alter table "public"."fee_assignments" add constraint "fee_assignments_fee_group_id_fkey" FOREIGN KEY (fee_group_id) REFERENCES fee_groups(id);
alter table "public"."fee_assignments" add constraint "fee_assignments_student_id_fkey" FOREIGN KEY (student_id) REFERENCES students(id);
alter table "public"."fee_groups" add constraint "fee_groups_academic_session_id_fkey" FOREIGN KEY (academic_session_id) REFERENCES academic_sessions(id);
alter table "public"."fee_groups" add constraint "fee_groups_branch_id_fkey" FOREIGN KEY (branch_id) REFERENCES branches(id);
alter table "public"."fee_groups" add constraint "fee_groups_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id);
alter table "public"."fee_payments" add constraint "fee_payments_assignment_id_fkey" FOREIGN KEY (assignment_id) REFERENCES fee_assignments(id);
alter table "public"."fee_payments" add constraint "fee_payments_branch_id_fkey" FOREIGN KEY (branch_id) REFERENCES branches(id);
alter table "public"."fee_payments" add constraint "fee_payments_posted_by_fkey" FOREIGN KEY (posted_by) REFERENCES auth.users(id);
alter table "public"."fee_payments" add constraint "fee_payments_voided_by_fkey" FOREIGN KEY (voided_by) REFERENCES auth.users(id);
alter table "public"."fee_refunds" add constraint "fee_refunds_branch_id_fkey" FOREIGN KEY (branch_id) REFERENCES branches(id);
alter table "public"."fee_refunds" add constraint "fee_refunds_issued_by_fkey" FOREIGN KEY (issued_by) REFERENCES auth.users(id);
alter table "public"."fee_refunds" add constraint "fee_refunds_payment_id_fkey" FOREIGN KEY (payment_id) REFERENCES fee_payments(id);
alter table "public"."fee_waivers" add constraint "fee_waivers_assignment_id_fkey" FOREIGN KEY (assignment_id) REFERENCES fee_assignments(id);
alter table "public"."fee_waivers" add constraint "fee_waivers_waived_by_fkey" FOREIGN KEY (waived_by) REFERENCES auth.users(id);
alter table "public"."finance_audit_log" add constraint "finance_audit_log_actor_id_fkey" FOREIGN KEY (actor_id) REFERENCES auth.users(id);
alter table "public"."finance_audit_log" add constraint "finance_audit_log_branch_id_fkey" FOREIGN KEY (branch_id) REFERENCES branches(id);
alter table "public"."learning_courses" add constraint "learning_courses_branch_id_fkey" FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE CASCADE;
alter table "public"."learning_courses" add constraint "learning_courses_class_id_fkey" FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE CASCADE;
alter table "public"."learning_courses" add constraint "learning_courses_session_id_fkey" FOREIGN KEY (session_id) REFERENCES academic_sessions(id) ON DELETE RESTRICT;
alter table "public"."learning_courses" add constraint "learning_courses_teacher_id_fkey" FOREIGN KEY (teacher_id) REFERENCES profiles(id) ON DELETE SET NULL;
alter table "public"."learning_homework" add constraint "learning_homework_course_id_fkey" FOREIGN KEY (course_id) REFERENCES learning_courses(id) ON DELETE CASCADE;
alter table "public"."learning_homework" add constraint "learning_homework_created_by_fkey" FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE SET NULL;
alter table "public"."learning_homework_submissions" add constraint "learning_homework_submissions_graded_by_fkey" FOREIGN KEY (graded_by) REFERENCES profiles(id) ON DELETE SET NULL;
alter table "public"."learning_homework_submissions" add constraint "learning_homework_submissions_homework_id_fkey" FOREIGN KEY (homework_id) REFERENCES learning_homework(id) ON DELETE CASCADE;
alter table "public"."learning_homework_submissions" add constraint "learning_homework_submissions_student_id_fkey" FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE;
alter table "public"."learning_inbox_reads" add constraint "learning_inbox_reads_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table "public"."learning_lesson_progress" add constraint "learning_lesson_progress_lesson_id_fkey" FOREIGN KEY (lesson_id) REFERENCES learning_lessons(id) ON DELETE CASCADE;
alter table "public"."learning_lesson_progress" add constraint "learning_lesson_progress_student_id_fkey" FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE;
alter table "public"."learning_lessons" add constraint "learning_lessons_course_id_fkey" FOREIGN KEY (course_id) REFERENCES learning_courses(id) ON DELETE CASCADE;
alter table "public"."learning_vocab_progress" add constraint "learning_vocab_progress_student_id_fkey" FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE;
alter table "public"."learning_vocab_progress" add constraint "learning_vocab_progress_vocabulary_id_fkey" FOREIGN KEY (vocabulary_id) REFERENCES learning_vocabulary(id) ON DELETE CASCADE;
alter table "public"."learning_vocabulary" add constraint "learning_vocabulary_course_id_fkey" FOREIGN KEY (course_id) REFERENCES learning_courses(id) ON DELETE CASCADE;
alter table "public"."learning_vocabulary" add constraint "learning_vocabulary_lesson_id_fkey" FOREIGN KEY (lesson_id) REFERENCES learning_lessons(id) ON DELETE SET NULL;
alter table "public"."library_items" add constraint "library_items_branch_id_fkey" FOREIGN KEY (branch_id) REFERENCES branches(id);
alter table "public"."library_items" add constraint "library_items_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id);
alter table "public"."library_loans" add constraint "library_loans_branch_id_fkey" FOREIGN KEY (branch_id) REFERENCES branches(id);
alter table "public"."library_loans" add constraint "library_loans_issued_by_fkey" FOREIGN KEY (issued_by) REFERENCES auth.users(id);
alter table "public"."library_loans" add constraint "library_loans_item_id_fkey" FOREIGN KEY (item_id) REFERENCES library_items(id);
alter table "public"."library_loans" add constraint "library_loans_returned_by_fkey" FOREIGN KEY (returned_by) REFERENCES auth.users(id);
alter table "public"."library_loans" add constraint "library_loans_student_id_fkey" FOREIGN KEY (student_id) REFERENCES students(id);
alter table "public"."notification_reads" add constraint "notification_reads_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table "public"."parent_student_links" add constraint "parent_student_links_parent_user_id_fkey" FOREIGN KEY (parent_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table "public"."parent_student_links" add constraint "parent_student_links_student_id_fkey" FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE;
alter table "public"."parent_student_links" add constraint "parent_student_links_verified_by_fkey" FOREIGN KEY (verified_by) REFERENCES auth.users(id);
alter table "public"."profiles" add constraint "profiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table "public"."sai_alumni" add constraint "sai_alumni_branch_id_fkey" FOREIGN KEY (branch_id) REFERENCES branches(id);
alter table "public"."sai_alumni" add constraint "sai_alumni_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table "public"."sai_alumni" add constraint "sai_alumni_student_id_fkey" FOREIGN KEY (student_id) REFERENCES students(id);
alter table "public"."sai_certificates" add constraint "sai_certificates_branch_id_fkey" FOREIGN KEY (branch_id) REFERENCES branches(id);
alter table "public"."sai_certificates" add constraint "sai_certificates_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table "public"."sai_certificates" add constraint "sai_certificates_student_id_fkey" FOREIGN KEY (student_id) REFERENCES students(id);
alter table "public"."sai_cms_pages" add constraint "sai_cms_pages_branch_id_fkey" FOREIGN KEY (branch_id) REFERENCES branches(id);
alter table "public"."sai_cms_pages" add constraint "sai_cms_pages_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table "public"."sai_download_resources" add constraint "sai_download_resources_branch_id_fkey" FOREIGN KEY (branch_id) REFERENCES branches(id);
alter table "public"."sai_download_resources" add constraint "sai_download_resources_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table "public"."sai_housing_rooms" add constraint "sai_housing_rooms_branch_id_fkey" FOREIGN KEY (branch_id) REFERENCES branches(id);
alter table "public"."sai_housing_rooms" add constraint "sai_housing_rooms_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table "public"."sai_inventory_items" add constraint "sai_inventory_items_branch_id_fkey" FOREIGN KEY (branch_id) REFERENCES branches(id);
alter table "public"."sai_inventory_items" add constraint "sai_inventory_items_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table "public"."sai_student_portfolios" add constraint "sai_student_portfolios_branch_id_fkey" FOREIGN KEY (branch_id) REFERENCES branches(id);
alter table "public"."sai_student_portfolios" add constraint "sai_student_portfolios_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table "public"."sai_student_portfolios" add constraint "sai_student_portfolios_student_id_fkey" FOREIGN KEY (student_id) REFERENCES students(id);
alter table "public"."sai_system_settings" add constraint "sai_system_settings_updated_by_fkey" FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table "public"."sai_system_settings_audit" add constraint "sai_system_settings_audit_actor_user_id_fkey" FOREIGN KEY (actor_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table "public"."sai_transport_routes" add constraint "sai_transport_routes_branch_id_fkey" FOREIGN KEY (branch_id) REFERENCES branches(id);
alter table "public"."sai_transport_routes" add constraint "sai_transport_routes_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table "public"."students" add constraint "students_branch_id_fkey" FOREIGN KEY (branch_id) REFERENCES branches(id);
alter table "public"."students" add constraint "students_class_id_fkey" FOREIGN KEY (class_id) REFERENCES classes(id);
alter table "public"."students" add constraint "students_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table "public"."user_roles" add constraint "user_roles_assigned_by_fkey" FOREIGN KEY (assigned_by) REFERENCES auth.users(id);
alter table "public"."user_roles" add constraint "user_roles_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
CREATE OR REPLACE FUNCTION private.sai_assert_security_invariants(p_enforce_execute boolean DEFAULT false)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
declare
  v_wrappers constant text[] := array[
    'sai_security_branch_member','sai_security_can_read_branch','sai_security_can_read_class',
    'sai_security_can_read_session','sai_security_can_read_student','sai_security_has_role',
    'sai_learning_can_grade_homework','sai_learning_can_manage_course','sai_learning_can_read_course',
    'sai_learning_can_read_homework','sai_learning_own_student',
    'sai_finance_can_read_student','sai_finance_has_role','sai_finance_staff'
  ];
  v_count integer;
  v_names text;
begin
  -- Invariant 1: no RLS policy may depend on a public sai_* helper.
  -- Uses pg_depend (authoritative) rather than pg_policies.qual, because the
  -- deparsed expression is rendered relative to the caller search_path.
  select count(*), string_agg(c.relname || '.' || pol.polname, ', ' order by pol.polname)
    into v_count, v_names
  from pg_depend d
  join pg_policy pol on pol.oid = d.objid
  join pg_class c on c.oid = pol.polrelid
  join pg_proc p on p.oid = d.refobjid
  join pg_namespace pn on pn.oid = p.pronamespace
  where d.classid = 'pg_policy'::regclass
    and d.refclassid = 'pg_proc'::regclass
    and pn.nspname = 'public'
    and p.proname like 'sai\_%' escape '\';

  if v_count > 0 then
    raise exception
      'security invariant violated: % RLS policy(ies) depend on the public helper layer (%). Re-point them to private.* (migrations 022/025/026).',
      v_count, v_names using errcode = '42501';
  end if;

  -- Invariant 2: no private sai_* helper may call a public sai_* helper.
  select count(*), string_agg(src.proname, ', ' order by src.proname)
    into v_count, v_names
  from pg_depend d
  join pg_proc src on src.oid = d.objid
  join pg_namespace sn on sn.oid = src.pronamespace
  join pg_proc ref on ref.oid = d.refobjid
  join pg_namespace rn on rn.oid = ref.pronamespace
  where d.classid = 'pg_proc'::regclass
    and d.refclassid = 'pg_proc'::regclass
    and sn.nspname = 'private'
    and rn.nspname = 'public'
    and ref.proname like 'sai\_%' escape '\'
    and src.proname like 'sai\_%' escape '\';

  if v_count > 0 then
    raise exception
      'security invariant violated: % private helper(s) call the public helper layer (%). Call private.* instead (migration 025).',
      v_count, v_names using errcode = '42501';
  end if;

  -- Invariant 3: every public wrapper must remain a pure private.* delegator.
  select count(*), string_agg(p.proname, ', ' order by p.proname)
    into v_count, v_names
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = any (v_wrappers)
    and p.prosrc !~ 'private\.sai_';

  if v_count > 0 then
    raise exception
      'security invariant violated: % public wrapper(s) no longer delegate to private.* (%). Re-apply 022/026.',
      v_count, v_names using errcode = '42501';
  end if;

  -- Invariant 4 (opt-in): wrappers must not be an RPC enumeration oracle.
  if p_enforce_execute then
    select count(*) into v_count
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = any (v_wrappers)
      and has_function_privilege('authenticated', p.oid, 'execute');

    if v_count > 0 then
      raise exception
        'security invariant violated: % public wrapper(s) still grant EXECUTE to authenticated, so the UUID enumeration oracle is open. Run 023 and 028.',
        v_count using errcode = '42501';
    end if;
  end if;

  return format(
    'security invariants OK: 0 policies on public helpers, 0 private helpers calling public, %s wrappers delegating, execute_enforced=%s',
    array_length(v_wrappers, 1), p_enforce_execute
  );
end;
$function$
;
revoke all on function "private"."sai_assert_security_invariants"(p_enforce_execute boolean) from public,anon,authenticated,service_role;
grant execute on function "private"."sai_assert_security_invariants"(p_enforce_execute boolean) to public;
CREATE OR REPLACE FUNCTION private.sai_attendance_manage_class(wanted_class uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
  select exists (
    select 1 from public.classes c where c.id = wanted_class and (
      private.sai_security_has_role('super_admin')
      or (private.sai_security_branch_member(c.branch_id) and (
        private.sai_security_has_role('admin')
        or (private.sai_security_has_role('teacher') and c.teacher_id = (select auth.uid()))
      ))
    )
  );
$function$
;
revoke all on function "private"."sai_attendance_manage_class"(wanted_class uuid) from public,anon,authenticated,service_role;
grant execute on function "private"."sai_attendance_manage_class"(wanted_class uuid) to "service_role";
grant execute on function "private"."sai_attendance_manage_class"(wanted_class uuid) to "authenticated";
CREATE OR REPLACE FUNCTION private.sai_attendance_view_record(wanted_session uuid, wanted_student uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
  select exists (
    select 1 from public.attendance_sessions a
    join public.students s on s.id = wanted_student
    where a.id = wanted_session and (
      private.sai_attendance_manage_class(a.class_id)
      or (private.sai_security_has_role('receptionist') and private.sai_security_branch_member(a.branch_id))
      or (private.sai_security_has_role('student') and s.user_id = (select auth.uid()))
      or (private.sai_security_has_role('parent') and exists (
        select 1 from public.parent_student_links l where l.student_id = s.id
          and l.parent_user_id = (select auth.uid()) and l.verified_at is not null
      ))
    )
  );
$function$
;
revoke all on function "private"."sai_attendance_view_record"(wanted_session uuid, wanted_student uuid) from public,anon,authenticated,service_role;
grant execute on function "private"."sai_attendance_view_record"(wanted_session uuid, wanted_student uuid) to "service_role";
grant execute on function "private"."sai_attendance_view_record"(wanted_session uuid, wanted_student uuid) to "authenticated";
CREATE OR REPLACE FUNCTION private.sai_attendance_view_session(wanted_session uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
  select exists (
    select 1 from public.attendance_sessions a where a.id = wanted_session and (
      private.sai_attendance_manage_class(a.class_id)
      or (private.sai_security_has_role('receptionist') and private.sai_security_branch_member(a.branch_id))
      or exists (select 1 from public.attendance_records r
        where r.attendance_session_id = a.id and private.sai_attendance_view_record(a.id, r.student_id))
    )
  );
$function$
;
revoke all on function "private"."sai_attendance_view_session"(wanted_session uuid) from public,anon,authenticated,service_role;
grant execute on function "private"."sai_attendance_view_session"(wanted_session uuid) to "service_role";
grant execute on function "private"."sai_attendance_view_session"(wanted_session uuid) to "authenticated";
CREATE OR REPLACE FUNCTION private.sai_finance_can_read_student(wanted_student uuid, wanted_branch uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
  select
    exists (
      select 1 from public.user_roles r
      where r.user_id = (select auth.uid())
        and (
          r.role = 'super_admin'
          or (
            r.role in ('admin', 'accountant', 'receptionist')
            and exists (
              select 1 from public.branch_memberships m
              where m.user_id = (select auth.uid())
                and m.branch_id = wanted_branch and m.is_active
            )
          )
        )
    )
    or exists (
      select 1 from public.students s
      where s.id = wanted_student
        and (
          (
            s.user_id = (select auth.uid())
            and exists (
              select 1 from public.user_roles r
              where r.user_id = (select auth.uid()) and r.role = 'student'
            )
          )
          or (
            exists (
              select 1 from public.user_roles r
              where r.user_id = (select auth.uid()) and r.role = 'parent'
            )
            and exists (
              select 1 from public.parent_student_links l
              where l.student_id = s.id
                and l.parent_user_id = (select auth.uid())
                and l.verified_at is not null
            )
          )
        )
    );
$function$
;
revoke all on function "private"."sai_finance_can_read_student"(wanted_student uuid, wanted_branch uuid) from public,anon,authenticated,service_role;
grant execute on function "private"."sai_finance_can_read_student"(wanted_student uuid, wanted_branch uuid) to public;
CREATE OR REPLACE FUNCTION private.sai_finance_has_role(wanted text[])
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
  select exists (
    select 1 from public.user_roles r
    where r.user_id = (select auth.uid()) and r.role::text = any(wanted)
  );
$function$
;
revoke all on function "private"."sai_finance_has_role"(wanted text[]) from public,anon,authenticated,service_role;
grant execute on function "private"."sai_finance_has_role"(wanted text[]) to public;
CREATE OR REPLACE FUNCTION private.sai_finance_staff(wanted_branch uuid, wanted text[])
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
  select private.sai_finance_has_role(array['super_admin'])
    or (private.sai_finance_has_role(wanted) and private.sai_security_branch_member(wanted_branch));
$function$
;
revoke all on function "private"."sai_finance_staff"(wanted_branch uuid, wanted text[]) from public,anon,authenticated,service_role;
grant execute on function "private"."sai_finance_staff"(wanted_branch uuid, wanted text[]) to public;
CREATE OR REPLACE FUNCTION private.sai_learning_can_grade_homework(wanted_homework uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
  select exists (
    select 1 from public.learning_homework h
    where h.id = wanted_homework and private.sai_learning_can_manage_course(h.course_id)
  );
$function$
;
revoke all on function "private"."sai_learning_can_grade_homework"(wanted_homework uuid) from public,anon,authenticated,service_role;
grant execute on function "private"."sai_learning_can_grade_homework"(wanted_homework uuid) to "authenticated";
grant execute on function "private"."sai_learning_can_grade_homework"(wanted_homework uuid) to "service_role";
CREATE OR REPLACE FUNCTION private.sai_learning_can_manage_course(wanted_course uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
  select exists (
    select 1 from public.learning_courses c
    where c.id = wanted_course
      and (
        private.sai_security_has_role('super_admin')
        or (private.sai_security_has_role('admin') and private.sai_security_branch_member(c.branch_id))
        or (
          private.sai_security_has_role('teacher')
          and private.sai_security_branch_member(c.branch_id)
          and (
            c.teacher_id = (select auth.uid())
            or exists (
              select 1 from public.classes cl
              where cl.id = c.class_id and cl.teacher_id = (select auth.uid())
            )
          )
        )
      )
  );
$function$
;
revoke all on function "private"."sai_learning_can_manage_course"(wanted_course uuid) from public,anon,authenticated,service_role;
grant execute on function "private"."sai_learning_can_manage_course"(wanted_course uuid) to "authenticated";
grant execute on function "private"."sai_learning_can_manage_course"(wanted_course uuid) to "service_role";
CREATE OR REPLACE FUNCTION private.sai_learning_can_read_course(wanted_course uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
  select exists (
    select 1 from public.learning_courses c
    where c.id = wanted_course and private.sai_security_can_read_class(c.class_id)
  );
$function$
;
revoke all on function "private"."sai_learning_can_read_course"(wanted_course uuid) from public,anon,authenticated,service_role;
grant execute on function "private"."sai_learning_can_read_course"(wanted_course uuid) to "authenticated";
grant execute on function "private"."sai_learning_can_read_course"(wanted_course uuid) to "service_role";
CREATE OR REPLACE FUNCTION private.sai_learning_can_read_homework(wanted_homework uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
  select exists (
    select 1 from public.learning_homework h
    join public.learning_courses c on c.id = h.course_id
    where h.id = wanted_homework
      and (h.is_published or private.sai_learning_can_manage_course(c.id))
      and private.sai_security_can_read_class(c.class_id)
  );
$function$
;
revoke all on function "private"."sai_learning_can_read_homework"(wanted_homework uuid) from public,anon,authenticated,service_role;
grant execute on function "private"."sai_learning_can_read_homework"(wanted_homework uuid) to "authenticated";
grant execute on function "private"."sai_learning_can_read_homework"(wanted_homework uuid) to "service_role";
CREATE OR REPLACE FUNCTION private.sai_learning_own_student(wanted_student uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
  select exists (
    select 1 from public.students s
    where s.id = wanted_student and s.user_id = (select auth.uid())
  );
$function$
;
revoke all on function "private"."sai_learning_own_student"(wanted_student uuid) from public,anon,authenticated,service_role;
grant execute on function "private"."sai_learning_own_student"(wanted_student uuid) to "authenticated";
grant execute on function "private"."sai_learning_own_student"(wanted_student uuid) to "service_role";
CREATE OR REPLACE FUNCTION private.sai_security_branch_member(wanted_branch uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
  select exists (
    select 1 from public.branch_memberships m
    where m.user_id = (select auth.uid())
      and m.branch_id = wanted_branch and m.is_active
  );
$function$
;
revoke all on function "private"."sai_security_branch_member"(wanted_branch uuid) from public,anon,authenticated,service_role;
grant execute on function "private"."sai_security_branch_member"(wanted_branch uuid) to "service_role";
grant execute on function "private"."sai_security_branch_member"(wanted_branch uuid) to "authenticated";
CREATE OR REPLACE FUNCTION private.sai_security_can_read_branch(wanted_branch uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
  select private.sai_security_has_role('super_admin')
    or (
      private.sai_security_branch_member(wanted_branch)
      and exists (
        select 1 from public.user_roles r
        where r.user_id = (select auth.uid())
          and r.role in (
            'admin', 'teacher', 'accountant', 'receptionist',
            'librarian', 'content_editor'
          )
      )
    )
    or exists (
      select 1 from public.students s
      where s.branch_id = wanted_branch
        and (
          (private.sai_security_has_role('student')
            and s.user_id = (select auth.uid()))
          or (
            private.sai_security_has_role('parent')
            and exists (
              select 1 from public.parent_student_links l
              where l.student_id = s.id
                and l.parent_user_id = (select auth.uid())
                and l.verified_at is not null
            )
          )
        )
    );
$function$
;
revoke all on function "private"."sai_security_can_read_branch"(wanted_branch uuid) from public,anon,authenticated,service_role;
grant execute on function "private"."sai_security_can_read_branch"(wanted_branch uuid) to "service_role";
grant execute on function "private"."sai_security_can_read_branch"(wanted_branch uuid) to "authenticated";
CREATE OR REPLACE FUNCTION private.sai_security_can_read_class(wanted_class uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
  select exists (
    select 1
    from public.classes c
    where c.id = wanted_class
      and (
        private.sai_security_has_role('super_admin')
        or (
          private.sai_security_has_role('admin')
          and private.sai_security_branch_member(c.branch_id)
        )
        or (
          private.sai_security_has_role('teacher')
          and c.teacher_id = (select auth.uid())
          and private.sai_security_branch_member(c.branch_id)
        )
        or exists (
          select 1 from public.students s
          where s.class_id = c.id and s.branch_id = c.branch_id
            and (
              (private.sai_security_has_role('student')
                and s.user_id = (select auth.uid()))
              or (
                private.sai_security_has_role('parent')
                and exists (
                  select 1 from public.parent_student_links l
                  where l.student_id = s.id
                    and l.parent_user_id = (select auth.uid())
                    and l.verified_at is not null
                )
              )
            )
        )
      )
  );
$function$
;
revoke all on function "private"."sai_security_can_read_class"(wanted_class uuid) from public,anon,authenticated,service_role;
grant execute on function "private"."sai_security_can_read_class"(wanted_class uuid) to "service_role";
grant execute on function "private"."sai_security_can_read_class"(wanted_class uuid) to "authenticated";
CREATE OR REPLACE FUNCTION private.sai_security_can_read_session(wanted_session uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
  select private.sai_security_has_role('super_admin')
    or exists (
      select 1 from public.classes c
      where c.session_id = wanted_session
        and private.sai_security_can_read_class(c.id)
    );
$function$
;
revoke all on function "private"."sai_security_can_read_session"(wanted_session uuid) from public,anon,authenticated,service_role;
grant execute on function "private"."sai_security_can_read_session"(wanted_session uuid) to "service_role";
grant execute on function "private"."sai_security_can_read_session"(wanted_session uuid) to "authenticated";
CREATE OR REPLACE FUNCTION private.sai_security_can_read_student(wanted_student uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
  select exists (
    select 1
    from public.students s
    where s.id = wanted_student
      and (
        private.sai_security_has_role('super_admin')
        or (
          private.sai_security_has_role('admin')
          and private.sai_security_branch_member(s.branch_id)
        )
        or (
          private.sai_security_has_role('teacher')
          and private.sai_security_branch_member(s.branch_id)
          and exists (
            select 1 from public.classes c
            where c.id = s.class_id and c.branch_id = s.branch_id
              and c.teacher_id = (select auth.uid())
          )
        )
        or (
          private.sai_security_has_role('student')
          and s.user_id = (select auth.uid())
        )
        or (
          private.sai_security_has_role('parent')
          and exists (
            select 1 from public.parent_student_links l
            where l.student_id = s.id
              and l.parent_user_id = (select auth.uid())
              and l.verified_at is not null
          )
        )
      )
  );
$function$
;
revoke all on function "private"."sai_security_can_read_student"(wanted_student uuid) from public,anon,authenticated,service_role;
grant execute on function "private"."sai_security_can_read_student"(wanted_student uuid) to "service_role";
grant execute on function "private"."sai_security_can_read_student"(wanted_student uuid) to "authenticated";
CREATE OR REPLACE FUNCTION private.sai_security_has_role(wanted_role app_role)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
  select exists (
    select 1 from public.user_roles r
    where r.user_id = (select auth.uid()) and r.role = wanted_role
  );
$function$
;
revoke all on function "private"."sai_security_has_role"(wanted_role app_role) from public,anon,authenticated,service_role;
grant execute on function "private"."sai_security_has_role"(wanted_role app_role) to "service_role";
grant execute on function "private"."sai_security_has_role"(wanted_role app_role) to "authenticated";
CREATE OR REPLACE FUNCTION private.sai_system_settings_log()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 IF TG_OP='DELETE' THEN
  INSERT INTO public.sai_system_settings_audit(category,setting_key,action,actor_user_id)
   VALUES (OLD.category,OLD.setting_key,TG_OP,(SELECT auth.uid()));
  RETURN OLD;
 END IF;
 INSERT INTO public.sai_system_settings_audit(category,setting_key,action,actor_user_id)
  VALUES (NEW.category,NEW.setting_key,TG_OP,(SELECT auth.uid()));
 RETURN NEW;
END $function$
;
revoke all on function "private"."sai_system_settings_log"() from public,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION private.sai_system_settings_stamp()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
 NEW.updated_by:=(SELECT auth.uid());
 NEW.updated_at:=now();
 RETURN NEW;
END $function$
;
revoke all on function "private"."sai_system_settings_stamp"() from public,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.sai_admission_history(p_enquiry_id uuid)
 RETURNS TABLE(entry_id uuid, action text, old_status text, new_status text, changed_columns jsonb, actor_id uuid, actor_name text, occurred_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_branch uuid;
begin
  select e.branch_id into v_branch from public.admissions_enquiries e where e.id = p_enquiry_id;
  if v_branch is null then
    raise exception 'Enquiry not found' using errcode = 'P0002';
  end if;
  if not (public.sai_security_has_role('super_admin')
    or (public.sai_security_branch_member(v_branch)
      and (public.sai_security_has_role('admin') or public.sai_security_has_role('receptionist')))) then
    raise exception 'Not authorized for this branch' using errcode = '42501';
  end if;

  return query
    select a.id,
           a.action,
           nullif(a.metadata ->> 'old_status', ''),
           nullif(a.metadata ->> 'new_status', ''),
           coalesce(a.metadata -> 'changed_columns', '[]'::jsonb),
           a.actor_user_id,
           coalesce(nullif(btrim(p.full_name), ''), 'النظام'),
           a.created_at
    from public.audit_logs a
    left join public.profiles p on p.id = a.actor_user_id
    where a.entity_type = 'admissions_enquiries'
      and a.entity_id = p_enquiry_id
    order by a.created_at, a.id;
end;
$function$
;
revoke all on function "public"."sai_admission_history"(p_enquiry_id uuid) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_admission_history"(p_enquiry_id uuid) to "authenticated";
grant execute on function "public"."sai_admission_history"(p_enquiry_id uuid) to "service_role";
CREATE OR REPLACE FUNCTION public.sai_admission_history_export(p_branch uuid DEFAULT NULL::uuid, p_from timestamp with time zone DEFAULT NULL::timestamp with time zone, p_to timestamp with time zone DEFAULT NULL::timestamp with time zone, p_enquiry_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(application_no text, applicant_full_name text, branch_name text, action text, old_status text, new_status text, changed_columns text, actor_name text, occurred_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_super boolean := public.sai_security_has_role('super_admin');
begin
  if p_enquiry_id is not null then
    if not (v_super or (public.sai_security_branch_member(
        (select e.branch_id from public.admissions_enquiries e where e.id = p_enquiry_id))
      and (public.sai_security_has_role('admin') or public.sai_security_has_role('receptionist')))) then
      raise exception 'Not authorized for this enquiry' using errcode = '42501';
    end if;
  elsif not v_super then
    if p_branch is null then
      raise exception 'Branch is required' using errcode = '22023';
    end if;
    if not (public.sai_security_branch_member(p_branch)
      and (public.sai_security_has_role('admin') or public.sai_security_has_role('receptionist'))) then
      raise exception 'Not authorized for this branch' using errcode = '42501';
    end if;
  end if;

  return query
    select e.application_no,
           e.applicant_full_name,
           b.name,
           a.action,
           nullif(a.metadata ->> 'old_status', ''),
           nullif(a.metadata ->> 'new_status', ''),
           (select string_agg(t.item, ', ')
              from jsonb_array_elements_text(coalesce(a.metadata -> 'changed_columns', '[]'::jsonb)) as t(item)),
           coalesce(nullif(btrim(p.full_name), ''), 'النظام'),
           a.created_at
      from public.audit_logs a
      join public.admissions_enquiries e on e.id = a.entity_id
      left join public.profiles p on p.id = a.actor_user_id
      left join public.branches b on b.id = e.branch_id
     where a.entity_type = 'admissions_enquiries'
       and (p_enquiry_id is null or e.id = p_enquiry_id)
       and (p_branch is null or e.branch_id = p_branch)
       and (p_from is null or a.created_at >= p_from)
       and (p_to is null or a.created_at <= p_to)
     order by a.created_at, a.id;
end;
$function$
;
revoke all on function "public"."sai_admission_history_export"(p_branch uuid, p_from timestamp with time zone, p_to timestamp with time zone, p_enquiry_id uuid) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_admission_history_export"(p_branch uuid, p_from timestamp with time zone, p_to timestamp with time zone, p_enquiry_id uuid) to "authenticated";
grant execute on function "public"."sai_admission_history_export"(p_branch uuid, p_from timestamp with time zone, p_to timestamp with time zone, p_enquiry_id uuid) to "service_role";
CREATE OR REPLACE FUNCTION public.sai_admission_reminder_candidates()
 RETURNS TABLE(enquiry_id uuid, application_no text, applicant_full_name text, email text, phone text, preferred_program text, preferred_level text, branch_name text, session_name text, status text, created_at timestamp with time zone, days_open integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_claim_role text := current_setting('request.jwt.claim.role', true);
begin
  -- Only the server (service role) or a direct database session may read applicant contacts.
  if coalesce(v_claim_role, '') not in ('', 'service_role') then
    raise exception 'Not authorized' using errcode = '42501';
  end if;

  return query
    select e.id,
           e.application_no,
           e.applicant_full_name,
           e.email,
           e.phone,
           e.preferred_program,
           e.preferred_level,
           b.name,
           s.name,
           e.status,
           e.created_at,
           (now()::date - e.created_at::date)
      from public.admissions_enquiries e
      left join public.branches b on b.id = e.branch_id
      left join public.academic_sessions s on s.id = e.academic_session_id
     where e.status = 'new'
       and e.created_at <= now() - interval '3 days'
       and not exists (
         select 1 from public.admission_reminder_log l
          where l.enquiry_id = e.id and l.reminder_kind = 'stale_new'
       )
     order by e.created_at;
end;
$function$
;
revoke all on function "public"."sai_admission_reminder_candidates"() from public,anon,authenticated,service_role;
grant execute on function "public"."sai_admission_reminder_candidates"() to "service_role";
CREATE OR REPLACE FUNCTION public.sai_admission_roster_export(p_branch uuid DEFAULT NULL::uuid, p_session uuid DEFAULT NULL::uuid, p_status text DEFAULT NULL::text, p_from timestamp with time zone DEFAULT NULL::timestamp with time zone, p_to timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS TABLE(application_no text, applicant_full_name text, guardian_name text, phone text, email text, preferred_program text, preferred_level text, branch_name text, session_name text, status text, assigned_name text, source text, notes text, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_super boolean := public.sai_security_has_role('super_admin');
begin
  if not v_super then
    if not (public.sai_security_has_role('admin') or public.sai_security_has_role('receptionist')) then
      raise exception 'Not authorized to export admissions' using errcode = '42501';
    end if;
    if p_branch is null then
      raise exception 'Branch is required' using errcode = '22023';
    end if;
    if not public.sai_security_branch_member(p_branch) then
      raise exception 'Not authorized for this branch' using errcode = '42501';
    end if;
  end if;

  return query
    select e.application_no,
           e.applicant_full_name,
           e.guardian_name,
           e.phone,
           e.email,
           e.preferred_program,
           e.preferred_level,
           b.name,
           s.name,
           e.status,
           coalesce(nullif(btrim(p.full_name), ''), 'غير مسند'),
           e.source,
           e.notes,
           e.created_at,
           e.updated_at
      from public.admissions_enquiries e
      left join public.branches b on b.id = e.branch_id
      left join public.academic_sessions s on s.id = e.academic_session_id
      left join public.profiles p on p.id = e.assigned_to
     where (p_branch is null or e.branch_id = p_branch)
       and (p_session is null or e.academic_session_id = p_session)
       and (p_status is null or e.status = p_status)
       and (p_from is null or e.created_at >= p_from)
       and (p_to is null or e.created_at <= p_to)
     order by e.created_at, e.id;
end;
$function$
;
revoke all on function "public"."sai_admission_roster_export"(p_branch uuid, p_session uuid, p_status text, p_from timestamp with time zone, p_to timestamp with time zone) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_admission_roster_export"(p_branch uuid, p_session uuid, p_status text, p_from timestamp with time zone, p_to timestamp with time zone) to "authenticated";
grant execute on function "public"."sai_admission_roster_export"(p_branch uuid, p_session uuid, p_status text, p_from timestamp with time zone, p_to timestamp with time zone) to "service_role";
CREATE OR REPLACE FUNCTION public.sai_admission_status_email_context(p_enquiry_id uuid)
 RETURNS TABLE(application_no text, applicant_full_name text, email text, status text, previous_status text, preferred_program text, preferred_level text, branch_name text, session_name text, occurrence timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_branch uuid;
begin
  select e.branch_id into v_branch from public.admissions_enquiries e where e.id = p_enquiry_id;
  if v_branch is null then
    raise exception 'Enquiry not found' using errcode = 'P0002';
  end if;
  if not (public.sai_security_has_role('super_admin')
    or (public.sai_security_branch_member(v_branch)
      and (public.sai_security_has_role('admin') or public.sai_security_has_role('receptionist')))) then
    raise exception 'Not authorized for this branch' using errcode = '42501';
  end if;

  return query
    select e.application_no,
           e.applicant_full_name,
           e.email,
           e.status,
           (select nullif(a.metadata ->> 'old_status', '')
              from public.audit_logs a
             where a.entity_type = 'admissions_enquiries'
               and a.entity_id = e.id
               and a.action = 'status_change'
             order by a.created_at desc, a.id desc
             limit 1),
           e.preferred_program,
           e.preferred_level,
           (select b.name from public.branches b where b.id = e.branch_id),
           (select s.name from public.academic_sessions s where s.id = e.academic_session_id),
           e.updated_at
      from public.admissions_enquiries e
     where e.id = p_enquiry_id;
end;
$function$
;
revoke all on function "public"."sai_admission_status_email_context"(p_enquiry_id uuid) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_admission_status_email_context"(p_enquiry_id uuid) to "authenticated";
grant execute on function "public"."sai_admission_status_email_context"(p_enquiry_id uuid) to "service_role";
CREATE OR REPLACE FUNCTION public.sai_admissions_audit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  changed jsonb := '[]'::jsonb;
  old_status text;
begin
  if tg_op = 'UPDATE' then
    old_status := old.status;
    select coalesce(jsonb_agg(k.key order by k.key), '[]'::jsonb)
      into changed from jsonb_each(to_jsonb(new)) k
      where k.value is distinct from to_jsonb(old) -> k.key;
  end if;
  insert into public.audit_logs (actor_user_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), case when tg_op = 'UPDATE' and old.status is distinct from new.status
      then 'status_change' else lower(tg_op) end,
    'admissions_enquiries', new.id,
    jsonb_build_object('source', 'sai_admissions_trigger', 'branch_id', new.branch_id,
      'changed_columns', changed, 'old_status', old_status, 'new_status', new.status));
  return new;
end;
$function$
;
revoke all on function "public"."sai_admissions_audit"() from public,anon,authenticated,service_role;
grant execute on function "public"."sai_admissions_audit"() to "service_role";
CREATE OR REPLACE FUNCTION public.sai_admissions_prepare()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not (public.sai_security_has_role('super_admin')
    or (public.sai_security_branch_member(new.branch_id)
      and (public.sai_security_has_role('admin') or public.sai_security_has_role('receptionist')))) then
    raise exception 'Not authorized for this branch' using errcode = '42501';
  end if;
  if tg_op = 'INSERT' or new.academic_session_id is distinct from old.academic_session_id then
    if not exists (select 1 from public.academic_sessions s
      where s.id = new.academic_session_id and s.is_active) then
      raise exception 'Active session is required' using errcode = '23514';
    end if;
  end if;
  if new.assigned_to is not null and (tg_op = 'INSERT' or new.assigned_to is distinct from old.assigned_to) then
    if not exists (
      select 1 from public.branch_memberships m
      where m.user_id = new.assigned_to and m.branch_id = new.branch_id and m.is_active
        and exists (select 1 from public.user_roles r where r.user_id = m.user_id
          and r.role in ('super_admin','admin','teacher','accountant','receptionist','librarian','content_editor'))
    ) then
      raise exception 'Assignee is not active staff in this branch';
    end if;
  end if;
  new.updated_at := now();
  if new.status in ('enrolled','rejected','withdrawn') then
    if tg_op = 'INSERT' then new.closed_at := now();
    elsif old.status not in ('enrolled','rejected','withdrawn') then new.closed_at := now();
    else new.closed_at := old.closed_at;
    end if;
  else
    new.closed_at := null;
  end if;
  return new;
end;
$function$
;
revoke all on function "public"."sai_admissions_prepare"() from public,anon,authenticated,service_role;
grant execute on function "public"."sai_admissions_prepare"() to "service_role";
CREATE OR REPLACE FUNCTION public.sai_admissions_sessions(wanted_branch uuid)
 RETURNS TABLE(id uuid, name text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if wanted_branch is null or not exists (select 1 from public.branches b where b.id = wanted_branch)
    or not (public.sai_security_has_role('super_admin')
      or (public.sai_security_branch_member(wanted_branch)
        and (public.sai_security_has_role('admin') or public.sai_security_has_role('receptionist')))) then
    raise exception 'Not authorized for this branch' using errcode = '42501';
  end if;
  return query select s.id, s.name from public.academic_sessions s
    where s.is_active order by s.name, s.id;
end;
$function$
;
revoke all on function "public"."sai_admissions_sessions"(wanted_branch uuid) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_admissions_sessions"(wanted_branch uuid) to "service_role";
grant execute on function "public"."sai_admissions_sessions"(wanted_branch uuid) to "authenticated";
CREATE OR REPLACE FUNCTION public.sai_admissions_staff(wanted_branch uuid)
 RETURNS TABLE(user_id uuid, full_name text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not (public.sai_security_has_role('super_admin')
    or (public.sai_security_branch_member(wanted_branch)
      and (public.sai_security_has_role('admin') or public.sai_security_has_role('receptionist')))) then
    raise exception 'Not authorized for this branch' using errcode = '42501';
  end if;
  return query
    select m.user_id, p.full_name
    from public.branch_memberships m
    join public.profiles p on p.id = m.user_id
    where m.branch_id = wanted_branch and m.is_active
      and exists (select 1 from public.user_roles r where r.user_id = m.user_id
        and r.role in ('super_admin','admin','teacher','accountant','receptionist','librarian','content_editor'))
    order by p.full_name, m.user_id;
end;
$function$
;
revoke all on function "public"."sai_admissions_staff"(wanted_branch uuid) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_admissions_staff"(wanted_branch uuid) to "service_role";
grant execute on function "public"."sai_admissions_staff"(wanted_branch uuid) to "authenticated";
CREATE OR REPLACE FUNCTION public.sai_admissions_stale_new_count(p_branch uuid DEFAULT NULL::uuid)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
declare
  v_count integer;
begin
  if p_branch is null then
    if not private.sai_security_has_role('super_admin'::public.app_role) then
      raise exception 'Not authorized' using errcode = '42501';
    end if;
  elsif not (
    private.sai_security_has_role('super_admin'::public.app_role)
    or (
      private.sai_security_branch_member(p_branch)
      and (private.sai_security_has_role('admin'::public.app_role)
        or private.sai_security_has_role('receptionist'::public.app_role))
    )
  ) then
    raise exception 'Not authorized' using errcode = '42501';
  end if;

  select count(*)::integer into v_count
    from public.admissions_enquiries e
   where e.status = 'new'
     and e.created_at <= now() - interval '3 days'
     and (p_branch is null or e.branch_id = p_branch);

  return coalesce(v_count, 0);
end;
$function$
;
revoke all on function "public"."sai_admissions_stale_new_count"(p_branch uuid) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_admissions_stale_new_count"(p_branch uuid) to "authenticated";
grant execute on function "public"."sai_admissions_stale_new_count"(p_branch uuid) to "service_role";
CREATE OR REPLACE FUNCTION public.sai_attendance_audit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare audit_action text;
begin
  if tg_table_name = 'attendance_sessions' then
    if tg_op = 'INSERT' then audit_action := 'create';
    elsif new.status = 'closed' then audit_action := 'close';
    elsif new.status = 'cancelled' then audit_action := 'cancel';
    else audit_action := 'update'; end if;
  elsif tg_op = 'INSERT' then audit_action := 'mark';
  else audit_action := 'correct'; end if;
  insert into public.audit_logs (actor_user_id, action, entity_type, entity_id, metadata)
    values (auth.uid(), audit_action, tg_table_name, new.id,
      jsonb_build_object('source', 'sai_attendance_trigger'));
  return new;
end;
$function$
;
revoke all on function "public"."sai_attendance_audit"() from public,anon,authenticated,service_role;
grant execute on function "public"."sai_attendance_audit"() to "service_role";
CREATE OR REPLACE FUNCTION public.sai_attendance_classes()
 RETURNS TABLE(id uuid, name text, branch_id uuid, academic_session_id uuid, teacher_id uuid)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
  select c.id, c.name, c.branch_id, c.session_id, c.teacher_id
  from public.classes c where private.sai_attendance_manage_class(c.id)
    or (public.sai_security_has_role('receptionist') and public.sai_security_branch_member(c.branch_id))
    or public.sai_security_can_read_class(c.id)
  order by c.name, c.id;
$function$
;
revoke all on function "public"."sai_attendance_classes"() from public,anon,authenticated,service_role;
grant execute on function "public"."sai_attendance_classes"() to "service_role";
grant execute on function "public"."sai_attendance_classes"() to "authenticated";
CREATE OR REPLACE FUNCTION public.sai_attendance_prepare_record()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
declare session_row public.attendance_sessions%rowtype;
begin
  select * into session_row from public.attendance_sessions a
    where a.id = new.attendance_session_id for update;
  if not found then raise exception 'Attendance session not found' using errcode = '23503'; end if;
  if not (private.sai_attendance_manage_class(session_row.class_id)
    or (tg_op = 'UPDATE' and public.sai_security_has_role('receptionist')
      and public.sai_security_branch_member(session_row.branch_id))) then
    raise exception 'Not authorized for this attendance' using errcode = '42501';
  end if;
  if session_row.status <> 'open' then
    raise exception 'Attendance session is read-only' using errcode = '23514';
  end if;
  if tg_op = 'INSERT' then
    perform 1 from public.students s where s.id = new.student_id
      and s.class_id = session_row.class_id and s.branch_id = session_row.branch_id for share;
    if not found then
      raise exception 'Student does not belong to this class' using errcode = '23514';
    end if;
  end if;
  new.marked_by := auth.uid();
  new.marked_at := now();
  new.updated_at := now();
  return new;
end;
$function$
;
revoke all on function "public"."sai_attendance_prepare_record"() from public,anon,authenticated,service_role;
grant execute on function "public"."sai_attendance_prepare_record"() to "service_role";
CREATE OR REPLACE FUNCTION public.sai_attendance_prepare_session()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
begin
  if not private.sai_attendance_manage_class(new.class_id) then
    raise exception 'Not authorized for this class' using errcode = '42501';
  end if;
  if tg_op = 'UPDATE' and old.status <> 'open' then
    raise exception 'Attendance session is read-only' using errcode = '23514';
  end if;
  if new.attendance_date > (now() at time zone 'Asia/Aden')::date then
    raise exception 'Future attendance date is not permitted' using errcode = '23514';
  end if;
  if not exists (select 1 from public.classes c where c.id = new.class_id
    and c.branch_id = new.branch_id and c.session_id = new.academic_session_id) then
    raise exception 'Class, branch and academic session do not match' using errcode = '23514';
  end if;
  new.updated_at := now();
  return new;
end;
$function$
;
revoke all on function "public"."sai_attendance_prepare_session"() from public,anon,authenticated,service_role;
grant execute on function "public"."sai_attendance_prepare_session"() to "service_role";
CREATE OR REPLACE FUNCTION public.sai_attendance_roster(wanted_session uuid)
 RETURNS TABLE(student_id uuid, full_name text, record_id uuid, attendance_status text, note text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
declare session_row public.attendance_sessions%rowtype; manager boolean;
begin
  select * into session_row from public.attendance_sessions where id = wanted_session;
  if not found then raise exception 'Attendance session not found' using errcode = '42501'; end if;
  manager := private.sai_attendance_manage_class(session_row.class_id);
  if not (manager or (public.sai_security_has_role('receptionist')
    and public.sai_security_branch_member(session_row.branch_id))) then
    raise exception 'Not authorized for roster' using errcode = '42501';
  end if;
  return query select s.id, s.full_name, r.id, r.status, r.note
    from public.students s
    left join public.attendance_records r on r.student_id = s.id and r.attendance_session_id = wanted_session
    where (manager and s.class_id = session_row.class_id and s.branch_id = session_row.branch_id)
      or r.id is not null
    order by s.full_name, s.id;
end;
$function$
;
revoke all on function "public"."sai_attendance_roster"(wanted_session uuid) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_attendance_roster"(wanted_session uuid) to "service_role";
grant execute on function "public"."sai_attendance_roster"(wanted_session uuid) to "authenticated";
CREATE OR REPLACE FUNCTION public.sai_directory()
 RETURNS TABLE(user_id uuid, full_name text, email text, preferred_locale text, has_profile boolean, signed_up_at timestamp with time zone, roles text[])
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.sai_security_has_role('super_admin') then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  return query
    select u.id,
           coalesce(nullif(p.full_name, ''),
                    nullif(u.raw_user_meta_data ->> 'full_name', ''),
                    u.email::text,
                    'Unnamed account')::text as full_name,
           coalesce(p.email, u.email)::text as email,
           coalesce(p.preferred_locale, 'ar')::text as preferred_locale,
           (p.id is not null) as has_profile,
           u.created_at as signed_up_at,
           coalesce((select array_agg(r.role::text) from public.user_roles r where r.user_id = u.id),
                    array[]::text[]) as roles
    from auth.users u
    left join public.profiles p on p.id = u.id
    order by 2;
end;
$function$
;
revoke all on function "public"."sai_directory"() from public,anon,authenticated,service_role;
grant execute on function "public"."sai_directory"() to "authenticated";
grant execute on function "public"."sai_directory"() to "service_role";
CREATE OR REPLACE FUNCTION public.sai_finance_assign(wanted_group uuid, wanted_student uuid, wanted_discount numeric, wanted_due date)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
declare g public.fee_groups%rowtype; student_class uuid; student_branch uuid;
  result uuid; discount numeric;
begin
  select * into g from public.fee_groups where id = wanted_group and is_active for share;
  if not found or not public.sai_finance_staff(g.branch_id, array['admin', 'accountant']) then
    raise exception 'Fee group unavailable or unauthorized' using errcode = '42501';
  end if;
  if wanted_discount is null or wanted_discount < 0 then
    raise exception 'Invalid discount' using errcode = '23514';
  end if;
  discount := round(wanted_discount, 2);
  if discount > g.amount then
    raise exception 'Invalid discount' using errcode = '23514';
  end if;
  select s.class_id, s.branch_id into student_class, student_branch
  from public.students s where s.id = wanted_student;
  if not found or student_branch <> g.branch_id then
    raise exception 'Student is not enrolled in this branch' using errcode = '23514';
  end if;
  if student_class is not null then
    perform 1 from public.classes c
    where c.id = student_class and c.branch_id = g.branch_id
      and c.session_id = g.academic_session_id;
    if not found then
      raise exception 'Student class session does not match the fee group' using errcode = '23514';
    end if;
  end if;
  insert into public.fee_assignments(fee_group_id, student_id, branch_id, academic_session_id,
    class_id, original_amount, discount_amount, due_date, created_by)
  values (g.id, wanted_student, g.branch_id, g.academic_session_id, student_class, g.amount,
    discount, coalesce(wanted_due, g.due_date), auth.uid())
  returning id into result;
  insert into public.finance_audit_log(branch_id, actor_id, action, entity_id, details)
  values (g.branch_id, auth.uid(), 'assign', result,
    jsonb_build_object('group_id', g.id, 'original_amount', g.amount, 'discount', discount));
  return result;
end;
$function$
;
revoke all on function "public"."sai_finance_assign"(wanted_group uuid, wanted_student uuid, wanted_discount numeric, wanted_due date) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_finance_assign"(wanted_group uuid, wanted_student uuid, wanted_discount numeric, wanted_due date) to "authenticated";
CREATE OR REPLACE FUNCTION public.sai_finance_assignments()
 RETURNS TABLE(id uuid, fee_group_id uuid, student_id uuid, branch_id uuid, academic_session_id uuid, class_id uuid, original_amount numeric, discount_amount numeric, final_amount numeric, due_date date, status text, balance numeric)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
  select a.id, a.fee_group_id, a.student_id, a.branch_id, a.academic_session_id, a.class_id,
    a.original_amount, a.discount_amount, a.final_amount, a.due_date,
    case
      when a.cancelled_at is not null then 'cancelled'
      when public.sai_finance_balance(a.id) <= 0
        and exists (select 1 from public.fee_waivers w where w.assignment_id = a.id) then 'waived'
      when public.sai_finance_balance(a.id) <= 0 then 'paid'
      when exists (select 1 from public.fee_payments p
        where p.assignment_id = a.id and p.voided_at is null) then 'partial'
      else 'unpaid'
    end,
    case when a.cancelled_at is not null then 0 else greatest(public.sai_finance_balance(a.id), 0) end
  from public.fee_assignments a
  where public.sai_finance_can_read_student(a.student_id, a.branch_id)
  order by a.created_at desc, a.id;
$function$
;
revoke all on function "public"."sai_finance_assignments"() from public,anon,authenticated,service_role;
grant execute on function "public"."sai_finance_assignments"() to "authenticated";
CREATE OR REPLACE FUNCTION public.sai_finance_audit(wanted_branch uuid)
 RETURNS TABLE(id bigint, actor_id uuid, action text, entity_id uuid, details jsonb, created_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
  select l.id, l.actor_id, l.action, l.entity_id, l.details, l.created_at
  from public.finance_audit_log l
  where l.branch_id = wanted_branch
    and public.sai_finance_staff(wanted_branch, array['accountant'])
  order by l.id desc;
$function$
;
revoke all on function "public"."sai_finance_audit"(wanted_branch uuid) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_finance_audit"(wanted_branch uuid) to "authenticated";
CREATE OR REPLACE FUNCTION public.sai_finance_balance(wanted uuid)
 RETURNS numeric
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
  select a.final_amount
    - coalesce((select sum(p.amount) from public.fee_payments p
        where p.assignment_id = a.id and p.voided_at is null), 0)
    - coalesce((select sum(w.amount) from public.fee_waivers w
        where w.assignment_id = a.id), 0)
  from public.fee_assignments a where a.id = wanted;
$function$
;
revoke all on function "public"."sai_finance_balance"(wanted uuid) from public,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.sai_finance_can_read_student(wanted_student uuid, wanted_branch uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
  select private.sai_finance_can_read_student(wanted_student, wanted_branch);
$function$
;
revoke all on function "public"."sai_finance_can_read_student"(wanted_student uuid, wanted_branch uuid) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_finance_can_read_student"(wanted_student uuid, wanted_branch uuid) to "authenticated";
CREATE OR REPLACE FUNCTION public.sai_finance_cancel(wanted_assignment uuid, wanted_reason text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
declare a public.fee_assignments%rowtype;
begin
  select * into a from public.fee_assignments where id = wanted_assignment for update;
  if not found or not public.sai_finance_staff(a.branch_id, array['admin', 'accountant']) then
    raise exception 'Assignment unavailable or unauthorized' using errcode = '42501';
  end if;
  if a.cancelled_at is not null or wanted_reason is null or btrim(wanted_reason) = ''
    or exists (select 1 from public.fee_payments p
      where p.assignment_id = a.id and p.voided_at is null) then
    raise exception 'Cancellation requires a reason and no posted payment' using errcode = '23514';
  end if;
  update public.fee_assignments
    set cancelled_at = now(), cancelled_by = auth.uid(), cancellation_reason = btrim(wanted_reason)
    where id = a.id;
  insert into public.finance_audit_log(branch_id, actor_id, action, entity_id, details)
  values (a.branch_id, auth.uid(), 'cancel', a.id, jsonb_build_object('reason', btrim(wanted_reason)));
end;
$function$
;
revoke all on function "public"."sai_finance_cancel"(wanted_assignment uuid, wanted_reason text) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_finance_cancel"(wanted_assignment uuid, wanted_reason text) to "authenticated";
CREATE OR REPLACE FUNCTION public.sai_finance_groups()
 RETURNS TABLE(id uuid, branch_id uuid, academic_session_id uuid, name text, description text, amount numeric, currency text, due_date date, is_active boolean, created_by uuid, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
  select g.id, g.branch_id, g.academic_session_id, g.name, g.description, g.amount, g.currency,
    g.due_date, g.is_active, g.created_by, g.created_at, g.updated_at
  from public.fee_groups g
  where public.sai_finance_staff(g.branch_id, array['admin', 'accountant', 'receptionist'])
  order by g.created_at desc, g.id;
$function$
;
revoke all on function "public"."sai_finance_groups"() from public,anon,authenticated,service_role;
grant execute on function "public"."sai_finance_groups"() to "authenticated";
CREATE OR REPLACE FUNCTION public.sai_finance_has_role(wanted text[])
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
  select private.sai_finance_has_role(wanted);
$function$
;
revoke all on function "public"."sai_finance_has_role"(wanted text[]) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_finance_has_role"(wanted text[]) to "authenticated";
CREATE OR REPLACE FUNCTION public.sai_finance_pay(wanted_assignment uuid, wanted_amount numeric, wanted_method text, wanted_reference text, wanted_key uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
declare a public.fee_assignments%rowtype; p public.fee_payments%rowtype; result uuid;
  amount numeric; ref text := nullif(btrim(wanted_reference), '');
begin
  select * into a from public.fee_assignments where id = wanted_assignment for update;
  if not found or a.cancelled_at is not null then
    raise exception 'Assignment unavailable' using errcode = '42501';
  end if;
  if not public.sai_finance_staff(a.branch_id, array['admin', 'accountant', 'receptionist']) then
    raise exception 'Assignment unavailable or unauthorized' using errcode = '42501';
  end if;
  if wanted_amount is null or wanted_amount <= 0 or wanted_method is null
    or wanted_method not in ('cash', 'bank_transfer', 'wallet', 'card') or wanted_key is null
    or (wanted_method <> 'cash' and ref is null) then
    raise exception 'Invalid payment' using errcode = '23514';
  end if;
  amount := round(wanted_amount, 2);
  if amount <= 0 then
    raise exception 'Invalid payment amount' using errcode = '23514';
  end if;
  select * into p from public.fee_payments where idempotency_key = wanted_key;
  if found then
    if p.assignment_id <> wanted_assignment or p.amount <> amount or p.method <> wanted_method
      or p.transaction_reference is distinct from ref then
      raise exception 'Idempotency key conflict' using errcode = '23505';
    end if;
    return p.id;
  end if;
  if amount > public.sai_finance_balance(a.id) then
    raise exception 'Payment exceeds outstanding balance' using errcode = '23514';
  end if;
  insert into public.fee_payments(assignment_id, branch_id, amount, method, transaction_reference,
    idempotency_key, receipt_number, posted_by)
  values (a.id, a.branch_id, amount, wanted_method, ref, wanted_key,
    'SAI-' || to_char(now() at time zone 'Asia/Aden', 'YYYY') || '-' ||
      lpad(nextval('public.finance_receipt_seq')::text, 6, '0'), auth.uid())
  returning id into result;
  insert into public.finance_audit_log(branch_id, actor_id, action, entity_id, details)
  values (a.branch_id, auth.uid(), 'payment_post', result,
    jsonb_build_object('amount', amount, 'assignment_id', a.id));
  return result;
end;
$function$
;
revoke all on function "public"."sai_finance_pay"(wanted_assignment uuid, wanted_amount numeric, wanted_method text, wanted_reference text, wanted_key uuid) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_finance_pay"(wanted_assignment uuid, wanted_amount numeric, wanted_method text, wanted_reference text, wanted_key uuid) to "authenticated";
CREATE OR REPLACE FUNCTION public.sai_finance_payments(wanted_assignment uuid)
 RETURNS TABLE(id uuid, assignment_id uuid, amount numeric, currency text, method text, transaction_reference text, receipt_number text, posted_by uuid, posted_at timestamp with time zone, voided_at timestamp with time zone, voided_by uuid, void_reason text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
  select p.id, p.assignment_id, p.amount, p.currency, p.method, p.transaction_reference,
    p.receipt_number, p.posted_by, p.posted_at, p.voided_at, p.voided_by, p.void_reason
  from public.fee_payments p
  join public.fee_assignments a on a.id = p.assignment_id
  where p.assignment_id = wanted_assignment
    and public.sai_finance_can_read_student(a.student_id, a.branch_id)
  order by p.posted_at desc, p.id;
$function$
;
revoke all on function "public"."sai_finance_payments"(wanted_assignment uuid) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_finance_payments"(wanted_assignment uuid) to "authenticated";
CREATE OR REPLACE FUNCTION public.sai_finance_refund(wanted_payment uuid, wanted_amount numeric, wanted_method text, wanted_reference text, wanted_reason text, wanted_key uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
declare p public.fee_payments%rowtype; r public.fee_refunds%rowtype; amount numeric;
  ref text := nullif(btrim(wanted_reference), ''); result uuid; already numeric;
begin
  if not public.sai_finance_has_role(array['super_admin']) then
    raise exception 'Only a super admin may issue refunds' using errcode = '42501';
  end if;
  select * into p from public.fee_payments where id = wanted_payment;
  if not found then
    raise exception 'Payment not found' using errcode = '23503';
  end if;
  if wanted_key is null then
    raise exception 'Refund key required' using errcode = '23514';
  end if;
  amount := round(wanted_amount, 2);
  select * into r from public.fee_refunds where idempotency_key = wanted_key;
  if found then
    if r.payment_id is distinct from wanted_payment or r.amount is distinct from amount
      or r.method is distinct from wanted_method or r.reference is distinct from ref
      or r.reason is distinct from btrim(wanted_reason) then
      raise exception 'Refund idempotency key conflict' using errcode = '23505';
    end if;
    return r.id;
  end if;
  select coalesce(sum(x.amount), 0) into already
  from public.fee_refunds x where x.payment_id = p.id;
  if p.voided_at is null or amount is null or amount <= 0
    or wanted_method is null or wanted_method not in ('cash', 'bank_transfer', 'wallet', 'card')
    or (wanted_method <> 'cash' and ref is null)
    or wanted_reason is null or btrim(wanted_reason) = ''
    or amount > p.amount - already then
    raise exception 'Invalid refund or refund exceeds remaining amount' using errcode = '23514';
  end if;
  insert into public.fee_refunds(payment_id, branch_id, amount, method, reference, refund_number,
    reason, issued_by, idempotency_key)
  values (p.id, p.branch_id, amount, wanted_method, ref,
    'SAI-R-' || to_char(now() at time zone 'Asia/Aden', 'YYYY') || '-' ||
      lpad(nextval('public.finance_refund_seq')::text, 6, '0'),
    btrim(wanted_reason), auth.uid(), wanted_key)
  returning id into result;
  insert into public.finance_audit_log(branch_id, actor_id, action, entity_id, details)
  values (p.branch_id, auth.uid(), 'refund', result,
    jsonb_build_object('payment_id', p.id, 'amount', amount, 'reason', btrim(wanted_reason)));
  return result;
end;
$function$
;
revoke all on function "public"."sai_finance_refund"(wanted_payment uuid, wanted_amount numeric, wanted_method text, wanted_reference text, wanted_reason text, wanted_key uuid) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_finance_refund"(wanted_payment uuid, wanted_amount numeric, wanted_method text, wanted_reference text, wanted_reason text, wanted_key uuid) to "authenticated";
CREATE OR REPLACE FUNCTION public.sai_finance_refunds(wanted_payment uuid)
 RETURNS TABLE(id uuid, payment_id uuid, amount numeric, method text, reference text, refund_number text, reason text, issued_by uuid, issued_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
  select r.id, r.payment_id, r.amount, r.method, r.reference, r.refund_number, r.reason,
    r.issued_by, r.issued_at
  from public.fee_refunds r
  join public.fee_payments p on p.id = r.payment_id
  where r.payment_id = wanted_payment
    and public.sai_finance_staff(r.branch_id, array['accountant'])
  order by r.issued_at desc, r.id;
$function$
;
revoke all on function "public"."sai_finance_refunds"(wanted_payment uuid) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_finance_refunds"(wanted_payment uuid) to "authenticated";
CREATE OR REPLACE FUNCTION public.sai_finance_save_group(wanted_id uuid, wanted_branch uuid, wanted_session uuid, wanted_name text, wanted_description text, wanted_amount numeric, wanted_due date, wanted_active boolean)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
declare group_row public.fee_groups%rowtype; group_amount numeric;
begin
  if auth.uid() is null
    or not public.sai_finance_staff(wanted_branch, array['admin', 'accountant']) then
    raise exception 'Not authorized for this branch' using errcode = '42501';
  end if;
  if wanted_name is null or btrim(wanted_name) = '' or wanted_amount is null
    or wanted_amount < 0 or wanted_due is null or wanted_active is null or wanted_session is null then
    raise exception 'Invalid fee group' using errcode = '23514';
  end if;
  group_amount := round(wanted_amount, 2);
  if wanted_id is null then
    insert into public.fee_groups(branch_id, academic_session_id, name, description, amount,
      due_date, is_active, created_by)
    values (wanted_branch, wanted_session, btrim(wanted_name), nullif(btrim(wanted_description), ''),
      group_amount, wanted_due, wanted_active, auth.uid())
    returning * into group_row;
  else
    update public.fee_groups
      set name = btrim(wanted_name), description = nullif(btrim(wanted_description), ''),
        amount = group_amount, due_date = wanted_due, is_active = wanted_active, updated_at = now()
      where id = wanted_id and branch_id = wanted_branch and academic_session_id = wanted_session
      returning * into group_row;
    if not found then
      raise exception 'Fee group not found or scope changed' using errcode = '42501';
    end if;
  end if;
  insert into public.finance_audit_log(branch_id, actor_id, action, entity_id, details)
  values (group_row.branch_id, auth.uid(),
    case when wanted_id is null then 'group_create' else 'group_update' end,
    group_row.id,
    jsonb_build_object('amount', group_row.amount, 'due_date', group_row.due_date,
      'is_active', group_row.is_active));
  return group_row.id;
end;
$function$
;
revoke all on function "public"."sai_finance_save_group"(wanted_id uuid, wanted_branch uuid, wanted_session uuid, wanted_name text, wanted_description text, wanted_amount numeric, wanted_due date, wanted_active boolean) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_finance_save_group"(wanted_id uuid, wanted_branch uuid, wanted_session uuid, wanted_name text, wanted_description text, wanted_amount numeric, wanted_due date, wanted_active boolean) to "authenticated";
CREATE OR REPLACE FUNCTION public.sai_finance_staff(wanted_branch uuid, wanted text[])
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
  select private.sai_finance_staff(wanted_branch, wanted);
$function$
;
revoke all on function "public"."sai_finance_staff"(wanted_branch uuid, wanted text[]) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_finance_staff"(wanted_branch uuid, wanted text[]) to "authenticated";
CREATE OR REPLACE FUNCTION public.sai_finance_void(wanted_payment uuid, wanted_reason text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
declare p public.fee_payments%rowtype; a public.fee_assignments%rowtype;
begin
  select * into p from public.fee_payments where id = wanted_payment;
  if not found or not public.sai_finance_staff(p.branch_id, array['accountant']) then
    raise exception 'Payment unavailable or unauthorized' using errcode = '42501';
  end if;
  if wanted_reason is null or length(btrim(wanted_reason)) < 10 then
    raise exception 'Void reason must have at least 10 characters' using errcode = '23514';
  end if;
  select * into a from public.fee_assignments where id = p.assignment_id for update;
  update public.fee_payments
    set voided_at = now(), voided_by = auth.uid(), void_reason = btrim(wanted_reason)
    where id = p.id and voided_at is null;
  if not found then
    raise exception 'Payment already voided' using errcode = '23514';
  end if;
  insert into public.finance_audit_log(branch_id, actor_id, action, entity_id, details)
  values (p.branch_id, auth.uid(), 'payment_void', p.id,
    jsonb_build_object('reason', btrim(wanted_reason)));
end;
$function$
;
revoke all on function "public"."sai_finance_void"(wanted_payment uuid, wanted_reason text) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_finance_void"(wanted_payment uuid, wanted_reason text) to "authenticated";
CREATE OR REPLACE FUNCTION public.sai_finance_waive(wanted_assignment uuid, wanted_reason text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
declare a public.fee_assignments%rowtype; amount numeric; result uuid;
begin
  select * into a from public.fee_assignments where id = wanted_assignment for update;
  if not found or not public.sai_finance_staff(a.branch_id, array['accountant']) then
    raise exception 'Assignment unavailable or unauthorized' using errcode = '42501';
  end if;
  amount := public.sai_finance_balance(a.id);
  if a.cancelled_at is not null or amount <= 0 or wanted_reason is null or btrim(wanted_reason) = '' then
    raise exception 'Waiver requires an outstanding balance and reason' using errcode = '23514';
  end if;
  insert into public.fee_waivers(assignment_id, amount, reason, waived_by)
  values (a.id, amount, btrim(wanted_reason), auth.uid()) returning id into result;
  insert into public.finance_audit_log(branch_id, actor_id, action, entity_id, details)
  values (a.branch_id, auth.uid(), 'waive', result,
    jsonb_build_object('assignment_id', a.id, 'amount', amount, 'reason', btrim(wanted_reason)));
  return result;
end;
$function$
;
revoke all on function "public"."sai_finance_waive"(wanted_assignment uuid, wanted_reason text) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_finance_waive"(wanted_assignment uuid, wanted_reason text) to "authenticated";
CREATE OR REPLACE FUNCTION public.sai_learning_can_grade_homework(wanted_homework uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$ select private.sai_learning_can_grade_homework($1) $function$
;
revoke all on function "public"."sai_learning_can_grade_homework"(wanted_homework uuid) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_learning_can_grade_homework"(wanted_homework uuid) to "authenticated";
grant execute on function "public"."sai_learning_can_grade_homework"(wanted_homework uuid) to "service_role";
CREATE OR REPLACE FUNCTION public.sai_learning_can_manage_course(wanted_course uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$ select private.sai_learning_can_manage_course($1) $function$
;
revoke all on function "public"."sai_learning_can_manage_course"(wanted_course uuid) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_learning_can_manage_course"(wanted_course uuid) to "authenticated";
grant execute on function "public"."sai_learning_can_manage_course"(wanted_course uuid) to "service_role";
CREATE OR REPLACE FUNCTION public.sai_learning_can_read_course(wanted_course uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$ select private.sai_learning_can_read_course($1) $function$
;
revoke all on function "public"."sai_learning_can_read_course"(wanted_course uuid) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_learning_can_read_course"(wanted_course uuid) to "authenticated";
grant execute on function "public"."sai_learning_can_read_course"(wanted_course uuid) to "service_role";
CREATE OR REPLACE FUNCTION public.sai_learning_can_read_homework(wanted_homework uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$ select private.sai_learning_can_read_homework($1) $function$
;
revoke all on function "public"."sai_learning_can_read_homework"(wanted_homework uuid) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_learning_can_read_homework"(wanted_homework uuid) to "authenticated";
grant execute on function "public"."sai_learning_can_read_homework"(wanted_homework uuid) to "service_role";
CREATE OR REPLACE FUNCTION public.sai_learning_own_student(wanted_student uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$ select private.sai_learning_own_student($1) $function$
;
revoke all on function "public"."sai_learning_own_student"(wanted_student uuid) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_learning_own_student"(wanted_student uuid) to "authenticated";
grant execute on function "public"."sai_learning_own_student"(wanted_student uuid) to "service_role";
CREATE OR REPLACE FUNCTION public.sai_library_issue(p_item uuid, p_student uuid, p_due date)
 RETURNS uuid
 LANGUAGE sql
AS $function$
  with updated as (
    update public.library_items
      set copies_available = copies_available - 1, updated_at = now()
    where id = p_item and is_active and copies_available > 0
    returning id, branch_id
  )
  insert into public.library_loans(item_id, branch_id, student_id, issued_by, due_date)
  select updated.id, updated.branch_id, p_student, auth.uid(), p_due from updated
  returning id;
$function$
;
revoke all on function "public"."sai_library_issue"(p_item uuid, p_student uuid, p_due date) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_library_issue"(p_item uuid, p_student uuid, p_due date) to "authenticated";
CREATE OR REPLACE FUNCTION public.sai_library_return(p_loan uuid)
 RETURNS void
 LANGUAGE sql
AS $function$
  with returned as (
    update public.library_loans
      set returned_at = now(), returned_by = auth.uid()
    where id = p_loan and returned_at is null
    returning item_id
  )
  update public.library_items i
    set copies_available = least(i.copies_total, i.copies_available + 1), updated_at = now()
    from returned r where i.id = r.item_id;
$function$
;
revoke all on function "public"."sai_library_return"(p_loan uuid) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_library_return"(p_loan uuid) to "authenticated";
CREATE OR REPLACE FUNCTION public.sai_management_audit_mutation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  new_row jsonb := to_jsonb(new);
  old_row jsonb;
  changed_columns jsonb;
  target_id uuid;
begin
  if tg_op = 'UPDATE' then
    old_row := to_jsonb(old);
    select coalesce(jsonb_agg(k.key order by k.key), '[]'::jsonb)
      into changed_columns
      from jsonb_each(new_row) as k
      where k.value is distinct from old_row -> k.key;
  else
    changed_columns := '[]'::jsonb;
  end if;
  target_id := case when tg_table_name = 'branch_memberships'
    then (new_row ->> 'branch_id')::uuid else (new_row ->> 'id')::uuid end;
  insert into public.audit_logs (actor_user_id, action, entity_type, entity_id, metadata)
  values (
    auth.uid(), lower(tg_op), tg_table_name, target_id,
    jsonb_build_object('source', 'sai_management_trigger',
      'changed_columns', changed_columns,
      'branch_id', case when tg_table_name = 'branches' then new_row -> 'id'
        else new_row -> 'branch_id' end,
      'membership_user_id', case when tg_table_name = 'branch_memberships'
        then new_row -> 'user_id' else null end)
  );
  return new;
end;
$function$
;
revoke all on function "public"."sai_management_audit_mutation"() from public,anon,authenticated,service_role;
grant execute on function "public"."sai_management_audit_mutation"() to "service_role";
CREATE OR REPLACE FUNCTION public.sai_management_validate_student_class()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not (public.sai_security_has_role('super_admin') or
    (public.sai_security_has_role('admin') and public.sai_security_branch_member(new.branch_id))) then
    raise exception 'Not authorized for this branch' using errcode = '42501';
  end if;
  if new.class_id is not null and not exists (
    select 1 from public.classes c
    where c.id = new.class_id and c.branch_id = new.branch_id
  ) then
    raise exception 'Invalid class or branch';
  end if;
  return new;
end;
$function$
;
revoke all on function "public"."sai_management_validate_student_class"() from public,anon,authenticated,service_role;
grant execute on function "public"."sai_management_validate_student_class"() to "service_role";
CREATE OR REPLACE FUNCTION public.sai_public_admission_history(p_reference text)
 RETURNS TABLE(action text, new_status text, occurred_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id uuid;
begin
  if p_reference is null or length(btrim(p_reference)) < 6 then
    raise exception 'INVALID_REFERENCE' using errcode = '22023';
  end if;

  select e.id into v_id
  from public.admissions_enquiries e
  where upper(e.application_no) = upper(btrim(p_reference))
  limit 1;

  if v_id is null then
    return;
  end if;

  return query
    select a.action,
           coalesce(nullif(a.metadata ->> 'new_status', ''), 'new'),
           a.created_at
    from public.audit_logs a
    where a.entity_type = 'admissions_enquiries'
      and a.entity_id = v_id
      and a.action in ('insert', 'status_change')
    order by a.created_at, a.id;
end;
$function$
;
revoke all on function "public"."sai_public_admission_history"(p_reference text) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_public_admission_history"(p_reference text) to "service_role";
grant execute on function "public"."sai_public_admission_history"(p_reference text) to "anon";
grant execute on function "public"."sai_public_admission_history"(p_reference text) to "authenticated";
CREATE OR REPLACE FUNCTION public.sai_public_admission_status(p_reference text)
 RETURNS TABLE(application_no text, applicant_name text, program text, level text, status text, branch_name text, session_name text, submitted_at timestamp with time zone, status_updated_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if p_reference is null or length(btrim(p_reference)) < 6 then
    raise exception 'INVALID_REFERENCE' using errcode = '22023';
  end if;
  return query
    select e.application_no,
           e.applicant_full_name,
           e.preferred_program,
           e.preferred_level,
           e.status,
           b.name,
           s.name,
           e.created_at,
           e.updated_at
    from public.admissions_enquiries e
    join public.branches b on b.id = e.branch_id
    join public.academic_sessions s on s.id = e.academic_session_id
    where upper(e.application_no) = upper(btrim(p_reference))
    limit 1;
end;
$function$
;
revoke all on function "public"."sai_public_admission_status"(p_reference text) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_public_admission_status"(p_reference text) to "service_role";
grant execute on function "public"."sai_public_admission_status"(p_reference text) to "anon";
grant execute on function "public"."sai_public_admission_status"(p_reference text) to "authenticated";
CREATE OR REPLACE FUNCTION public.sai_public_admission_submit(p_full_name text, p_phone text, p_email text, p_program text, p_message text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_branch uuid;
  v_session uuid;
  v_creator uuid;
  v_ref text;
begin
  if length(btrim(coalesce(p_full_name, ''))) < 2 then
    raise exception 'INVALID_NAME' using errcode = '22023';
  end if;
  if length(btrim(coalesce(p_phone, ''))) < 6 then
    raise exception 'INVALID_PHONE' using errcode = '22023';
  end if;
  if btrim(coalesce(p_email, '')) <> '' and p_email !~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'INVALID_EMAIL' using errcode = '22023';
  end if;
  if length(coalesce(p_message, '')) > 500 then
    raise exception 'MESSAGE_TOO_LONG' using errcode = '22023';
  end if;

  select b.id into v_branch from public.branches b
    where b.is_active order by b.created_at, b.id limit 1;
  select s.id into v_session from public.academic_sessions s
    where s.is_active order by s.starts_on desc, s.id limit 1;
  if v_branch is null or v_session is null then
    raise exception 'NO_ACTIVE_TERM' using errcode = 'P0001';
  end if;
  select r.user_id into v_creator from public.user_roles r
    where r.role = 'super_admin' order by r.assigned_at, r.user_id limit 1;
  if v_creator is null then
    raise exception 'NO_ADMISSIONS_OWNER' using errcode = 'P0001';
  end if;

  perform set_config('sai.public_web_enquiry', 'on', true);
  insert into public.admissions_enquiries (
    branch_id, academic_session_id, applicant_full_name, phone, email,
    preferred_program, source, notes, status, created_by
  ) values (
    v_branch, v_session, btrim(p_full_name), nullif(btrim(p_phone), ''), nullif(btrim(p_email), ''),
    nullif(btrim(p_program), ''), 'website', nullif(left(coalesce(p_message, ''), 500), ''), 'new', v_creator
  ) returning application_no into v_ref;
  perform set_config('sai.public_web_enquiry', 'off', true);

  return v_ref;
end;
$function$
;
revoke all on function "public"."sai_public_admission_submit"(p_full_name text, p_phone text, p_email text, p_program text, p_message text) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_public_admission_submit"(p_full_name text, p_phone text, p_email text, p_program text, p_message text) to "service_role";
grant execute on function "public"."sai_public_admission_submit"(p_full_name text, p_phone text, p_email text, p_program text, p_message text) to "anon";
grant execute on function "public"."sai_public_admission_submit"(p_full_name text, p_phone text, p_email text, p_program text, p_message text) to "authenticated";
CREATE OR REPLACE FUNCTION public.sai_security_branch_member(wanted_branch uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$ select private.sai_security_branch_member($1) $function$
;
revoke all on function "public"."sai_security_branch_member"(wanted_branch uuid) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_security_branch_member"(wanted_branch uuid) to "authenticated";
grant execute on function "public"."sai_security_branch_member"(wanted_branch uuid) to "service_role";
CREATE OR REPLACE FUNCTION public.sai_security_can_read_branch(wanted_branch uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$ select private.sai_security_can_read_branch($1) $function$
;
revoke all on function "public"."sai_security_can_read_branch"(wanted_branch uuid) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_security_can_read_branch"(wanted_branch uuid) to "authenticated";
grant execute on function "public"."sai_security_can_read_branch"(wanted_branch uuid) to "service_role";
CREATE OR REPLACE FUNCTION public.sai_security_can_read_class(wanted_class uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$ select private.sai_security_can_read_class($1) $function$
;
revoke all on function "public"."sai_security_can_read_class"(wanted_class uuid) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_security_can_read_class"(wanted_class uuid) to "authenticated";
grant execute on function "public"."sai_security_can_read_class"(wanted_class uuid) to "service_role";
CREATE OR REPLACE FUNCTION public.sai_security_can_read_session(wanted_session uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$ select private.sai_security_can_read_session($1) $function$
;
revoke all on function "public"."sai_security_can_read_session"(wanted_session uuid) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_security_can_read_session"(wanted_session uuid) to "authenticated";
grant execute on function "public"."sai_security_can_read_session"(wanted_session uuid) to "service_role";
CREATE OR REPLACE FUNCTION public.sai_security_can_read_student(wanted_student uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$ select private.sai_security_can_read_student($1) $function$
;
revoke all on function "public"."sai_security_can_read_student"(wanted_student uuid) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_security_can_read_student"(wanted_student uuid) to "authenticated";
grant execute on function "public"."sai_security_can_read_student"(wanted_student uuid) to "service_role";
CREATE OR REPLACE FUNCTION public.sai_security_has_role(wanted_role app_role)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$ select private.sai_security_has_role($1) $function$
;
revoke all on function "public"."sai_security_has_role"(wanted_role app_role) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_security_has_role"(wanted_role app_role) to "authenticated";
grant execute on function "public"."sai_security_has_role"(wanted_role app_role) to "service_role";
CREATE OR REPLACE FUNCTION public.sai_set_role(p_user_id uuid, p_role app_role, p_enabled boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_me uuid := auth.uid();
begin
  if not public.sai_security_has_role('super_admin') then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_user_id is null then
    raise exception 'invalid_user' using errcode = '22023';
  end if;

  if p_enabled then
    if not exists (select 1 from auth.users u where u.id = p_user_id) then
      raise exception 'unknown_user' using errcode = '22023';
    end if;
    if not exists (select 1 from public.profiles p where p.id = p_user_id) then
      insert into public.profiles (id, full_name, email, preferred_locale)
      select u.id,
             coalesce(nullif(u.raw_user_meta_data ->> 'full_name', ''), u.email, 'New account'),
             u.email,
             'ar'
      from auth.users u
      where u.id = p_user_id;
    end if;

    insert into public.user_roles (user_id, role, assigned_by)
    values (p_user_id, p_role, v_me)
    on conflict (user_id, role) do nothing;

    if p_role in ('super_admin', 'admin', 'receptionist') then
      insert into public.branch_memberships (user_id, branch_id, is_active)
      select p_user_id, b.id, true
      from public.branches b
      where not exists (
        select 1 from public.branch_memberships m where m.user_id = p_user_id and m.branch_id = b.id
      );
    elsif p_role in ('teacher', 'accountant', 'librarian', 'content_editor') then
      insert into public.branch_memberships (user_id, branch_id, is_active)
      select p_user_id, b.id, true
      from public.branches b
      where b.is_active
        and not exists (
          select 1 from public.branch_memberships m where m.user_id = p_user_id and m.branch_id = b.id
        );
    end if;
  else
    if p_user_id = v_me and p_role = 'super_admin' then
      raise exception 'cannot_remove_own_super_admin' using errcode = '42501';
    end if;
    delete from public.user_roles where user_id = p_user_id and role = p_role;
  end if;

  insert into public.audit_logs (actor_user_id, action, entity_type, entity_id, metadata)
  values (v_me,
          case when p_enabled then 'role.grant' else 'role.revoke' end,
          'user_role', p_user_id, jsonb_build_object('role', p_role::text));

  return jsonb_build_object('user_id', p_user_id, 'role', p_role, 'enabled', p_enabled);
end;
$function$
;
revoke all on function "public"."sai_set_role"(p_user_id uuid, p_role app_role, p_enabled boolean) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_set_role"(p_user_id uuid, p_role app_role, p_enabled boolean) to "authenticated";
grant execute on function "public"."sai_set_role"(p_user_id uuid, p_role app_role, p_enabled boolean) to "service_role";
CREATE OR REPLACE FUNCTION public.sai_staff_directory()
 RETURNS TABLE(user_id uuid, full_name text, email text, roles text[])
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not (public.sai_security_has_role('super_admin')
          or public.sai_security_has_role('admin')
          or public.sai_security_has_role('receptionist')) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  return query
    select ur.user_id,
           coalesce(p.full_name, 'Staff member')::text as full_name,
           p.email::text as email,
           array_agg(ur.role::text) as roles
    from public.user_roles ur
    left join public.profiles p on p.id = ur.user_id
    where ur.role in ('super_admin','admin','receptionist','teacher','accountant','librarian','content_editor')
    group by ur.user_id, p.full_name, p.email
    order by coalesce(p.full_name, 'Staff member');
end;
$function$
;
revoke all on function "public"."sai_staff_directory"() from public,anon,authenticated,service_role;
grant execute on function "public"."sai_staff_directory"() to "authenticated";
grant execute on function "public"."sai_staff_directory"() to "service_role";
CREATE OR REPLACE FUNCTION public.sai_submit_application(p_full_name text, p_guardian_name text, p_phone text, p_email text, p_program text, p_level text, p_notes text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_admin uuid;
  v_branch uuid;
  v_session uuid;
  v_year text := to_char(now(), 'YYYY');
  v_seq integer;
  v_no text;
  v_row public.admissions_enquiries;
  v_attempt integer;
begin
  if coalesce(length(btrim(p_full_name)), 0) < 2 then
    raise exception 'invalid_name' using errcode = '22023';
  end if;
  if coalesce(btrim(p_phone), '') = '' and coalesce(btrim(p_email), '') = '' then
    raise exception 'missing_contact' using errcode = '22023';
  end if;
  if coalesce(length(p_notes), 0) > 1000 then
    raise exception 'notes_too_long' using errcode = '22023';
  end if;

  select r.user_id into v_admin from public.user_roles r where r.role = 'super_admin' limit 1;
  if v_admin is null then
    raise exception 'no_administrator' using errcode = '42501';
  end if;

  select b.id into v_branch from public.branches b where b.is_active order by b.created_at limit 1;
  if v_branch is null then
    select b.id into v_branch from public.branches b order by b.created_at limit 1;
  end if;
  select s.id into v_session from public.academic_sessions s where s.is_active order by s.starts_on desc limit 1;
  if v_session is null then
    select s.id into v_session from public.academic_sessions s order by s.starts_on desc limit 1;
  end if;
  if v_branch is null or v_session is null then
    raise exception 'college_not_configured' using errcode = '42501';
  end if;

  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_admin::text, 'role', 'authenticated', 'aud', 'authenticated')::text,
    true
  );

  select coalesce(max(substring(e.application_no from ('^SAI-' || v_year || '-(\d+)$'))::int), 0) + 1
    into v_seq
    from public.admissions_enquiries e
    where e.application_no ~ ('^SAI-' || v_year || '-\d+$');

  for v_attempt in 0..5 loop
    v_no := 'SAI-' || v_year || '-' || lpad((v_seq + v_attempt)::text, 4, '0');
    begin
      insert into public.admissions_enquiries (
        branch_id, academic_session_id, application_no, applicant_full_name, guardian_name,
        phone, email, preferred_program, preferred_level, source, notes, status
      ) values (
        v_branch, v_session, v_no, btrim(p_full_name), nullif(btrim(coalesce(p_guardian_name, '')), ''),
        nullif(btrim(coalesce(p_phone, '')), ''), nullif(btrim(coalesce(p_email, '')), ''),
        nullif(btrim(coalesce(p_program, '')), ''), nullif(btrim(coalesce(p_level, '')), ''),
        'website', nullif(btrim(coalesce(p_notes, '')), ''), 'new'
      )
      returning * into v_row;

      return jsonb_build_object(
        'application_no', v_row.application_no,
        'created_at', v_row.created_at,
        'program', v_row.preferred_program
      );
    exception when unique_violation then
      continue;
    end;
  end loop;

  raise exception 'could_not_allocate_number' using errcode = '23505';
end;
$function$
;
revoke all on function "public"."sai_submit_application"(p_full_name text, p_guardian_name text, p_phone text, p_email text, p_program text, p_level text, p_notes text) from public,anon,authenticated,service_role;
grant execute on function "public"."sai_submit_application"(p_full_name text, p_guardian_name text, p_phone text, p_email text, p_program text, p_level text, p_notes text) to "service_role";
CREATE OR REPLACE FUNCTION public.sai_unified_module_audit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE rid uuid; bid uuid;
BEGIN
 IF TG_OP='DELETE' THEN rid=OLD.id; bid=OLD.branch_id; ELSE rid=NEW.id; bid=NEW.branch_id; END IF;
 INSERT INTO public.audit_logs(actor_user_id,action,entity_type,entity_id,metadata)
 VALUES((SELECT auth.uid()),TG_OP,TG_TABLE_NAME,rid,jsonb_build_object('branch_id',bid));
 IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END $function$
;
revoke all on function "public"."sai_unified_module_audit"() from public,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.sai_unified_module_stamp()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 IF TG_OP='INSERT' THEN NEW.created_by=(SELECT auth.uid()); NEW.created_at=now();
 ELSE NEW.created_by=OLD.created_by; NEW.created_at=OLD.created_at; END IF;
 NEW.updated_at=now(); RETURN NEW;
END $function$
;
revoke all on function "public"."sai_unified_module_stamp"() from public,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.sai_unified_module_student_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 IF NEW.student_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.students s WHERE s.id=NEW.student_id AND s.branch_id=NEW.branch_id)
 THEN RAISE EXCEPTION 'Student and record must belong to same branch' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $function$
;
revoke all on function "public"."sai_unified_module_student_guard"() from public,anon,authenticated,service_role;
alter table "public"."academic_sessions" enable row level security;
revoke all on table "public"."academic_sessions" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."academic_sessions" to "service_role";
grant select on table "public"."academic_sessions" to "authenticated";
alter table "public"."admission_reminder_log" enable row level security;
revoke all on table "public"."admission_reminder_log" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."admission_reminder_log" to "service_role";
alter table "public"."admission_reminder_runs" enable row level security;
revoke all on table "public"."admission_reminder_runs" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."admission_reminder_runs" to "service_role";
alter table "public"."admissions_enquiries" enable row level security;
revoke all on table "public"."admissions_enquiries" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."admissions_enquiries" to "service_role";
grant select on table "public"."admissions_enquiries" to "authenticated";
alter table "public"."announcement_deliveries" enable row level security;
revoke all on table "public"."announcement_deliveries" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."announcement_deliveries" to "service_role";
grant select on table "public"."announcement_deliveries" to "authenticated";
alter table "public"."announcement_reads" enable row level security;
revoke all on table "public"."announcement_reads" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."announcement_reads" to "anon";
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."announcement_reads" to "authenticated";
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."announcement_reads" to "service_role";
alter table "public"."announcements" enable row level security;
revoke all on table "public"."announcements" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."announcements" to "anon";
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."announcements" to "authenticated";
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."announcements" to "service_role";
alter table "public"."attendance_records" enable row level security;
revoke all on table "public"."attendance_records" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."attendance_records" to "service_role";
grant select on table "public"."attendance_records" to "authenticated";
alter table "public"."attendance_sessions" enable row level security;
revoke all on table "public"."attendance_sessions" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."attendance_sessions" to "service_role";
grant select on table "public"."attendance_sessions" to "authenticated";
alter table "public"."audit_logs" enable row level security;
revoke all on table "public"."audit_logs" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."audit_logs" to "service_role";
grant select on table "public"."audit_logs" to "authenticated";
alter table "public"."branch_memberships" enable row level security;
revoke all on table "public"."branch_memberships" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."branch_memberships" to "service_role";
grant select on table "public"."branch_memberships" to "authenticated";
alter table "public"."branches" enable row level security;
revoke all on table "public"."branches" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."branches" to "service_role";
grant select on table "public"."branches" to "authenticated";
alter table "public"."classes" enable row level security;
revoke all on table "public"."classes" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."classes" to "service_role";
grant select on table "public"."classes" to "authenticated";
alter table "public"."cms_news" enable row level security;
revoke all on table "public"."cms_news" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."cms_news" to "authenticated";
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."cms_news" to "service_role";
grant select on table "public"."cms_news" to "anon";
alter table "public"."cms_programs" enable row level security;
revoke all on table "public"."cms_programs" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."cms_programs" to "authenticated";
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."cms_programs" to "service_role";
grant select on table "public"."cms_programs" to "anon";
alter table "public"."cms_site_content" enable row level security;
revoke all on table "public"."cms_site_content" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."cms_site_content" to "authenticated";
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."cms_site_content" to "service_role";
grant select on table "public"."cms_site_content" to "anon";
alter table "public"."fee_assignments" enable row level security;
revoke all on table "public"."fee_assignments" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."fee_assignments" to "service_role";
grant select on table "public"."fee_assignments" to "authenticated";
alter table "public"."fee_groups" enable row level security;
revoke all on table "public"."fee_groups" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."fee_groups" to "service_role";
grant select on table "public"."fee_groups" to "authenticated";
alter table "public"."fee_payments" enable row level security;
revoke all on table "public"."fee_payments" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."fee_payments" to "service_role";
grant select on table "public"."fee_payments" to "authenticated";
alter table "public"."fee_refunds" enable row level security;
revoke all on table "public"."fee_refunds" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."fee_refunds" to "service_role";
grant select on table "public"."fee_refunds" to "authenticated";
alter table "public"."fee_waivers" enable row level security;
revoke all on table "public"."fee_waivers" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."fee_waivers" to "service_role";
grant select on table "public"."fee_waivers" to "authenticated";
alter table "public"."finance_audit_log" enable row level security;
revoke all on table "public"."finance_audit_log" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."finance_audit_log" to "service_role";
grant select on table "public"."finance_audit_log" to "authenticated";
alter table "public"."learning_courses" enable row level security;
revoke all on table "public"."learning_courses" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."learning_courses" to "authenticated";
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."learning_courses" to "service_role";
alter table "public"."learning_homework" enable row level security;
revoke all on table "public"."learning_homework" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."learning_homework" to "authenticated";
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."learning_homework" to "service_role";
alter table "public"."learning_homework_submissions" enable row level security;
revoke all on table "public"."learning_homework_submissions" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."learning_homework_submissions" to "authenticated";
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."learning_homework_submissions" to "service_role";
alter table "public"."learning_inbox_reads" enable row level security;
revoke all on table "public"."learning_inbox_reads" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."learning_inbox_reads" to "authenticated";
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."learning_inbox_reads" to "service_role";
alter table "public"."learning_lesson_progress" enable row level security;
revoke all on table "public"."learning_lesson_progress" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."learning_lesson_progress" to "authenticated";
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."learning_lesson_progress" to "service_role";
alter table "public"."learning_lessons" enable row level security;
revoke all on table "public"."learning_lessons" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."learning_lessons" to "authenticated";
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."learning_lessons" to "service_role";
alter table "public"."learning_vocab_progress" enable row level security;
revoke all on table "public"."learning_vocab_progress" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."learning_vocab_progress" to "anon";
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."learning_vocab_progress" to "authenticated";
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."learning_vocab_progress" to "service_role";
alter table "public"."learning_vocabulary" enable row level security;
revoke all on table "public"."learning_vocabulary" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."learning_vocabulary" to "anon";
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."learning_vocabulary" to "authenticated";
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."learning_vocabulary" to "service_role";
alter table "public"."library_items" enable row level security;
revoke all on table "public"."library_items" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."library_items" to "anon";
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."library_items" to "authenticated";
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."library_items" to "service_role";
alter table "public"."library_loans" enable row level security;
revoke all on table "public"."library_loans" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."library_loans" to "anon";
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."library_loans" to "authenticated";
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."library_loans" to "service_role";
alter table "public"."notification_reads" enable row level security;
revoke all on table "public"."notification_reads" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."notification_reads" to "anon";
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."notification_reads" to "authenticated";
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."notification_reads" to "service_role";
alter table "public"."parent_student_links" enable row level security;
revoke all on table "public"."parent_student_links" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."parent_student_links" to "service_role";
grant select on table "public"."parent_student_links" to "authenticated";
alter table "public"."profiles" enable row level security;
revoke all on table "public"."profiles" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."profiles" to "service_role";
grant select on table "public"."profiles" to "authenticated";
alter table "public"."sai_alumni" enable row level security;
revoke all on table "public"."sai_alumni" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."sai_alumni" to "service_role";
grant insert,select,update on table "public"."sai_alumni" to "authenticated";
alter table "public"."sai_certificates" enable row level security;
revoke all on table "public"."sai_certificates" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."sai_certificates" to "service_role";
grant insert,select,update on table "public"."sai_certificates" to "authenticated";
alter table "public"."sai_cms_pages" enable row level security;
revoke all on table "public"."sai_cms_pages" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."sai_cms_pages" to "service_role";
grant insert,select,update,delete on table "public"."sai_cms_pages" to "authenticated";
grant select on table "public"."sai_cms_pages" to "anon";
alter table "public"."sai_download_resources" enable row level security;
revoke all on table "public"."sai_download_resources" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."sai_download_resources" to "service_role";
grant insert,select,update,delete on table "public"."sai_download_resources" to "authenticated";
alter table "public"."sai_housing_rooms" enable row level security;
revoke all on table "public"."sai_housing_rooms" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."sai_housing_rooms" to "service_role";
grant insert,select,update on table "public"."sai_housing_rooms" to "authenticated";
alter table "public"."sai_inventory_items" enable row level security;
revoke all on table "public"."sai_inventory_items" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."sai_inventory_items" to "service_role";
grant insert,select,update on table "public"."sai_inventory_items" to "authenticated";
alter table "public"."sai_student_portfolios" enable row level security;
revoke all on table "public"."sai_student_portfolios" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."sai_student_portfolios" to "service_role";
grant insert,select,update on table "public"."sai_student_portfolios" to "authenticated";
alter table "public"."sai_system_settings" enable row level security;
revoke all on table "public"."sai_system_settings" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."sai_system_settings" to "service_role";
grant insert,select,update on table "public"."sai_system_settings" to "authenticated";
alter table "public"."sai_system_settings_audit" enable row level security;
revoke all on table "public"."sai_system_settings_audit" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."sai_system_settings_audit" to "service_role";
grant select on table "public"."sai_system_settings_audit" to "authenticated";
alter table "public"."sai_transport_routes" enable row level security;
revoke all on table "public"."sai_transport_routes" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."sai_transport_routes" to "service_role";
grant insert,select,update,delete on table "public"."sai_transport_routes" to "authenticated";
alter table "public"."students" enable row level security;
revoke all on table "public"."students" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."students" to "service_role";
grant select on table "public"."students" to "authenticated";
alter table "public"."user_roles" enable row level security;
revoke all on table "public"."user_roles" from public,anon,authenticated,service_role;
grant insert,select,update,delete,truncate,references,trigger,maintain on table "public"."user_roles" to "service_role";
grant select on table "public"."user_roles" to "authenticated";
revoke all on sequence "public"."admissions_application_no_seq" from public,anon,authenticated,service_role;
grant select,update,usage on sequence "public"."admissions_application_no_seq" to "anon";
grant select,update,usage on sequence "public"."admissions_application_no_seq" to "authenticated";
grant select,update,usage on sequence "public"."admissions_application_no_seq" to "service_role";
revoke all on sequence "public"."finance_audit_log_id_seq" from public,anon,authenticated,service_role;
grant select,update,usage on sequence "public"."finance_audit_log_id_seq" to "anon";
grant select,update,usage on sequence "public"."finance_audit_log_id_seq" to "authenticated";
grant select,update,usage on sequence "public"."finance_audit_log_id_seq" to "service_role";
revoke all on sequence "public"."finance_receipt_seq" from public,anon,authenticated,service_role;
grant select,update,usage on sequence "public"."finance_receipt_seq" to "anon";
grant select,update,usage on sequence "public"."finance_receipt_seq" to "authenticated";
grant select,update,usage on sequence "public"."finance_receipt_seq" to "service_role";
revoke all on sequence "public"."finance_refund_seq" from public,anon,authenticated,service_role;
grant select,update,usage on sequence "public"."finance_refund_seq" to "anon";
grant select,update,usage on sequence "public"."finance_refund_seq" to "authenticated";
grant select,update,usage on sequence "public"."finance_refund_seq" to "service_role";
revoke all on sequence "public"."sai_system_settings_audit_id_seq" from public,anon,authenticated,service_role;
grant select,update,usage on sequence "public"."sai_system_settings_audit_id_seq" to "anon";
grant select,update,usage on sequence "public"."sai_system_settings_audit_id_seq" to "authenticated";
grant select,update,usage on sequence "public"."sai_system_settings_audit_id_seq" to "service_role";
grant insert ("name") on "public"."academic_sessions" to "authenticated";
grant update ("name") on "public"."academic_sessions" to "authenticated";
grant insert ("starts_on") on "public"."academic_sessions" to "authenticated";
grant update ("starts_on") on "public"."academic_sessions" to "authenticated";
grant insert ("ends_on") on "public"."academic_sessions" to "authenticated";
grant update ("ends_on") on "public"."academic_sessions" to "authenticated";
grant insert ("is_active") on "public"."academic_sessions" to "authenticated";
grant update ("is_active") on "public"."academic_sessions" to "authenticated";
grant insert ("branch_id") on "public"."admissions_enquiries" to "authenticated";
grant insert ("academic_session_id") on "public"."admissions_enquiries" to "authenticated";
grant update ("academic_session_id") on "public"."admissions_enquiries" to "authenticated";
grant insert ("applicant_full_name") on "public"."admissions_enquiries" to "authenticated";
grant update ("applicant_full_name") on "public"."admissions_enquiries" to "authenticated";
grant insert ("guardian_name") on "public"."admissions_enquiries" to "authenticated";
grant update ("guardian_name") on "public"."admissions_enquiries" to "authenticated";
grant insert ("phone") on "public"."admissions_enquiries" to "authenticated";
grant update ("phone") on "public"."admissions_enquiries" to "authenticated";
grant insert ("email") on "public"."admissions_enquiries" to "authenticated";
grant update ("email") on "public"."admissions_enquiries" to "authenticated";
grant insert ("preferred_program") on "public"."admissions_enquiries" to "authenticated";
grant update ("preferred_program") on "public"."admissions_enquiries" to "authenticated";
grant insert ("preferred_level") on "public"."admissions_enquiries" to "authenticated";
grant update ("preferred_level") on "public"."admissions_enquiries" to "authenticated";
grant insert ("source") on "public"."admissions_enquiries" to "authenticated";
grant update ("source") on "public"."admissions_enquiries" to "authenticated";
grant insert ("notes") on "public"."admissions_enquiries" to "authenticated";
grant update ("notes") on "public"."admissions_enquiries" to "authenticated";
grant update ("status") on "public"."admissions_enquiries" to "authenticated";
grant insert ("assigned_to") on "public"."admissions_enquiries" to "authenticated";
grant update ("assigned_to") on "public"."admissions_enquiries" to "authenticated";
grant insert ("attendance_session_id") on "public"."attendance_records" to "authenticated";
grant insert ("student_id") on "public"."attendance_records" to "authenticated";
grant insert ("status") on "public"."attendance_records" to "authenticated";
grant update ("status") on "public"."attendance_records" to "authenticated";
grant insert ("note") on "public"."attendance_records" to "authenticated";
grant update ("note") on "public"."attendance_records" to "authenticated";
grant insert ("branch_id") on "public"."attendance_sessions" to "authenticated";
grant insert ("academic_session_id") on "public"."attendance_sessions" to "authenticated";
grant insert ("class_id") on "public"."attendance_sessions" to "authenticated";
grant insert ("attendance_date") on "public"."attendance_sessions" to "authenticated";
grant insert ("start_time") on "public"."attendance_sessions" to "authenticated";
grant update ("start_time") on "public"."attendance_sessions" to "authenticated";
grant insert ("end_time") on "public"."attendance_sessions" to "authenticated";
grant update ("end_time") on "public"."attendance_sessions" to "authenticated";
grant update ("status") on "public"."attendance_sessions" to "authenticated";
grant insert ("actor_user_id") on "public"."audit_logs" to "authenticated";
grant insert ("action") on "public"."audit_logs" to "authenticated";
grant insert ("entity_type") on "public"."audit_logs" to "authenticated";
grant insert ("entity_id") on "public"."audit_logs" to "authenticated";
grant insert ("metadata") on "public"."audit_logs" to "authenticated";
grant insert ("user_id") on "public"."branch_memberships" to "authenticated";
grant insert ("branch_id") on "public"."branch_memberships" to "authenticated";
grant insert ("is_active") on "public"."branch_memberships" to "authenticated";
grant update ("is_active") on "public"."branch_memberships" to "authenticated";
grant insert ("name") on "public"."branches" to "authenticated";
grant update ("name") on "public"."branches" to "authenticated";
grant insert ("code") on "public"."branches" to "authenticated";
grant update ("code") on "public"."branches" to "authenticated";
grant insert ("address") on "public"."branches" to "authenticated";
grant update ("address") on "public"."branches" to "authenticated";
grant insert ("is_active") on "public"."branches" to "authenticated";
grant update ("is_active") on "public"."branches" to "authenticated";
grant insert ("branch_id") on "public"."classes" to "authenticated";
grant insert ("session_id") on "public"."classes" to "authenticated";
grant insert ("name") on "public"."classes" to "authenticated";
grant update ("name") on "public"."classes" to "authenticated";
grant insert ("program") on "public"."classes" to "authenticated";
grant update ("program") on "public"."classes" to "authenticated";
grant insert ("capacity") on "public"."classes" to "authenticated";
grant update ("capacity") on "public"."classes" to "authenticated";
grant insert ("teacher_id") on "public"."classes" to "authenticated";
grant insert ("is_active") on "public"."classes" to "authenticated";
grant update ("is_active") on "public"."classes" to "authenticated";
grant insert ("id") on "public"."profiles" to "authenticated";
grant insert ("full_name") on "public"."profiles" to "authenticated";
grant update ("full_name") on "public"."profiles" to "authenticated";
grant insert ("phone") on "public"."profiles" to "authenticated";
grant update ("phone") on "public"."profiles" to "authenticated";
grant insert ("preferred_locale") on "public"."profiles" to "authenticated";
grant update ("preferred_locale") on "public"."profiles" to "authenticated";
grant insert ("user_id") on "public"."students" to "authenticated";
grant insert ("branch_id") on "public"."students" to "authenticated";
grant insert ("admission_no") on "public"."students" to "authenticated";
grant update ("admission_no") on "public"."students" to "authenticated";
grant insert ("full_name") on "public"."students" to "authenticated";
grant update ("full_name") on "public"."students" to "authenticated";
grant insert ("date_of_birth") on "public"."students" to "authenticated";
grant update ("date_of_birth") on "public"."students" to "authenticated";
grant insert ("class_id") on "public"."students" to "authenticated";
grant update ("class_id") on "public"."students" to "authenticated";
grant insert ("status") on "public"."students" to "authenticated";
grant update ("status") on "public"."students" to "authenticated";
create policy "academic_sessions_insert_super_admin" on "public"."academic_sessions" as PERMISSIVE for INSERT to "authenticated" with check (private.sai_security_has_role('super_admin'::app_role));
create policy "academic_sessions_select_authorized" on "public"."academic_sessions" as PERMISSIVE for SELECT to "authenticated" using (private.sai_security_can_read_session(id));
create policy "academic_sessions_update_super_admin" on "public"."academic_sessions" as PERMISSIVE for UPDATE to "authenticated" using (private.sai_security_has_role('super_admin'::app_role)) with check (private.sai_security_has_role('super_admin'::app_role));
create policy "admission_reminder_log_deny_api" on "public"."admission_reminder_log" as PERMISSIVE for ALL to "anon","authenticated" using (false) with check (false);
create policy "admission_reminder_runs_deny_api" on "public"."admission_reminder_runs" as PERMISSIVE for ALL to "anon","authenticated" using (false) with check (false);
create policy "admissions_insert_staff" on "public"."admissions_enquiries" as PERMISSIVE for INSERT to "authenticated" with check (((created_by = ( SELECT auth.uid() AS uid)) AND (status = 'new'::text) AND (private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('receptionist'::app_role))))));
create policy "admissions_select_authorized" on "public"."admissions_enquiries" as PERMISSIVE for SELECT to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('receptionist'::app_role) OR (private.sai_security_has_role('teacher'::app_role) AND (assigned_to = ( SELECT auth.uid() AS uid)))))));
create policy "admissions_update_staff" on "public"."admissions_enquiries" as PERMISSIVE for UPDATE to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('receptionist'::app_role))))) with check ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('receptionist'::app_role)))));
create policy "announcement_deliveries_read" on "public"."announcement_deliveries" as PERMISSIVE for SELECT to "authenticated" using ((EXISTS ( SELECT 1
   FROM announcements a
  WHERE ((a.id = announcement_deliveries.announcement_id) AND (EXISTS ( SELECT 1
           FROM user_roles r
          WHERE ((r.user_id = ( SELECT auth.uid() AS uid)) AND ((r.role = 'super_admin'::app_role) OR ((r.role = ANY (ARRAY['admin'::app_role, 'content_editor'::app_role])) AND ((a.branch_id IS NULL) OR private.sai_security_branch_member(a.branch_id)))))))))));
create policy "announcement_reads_own" on "public"."announcement_reads" as PERMISSIVE for ALL to "authenticated" using ((user_id = ( SELECT auth.uid() AS uid))) with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "announcements_read" on "public"."announcements" as PERMISSIVE for SELECT to "authenticated" using (((EXISTS ( SELECT 1
   FROM user_roles r
  WHERE ((r.user_id = ( SELECT auth.uid() AS uid)) AND ((r.role = 'super_admin'::app_role) OR ((r.role = ANY (ARRAY['admin'::app_role, 'content_editor'::app_role])) AND private.sai_security_branch_member(announcements.branch_id)))))) OR (is_published AND ((expires_at IS NULL) OR (expires_at > now())) AND ((branch_id IS NULL) OR private.sai_security_branch_member(branch_id) OR (EXISTS ( SELECT 1
   FROM user_roles r
  WHERE ((r.user_id = ( SELECT auth.uid() AS uid)) AND (r.role = 'super_admin'::app_role))))) AND ((audience = 'all'::text) OR (EXISTS ( SELECT 1
   FROM user_roles r
  WHERE ((r.user_id = ( SELECT auth.uid() AS uid)) AND (((announcements.audience = 'staff'::text) AND (r.role = ANY (ARRAY['super_admin'::app_role, 'admin'::app_role, 'teacher'::app_role, 'accountant'::app_role, 'receptionist'::app_role, 'librarian'::app_role, 'content_editor'::app_role]))) OR ((announcements.audience = 'teachers'::text) AND (r.role = 'teacher'::app_role)) OR ((announcements.audience = 'parents'::text) AND (r.role = 'parent'::app_role)) OR ((announcements.audience = 'students'::text) AND (r.role = 'student'::app_role))))))))));
create policy "announcements_write" on "public"."announcements" as PERMISSIVE for ALL to "authenticated" using (((published_by = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
   FROM user_roles r
  WHERE ((r.user_id = ( SELECT auth.uid() AS uid)) AND (r.role = 'super_admin'::app_role)))))) with check ((EXISTS ( SELECT 1
   FROM user_roles r
  WHERE ((r.user_id = ( SELECT auth.uid() AS uid)) AND ((r.role = 'super_admin'::app_role) OR ((r.role = ANY (ARRAY['admin'::app_role, 'content_editor'::app_role])) AND ((announcements.branch_id IS NULL) OR private.sai_security_branch_member(announcements.branch_id))))))));
create policy "attendance_records_insert" on "public"."attendance_records" as PERMISSIVE for INSERT to "authenticated" with check ((EXISTS ( SELECT 1
   FROM attendance_sessions a
  WHERE ((a.id = attendance_records.attendance_session_id) AND private.sai_attendance_manage_class(a.class_id)))));
create policy "attendance_records_read" on "public"."attendance_records" as PERMISSIVE for SELECT to "authenticated" using (private.sai_attendance_view_record(attendance_session_id, student_id));
create policy "attendance_records_update" on "public"."attendance_records" as PERMISSIVE for UPDATE to "authenticated" using ((EXISTS ( SELECT 1
   FROM attendance_sessions a
  WHERE ((a.id = attendance_records.attendance_session_id) AND (private.sai_attendance_manage_class(a.class_id) OR (private.sai_security_has_role('receptionist'::app_role) AND private.sai_security_branch_member(a.branch_id))))))) with check ((EXISTS ( SELECT 1
   FROM attendance_sessions a
  WHERE ((a.id = attendance_records.attendance_session_id) AND (private.sai_attendance_manage_class(a.class_id) OR (private.sai_security_has_role('receptionist'::app_role) AND private.sai_security_branch_member(a.branch_id)))))));
create policy "attendance_sessions_insert" on "public"."attendance_sessions" as PERMISSIVE for INSERT to "authenticated" with check ((private.sai_attendance_manage_class(class_id) AND (created_by = ( SELECT auth.uid() AS uid))));
create policy "attendance_sessions_read" on "public"."attendance_sessions" as PERMISSIVE for SELECT to "authenticated" using (private.sai_attendance_view_session(id));
create policy "attendance_sessions_update" on "public"."attendance_sessions" as PERMISSIVE for UPDATE to "authenticated" using (private.sai_attendance_manage_class(class_id)) with check (private.sai_attendance_manage_class(class_id));
create policy "audit_logs_insert_self" on "public"."audit_logs" as PERMISSIVE for INSERT to "authenticated" with check ((actor_user_id = ( SELECT auth.uid() AS uid)));
create policy "audit_logs_select_super_admin" on "public"."audit_logs" as PERMISSIVE for SELECT to "authenticated" using (private.sai_security_has_role('super_admin'::app_role));
create policy "branch_memberships_insert_super_admin" on "public"."branch_memberships" as PERMISSIVE for INSERT to "authenticated" with check (private.sai_security_has_role('super_admin'::app_role));
create policy "branch_memberships_select_self_or_super_admin" on "public"."branch_memberships" as PERMISSIVE for SELECT to "authenticated" using (((user_id = ( SELECT auth.uid() AS uid)) OR private.sai_security_has_role('super_admin'::app_role)));
create policy "branch_memberships_update_self_or_super_admin" on "public"."branch_memberships" as PERMISSIVE for UPDATE to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR ((user_id = ( SELECT auth.uid() AS uid)) AND private.sai_security_has_role('admin'::app_role) AND private.sai_security_branch_member(branch_id)))) with check ((private.sai_security_has_role('super_admin'::app_role) OR ((user_id = ( SELECT auth.uid() AS uid)) AND private.sai_security_has_role('admin'::app_role))));
create policy "branches_insert_super_admin" on "public"."branches" as PERMISSIVE for INSERT to "authenticated" with check (private.sai_security_has_role('super_admin'::app_role));
create policy "branches_select_authorized" on "public"."branches" as PERMISSIVE for SELECT to "authenticated" using (private.sai_security_can_read_branch(id));
create policy "branches_update_scoped_admin" on "public"."branches" as PERMISSIVE for UPDATE to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_has_role('admin'::app_role) AND private.sai_security_branch_member(id)))) with check ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_has_role('admin'::app_role) AND private.sai_security_branch_member(id))));
create policy "classes_insert_scoped_admin" on "public"."classes" as PERMISSIVE for INSERT to "authenticated" with check ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_has_role('admin'::app_role) AND private.sai_security_branch_member(branch_id) AND private.sai_security_can_read_session(session_id))));
create policy "classes_select_authorized" on "public"."classes" as PERMISSIVE for SELECT to "authenticated" using (private.sai_security_can_read_class(id));
create policy "classes_update_scoped_admin" on "public"."classes" as PERMISSIVE for UPDATE to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_has_role('admin'::app_role) AND private.sai_security_branch_member(branch_id)))) with check ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_has_role('admin'::app_role) AND private.sai_security_branch_member(branch_id))));
create policy "cms_news_public_read" on "public"."cms_news" as PERMISSIVE for SELECT to public using (is_published);
create policy "cms_news_staff_read" on "public"."cms_news" as PERMISSIVE for SELECT to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('content_editor'::app_role)));
create policy "cms_news_write" on "public"."cms_news" as PERMISSIVE for ALL to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('content_editor'::app_role))) with check ((private.sai_security_has_role('super_admin'::app_role) OR private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('content_editor'::app_role)));
create policy "cms_programs_public_read" on "public"."cms_programs" as PERMISSIVE for SELECT to public using (is_published);
create policy "cms_programs_staff_read" on "public"."cms_programs" as PERMISSIVE for SELECT to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('content_editor'::app_role)));
create policy "cms_programs_write" on "public"."cms_programs" as PERMISSIVE for ALL to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('content_editor'::app_role))) with check ((private.sai_security_has_role('super_admin'::app_role) OR private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('content_editor'::app_role)));
create policy "cms_site_content_public_read" on "public"."cms_site_content" as PERMISSIVE for SELECT to public using (true);
create policy "cms_site_content_write" on "public"."cms_site_content" as PERMISSIVE for ALL to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('content_editor'::app_role))) with check ((private.sai_security_has_role('super_admin'::app_role) OR private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('content_editor'::app_role)));
create policy "fee_assignments_read" on "public"."fee_assignments" as PERMISSIVE for SELECT to "authenticated" using (private.sai_finance_can_read_student(student_id, branch_id));
create policy "fee_groups_read" on "public"."fee_groups" as PERMISSIVE for SELECT to "authenticated" using (private.sai_finance_staff(branch_id, ARRAY['admin'::text, 'accountant'::text, 'receptionist'::text]));
create policy "fee_payments_read" on "public"."fee_payments" as PERMISSIVE for SELECT to "authenticated" using ((EXISTS ( SELECT 1
   FROM fee_assignments a
  WHERE ((a.id = fee_payments.assignment_id) AND private.sai_finance_can_read_student(a.student_id, a.branch_id)))));
create policy "fee_refunds_read" on "public"."fee_refunds" as PERMISSIVE for SELECT to "authenticated" using (private.sai_finance_staff(branch_id, ARRAY['accountant'::text]));
create policy "fee_waivers_read" on "public"."fee_waivers" as PERMISSIVE for SELECT to "authenticated" using ((EXISTS ( SELECT 1
   FROM fee_assignments a
  WHERE ((a.id = fee_waivers.assignment_id) AND private.sai_finance_can_read_student(a.student_id, a.branch_id)))));
create policy "finance_audit_read" on "public"."finance_audit_log" as PERMISSIVE for SELECT to "authenticated" using (private.sai_finance_staff(branch_id, ARRAY['accountant'::text]));
create policy "learning_courses_select" on "public"."learning_courses" as PERMISSIVE for SELECT to "authenticated" using (private.sai_security_can_read_class(class_id));
create policy "learning_courses_write" on "public"."learning_courses" as PERMISSIVE for ALL to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_has_role('admin'::app_role) AND private.sai_security_branch_member(branch_id)) OR (private.sai_security_has_role('teacher'::app_role) AND private.sai_security_branch_member(branch_id) AND ((teacher_id = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
   FROM classes cl
  WHERE ((cl.id = learning_courses.class_id) AND (cl.teacher_id = ( SELECT auth.uid() AS uid))))))))) with check ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_has_role('admin'::app_role) AND private.sai_security_branch_member(branch_id)) OR (private.sai_security_has_role('teacher'::app_role) AND private.sai_security_branch_member(branch_id) AND ((teacher_id = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
   FROM classes cl
  WHERE ((cl.id = learning_courses.class_id) AND (cl.teacher_id = ( SELECT auth.uid() AS uid)))))))));
create policy "learning_homework_select" on "public"."learning_homework" as PERMISSIVE for SELECT to "authenticated" using (private.sai_learning_can_read_homework(id));
create policy "learning_homework_write" on "public"."learning_homework" as PERMISSIVE for ALL to "authenticated" using (private.sai_learning_can_manage_course(course_id)) with check (private.sai_learning_can_manage_course(course_id));
create policy "learning_submissions_select" on "public"."learning_homework_submissions" as PERMISSIVE for SELECT to "authenticated" using ((private.sai_security_can_read_student(student_id) AND private.sai_learning_can_read_homework(homework_id)));
create policy "learning_submissions_staff_update" on "public"."learning_homework_submissions" as PERMISSIVE for UPDATE to "authenticated" using (private.sai_learning_can_grade_homework(homework_id)) with check (private.sai_learning_can_grade_homework(homework_id));
create policy "learning_submissions_student_insert" on "public"."learning_homework_submissions" as PERMISSIVE for INSERT to "authenticated" with check ((private.sai_learning_own_student(student_id) AND private.sai_learning_can_read_homework(homework_id) AND (status = 'submitted'::text)));
create policy "learning_submissions_student_update" on "public"."learning_homework_submissions" as PERMISSIVE for UPDATE to "authenticated" using ((private.sai_learning_own_student(student_id) AND (status = ANY (ARRAY['submitted'::text, 'returned'::text])))) with check ((private.sai_learning_own_student(student_id) AND (status = 'submitted'::text)));
create policy "learning_inbox_reads_insert_own" on "public"."learning_inbox_reads" as PERMISSIVE for INSERT to public with check ((user_id = auth.uid()));
create policy "learning_inbox_reads_select_own" on "public"."learning_inbox_reads" as PERMISSIVE for SELECT to public using ((user_id = auth.uid()));
create policy "learning_inbox_reads_update_own" on "public"."learning_inbox_reads" as PERMISSIVE for UPDATE to public using ((user_id = auth.uid())) with check ((user_id = auth.uid()));
create policy "learning_progress_select" on "public"."learning_lesson_progress" as PERMISSIVE for SELECT to "authenticated" using (private.sai_security_can_read_student(student_id));
create policy "learning_progress_write" on "public"."learning_lesson_progress" as PERMISSIVE for ALL to "authenticated" using (private.sai_learning_own_student(student_id)) with check (private.sai_learning_own_student(student_id));
create policy "learning_lessons_select" on "public"."learning_lessons" as PERMISSIVE for SELECT to "authenticated" using ((is_published OR private.sai_learning_can_manage_course(course_id)));
create policy "learning_lessons_write" on "public"."learning_lessons" as PERMISSIVE for ALL to "authenticated" using (private.sai_learning_can_manage_course(course_id)) with check (private.sai_learning_can_manage_course(course_id));
create policy "learning_vocab_progress_select" on "public"."learning_vocab_progress" as PERMISSIVE for SELECT to "authenticated" using (private.sai_security_can_read_student(student_id));
create policy "learning_vocab_progress_write" on "public"."learning_vocab_progress" as PERMISSIVE for ALL to "authenticated" using (private.sai_learning_own_student(student_id)) with check (private.sai_learning_own_student(student_id));
create policy "learning_vocabulary_select" on "public"."learning_vocabulary" as PERMISSIVE for SELECT to "authenticated" using ((is_published OR private.sai_learning_can_manage_course(course_id)));
create policy "learning_vocabulary_write" on "public"."learning_vocabulary" as PERMISSIVE for ALL to "authenticated" using (private.sai_learning_can_manage_course(course_id)) with check (private.sai_learning_can_manage_course(course_id));
create policy "library_items_read" on "public"."library_items" as PERMISSIVE for SELECT to "authenticated" using ((is_active OR (EXISTS ( SELECT 1
   FROM user_roles r
  WHERE ((r.user_id = ( SELECT auth.uid() AS uid)) AND (r.role = ANY (ARRAY['super_admin'::app_role, 'admin'::app_role, 'librarian'::app_role, 'teacher'::app_role])))))));
create policy "library_items_write" on "public"."library_items" as PERMISSIVE for ALL to "authenticated" using ((EXISTS ( SELECT 1
   FROM user_roles r
  WHERE ((r.user_id = ( SELECT auth.uid() AS uid)) AND ((r.role = 'super_admin'::app_role) OR ((r.role = ANY (ARRAY['admin'::app_role, 'librarian'::app_role])) AND private.sai_security_branch_member(library_items.branch_id))))))) with check ((EXISTS ( SELECT 1
   FROM user_roles r
  WHERE ((r.user_id = ( SELECT auth.uid() AS uid)) AND ((r.role = 'super_admin'::app_role) OR ((r.role = ANY (ARRAY['admin'::app_role, 'librarian'::app_role])) AND private.sai_security_branch_member(library_items.branch_id)))))));
create policy "library_loans_read" on "public"."library_loans" as PERMISSIVE for SELECT to "authenticated" using (((EXISTS ( SELECT 1
   FROM user_roles r
  WHERE ((r.user_id = ( SELECT auth.uid() AS uid)) AND ((r.role = 'super_admin'::app_role) OR ((r.role = ANY (ARRAY['admin'::app_role, 'librarian'::app_role, 'receptionist'::app_role, 'teacher'::app_role])) AND private.sai_security_branch_member(library_loans.branch_id)))))) OR (EXISTS ( SELECT 1
   FROM students s
  WHERE ((s.id = library_loans.student_id) AND (s.user_id = ( SELECT auth.uid() AS uid))))) OR (EXISTS ( SELECT 1
   FROM (parent_student_links l
     JOIN students s ON (((s.id = l.student_id) AND (s.id = library_loans.student_id))))
  WHERE ((l.parent_user_id = ( SELECT auth.uid() AS uid)) AND (l.verified_at IS NOT NULL))))));
create policy "library_loans_write" on "public"."library_loans" as PERMISSIVE for ALL to "authenticated" using ((EXISTS ( SELECT 1
   FROM user_roles r
  WHERE ((r.user_id = ( SELECT auth.uid() AS uid)) AND ((r.role = 'super_admin'::app_role) OR ((r.role = ANY (ARRAY['admin'::app_role, 'librarian'::app_role])) AND private.sai_security_branch_member(library_loans.branch_id))))))) with check ((EXISTS ( SELECT 1
   FROM user_roles r
  WHERE ((r.user_id = ( SELECT auth.uid() AS uid)) AND ((r.role = 'super_admin'::app_role) OR ((r.role = ANY (ARRAY['admin'::app_role, 'librarian'::app_role])) AND private.sai_security_branch_member(library_loans.branch_id)))))));
create policy "notification_reads_insert_self" on "public"."notification_reads" as PERMISSIVE for INSERT to "authenticated" with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "notification_reads_select_self" on "public"."notification_reads" as PERMISSIVE for SELECT to "authenticated" using ((user_id = ( SELECT auth.uid() AS uid)));
create policy "notification_reads_update_self" on "public"."notification_reads" as PERMISSIVE for UPDATE to "authenticated" using ((user_id = ( SELECT auth.uid() AS uid))) with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "parent_student_links_select_parent_or_super_admin" on "public"."parent_student_links" as PERMISSIVE for SELECT to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_has_role('parent'::app_role) AND (parent_user_id = ( SELECT auth.uid() AS uid)) AND (verified_at IS NOT NULL))));
create policy "profiles_insert_self" on "public"."profiles" as PERMISSIVE for INSERT to "authenticated" with check ((id = ( SELECT auth.uid() AS uid)));
create policy "profiles_select_self" on "public"."profiles" as PERMISSIVE for SELECT to "authenticated" using ((id = ( SELECT auth.uid() AS uid)));
create policy "profiles_update_self" on "public"."profiles" as PERMISSIVE for UPDATE to "authenticated" using ((id = ( SELECT auth.uid() AS uid))) with check ((id = ( SELECT auth.uid() AS uid)));
create policy "sai_alumni_insert" on "public"."sai_alumni" as PERMISSIVE for INSERT to "authenticated" with check ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('receptionist'::app_role)))));
create policy "sai_alumni_read" on "public"."sai_alumni" as PERMISSIVE for SELECT to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR ((private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('receptionist'::app_role))) OR ((student_id IS NOT NULL) AND ((EXISTS ( SELECT 1
   FROM students s
  WHERE ((s.id = sai_alumni.student_id) AND (s.user_id = ( SELECT auth.uid() AS uid))))) OR (EXISTS ( SELECT 1
   FROM parent_student_links l
  WHERE ((l.student_id = sai_alumni.student_id) AND (l.parent_user_id = ( SELECT auth.uid() AS uid)) AND (l.verified_at IS NOT NULL)))))))));
create policy "sai_alumni_update" on "public"."sai_alumni" as PERMISSIVE for UPDATE to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('receptionist'::app_role))))) with check ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('receptionist'::app_role)))));
create policy "sai_certificates_insert" on "public"."sai_certificates" as PERMISSIVE for INSERT to "authenticated" with check ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('receptionist'::app_role)))));
create policy "sai_certificates_read" on "public"."sai_certificates" as PERMISSIVE for SELECT to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR ((private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('receptionist'::app_role))) OR ((student_id IS NOT NULL) AND ((EXISTS ( SELECT 1
   FROM students s
  WHERE ((s.id = sai_certificates.student_id) AND (s.user_id = ( SELECT auth.uid() AS uid))))) OR (EXISTS ( SELECT 1
   FROM parent_student_links l
  WHERE ((l.student_id = sai_certificates.student_id) AND (l.parent_user_id = ( SELECT auth.uid() AS uid)) AND (l.verified_at IS NOT NULL)))))))));
create policy "sai_certificates_update" on "public"."sai_certificates" as PERMISSIVE for UPDATE to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('receptionist'::app_role))))) with check ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('receptionist'::app_role)))));
create policy "sai_cms_pages_anon_read" on "public"."sai_cms_pages" as PERMISSIVE for SELECT to "anon" using (is_published);
create policy "sai_cms_pages_delete" on "public"."sai_cms_pages" as PERMISSIVE for DELETE to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('content_editor'::app_role)))));
create policy "sai_cms_pages_insert" on "public"."sai_cms_pages" as PERMISSIVE for INSERT to "authenticated" with check ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('content_editor'::app_role)))));
create policy "sai_cms_pages_read" on "public"."sai_cms_pages" as PERMISSIVE for SELECT to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR ((private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('content_editor'::app_role))) OR is_published)));
create policy "sai_cms_pages_update" on "public"."sai_cms_pages" as PERMISSIVE for UPDATE to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('content_editor'::app_role))))) with check ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('content_editor'::app_role)))));
create policy "sai_download_resources_delete" on "public"."sai_download_resources" as PERMISSIVE for DELETE to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('librarian'::app_role) OR private.sai_security_has_role('content_editor'::app_role)))));
create policy "sai_download_resources_insert" on "public"."sai_download_resources" as PERMISSIVE for INSERT to "authenticated" with check ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('librarian'::app_role) OR private.sai_security_has_role('content_editor'::app_role)))));
create policy "sai_download_resources_read" on "public"."sai_download_resources" as PERMISSIVE for SELECT to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR ((private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('librarian'::app_role) OR private.sai_security_has_role('content_editor'::app_role))) OR (is_published AND (private.sai_security_branch_member(branch_id) OR (EXISTS ( SELECT 1
   FROM students s
  WHERE ((s.branch_id = sai_download_resources.branch_id) AND (s.user_id = ( SELECT auth.uid() AS uid))))) OR (EXISTS ( SELECT 1
   FROM (parent_student_links l
     JOIN students s ON ((s.id = l.student_id)))
  WHERE ((l.parent_user_id = ( SELECT auth.uid() AS uid)) AND (l.verified_at IS NOT NULL) AND (s.branch_id = sai_download_resources.branch_id)))))))));
create policy "sai_download_resources_update" on "public"."sai_download_resources" as PERMISSIVE for UPDATE to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('librarian'::app_role) OR private.sai_security_has_role('content_editor'::app_role))))) with check ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('librarian'::app_role) OR private.sai_security_has_role('content_editor'::app_role)))));
create policy "sai_housing_rooms_insert" on "public"."sai_housing_rooms" as PERMISSIVE for INSERT to "authenticated" with check ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('receptionist'::app_role)))));
create policy "sai_housing_rooms_read" on "public"."sai_housing_rooms" as PERMISSIVE for SELECT to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR ((private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('receptionist'::app_role))) OR (private.sai_security_branch_member(branch_id) OR (EXISTS ( SELECT 1
   FROM students s
  WHERE ((s.branch_id = sai_housing_rooms.branch_id) AND (s.user_id = ( SELECT auth.uid() AS uid))))) OR (EXISTS ( SELECT 1
   FROM (parent_student_links l
     JOIN students s ON ((s.id = l.student_id)))
  WHERE ((l.parent_user_id = ( SELECT auth.uid() AS uid)) AND (l.verified_at IS NOT NULL) AND (s.branch_id = sai_housing_rooms.branch_id))))))));
create policy "sai_housing_rooms_update" on "public"."sai_housing_rooms" as PERMISSIVE for UPDATE to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('receptionist'::app_role))))) with check ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('receptionist'::app_role)))));
create policy "sai_inventory_items_insert" on "public"."sai_inventory_items" as PERMISSIVE for INSERT to "authenticated" with check ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('accountant'::app_role)))));
create policy "sai_inventory_items_read" on "public"."sai_inventory_items" as PERMISSIVE for SELECT to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('accountant'::app_role)))));
create policy "sai_inventory_items_update" on "public"."sai_inventory_items" as PERMISSIVE for UPDATE to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('accountant'::app_role))))) with check ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('accountant'::app_role)))));
create policy "sai_student_portfolios_insert" on "public"."sai_student_portfolios" as PERMISSIVE for INSERT to "authenticated" with check ((private.sai_security_has_role('super_admin'::app_role) OR ((private.sai_security_branch_member(branch_id) AND private.sai_security_has_role('admin'::app_role)) OR (private.sai_security_has_role('teacher'::app_role) AND (EXISTS ( SELECT 1
   FROM (students s
     JOIN classes c ON ((c.id = s.class_id)))
  WHERE ((s.id = sai_student_portfolios.student_id) AND (s.branch_id = sai_student_portfolios.branch_id) AND (c.branch_id = sai_student_portfolios.branch_id) AND (c.teacher_id = ( SELECT auth.uid() AS uid)))))))));
create policy "sai_student_portfolios_read" on "public"."sai_student_portfolios" as PERMISSIVE for SELECT to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR ((private.sai_security_branch_member(branch_id) AND private.sai_security_has_role('admin'::app_role)) OR (private.sai_security_has_role('teacher'::app_role) AND (EXISTS ( SELECT 1
   FROM (students s
     JOIN classes c ON ((c.id = s.class_id)))
  WHERE ((s.id = sai_student_portfolios.student_id) AND (s.branch_id = sai_student_portfolios.branch_id) AND (c.branch_id = sai_student_portfolios.branch_id) AND (c.teacher_id = ( SELECT auth.uid() AS uid)))))) OR ((student_id IS NOT NULL) AND ((EXISTS ( SELECT 1
   FROM students s
  WHERE ((s.id = sai_student_portfolios.student_id) AND (s.user_id = ( SELECT auth.uid() AS uid))))) OR (EXISTS ( SELECT 1
   FROM parent_student_links l
  WHERE ((l.student_id = sai_student_portfolios.student_id) AND (l.parent_user_id = ( SELECT auth.uid() AS uid)) AND (l.verified_at IS NOT NULL)))))))));
create policy "sai_student_portfolios_update" on "public"."sai_student_portfolios" as PERMISSIVE for UPDATE to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR ((private.sai_security_branch_member(branch_id) AND private.sai_security_has_role('admin'::app_role)) OR (private.sai_security_has_role('teacher'::app_role) AND (EXISTS ( SELECT 1
   FROM (students s
     JOIN classes c ON ((c.id = s.class_id)))
  WHERE ((s.id = sai_student_portfolios.student_id) AND (s.branch_id = sai_student_portfolios.branch_id) AND (c.branch_id = sai_student_portfolios.branch_id) AND (c.teacher_id = ( SELECT auth.uid() AS uid))))))))) with check ((private.sai_security_has_role('super_admin'::app_role) OR ((private.sai_security_branch_member(branch_id) AND private.sai_security_has_role('admin'::app_role)) OR (private.sai_security_has_role('teacher'::app_role) AND (EXISTS ( SELECT 1
   FROM (students s
     JOIN classes c ON ((c.id = s.class_id)))
  WHERE ((s.id = sai_student_portfolios.student_id) AND (s.branch_id = sai_student_portfolios.branch_id) AND (c.branch_id = sai_student_portfolios.branch_id) AND (c.teacher_id = ( SELECT auth.uid() AS uid)))))))));
create policy "sai_settings_insert" on "public"."sai_system_settings" as PERMISSIVE for INSERT to "authenticated" with check (private.sai_security_has_role('super_admin'::app_role));
create policy "sai_settings_read" on "public"."sai_system_settings" as PERMISSIVE for SELECT to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_has_role('admin'::app_role) AND (category <> ALL (ARRAY['backups'::text, 'extensions'::text, 'verification'::text, 'updates'::text])))));
create policy "sai_settings_update" on "public"."sai_system_settings" as PERMISSIVE for UPDATE to "authenticated" using (private.sai_security_has_role('super_admin'::app_role)) with check (private.sai_security_has_role('super_admin'::app_role));
create policy "sai_settings_audit_read" on "public"."sai_system_settings_audit" as PERMISSIVE for SELECT to "authenticated" using (private.sai_security_has_role('super_admin'::app_role));
create policy "sai_transport_routes_delete" on "public"."sai_transport_routes" as PERMISSIVE for DELETE to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('receptionist'::app_role)))));
create policy "sai_transport_routes_insert" on "public"."sai_transport_routes" as PERMISSIVE for INSERT to "authenticated" with check ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('receptionist'::app_role)))));
create policy "sai_transport_routes_read" on "public"."sai_transport_routes" as PERMISSIVE for SELECT to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR ((private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('receptionist'::app_role))) OR (private.sai_security_branch_member(branch_id) OR (EXISTS ( SELECT 1
   FROM students s
  WHERE ((s.branch_id = sai_transport_routes.branch_id) AND (s.user_id = ( SELECT auth.uid() AS uid))))) OR (EXISTS ( SELECT 1
   FROM (parent_student_links l
     JOIN students s ON ((s.id = l.student_id)))
  WHERE ((l.parent_user_id = ( SELECT auth.uid() AS uid)) AND (l.verified_at IS NOT NULL) AND (s.branch_id = sai_transport_routes.branch_id))))))));
create policy "sai_transport_routes_update" on "public"."sai_transport_routes" as PERMISSIVE for UPDATE to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('receptionist'::app_role))))) with check ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_branch_member(branch_id) AND (private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('receptionist'::app_role)))));
create policy "students_insert_scoped_admin" on "public"."students" as PERMISSIVE for INSERT to "authenticated" with check ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_has_role('admin'::app_role) AND private.sai_security_branch_member(branch_id))));
create policy "students_select_authorized" on "public"."students" as PERMISSIVE for SELECT to "authenticated" using (private.sai_security_can_read_student(id));
create policy "students_update_scoped_admin" on "public"."students" as PERMISSIVE for UPDATE to "authenticated" using ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_has_role('admin'::app_role) AND private.sai_security_branch_member(branch_id)))) with check ((private.sai_security_has_role('super_admin'::app_role) OR (private.sai_security_has_role('admin'::app_role) AND private.sai_security_branch_member(branch_id))));
create policy "user_roles_select_self_or_super_admin" on "public"."user_roles" as PERMISSIVE for SELECT to "authenticated" using (((user_id = ( SELECT auth.uid() AS uid)) OR private.sai_security_has_role('super_admin'::app_role)));
create policy "lesson_media_delete" on "storage"."objects" as PERMISSIVE for DELETE to "authenticated" using (((bucket_id = 'lesson-media'::text) AND (EXISTS ( SELECT 1
   FROM learning_lessons l
  WHERE (((l.id)::text = (storage.foldername(objects.name))[1]) AND private.sai_learning_can_manage_course(l.course_id))))));
create policy "lesson_media_read" on "storage"."objects" as PERMISSIVE for SELECT to "authenticated" using (((bucket_id = 'lesson-media'::text) AND (EXISTS ( SELECT 1
   FROM learning_lessons l
  WHERE (((l.id)::text = (storage.foldername(objects.name))[1]) AND (private.sai_learning_can_manage_course(l.course_id) OR (l.is_published AND private.sai_learning_can_read_course(l.course_id))))))));
create policy "lesson_media_update" on "storage"."objects" as PERMISSIVE for UPDATE to "authenticated" using (((bucket_id = 'lesson-media'::text) AND (EXISTS ( SELECT 1
   FROM learning_lessons l
  WHERE (((l.id)::text = (storage.foldername(objects.name))[1]) AND private.sai_learning_can_manage_course(l.course_id)))))) with check (((bucket_id = 'lesson-media'::text) AND (EXISTS ( SELECT 1
   FROM learning_lessons l
  WHERE (((l.id)::text = (storage.foldername(objects.name))[1]) AND private.sai_learning_can_manage_course(l.course_id))))));
create policy "lesson_media_write" on "storage"."objects" as PERMISSIVE for INSERT to "authenticated" with check (((bucket_id = 'lesson-media'::text) AND (EXISTS ( SELECT 1
   FROM learning_lessons l
  WHERE (((l.id)::text = (storage.foldername(objects.name))[1]) AND private.sai_learning_can_manage_course(l.course_id))))));
CREATE TRIGGER audit_sessions_management AFTER INSERT OR UPDATE ON public.academic_sessions FOR EACH ROW EXECUTE FUNCTION sai_management_audit_mutation();
CREATE TRIGGER admissions_audit AFTER INSERT OR UPDATE ON public.admissions_enquiries FOR EACH ROW EXECUTE FUNCTION sai_admissions_audit();
CREATE TRIGGER admissions_prepare BEFORE INSERT OR UPDATE ON public.admissions_enquiries FOR EACH ROW EXECUTE FUNCTION sai_admissions_prepare();
CREATE TRIGGER attendance_record_audit AFTER INSERT OR UPDATE ON public.attendance_records FOR EACH ROW EXECUTE FUNCTION sai_attendance_audit();
CREATE TRIGGER attendance_record_prepare BEFORE INSERT OR UPDATE ON public.attendance_records FOR EACH ROW EXECUTE FUNCTION sai_attendance_prepare_record();
CREATE TRIGGER attendance_session_audit AFTER INSERT OR UPDATE ON public.attendance_sessions FOR EACH ROW EXECUTE FUNCTION sai_attendance_audit();
CREATE TRIGGER attendance_session_prepare BEFORE INSERT OR UPDATE ON public.attendance_sessions FOR EACH ROW EXECUTE FUNCTION sai_attendance_prepare_session();
CREATE TRIGGER audit_memberships_management AFTER INSERT OR UPDATE ON public.branch_memberships FOR EACH ROW EXECUTE FUNCTION sai_management_audit_mutation();
CREATE TRIGGER audit_branches_management AFTER INSERT OR UPDATE ON public.branches FOR EACH ROW EXECUTE FUNCTION sai_management_audit_mutation();
CREATE TRIGGER audit_classes_management AFTER INSERT OR UPDATE ON public.classes FOR EACH ROW EXECUTE FUNCTION sai_management_audit_mutation();
CREATE TRIGGER sai_alumni_audit AFTER INSERT OR DELETE OR UPDATE ON public.sai_alumni FOR EACH ROW EXECUTE FUNCTION sai_unified_module_audit();
CREATE TRIGGER sai_alumni_stamp BEFORE INSERT OR UPDATE ON public.sai_alumni FOR EACH ROW EXECUTE FUNCTION sai_unified_module_stamp();
CREATE TRIGGER sai_alumni_student_guard BEFORE INSERT OR UPDATE OF branch_id, student_id ON public.sai_alumni FOR EACH ROW EXECUTE FUNCTION sai_unified_module_student_guard();
CREATE TRIGGER sai_certificates_audit AFTER INSERT OR DELETE OR UPDATE ON public.sai_certificates FOR EACH ROW EXECUTE FUNCTION sai_unified_module_audit();
CREATE TRIGGER sai_certificates_stamp BEFORE INSERT OR UPDATE ON public.sai_certificates FOR EACH ROW EXECUTE FUNCTION sai_unified_module_stamp();
CREATE TRIGGER sai_certificates_student_guard BEFORE INSERT OR UPDATE OF branch_id, student_id ON public.sai_certificates FOR EACH ROW EXECUTE FUNCTION sai_unified_module_student_guard();
CREATE TRIGGER sai_cms_pages_audit AFTER INSERT OR DELETE OR UPDATE ON public.sai_cms_pages FOR EACH ROW EXECUTE FUNCTION sai_unified_module_audit();
CREATE TRIGGER sai_cms_pages_stamp BEFORE INSERT OR UPDATE ON public.sai_cms_pages FOR EACH ROW EXECUTE FUNCTION sai_unified_module_stamp();
CREATE TRIGGER sai_download_resources_audit AFTER INSERT OR DELETE OR UPDATE ON public.sai_download_resources FOR EACH ROW EXECUTE FUNCTION sai_unified_module_audit();
CREATE TRIGGER sai_download_resources_stamp BEFORE INSERT OR UPDATE ON public.sai_download_resources FOR EACH ROW EXECUTE FUNCTION sai_unified_module_stamp();
CREATE TRIGGER sai_housing_rooms_audit AFTER INSERT OR DELETE OR UPDATE ON public.sai_housing_rooms FOR EACH ROW EXECUTE FUNCTION sai_unified_module_audit();
CREATE TRIGGER sai_housing_rooms_stamp BEFORE INSERT OR UPDATE ON public.sai_housing_rooms FOR EACH ROW EXECUTE FUNCTION sai_unified_module_stamp();
CREATE TRIGGER sai_inventory_items_audit AFTER INSERT OR DELETE OR UPDATE ON public.sai_inventory_items FOR EACH ROW EXECUTE FUNCTION sai_unified_module_audit();
CREATE TRIGGER sai_inventory_items_stamp BEFORE INSERT OR UPDATE ON public.sai_inventory_items FOR EACH ROW EXECUTE FUNCTION sai_unified_module_stamp();
CREATE TRIGGER sai_student_portfolios_audit AFTER INSERT OR DELETE OR UPDATE ON public.sai_student_portfolios FOR EACH ROW EXECUTE FUNCTION sai_unified_module_audit();
CREATE TRIGGER sai_student_portfolios_stamp BEFORE INSERT OR UPDATE ON public.sai_student_portfolios FOR EACH ROW EXECUTE FUNCTION sai_unified_module_stamp();
CREATE TRIGGER sai_student_portfolios_student_guard BEFORE INSERT OR UPDATE OF branch_id, student_id ON public.sai_student_portfolios FOR EACH ROW EXECUTE FUNCTION sai_unified_module_student_guard();
CREATE TRIGGER sai_system_settings_audit_trigger AFTER INSERT OR DELETE OR UPDATE ON public.sai_system_settings FOR EACH ROW EXECUTE FUNCTION private.sai_system_settings_log();
CREATE TRIGGER sai_system_settings_stamp_trigger BEFORE INSERT OR UPDATE ON public.sai_system_settings FOR EACH ROW EXECUTE FUNCTION private.sai_system_settings_stamp();
CREATE TRIGGER sai_transport_routes_audit AFTER INSERT OR DELETE OR UPDATE ON public.sai_transport_routes FOR EACH ROW EXECUTE FUNCTION sai_unified_module_audit();
CREATE TRIGGER sai_transport_routes_stamp BEFORE INSERT OR UPDATE ON public.sai_transport_routes FOR EACH ROW EXECUTE FUNCTION sai_unified_module_stamp();
CREATE TRIGGER audit_students_management AFTER INSERT OR UPDATE ON public.students FOR EACH ROW EXECUTE FUNCTION sai_management_audit_mutation();
CREATE TRIGGER students_validate_class_branch BEFORE INSERT OR UPDATE OF class_id, branch_id ON public.students FOR EACH ROW EXECUTE FUNCTION sai_management_validate_student_class();
CREATE INDEX admission_reminder_log_enquiry_idx ON public.admission_reminder_log USING btree (enquiry_id);
CREATE INDEX admissions_assignee_idx ON public.admissions_enquiries USING btree (assigned_to, branch_id);
CREATE INDEX admissions_scope_idx ON public.admissions_enquiries USING btree (branch_id, academic_session_id, status, created_at DESC);
CREATE INDEX announcement_deliveries_announcement_idx ON public.announcement_deliveries USING btree (announcement_id, status);
CREATE INDEX announcements_branch_idx ON public.announcements USING btree (branch_id);
CREATE INDEX announcements_published_idx ON public.announcements USING btree (is_published, published_at DESC);
CREATE INDEX attendance_records_student_idx ON public.attendance_records USING btree (student_id, attendance_session_id);
CREATE INDEX attendance_sessions_scope_idx ON public.attendance_sessions USING btree (branch_id, academic_session_id, attendance_date DESC);
CREATE INDEX audit_logs_entity_idx ON public.audit_logs USING btree (entity_type, entity_id, created_at);
CREATE INDEX branch_memberships_user_active_idx ON public.branch_memberships USING btree (user_id, is_active);
CREATE INDEX classes_scope_idx ON public.classes USING btree (branch_id, session_id);
CREATE INDEX classes_teacher_id_idx ON public.classes USING btree (teacher_id) WHERE (teacher_id IS NOT NULL);
CREATE INDEX fee_assignments_branch_idx ON public.fee_assignments USING btree (branch_id);
CREATE INDEX fee_assignments_student_idx ON public.fee_assignments USING btree (student_id);
CREATE UNIQUE INDEX fee_payment_reference_unique ON public.fee_payments USING btree (branch_id, method, transaction_reference) WHERE (transaction_reference IS NOT NULL);
CREATE INDEX fee_payments_assignment_idx ON public.fee_payments USING btree (assignment_id);
CREATE UNIQUE INDEX fee_refund_reference_unique ON public.fee_refunds USING btree (branch_id, method, reference) WHERE (reference IS NOT NULL);
CREATE INDEX fee_waivers_assignment_idx ON public.fee_waivers USING btree (assignment_id);
CREATE INDEX finance_audit_branch_idx ON public.finance_audit_log USING btree (branch_id, created_at DESC);
CREATE INDEX learning_courses_class_idx ON public.learning_courses USING btree (class_id);
CREATE INDEX learning_courses_teacher_id_idx ON public.learning_courses USING btree (teacher_id) WHERE (teacher_id IS NOT NULL);
CREATE INDEX learning_homework_course_idx ON public.learning_homework USING btree (course_id, "position");
CREATE INDEX learning_submissions_student_idx ON public.learning_homework_submissions USING btree (student_id);
CREATE INDEX learning_progress_student_idx ON public.learning_lesson_progress USING btree (student_id);
CREATE INDEX learning_lessons_course_idx ON public.learning_lessons USING btree (course_id, "position");
CREATE INDEX learning_vocab_progress_student_idx ON public.learning_vocab_progress USING btree (student_id);
CREATE INDEX learning_vocabulary_course_idx ON public.learning_vocabulary USING btree (course_id, "position");
CREATE INDEX learning_vocabulary_lesson_idx ON public.learning_vocabulary USING btree (lesson_id, "position");
CREATE INDEX library_items_branch_idx ON public.library_items USING btree (branch_id);
CREATE INDEX library_loans_item_idx ON public.library_loans USING btree (item_id);
CREATE UNIQUE INDEX library_loans_one_open_per_student ON public.library_loans USING btree (student_id, item_id) WHERE (returned_at IS NULL);
CREATE INDEX library_loans_open_idx ON public.library_loans USING btree (item_id) WHERE (returned_at IS NULL);
CREATE INDEX library_loans_student_idx ON public.library_loans USING btree (student_id);
CREATE INDEX parent_links_student_idx ON public.parent_student_links USING btree (student_id);
CREATE INDEX sai_alumni_branch_idx ON public.sai_alumni USING btree (branch_id, created_at DESC);
CREATE INDEX sai_certificates_branch_idx ON public.sai_certificates USING btree (branch_id, created_at DESC);
CREATE INDEX sai_cms_pages_branch_idx ON public.sai_cms_pages USING btree (branch_id, created_at DESC);
CREATE UNIQUE INDEX sai_cms_pages_slug_unique_idx ON public.sai_cms_pages USING btree (branch_id, slug) WHERE (slug IS NOT NULL);
CREATE INDEX sai_download_resources_branch_idx ON public.sai_download_resources USING btree (branch_id, created_at DESC);
CREATE INDEX sai_housing_rooms_branch_idx ON public.sai_housing_rooms USING btree (branch_id, created_at DESC);
CREATE INDEX sai_inventory_items_branch_idx ON public.sai_inventory_items USING btree (branch_id, created_at DESC);
CREATE INDEX sai_student_portfolios_branch_idx ON public.sai_student_portfolios USING btree (branch_id, created_at DESC);
CREATE INDEX sai_settings_audit_time_idx ON public.sai_system_settings_audit USING btree (happened_at DESC);
CREATE INDEX sai_transport_routes_branch_idx ON public.sai_transport_routes USING btree (branch_id, created_at DESC);
CREATE INDEX students_scope_idx ON public.students USING btree (branch_id, class_id);
set check_function_bodies=true;
