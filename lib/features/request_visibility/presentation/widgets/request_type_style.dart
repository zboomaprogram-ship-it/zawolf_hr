import 'package:flutter/material.dart';

import '../../../../theme/theme.dart';
import '../../domain/entities/request_visibility_record.dart';

/// Centralized style definitions for request types.
/// Provides distinctive border colors, shadow hues, icons, and labels.
final class RequestTypeStyle {
  const RequestTypeStyle({
    required this.borderColor,
    required this.shadowColor,
    required this.icon,
    required this.label,
  });

  final Color borderColor;
  final Color shadowColor;
  final IconData icon;
  final String label;

  static RequestTypeStyle fromSourceType(RequestSourceType type) => switch (type) {
    RequestSourceType.leave => const RequestTypeStyle(
      borderColor: ZaWolfColors.dayoffPurple,
      shadowColor: Color(0x477D8CFF),
      icon: Icons.event_available_outlined,
      label: 'إجازة',
    ),
    RequestSourceType.permission => const RequestTypeStyle(
      borderColor: ZaWolfColors.permissionTeal,
      shadowColor: Color(0x474FC3B2),
      icon: Icons.schedule_outlined,
      label: 'إذن',
    ),
    RequestSourceType.advance => const RequestTypeStyle(
      borderColor: ZaWolfColors.perfGold,
      shadowColor: Color(0x47E7C66A),
      icon: Icons.account_balance_wallet_outlined,
      label: 'سلفة',
    ),
    RequestSourceType.attendanceCorrection => const RequestTypeStyle(
      borderColor: ZaWolfColors.warning,
      shadowColor: Color(0x47E4B55D),
      icon: Icons.edit_calendar_outlined,
      label: 'تصحيح حضور',
    ),
    RequestSourceType.salaryDeduction => const RequestTypeStyle(
      borderColor: ZaWolfColors.error,
      shadowColor: Color(0x47FF6B6B),
      icon: Icons.money_off_outlined,
      label: 'خصم راتب',
    ),
    RequestSourceType.lateArrivalDeduction => const RequestTypeStyle(
      borderColor: ZaWolfColors.error,
      shadowColor: Color(0x47FF6B6B),
      icon: Icons.money_off_outlined,
      label: 'خصم حضور',
    ),
    RequestSourceType.administrative => const RequestTypeStyle(
      borderColor: ZaWolfColors.primaryCyan,
      shadowColor: Color(0x4745F0FF),
      icon: Icons.assignment_outlined,
      label: 'طلب إداري ومهمة',
    ),
    RequestSourceType.complaint => const RequestTypeStyle(
      borderColor: ZaWolfColors.warning,
      shadowColor: Color(0x47E4B55D),
      icon: Icons.report_problem_outlined,
      label: 'شكوى',
    ),
    RequestSourceType.resignation => const RequestTypeStyle(
      borderColor: ZaWolfColors.error,
      shadowColor: Color(0x47FF6B6B),
      icon: Icons.meeting_room_outlined,
      label: 'استقالة',
    ),
    RequestSourceType.employeeDeletion => const RequestTypeStyle(
      borderColor: ZaWolfColors.steel,
      shadowColor: Color(0x479AA9B5),
      icon: Icons.person_remove_outlined,
      label: 'حذف موظف',
    ),
    RequestSourceType.unknown => const RequestTypeStyle(
      borderColor: ZaWolfColors.primaryBlue,
      shadowColor: Color(0x47166C8C),
      icon: Icons.description_outlined,
      label: 'طلب',
    ),
  };

  static RequestTypeStyle get leave => fromSourceType(RequestSourceType.leave);
  static RequestTypeStyle get permission => fromSourceType(RequestSourceType.permission);
  static RequestTypeStyle get advance => fromSourceType(RequestSourceType.advance);
  static RequestTypeStyle get attendanceCorrection => fromSourceType(RequestSourceType.attendanceCorrection);
  static RequestTypeStyle get salaryDeduction => fromSourceType(RequestSourceType.salaryDeduction);
  static RequestTypeStyle get lateArrivalDeduction => fromSourceType(RequestSourceType.lateArrivalDeduction);
  static RequestTypeStyle get manualDeduction => fromSourceType(RequestSourceType.salaryDeduction);
  static RequestTypeStyle get administrative => fromSourceType(RequestSourceType.administrative);
  static RequestTypeStyle get complaint => fromSourceType(RequestSourceType.complaint);
  static RequestTypeStyle get resignation => fromSourceType(RequestSourceType.resignation);
  static RequestTypeStyle get employeeDeletion => fromSourceType(RequestSourceType.employeeDeletion);
  static RequestTypeStyle get unknown => fromSourceType(RequestSourceType.unknown);


  static Color stateColor(RequestLifecycleState state) => switch (state) {
    RequestLifecycleState.pending => ZaWolfColors.warning,
    RequestLifecycleState.approved ||
    RequestLifecycleState.confirmed => ZaWolfColors.success,
    RequestLifecycleState.rejected => ZaWolfColors.error,
    RequestLifecycleState.cancelled => ZaWolfColors.textMuted,
    RequestLifecycleState.unknown => ZaWolfColors.textSecondary,
  };

  static String stateLabel(RequestLifecycleState state) => switch (state) {
    RequestLifecycleState.pending => 'قيد المراجعة',
    RequestLifecycleState.approved => 'مقبول',
    RequestLifecycleState.rejected => 'مرفوض',
    RequestLifecycleState.cancelled => 'ملغي',
    RequestLifecycleState.confirmed => 'معتمد نهائيًا',
    RequestLifecycleState.unknown => 'غير محدد',
  };

  static String stageLabel(RequestApprovalStage stage) => switch (stage) {
    RequestApprovalStage.manager => 'المدير',
    RequestApprovalStage.ceo => 'المالك',
    RequestApprovalStage.hr => 'HR',
    RequestApprovalStage.finalised => 'مكتمل',
    RequestApprovalStage.unknown => 'مراجعة',
  };
}
