import 'package:flutter/material.dart';

import '../../../../theme/theme.dart';
import '../cubit/remote_day_cubit.dart';

class RemoteAttendanceStatusCard extends StatelessWidget {
  const RemoteAttendanceStatusCard({
    required this.state,
    required this.onCheckIn,
    required this.onCheckOut,
    super.key,
  });

  final RemoteDayState state;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case RemoteDayStatus.loading:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
          ),
        );

      case RemoteDayStatus.ineligible:
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ZaWolfColors.surface02,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ZaWolfColors.warning.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.info_outline, color: ZaWolfColors.warning),
                  SizedBox(width: 8),
                  Text(
                    'غير متاح للعمل عن بُعد اليوم',
                    style: TextStyle(
                      color: ZaWolfColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                state.errorMessage ?? 'اليوم غير مخصص للعمل عن بعد وفق جدولك المعتمد.',
                style: const TextStyle(color: ZaWolfColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        );

      case RemoteDayStatus.modeLocked:
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ZaWolfColors.surface02,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ZaWolfColors.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_clock, color: ZaWolfColors.error, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  state.errorMessage ??
                      'تم قفل نمط اليوم الواحد على الدوام المكتبي؛ لا يمكن التبديل للعمل عن بعد.',
                  style: const TextStyle(color: ZaWolfColors.textPrimary, fontSize: 14),
                ),
              ),
            ],
          ),
        );

      case RemoteDayStatus.eligible:
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: ZaWolfColors.surface02,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ZaWolfColors.borderGlow),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: ZaWolfColors.primaryCyan),
                  SizedBox(width: 10),
                  Text(
                    'أنت مؤهل لتسجيل الحضور عن بُعد اليوم',
                    style: TextStyle(
                      color: ZaWolfColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'يتم إثبات الحضور بمفتاح المرور المعتمد من HR وحاسوبك الشخصي دون الحاجة لمشاركة الموقع الجغرافي.',
                style: TextStyle(color: ZaWolfColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onCheckIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZaWolfColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.fingerprint),
                label: const Text('تسجيل الحضور بمفتاح المرور'),
              ),
            ],
          ),
        );

      case RemoteDayStatus.checkedIn:
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ZaWolfColors.surface02,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ZaWolfColors.success.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: ZaWolfColors.success),
                  SizedBox(width: 8),
                  Text(
                    'جلسة العمل عن بُعد نشطة',
                    style: TextStyle(
                      color: ZaWolfColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'معرّف الجلسة: ${state.sessionId ?? 'نشط'}',
                style: const TextStyle(color: ZaWolfColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onCheckOut,
                style: OutlinedButton.styleFrom(
                  foregroundColor: ZaWolfColors.error,
                  side: const BorderSide(color: ZaWolfColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.exit_to_app),
                label: const Text('تسجيل الانصراف عن بُعد'),
              ),
            ],
          ),
        );

      case RemoteDayStatus.checkedOut:
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: ZaWolfColors.surface02,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ZaWolfColors.success),
          ),
          child: const Row(
            children: [
              Icon(Icons.task_alt, color: ZaWolfColors.success, size: 32),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'تم إكمال وردية العمل عن بعد وتسجيل الانصراف بنجاح.',
                  style: TextStyle(
                    color: ZaWolfColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        );

      case RemoteDayStatus.error:
      case RemoteDayStatus.initial:
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ZaWolfColors.surface02,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ZaWolfColors.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: ZaWolfColors.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  state.errorMessage ?? 'تعذر تحميل حالة الدوام. أعد المحاولة.',
                  style: const TextStyle(color: ZaWolfColors.textPrimary, fontSize: 14),
                ),
              ),
            ],
          ),
        );
    }
  }
}
