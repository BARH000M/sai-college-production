/// Design-system theme entry point.
///
/// Phase 1 is additive: the palette and the Material theme already live in
/// `core/sai_theme.dart` and are used by every screen. This file re-exports
/// them so new code can depend on `design_system/` without the existing files
/// being moved, renamed or duplicated.
library;

export 'package:sai_college_mobile/core/sai_theme.dart';