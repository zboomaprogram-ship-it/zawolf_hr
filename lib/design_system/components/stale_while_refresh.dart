import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../tokens.dart';

/// Stale-while-refresh wrapper widget (Task C012 / FR-S3).
///
/// Ensures the screen preserves current content during pull-to-refresh or
/// background updates instead of unmounting and popping a disruptive spinner.
class StaleWhileRefresh extends StatelessWidget {
  const StaleWhileRefresh({
    required this.child,
    required this.hasData,
    this.isLoading = false,
    this.isRefreshing = false,
    this.loadingPlaceholder,
    this.onRefresh,
    this.errorMessage,
    this.onRetry,
    super.key,
  });

  /// The main content rendered when [hasData] is true.
  final Widget child;

  /// Whether valid data is currently present in state.
  final bool hasData;

  /// Whether the initial load is active (no data yet).
  final bool isLoading;

  /// Whether a background or pull refresh is in-flight while data is displayed.
  final bool isRefreshing;

  /// Skeleton or placeholder shown when [isLoading] is true and [hasData] is false.
  final Widget? loadingPlaceholder;

  /// Callback triggered on user pull-to-refresh.
  final Future<void> Function()? onRefresh;

  /// Optional error message to surface non-disruptively alongside stale data.
  final String? errorMessage;

  /// Optional callback to retry when [errorMessage] is present.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading && !hasData) {
      return loadingPlaceholder ??
          const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          );
    }

    Widget content = child;

    if (onRefresh != null) {
      content = RefreshIndicator(
        onRefresh: onRefresh!,
        color: ZaWolfColors.primaryCyan,
        backgroundColor: ZaWolfColors.surface01,
        child: content,
      );
    }

    return Stack(
      children: [
        Column(
          children: [
            if (errorMessage != null && hasData)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: DsSpacing.lg,
                  vertical: DsSpacing.sm,
                ),
                color: ZaWolfColors.error.withValues(alpha: 0.12),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: ZaWolfColors.error,
                    ),
                    const SizedBox(width: DsSpacing.sm),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: TextStyle(
                          color: ZaWolfColors.error,
                          fontSize: DsType.caption,
                        ),
                      ),
                    ),
                    if (onRetry != null)
                      TextButton(
                        onPressed: onRetry,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: DsSpacing.sm,
                          ),
                        ),
                        child: Text(
                          'إعادة المحاولة',
                          style: TextStyle(
                            color: ZaWolfColors.error,
                            fontWeight: FontWeight.bold,
                            fontSize: DsType.caption,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(child: content),
          ],
        ),
        if (isRefreshing && hasData)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              minHeight: 2.5,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                ZaWolfColors.primaryCyan,
              ),
            ),
          ),
      ],
    );
  }
}
