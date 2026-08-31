import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../tokens.dart';

/// Empty-state placeholder with optional call-to-action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.ctaLabel,
    this.onCta,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DsSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: ZaWolfColors.surface02,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: ZaWolfColors.textMuted, size: 28),
            ),
            const SizedBox(height: DsSpacing.lg),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: DsSpacing.sm),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: DsSpacing.lg),
              FilledButton(
                onPressed: onCta,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  backgroundColor: ZaWolfColors.primaryCyan,
                  foregroundColor: ZaWolfColors.background,
                ),
                child: Text(ctaLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error placeholder with retry. Message text must never expose provider or
/// Firebase internals (specs/ui_redesign/04_screen_states_polish_spec.md).
class ErrorState extends StatelessWidget {
  const ErrorState({
    this.message = 'حدث خطأ أثناء تحميل البيانات',
    this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DsSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: ZaWolfColors.errorSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: ZaWolfColors.error,
                size: 28,
              ),
            ),
            const SizedBox(height: DsSpacing.lg),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: DsSpacing.lg),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  foregroundColor: ZaWolfColors.primaryCyan,
                  side: const BorderSide(color: ZaWolfColors.primaryCyan),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
