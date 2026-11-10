# حالة قاعدة الإنتاج — 10 نوفمبر 2026

**المشروع المؤكد:** `aeryusbrulqdxjdynwfh` — `sai-college-production`.

## عمليات نُفذت بنجاح عن طريق موصل Supabase

- سجل الترحيلات يحوي `20261110172940 / sai_system_settings_shared_20261110` (جدول الإعدادات وسجل تدقيقه). تم التأكد من وجودهما وفحص سياساتهما؛ لا تعاود تشغيل SQL 031.
- ترحيل `20261110173339 / sai_unified_modules_web_mobile_secure` نجح. أنشأ الجداول التالية: `sai_download_resources`, `sai_inventory_items`, `sai_transport_routes`, `sai_student_portfolios`, `sai_housing_rooms`, `sai_certificates`, `sai_cms_pages`, `sai_alumni`.
- ترحيل `sai_unified_module_realtime` نجح، وتم التحقق أن الجداول الثمانية ضمن `supabase_realtime`.
- في نتائج المراجعة: تفعيل RLS لكل الجداول العشرة الجديدة، عدم منح `anon` قراءة إلا إلى `sai_cms_pages` (وهي قراءة للمنشور فقط وفق سياسة RLS)، وعدم منح الحذف للمخزون والسكن والشهادات والخريجين وملفات الإنجاز.
- جداول الطلاب والواجبات والمكتبة والمالية الموجودة سابقاً لم يُعد إنشاؤها أو حذفها.

## انتباه — ملفات SQL التاريخية في الحزمة

`database/029_unified_mobile_modules_PROPOSED.sql`, `database/030_realtime_existing_tables_PROPOSED.sql`, `database/031_system_settings.sql`, `database/032_validate_student_branch.sql`, و`database/033_module_audit_and_timestamps.sql` كانت **مسودات قبل الربط المباشر** ولا تطابق بالضرورة الترحيلات التي نفذت فعلياً. **لا تطبقها على قاعدة الإنتاج ولا تضعها في مجلد `supabase/migrations` لتعمل تلقائياً**. بعض الجداول موجودة بالفعل وسيتسبب تطبيق الملفات القديمة في تعارضات أو تغييرات غير مقصودة.

للتزامن مع GitHub، استخدم أسلوب استيراد المخطط الفعلي/فحص سجل الترحيلات عبر Supabase CLI على نسخة عمل منفصلة، مع مراجعة الاختلافات؛ لا تستبدل أو تعيد ضبط تاريخ الترحيلات في الإنتاج.

## حدود التحقق

- فحص RLS وسياسات الوصول والمنح والفهارس والمحفزات ووجود الجداول وRealtime تم مباشرة من قاعدة الإنتاج.
- لم يتم اختبار سلوك الحسابات الفعلية لكل الأدوار التسعة عبر تسجيل دخول حقيقي، ولم تختبر عمليات CRUD الشاملة end-to-end بعد.
- لا يزال كود React/Flutter في الحزمة؛ **لم يتم نشره على GitHub أو Hostinger، ولم يُبنَ APK هنا**.
- تحذيرات أمنية موجودة مسبقاً في دوال Supabase قديمة تحتاج مراجعة مستقلة، لا تُعد نتيجةً لهذه الترحيلات.
