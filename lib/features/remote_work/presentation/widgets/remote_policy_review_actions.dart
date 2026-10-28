import 'package:flutter/material.dart';

class RemotePolicyReviewActions extends StatelessWidget {
  const RemotePolicyReviewActions({
    super.key,
    required this.draftVersion,
    required this.hasUnsavedChanges,
    required this.working,
    required this.reason,
    required this.onApprove,
    required this.onPublish,
  });

  final int draftVersion;
  final bool hasUnsavedChanges;
  final bool working;
  final String reason;
  final VoidCallback onApprove;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final enabled = draftVersion > 0 && !hasUnsavedChanges && !working;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasUnsavedChanges)
          const Text(
            'احفظ التعديلات الحالية قبل اعتماد المسودة أو نشرها.',
            textDirection: TextDirection.rtl,
          ),
        OutlinedButton.icon(
          onPressed: enabled && reason.trim().isNotEmpty ? onApprove : null,
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('اعتماد المسودة'),
        ),
        FilledButton.tonalIcon(
          onPressed: enabled ? onPublish : null,
          icon: const Icon(Icons.publish_outlined),
          label: const Text('نشر السياسة المعتمدة'),
        ),
      ],
    );
  }
}
