import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_security_policy_service.dart';
import '../theme/theme.dart';

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
    if (url.isEmpty || !await launchUrl(Uri.parse(url))) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح صفحة التحديث. تواصل مع HR.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ZaWolfTheme.darkTheme,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.security_update_good_outlined,
                        size: 72,
                        color: ZaWolfColors.primaryCyan,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'تحديث أمني مطلوب',
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        status.policy.messageAr,
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'الإصدار الحالي ${status.version}+${status.currentBuild}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _openStore(context),
                          icon: const Icon(Icons.system_update_alt),
                          label: const Text('تحديث التطبيق'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('تحقق مرة أخرى'),
                      ),
                    ],
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
