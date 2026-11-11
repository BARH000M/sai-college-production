# Lesson 101 — reference vertical-slice contract (PROPOSAL, not deployed)

The live database currently has learning_courses, learning_lessons, learning_vocabulary, learning_lesson_progress, learning_homework and submissions. No lesson matching `101` by title or position was found in the inspection, and there are zero stored objects in the `lesson-media` bucket. Do not invent lesson audio, answers or approved curriculum.

**Canonical lesson identity:** resolve lesson by UUID from learning_lessons; never assume a numeric ID 101 maps to a UUID. Lesson 101 content and authentic audio need curriculum approval.

**Minimum requested DTO:**
```ts
type Lesson101 = {
  lessonId: string; courseId: string; title: string; isPublished: boolean;
  vocabulary: Array<{ id: string; hanzi: string; pinyin: string; meaningAr: string; meaningEn?: string }>;
  media: Array<{ kind: 'audio'|'video'|'image'; storagePath: string; requiresSignedUrl: boolean }>;
};
type ResumeCheckpoint = {
  lessonId: string; studentId: string; step: 'listen'|'read'|'speak'|'write'|'quiz';
  clientMutationId: string; updatedAt: string; serverVersion: number;
};
```

**Server-only grade trust:** no web or mobile client can submit an authoritative score or passed flag. An authorized RPC/Edge Function scores a fixed assessment using approved answer keys stored outside public Data API paths. Student-owned checkpoint mutations may be stored only after RLS validates enrollment and student identity.

**Proposed migration (for future staging, not executable SQL in this package):** introduce lesson_attempts (scored only by server), lesson_checkpoints (idempotency key + monotonic version), lesson_media registry (private paths). Establish enrollment-/class-/branch-aware RLS; do not add a teacher-wide read policy without a class constraint. Implement on staging after reconcile existing migrations.

**Sequence:** approve content -> provision private media -> create server-grade RPC -> connect Flutter and web -> run user-journey test -> verify persistence after restart/offline replay -> approve publishing. Fail the gate until all verified.
