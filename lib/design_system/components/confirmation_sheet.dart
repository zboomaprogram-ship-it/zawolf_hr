import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../tokens.dart';

/// Standardized destructive-action confirmation bottom sheet.
/// Returns true if the action was confirmed, false/null otherwise.
///
/// When [commentHint] is provided an Arabic-first comment field is shown;
/// set [requireComment] to block confirming until non-empty text is entered
/// (used by rejection reasons per specs/ui_redesign/06 R2).
Future<bool> showConfirmationSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'إلغاء',
  bool destructive = true,
  String? commentHint,
  bool requireComment = false,
  TextEditingController? commentController,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ZaWolfColors.surface01,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(DsRadius.sheet)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConfirmationSheet(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
        commentHint: commentHint,
        requireComment: requireComment,
        commentController: commentController,
      ),
    ),
  ).then((value) => value ?? false);
}

class ConfirmationSheet extends StatefulWidget {
  const ConfirmationSheet({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    this.destructive = true,
    this.commentHint,
    this.requireComment = false,
    this.commentController,
    super.key,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final String? commentHint;
  final bool requireComment;
  final TextEditingController? commentController;

  @override
  State<ConfirmationSheet> createState() => _ConfirmationSheetState();
}

class _ConfirmationSheetState extends State<ConfirmationSheet> {
  TextEditingController? _ownController;

  TextEditingController get _controller =>
      widget.commentController ?? _ownController!;

  @override
  void initState() {
    super.initState();
    if (widget.commentController == null &&
        (widget.commentHint != null || widget.requireComment)) {
      _ownController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  bool get _commentSatisfied {
    if (!widget.requireComment) return true;
    return _controller.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final accent =
        widget.destructive ? ZaWolfColors.error : ZaWolfColors.primaryCyan;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(DsSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 40,
              height: DsSpacing.xs,
              margin: const EdgeInsets.only(bottom: DsSpacing.lg),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ZaWolfColors.surface03,
                borderRadius: DsRadius.pillBorder,
              ),
            ),
            Text(widget.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: DsSpacing.sm),
            Text(widget.message, style: Theme.of(context).textTheme.bodyMedium),
            if (widget.commentHint != null ||
                widget.commentController != null) ...[
              const SizedBox(height: DsSpacing.lg),
              TextField(
                controller: _controller,
                maxLines: 3,
                textDirection: TextDirection.rtl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText:
                      widget.commentHint ?? 'اكتب ملاحظتك هنا...',
                ),
              ),
            ],
            const SizedBox(height: DsSpacing.xl),
            FilledButton(
              onPressed: _commentSatisfied
                  ? () => Navigator.of(context).pop(true)
                  : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                backgroundColor: accent,
                foregroundColor: ZaWolfColors.background,
                disabledBackgroundColor: accent.withValues(alpha: 0.4),
              ),
              child: Text(widget.confirmLabel),
            ),
            const SizedBox(height: DsSpacing.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              child: Text(widget.cancelLabel),
            ),
          ],
        ),
      ),
    );
  }
}
