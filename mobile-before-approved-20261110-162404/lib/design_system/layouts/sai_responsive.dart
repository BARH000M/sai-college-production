import 'package:flutter/material.dart';

class SaiResponsive extends StatelessWidget {
  const SaiResponsive({super.key, required this.compact, required this.expanded,
    this.breakpoint = 720});
  final Widget compact;
  final Widget expanded;
  final double breakpoint;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
      constraints.maxWidth < breakpoint ? compact : expanded,
  );
}
