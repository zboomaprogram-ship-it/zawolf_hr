import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/developer_tools_entitlement.dart';
import '../cubit/developer_tools_cubit.dart';

/// In-app troubleshooting only. This page never changes Android/iOS settings
/// and never exposes attendance/device/location controls.
final class DeveloperToolsPage extends StatelessWidget {
  const DeveloperToolsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('أدوات المطوّر')),
    body: BlocBuilder<DeveloperToolsCubit, DeveloperToolsState>(
      builder: (context, state) {
        if (state.status == DeveloperToolsStatus.initial ||
            state.status == DeveloperToolsStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!state.canShowMenu) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'لا تتوفر أدوات المطوّر لهذا الحساب حالياً. لا تؤثر هذه الصفحة في إعدادات حماية الحضور أو الجهاز.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final entitlement = state.entitlement!;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: Text(
                    entitlement.permanent ? 'صلاحية دائمة' : 'صلاحية مؤقتة',
                  ),
                  subtitle: Text(
                    entitlement.permanent
                        ? 'مفعلة حتى يتم سحبها من مسؤول النظام.'
                        : 'تنتهي في ${entitlement.expiresAt?.toLocal().toString().split('.').first ?? ''}',
                  ),
                ),
              ),
              if (entitlement.allows(DeveloperToolScope.appDiagnostics))
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('معلومات التطبيق'),
                  subtitle: Text('لعرض الإصدار وحالة الشاشة فقط.'),
                ),
              if (entitlement.allows(DeveloperToolScope.networkDiagnostics))
                const ListTile(
                  leading: Icon(Icons.network_check_outlined),
                  title: Text('فحص اتصال التطبيق'),
                  subtitle: Text('فحص آمن للاتصال دون عرض بيانات حساسة.'),
                ),
              if (entitlement.allows(DeveloperToolScope.releaseInformation))
                const ListTile(
                  leading: Icon(Icons.new_releases_outlined),
                  title: Text('معلومات الإصدار'),
                  subtitle: Text('للتحقق من إصدار التطبيق فقط.'),
                ),
              const Divider(),
              const Text(
                'لا تسمح هذه الأدوات بتشغيل USB debugging أو mock location أو تجاوز ربط الجهاز أو تسجيل الحضور.',
              ),
            ],
          ),
        );
      },
    ),
  );
}
