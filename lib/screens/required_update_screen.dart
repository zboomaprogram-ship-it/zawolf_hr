import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_security_policy_service.dart';
import '../theme/theme.dart';
import '../core/feature_flags/required_update_state.dart';
import '../services/safe_diagnostics_service.dart';

class RequiredUpdateScreen extends StatelessWidget {
  final AppSecurityStatus status;
  final VoidCallback onRetry;

  const RequiredUpdateScreen({
    super.key,
    required this.status,
    required this.onRetry,
  });

  Future<void> _openStore(BuildContext context) async {
    final url = status.policy.storeUrlForCurrentPlatform().trim();
    final destination = Uri.tryParse(url);
    if (destination == null ||
        url.isEmpty ||
        !await launchUrl(destination, mode: LaunchMode.externalApplication)) {
      await SafeDiagnosticsService.instance.capture(
        feature: 'required_update',
        safeCode: 'temporarily_unavailable',
        operation: 'open_store',
        surface: 'required_update',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح صفحة التحديث. تواصل مع HR.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewState = requiredUpdateViewState(status);
    final unavailable = viewState == RequiredUpdateViewState.policyUnavailable;
    final unsupported = viewState == RequiredUpdateViewState.unsupportedRelease;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ZaWolfTheme.darkTheme,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: ZaWolfColors.background,
          body: SafeArea(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [ZaWolfColors.surface01, ZaWolfColors.background],
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: ZaWolfColors.surface01,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: ZaWolfColors.primaryCyan.withValues(alpha: 0.6),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 28,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          unavailable
                              ? Icons.cloud_off_outlined
                              : unsupported
                              ? Icons.mobile_off_outlined
                              : Icons.security_update_good_outlined,
                          size: 72,
                          color:
                              unavailable
                                  ? ZaWolfColors.warning
                                  : ZaWolfColors.primaryCyan,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          unavailable
                              ? 'تعذر التحقق من الإصدار'
                              : unsupported
                              ? 'هذا الإصدار لم يعد مدعوماً'
                              : 'تحديث أمني مطلوب',
                          style: Theme.of(
                            context,
                          ).textTheme.headlineMedium?.copyWith(
                            color: ZaWolfColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          unavailable
                              ? 'تعذر الاتصال بسياسة أمان التطبيق. تحقق من الإنترنت ثم أعد المحاولة.'
                              : unsupported
                              ? 'لا توجد حزمة تحديث متاحة لهذا الجهاز حالياً. تواصل مع مسؤول النظام لمعرفة الإصدار المدعوم.'
                              : status.policy.messageAr,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(
                            color: ZaWolfColors.textSecondary,
                            height: 1.55,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'الإصدار الحالي ${status.version}+${status.currentBuild}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: ZaWolfColors.textMuted),
                        ),
                        const SizedBox(height: 28),
                        if (!unavailable && !unsupported)
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => _openStore(context),
                              icon: const Icon(Icons.system_update_alt),
                              label: const Text('تحديث التطبيق'),
                            ),
                          ),
                        SizedBox(height: unavailable || unsupported ? 20 : 10),
                        OutlinedButton.icon(
                          onPressed: () {
                            if (unavailable || unsupported) {
                              SafeDiagnosticsService.instance.capture(
                                feature: 'required_update',
                                safeCode:
                                    unavailable
                                        ? 'temporarily_unavailable'
                                        : 'validation_failed',
                                operation: 'retry_policy',
                                surface: 'required_update',
                              );
                            }
                            onRetry();
                          },
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            unavailable
                                ? 'إعادة الاتصال'
                                : unsupported
                                ? 'التحقق من توفر إصدار جديد'
                                : 'تحقق مرة أخرى',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
