import 'package:flutter/material.dart';

/// One calm, reusable status surface for all V2 screens. It intentionally
/// contains only Arabic user-facing state, never provider/Firebase diagnostics.
class WorkspaceSyncStatusBanner extends StatelessWidget {
  const WorkspaceSyncStatusBanner({
    required this.message,
    required this.kind,
    this.onAction,
    this.actionLabel = 'التحقق من الحالة',
    super.key,
  });

  final String message;
  final WorkspaceSyncStatusKind kind;
  final VoidCallback? onAction;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = switch (kind) {
      WorkspaceSyncStatusKind.saved => colors.primary,
      WorkspaceSyncStatusKind.pending => colors.tertiary,
      WorkspaceSyncStatusKind.conflict => colors.error,
      WorkspaceSyncStatusKind.failure => colors.error,
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        color: color.withValues(alpha: .12),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(message, style: TextStyle(color: color)),
            if (onAction != null)
              TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

enum WorkspaceSyncStatusKind { saved, pending, conflict, failure }
