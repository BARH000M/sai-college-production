import 'package:flutter/material.dart';

/// Standard scrollable page body.
///
/// Every screen currently opens a `ListView` with the same padding tuple
/// `14, 14, 14, 26`. Naming the layout keeps that rhythm for the modules still
/// to be built, and gives a single place to introduce pull-to-refresh later.
class SaiPageBody extends StatelessWidget {
  const SaiPageBody({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(14, 14, 14, 26),
    this.controller,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: controller,
      padding: padding,
      children: children,
    );
  }
}