# SAI College — Version 1087 • reference-aligned review prototype

Open **VISUAL-MOCKUP.html** for the interactive role/screen gallery, with phone, tablet and web sizes. Open **WEBSITE-PREVIEW.html** for the public-site design. Use **browser-preview/index.html** / **OPEN-PREVIEW.cmd** for the desktop interface. Extract the full ZIP first. No installation or configuration is needed.

The current review includes exactly nine core roles, a fixed multi-role account, and 32 permission-aware top-level sections. The pillars are Chinese LMS, LCMS and Academy SMS. All fonts are local Cairo and the UI is Arabic RTL with Chinese Hanzi/Pinyin learning content.

## What you can review

- Ten fixed sample accounts cover all nine roles and one administrator/teacher combination. Change accounts through **معاينة حساب آخر**. Switching the active role only uses that account's predefined fixture roles. There is no role assignment UI.
- Branch/session context changes fixture scope. Students see their own sample record, parents see linked children, and teachers see assigned sample classes.
- Search, notifications, quick-link configuration, role-specific KPIs, charts and a calendar.
- Chinese course catalog and lesson journey: listening, speaking UI, tones, vocabulary, handwriting canvas, reading, review queue, quiz and progress. Browser Mandarin voice playback works only if a Chinese voice is installed. Speaking capture/assessment and stroke recognition are explicitly illustrative.
- Homework submission and teacher grading in session memory.
- LCMS author/save/revise → submit → a different administrative account approves → publish → the lesson appears in the student catalog. Editing creates a draft and preserves the earlier published snapshot.
- Admission enquiry creation and stage changes, sample guardian links, attendance, library issue/return, local finance records, notices/templates, CMS draft items and an audit trail.
- CSV exports and A4/A3 print previews with college identity and clear sample-document markings.

Some subordinate tabs display representative layouts/data rather than full CRUD. Student import parses CSV UTF-8 exported from Excel, validates identifiers, duplicate records, class scope and capacity, and adds valid rows only to the current in-memory session. Native XLSX parsing is not included; QR is a clearly labeled non-scannable placeholder; live-class integrations show intended flows without joining a provider. No data is uploaded, sent, charged, persisted to a real database or represented as an official certificate.

## Added in 1087

- Reference-based shell and screen components across all nine roles, with the supplied logo in headers and print templates.
- Direct shortcuts to the six approved reference screens, with 320/390/430/768 preview widths and a desktop option.
- Compact student/parent cards, guardian-link preview, read-only account-role audit, and contextual bottom menus.
- Class search, program filtering, class detail and an in-memory Add Class form.
- CSV student import with downloadable template, validation and local commit; no account or role creation.
- Read notifications and mobile global search, plus downloadable design-review notes.
- Responsive public website preview with program filters, FAQ and a local-only enquiry confirmation.
- Fixed the student timetable showing unrelated classes and the accountant mobile layout overflowing.

## Implementation boundary

This deliverable is the design/review stage requested. Its client-side guards demonstrate intended behavior; they are not proof of server authorization. A real implementation must obtain role memberships from the authenticated server and enforce permissions, tenant/branch scope, ownership and audit rules on the server/database. Public clients must never assign roles. No production SQL or data was changed.

The earlier React/Windows and Flutter projects are preserved under **reference-source/**. They have not been upgraded to this new feature inventory and must not be treated as the approved nine-role implementation. The attached approved 1086 layout is bundled as **visuals/APPROVED-REFERENCE.png**. Version 1087 follows its white cards, navy typography, vivid red actions, status colors, compact forms and fixed role-specific bottom navigation. The exact supplied red/gold sunburst logo is used as a rounded image badge; its artwork and background were not regenerated or removed. Earlier artwork/source under reference-source and VISUAL-MOCKUP-V1086.html is archival, not the current UI.

## Optional later modules

Hostel, transport, physical inventory, payroll, alumni, school houses and CBSE-specific examination formats are listed as deferred in Settings → نطاق النسخة. They are excluded from the 32-section Chinese-academy MVP navigation.

## Review and testing

Read **REVIEW-CHECKLIST.md**. The feature inventory and intended role/module mapping are provided in **docs/**. Changes entered in the UI reset when the page is refreshed or the outer gallery reloads its iframe. Navigate inside the app to keep session changes. Use **ملاحظات التصميم** to record and download JSON feedback before leaving the page, or keep comments in the checklist.

Run `node --test tests/review-regressions.cjs` to repeat the current checks. They validate 32 sections, exact nine roles, assigned-role restrictions, ownership/class scopes, publication rules, quiz/review behavior, capacity and CSV handling. The current 26 automated checks exercise 563 permitted account/role/page/tab combinations in a mocked environment, including CSV parsing and import checks. See **QA-REPORT.md** for the completed browser checks and remaining verification limits. These checks do not validate a production backend or native app.
