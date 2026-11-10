import 'package:flutter/material.dart';

/// Canonical route names.
///
/// Phase 1 declares the names only; the app still navigates imperatively through
/// `Navigator` exactly as it does today. The route table is introduced in Phase
/// 2 together with `app/app.dart`, once the toolchain verification loop is in
/// place.
abstract final class SaiRouteNames {
  static const String dashboard = '/';
  static const String login = '/login';
  static const String passwordRecovery = '/password-recovery';
  static const String modules = '/modules';
  static const String students = '/students';
  static const String classes = '/classes';
  static const String attendance = '/attendance';
  static const String admissions = '/admissions';
  static const String finance = '/finance';
  static const String library = '/library';
  static const String courses = '/courses';
  static const String homework = '/homework';
  static const String notifications = '/notifications';
  static const String reports = '/reports';
  static const String settings = '/settings';
}

/// Thin wrapper over `Navigator` so screens stop repeating the
/// `MaterialPageRoute` boilerplate and a transition can be changed in one place.
abstract final class SaiNavigator {
  static Future<T?> push<T>(BuildContext context, Widget page) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute<T>(builder: (_) => page),
    );
  }

  static Future<T?> pushReplacement<T, TO>(BuildContext context, Widget page) {
    return Navigator.of(context).pushReplacement<T, TO>(
      MaterialPageRoute<T>(builder: (_) => page),
    );
  }

  static void pop<T>(BuildContext context, [T? result]) {
    Navigator.of(context).pop<T>(result);
  }
}