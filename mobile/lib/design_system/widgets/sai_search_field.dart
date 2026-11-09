import 'package:flutter/material.dart';

import 'package:sai_college_mobile/core/sai_theme.dart';

/// The standard search input: 12.5px text, 18px leading icon, compact padding.
///
/// Replaces the identical `TextField` + `InputDecoration` block repeated in the
/// classes, roles, student transfer and admission screens.
class SaiSearchField extends StatelessWidget {
  const SaiSearchField({
    super.key,
    required this.hintText,
    this.onChanged,
    this.controller,
    this.autofocus = false,
    this.textInputAction = TextInputAction.search,
  });

  final String hintText;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final bool autofocus;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      autofocus: autofocus,
      textInputAction: textInputAction,
      style: const TextStyle(fontSize: 12.5),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search, size: 18, color: SaiColors.muted),
        prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
      ),
    );
  }
}