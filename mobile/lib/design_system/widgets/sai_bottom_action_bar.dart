import 'package:flutter/material.dart';

import 'package:sai_college_mobile/core/localization/app_strings.dart';
import 'package:sai_college_mobile/core/sai_theme.dart';

/// The white bottom bar that closes action screens.
///
/// The class form, attendance register, student import, transfer and guardian
/// link screens each rebuild this bar; naming it keeps the paddings, the busy
/// spinner and the disabled rules identical everywhere.
class SaiBottomActionBar extends StatelessWidget {
  const SaiBottomActionBar({
    super.key,
    required this.primaryLabel,
    this.onPrimary,
    this.primaryIcon = Icons.check,
    this.secondaryLabel,
    this.onSecondary,
    this.busy = false,
    this.busyLabel = AppStrings.busy,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final IconData primaryIcon;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool busy;
  final String busyLabel;

  @override
  Widget build(BuildContext context) {
    final hasSecondary = secondaryLabel != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: SaiColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (hasSecondary) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onSecondary,
                  child: Text(secondaryLabel!),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: hasSecondary ? 2 : 1,
              child: FilledButton.icon(
                onPressed: busy ? null : onPrimary,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(primaryIcon, size: 18),
                label: Text(busy ? busyLabel : primaryLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}