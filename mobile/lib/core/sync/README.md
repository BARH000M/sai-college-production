# `core/sync` — reserved

This directory is deliberately empty in Phase 1.

An offline queue / retry layer is only useful once a module has write operations
that can fail mid-flight and must survive a dropped connection. Today's write
paths (class create/edit, attendance save, student import, parent link, student
transfer) fail loudly with a user-visible message and let the operator retry,
which is the correct behaviour for a college office on a stable connection.

Introducing a sync abstraction now would be speculative code with no consumer.
It will be created together with the first module that genuinely needs queued
writes — most likely attendance or finance — rather than ahead of it.