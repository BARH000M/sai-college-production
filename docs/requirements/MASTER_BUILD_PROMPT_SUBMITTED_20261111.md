MASTER BUILD PROMPT — YEMEN SAI ACADEMY V2
Full-Stack Audit, Implementation, Supabase Integration, Flutter, Testing & Production Deployment
Execution Mode: Autonomous Implementation Agent
Project: Yemen SAI Academy V2 / Yemen SAI Educational College
Website: https://www.sai-academic.com
GitHub Repository: https://github.com/BARH000M/sai-college-production
Local Project Root: D:\SAI-College-Production
Backend: Supabase (PostgreSQL, Auth, RLS, RPC, Storage, Realtime)
Web: Existing project framework — inspect before modifying
Mobile: Flutter (Android and iOS)
Languages: Arabic (primary), English, Simplified Chinese
Design: Cairo, RTL-first, responsive, accessible
Deployment: Existing website hosting and Supabase infrastructure
0. PRIMARY MISSION
You are the lead full-stack architect, Flutter engineer, Supabase database engineer, UI/UX designer, QA engineer, security auditor, and deployment engineer responsible for completing Yemen SAI Academy V2.
Your mission is to inspect, repair, complete, integrate, test, and prepare the existing system for production.
This is NOT a prototype-only task.
Do not deliver a visually attractive but nonfunctional application.
Every interface, button, form, dashboard, navigation item, learning activity, and authorized management operation must connect to real application logic and persistent backend data.
Required outcomes:
1.	Complete evidence-based audit of the existing project.
2.	Production-quality web and Flutter applications.
3.	Fully integrated Supabase backend.
4.	Version-controlled SQL migrations, RLS, RPC, and Storage policies.
5.	Real end-to-end learning functionality.
6.	Role-based dashboards and management workflows.
7.	Functional media and offline learning.
8.	Automated tests and security verification.
9.	Deployment to the authorized hosting environment.
10.	Android/iOS release preparation.
11.	Comprehensive implementation and verification reports.
Do not claim completion without verifiable evidence.
Do not create duplicate systems when existing production-quality functionality can be reused.
Do not delete existing working features, production data, or migrations.
Do not reset the existing Supabase database.
Do not replace the existing GitHub repository.
Do not introduce Docker as a mandatory dependency.
If a requested operation is unavailable in the current Readdy environment, implement and export everything supported, identify the exact blocker, and provide reproducible commands or artifacts for the remaining operation.
1. PHASE ONE — COMPLETE PROJECT AUDIT
Inspect the actual connected repository and all accessible project files.
Inspect:
•	mobile/
•	web/
•	supabase/
•	docs/
•	prototype/
•	.github/
•	.vscode/
•	Existing assets and design resources
•	Dependency manifests and lockfiles
•	Flutter configuration and Android/iOS build files
•	Existing tests and CI workflows
•	Environment configuration
•	Supabase schema and migration history
•	Authentication and authorization
•	Database relationships and constraints
•	RLS policies
•	RPC functions
•	Storage buckets and access policies
•	Media infrastructure
•	API integrations
•	Offline synchronization
•	Error handling and logging
Identify all implemented, partially implemented, missing, broken, disconnected, and placeholder functionality.
Generate:
docs/audits/PROJECT_AUDIT.md
docs/audits/FEATURE_INVENTORY.md
docs/audits/DATABASE_AUDIT.md
docs/audits/MOBILE_AUDIT.md
docs/audits/WEB_AUDIT.md
docs/audits/ASSET_INVENTORY.md
For each feature report:
Feature	Web	Mobile	Database	Security	Tests	Evidence	Priority
Status values:
•	COMPLETE
•	PARTIAL
•	BROKEN
•	MISSING
•	NOT VERIFIED
Do not mark a feature COMPLETE based solely on the presence of source code.
Run available baseline checks:
•	Flutter version and doctor
•	Flutter analyze
•	Flutter test
•	Flutter Android debug build
•	Web dependency installation
•	Web lint/typecheck
•	Web unit tests
•	Web production build
•	Supabase migration consistency
•	Database security tests
Record actual command outputs and exit codes.
PHASE GATE: A documented audit with evidence, prioritized blockers, and a concrete remediation plan.
2. PHASE TWO — DESIGN SYSTEM AND APPLICATION FOUNDATION
Implement a unified visual design system based on the existing Yemen SAI website and authorized branding assets.
Brand identity:
Arabic: كلية ساي التعليمية اليمنية الصينية
Chinese: 也门赛艾教育学院
English: Yemen SAI Educational College
Preserve the existing official logo and brand colors.
Design requirements:
•	Arabic-first RTL interface
•	Cairo font for Arabic
•	Appropriate Chinese font with complete Simplified Chinese glyph coverage
•	English typography support
•	Shared design tokens
•	Consistent spacing, typography, shadows, colors, and component states
•	Responsive mobile, tablet, and desktop layouts
•	Light and dark modes where supported
•	Accessible forms, contrast, and focus indicators
•	Loading, empty, error, success, and offline states
•	Reusable buttons, cards, tables, dialogs, and input components
•	Safe-area support
•	Small-screen navigation
•	Consistent role-specific dashboards
Implement:
1.	Splash screen
2.	Language selection
3.	Onboarding
4.	Authentication
5.	Password recovery
6.	Role-aware navigation
7.	User profile
8.	Notifications
9.	Settings
10.	Dashboard shell
11.	Global search
12.	Authorized quick actions
13.	Responsive navigation drawers and bottom tabs
14.	Session and branch selectors where supported by the data model
Navigation must be driven by actual authenticated permissions.
Do not expose administrative screens to unauthorized users.
PHASE GATE: Responsive screenshots, small/large device snapshots, navigation tests, and accessibility verification.
3. PHASE THREE — SUPABASE DATABASE AND BACKEND
Inspect existing migrations before making changes.
Use the existing connected Supabase project only after confirming its project identity and target environment.
Implement missing database capabilities through new, sequential, version-controlled SQL migrations.
Required backend areas:
Identity and access
•	User profiles
•	Role assignments
•	Multi-role support
•	Role permission mapping
•	Account activation and suspension
•	Audit logs
•	Secure session management
Academic management
•	Academic years and terms
•	Branches and departments
•	Courses and programs
•	Classes and sections
•	Student enrollments
•	Teachers and assignments
•	Timetables
•	Attendance
•	Assessments and examinations
•	Grades and transcripts
•	Learning progress
Administration
•	Admissions
•	Student records
•	Parent/student relationships
•	Staff management
•	Financial records
•	Fee management
•	Payment records
•	Library management
•	Notifications
•	Content management
•	Reporting
Learning management
•	Courses
•	Units
•	Lessons
•	Vocabulary
•	Chinese characters
•	Pronunciation resources
•	Audio assets
•	Writing exercises
•	Conversation activities
•	Quizzes
•	Attempt history
•	Progress tracking
•	Review scheduling
•	Offline sync metadata
Do not blindly create every listed table.
First map each requirement to existing schema objects and reuse or extend them.
SQL migration requirements
Every migration must be:
•	Idempotent where appropriate
•	Ordered
•	Version-controlled
•	Compatible with existing data
•	Reviewed for destructive operations
•	Tested in a safe environment
•	Documented with rollback or recovery instructions
Row Level Security
Enforce RLS on all exposed application tables.
Implement:
•	Student self-access
•	Parent access limited to verified linked children
•	Teacher access limited to authorized classes and academic operations
•	Accountant access limited to permitted finance operations
•	Receptionist access limited to permitted admissions and reception operations
•	Librarian access limited to library operations
•	Content Editor access limited to authorized content workflows
•	Admin access scoped to authorized administration
•	Super Admin access under explicit elevated policies
Public clients must never assign themselves privileged roles.
Prevent unauthorized cross-user, cross-class, and cross-branch data access.
RPC
Implement secure RPC functions only where required.
Include:
•	Input validation
•	Explicit authorization checks
•	Safe transaction boundaries
•	Appropriate search_path handling
•	Controlled EXECUTE privileges
•	Idempotency for retryable mutations
•	Structured error responses
Storage
Configure appropriate private/public buckets for:
•	Profile images
•	Lesson audio
•	Lesson videos
•	Learning images
•	Chinese writing assets
•	Documents
•	Student submissions
•	Authorized offline packages
Implement upload validation, file size restrictions, MIME checks, and access policies.
Use signed URLs for private assets when appropriate.
Never expose service-role credentials to web or mobile clients.
PHASE GATE: All required migrations verified, RLS denial tests passed, RPC authorization tests passed, and Storage access tests passed.
4. PHASE FOUR — REAL END-TO-END LESSON 101
Implement one fully functional Chinese lesson as the reference vertical slice.
Use the actual approved curriculum and content specification if available.
Do not invent lesson content and present it as approved curriculum.
If Lesson 101 content is unavailable, create clearly labeled review-ready content and report that curriculum approval remains pending.
The complete learning flow must support:
1.	Open Lesson 101.
2.	Load vocabulary from Supabase.
3.	Display Hanzi, Pinyin, Arabic meaning, and learning media.
4.	Play authentic lesson audio.
5.	Complete listening activities.
6.	Complete reading activities.
7.	Complete vocabulary practice.
8.	Complete pronunciation activities.
9.	Complete writing activities where specified.
10.	Complete an assessment.
11.	Save attempt results.
12.	Update student progress.
13.	Exit and reopen the lesson.
14.	Resume from the last valid checkpoint.
15.	Open the same student account on the web.
16.	Verify synchronized learning progress.
No static mock progress.
No fake quiz results.
No nonfunctional buttons.
No placeholder media presented as final.
Use real authenticated users and backend persistence.
PHASE GATE: A verified end-to-end Lesson 101 test, including progress synchronization between mobile and web, plus a physical Android device test when device access is available.
5. PHASE FIVE — COMPLETE CHINESE LEARNING ENGINES
Implement and integrate the approved learning engines.
Listening
•	Tone discrimination
•	Minimal pairs
•	Native-quality pronunciation audio
•	Repeat and replay
•	Listening comprehension
•	Audio-based assessment
Speaking
•	Microphone permission handling
•	Voice recording
•	Pronunciation evaluation through an explicitly selected and configured provider
•	Tone feedback
•	Retry workflows
•	Privacy-conscious audio handling
Reading
•	Hanzi recognition
•	Pinyin support
•	Vocabulary context
•	Sentence comprehension
•	Reading exercises
Writing
•	Stroke order demonstrations
•	Character tracing
•	Freehand writing
•	Stroke guidance
•	Writing progress tracking
•	Character review
Conversation
•	Structured dialogues
•	Role-play exercises
•	Listening and speaking interaction
•	Contextual vocabulary usage
•	Feedback and correction
Review
•	Spaced repetition scheduling
•	Weakness-based review
•	Mistake history
•	Progress analytics
•	Personalized revision sessions
Offline learning
•	Authorized downloadable lesson packages
•	Download progress
•	Offline asset playback
•	Local progress persistence
•	Reconnection detection
•	Idempotent synchronization
•	Conflict handling
•	Storage quota management
For every learning engine, report:
•	Implementation status
•	Content coverage
•	Test coverage
•	Audio quality
•	Media availability
•	External provider dependencies
•	Estimated operational costs
•	Offline support
•	Known limitations
Do not claim AI speech scoring works without a real configured provider and tested response.
PHASE GATE: A verified learning-engine test matrix with no unresolved critical failures.
6. PHASE SIX — NINE ROLE-BASED APPLICATION EXPERIENCES
Implement all nine approved roles:
1.	super_admin
2.	admin
3.	teacher
4.	accountant
5.	receptionist
6.	librarian
7.	student
8.	parent
9.	content_editor
Support users with multiple assigned roles.
Use the union of authorized permissions without allowing a role to bypass data-scoping rules.
Student
•	Learning dashboard
•	Courses and lessons
•	Learning activities
•	Quizzes
•	Grades
•	Attendance
•	Timetable
•	Review
•	Downloads
•	Notifications
•	Personal progress
Teacher
•	Assigned classes
•	Student rosters
•	Attendance
•	Assignments
•	Assessments
•	Grade entry
•	Teaching materials
•	Authorized student progress
•	Notifications
Parent
•	Verified linked children
•	Attendance
•	Grades
•	Timetable
•	Learning progress
•	Authorized financial information
•	School notifications
Content Editor
•	Course content
•	Lesson editing
•	Vocabulary
•	Media management
•	Review and approval workflows
•	Publishing status
•	Content validation
Receptionist
•	Admissions
•	Student registration
•	Authorized student directory
•	Reception workflows
•	Appointments
•	Notifications
Accountant
•	Fee management
•	Payment recording
•	Financial reports
•	Authorized student balances
•	Transaction history
Librarian
•	Library catalog
•	Borrowing
•	Returns
•	Reservations
•	Inventory
•	Overdue tracking
Admin
•	Authorized academic administration
•	Users and staff
•	Classes and schedules
•	Admissions
•	Operational reports
•	Settings within assigned scope
Super Admin
•	Global administration
•	Role and permission management
•	System configuration
•	Audit logs
•	Security monitoring
•	Cross-module reporting
•	Authorized platform governance
Every role must have:
•	Functional dashboard
•	Correct navigation
•	Authorized backend queries
•	Functional CRUD operations where permitted
•	Loading and error states
•	Permission denial handling
•	Automated access-control tests
PHASE GATE: Every role can perform its authorized operations and cannot access unauthorized data or functions.
7. PHASE SEVEN — SECURITY, PRIVACY AND PERFORMANCE
Audit and repair:
•	Authentication security
•	RLS bypass risks
•	Privilege escalation
•	Unsafe RPC functions
•	Storage policy gaps
•	Credential exposure
•	Insecure logging
•	Input validation
•	Sensitive data access
•	Offline data protection
•	Synchronization conflicts
•	Session expiration
•	Network failure handling
•	Crash handling
•	Error reporting
•	Low-end Android performance
•	Arabic RTL layout problems
•	Accessibility
•	Child privacy
•	Data retention
•	Account deletion workflows
Do not send children's recordings, images, or personal information to external AI services without appropriate authorization and privacy controls.
Test database backup restoration using a disposable environment.
Never perform a destructive restore against production.
PHASE GATE: All critical security, data integrity, and privacy checks pass.
8. PHASE EIGHT — AUTOMATED TESTING
Create and execute appropriate automated tests.
Required categories:
•	Dart unit tests
•	Flutter widget tests
•	Flutter integration tests
•	Web component tests
•	Web end-to-end tests
•	Supabase database tests
•	RLS positive and negative tests
•	RPC authorization tests
•	Storage permission tests
•	Multi-role access tests
•	Lesson progress persistence tests
•	Offline synchronization tests
•	Accessibility checks
•	Responsive layout tests
•	Performance smoke tests
Test real user journeys, not only isolated functions.
Record:
•	Test name
•	Expected result
•	Actual result
•	Pass/fail status
•	Execution environment
•	Evidence
•	Remaining defects
Do not report tests as passed unless they were executed successfully.
PHASE GATE: All critical automated tests pass and remaining noncritical issues are documented.
9. PHASE NINE — BUILD, DEPLOYMENT AND RELEASE
Web
•	Verify production build
•	Configure environment variables securely
•	Verify production Supabase connectivity
•	Prepare hosting deployment
•	Deploy to the authorized environment when credentials and deployment access are available
•	Verify the live website
•	Test authentication and authorized workflows
•	Verify HTTPS, routing, and asset loading
•	Document deployment and rollback procedures
Android
•	Resolve Flutter/Gradle compatibility issues
•	Pass Flutter analysis and tests
•	Produce debug APK for testing
•	Prepare signed Android App Bundle (AAB)
•	Verify application ID, branding, icons, and permissions
•	Prepare Play Store screenshots and metadata
•	Prepare internal testing release
iOS
•	Verify iOS project configuration
•	Prepare signing configuration
•	Use an authorized macOS or cloud build environment
•	Produce a valid archive when build access and signing credentials exist
•	Prepare TestFlight submission materials
•	Verify required permissions and privacy declarations
Store compliance
Prepare:
•	Privacy policy
•	Data safety documentation
•	Account deletion instructions
•	Child privacy disclosures
•	Permission justification
•	App descriptions
•	Screenshots
•	Release notes
•	Version information
•	Release checklist
Never generate or invent signing credentials.
Do not submit an app to a public store or change live production infrastructure without explicit approval.
PHASE GATE: Production deployment verified where authorized, release artifacts generated where technically possible, and the release checklist reviewed.
10. REQUIRED DELIVERABLES
Deliver the actual source-code changes, SQL files, configurations, tests, and reports.
Required artifacts:
docs/reports/FINAL_IMPLEMENTATION_REPORT.md
docs/reports/FEATURE_COMPLETION_MATRIX.md
docs/reports/SUPABASE_INTEGRATION_REPORT.md
docs/reports/RLS_SECURITY_REPORT.md
docs/reports/LEARNING_ENGINE_REPORT.md
docs/reports/ROLE_PERMISSION_MATRIX.md
docs/reports/TEST_EXECUTION_REPORT.md
docs/reports/BUILD_AND_DEPLOYMENT_REPORT.md
docs/reports/REMAINING_BLOCKERS.md
docs/reports/RELEASE_READINESS_CHECKLIST.md
Also deliver:
•	New SQL migration files
•	RLS policies and denial tests
•	RPC functions and tests
•	Storage configuration and tests
•	Updated web application
•	Updated Flutter application where repository access supports it
•	Updated environment variable examples without secrets
•	Automated test suites
•	Deployment configuration
•	Verified build artifacts when available
11. REPORTING FORMAT
At the end of each phase provide:
Requirement	Status	Files changed	Test evidence	Remaining issue
Clearly distinguish:
•	Implemented and tested
•	Implemented but not tested
•	Partially implemented
•	Blocked by external access
•	Not implemented
Provide the exact files, migrations, test commands, build results, and deployment URLs where verified.
Never fabricate test results, screenshots, database changes, APK/AAB files, or deployment success.
12. EXECUTION RULES
1.	Begin by auditing the existing repository.
2.	Preserve working code and production data.
3.	Prioritize critical defects and functional integrations.
4.	Build incrementally, with tests after each meaningful change.
5.	Use migrations for database changes.
6.	Validate security before exposing new data.
7.	Avoid unnecessary architectural rewrites.
8.	Keep web, mobile, and backend data contracts consistent.
9.	Maintain Arabic-first RTL and Chinese language support.
10.	Do not use fake production data or placeholder functionality.
11.	Never expose secret credentials.
12.	Never claim a tool operation succeeded without evidence.
13.	Do not request repeated approvals for ordinary reversible implementation work.
14.	Request approval before destructive, irreversible, or public-production actions.
15.	If Readdy cannot modify Flutter, execute SQL, access GitHub, or deploy to hosting, explicitly identify the limitation and produce usable handoff artifacts rather than claiming those actions were completed.
13. FINAL ACCEPTANCE CRITERIA
The project is complete only when:
•	The web application builds and operates correctly.
•	The Flutter application passes required checks.
•	Required Supabase integrations are functional.
•	All nine roles have correct permissions.
•	The real Lesson 101 flow works end-to-end.
•	Learning progress persists and synchronizes.
•	Required learning engines operate correctly.
•	RLS and Storage security tests pass.
•	Offline behavior is verified.
•	Critical security and privacy checks pass.
•	Available deployment targets are verified.
•	Mobile release readiness is documented.
•	No critical unresolved blockers remain.
A generated report is not proof of completion.
A successful UI preview is not proof of backend integration.
A successful build is not proof of application correctness.
Only actual implementation and verification evidence qualify.
START EXECUTION NOW
First, inspect the existing connected repository and Supabase configuration.
Produce the initial evidence-based audit, identify critical blockers, and begin implementing the highest-priority fixes.
Continue through the phases in dependency order.
Do not stop after producing a plan or visual prototype.
Deliver working code, SQL migrations, backend integrations, tests, deployment artifacts, and verified reports to the maximum extent supported by the connected environment.

