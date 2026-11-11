# Nine role permission matrix (target contract; not proven)
| Role | Primary allowed workflows | Must deny |
|---|---|---|
| super_admin | global governance, roles, audit, system settings | unauthorized public access to secrets |
| admin | branch operations, admissions, academic admin | protected super_admin settings |
| teacher | assigned classes, attendance, homework, grading | other classes and students |
| accountant | branch finance, receipts, invoices | role management and academic grading |
| receptionist | authorized admissions, reception, directory | unrelated finance and grades |
| librarian | catalog, issues, returns, inventory scope | unrelated records and roles |
| student | own learning, own progress, own timetable | peer data, grade tampering |
| parent | only verified linked children and permitted summaries | other/unverified child data |
| content_editor | authorized lessons, vocabulary, CMS, media | account/finance administration |

Multi-role union applies only to actions; every role retains branch/class/student row scope. Enforcement belongs in RLS/RPC/Edge Functions, not just a hidden menu. Verify both allowed and denied cases using separate staged user sessions before approval.
