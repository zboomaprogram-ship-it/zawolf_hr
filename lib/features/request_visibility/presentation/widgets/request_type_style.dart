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
      borderColor: Color(0xFF10B981), // Emerald
      shadowColor: Color(0x4710B981),
      icon: Icons.event_available_outlined,
      label: 'إجازة',
    ),
    RequestSourceType.permission => const RequestTypeStyle(
      borderColor: ZaWolfColors.primaryCyan, // Cyan
      shadowColor: Color(0x4706B6D4),
      icon: Icons.schedule_outlined,
      label: 'إذن',
    ),
    RequestSourceType.advance => const RequestTypeStyle(
      borderColor: Color(0xFFF59E0B), // Amber/Gold
      shadowColor: Color(0x47F59E0B),
      icon: Icons.account_balance_wallet_outlined,
      label: 'سلفة',
    ),
    RequestSourceType.attendanceCorrection => const RequestTypeStyle(
      borderColor: Color(0xFFFF7043), // Deep Orange
      shadowColor: Color(0x47FF7043),
      icon: Icons.edit_calendar_outlined,
      label: 'تصحيح حضور',
    ),
    RequestSourceType.salaryDeduction => const RequestTypeStyle(
      borderColor: Color(0xFFEF4444), // Crimson
      shadowColor: Color(0x47EF4444),
      icon: Icons.money_off_outlined,
      label: 'خصم راتب',
    ),
    RequestSourceType.lateArrivalDeduction => const RequestTypeStyle(
      borderColor: Color(0xFFEF4444), // Crimson
      shadowColor: Color(0x47EF4444),
      icon: Icons.money_off_outlined,
      label: 'خصم حضور',
    ),
    RequestSourceType.administrative => const RequestTypeStyle(
      borderColor: Color(0xFF8B5CF6), // Violet/Purple
      shadowColor: Color(0x478B5CF6),
      icon: Icons.assignment_outlined,
      label: 'طلب إداري ومهمة',
    ),
    RequestSourceType.complaint => const RequestTypeStyle(
      borderColor: Color(0xFFEC4899), // Pink/Coral
      shadowColor: Color(0x47EC4899),
      icon: Icons.report_problem_outlined,
      label: 'شكوى',
    ),
    RequestSourceType.resignation => const RequestTypeStyle(
      borderColor: Color(0xFFE11D48), // Ruby/Rose
      shadowColor: Color(0x47E11D48),
      icon: Icons.meeting_room_outlined,
      label: 'استقالة',
    ),
    RequestSourceType.employeeDeletion => const RequestTypeStyle(
      borderColor: Color(0xFF64748B), // Slate
      shadowColor: Color(0x4764748B),
      icon: Icons.person_remove_outlined,
      label: 'حذف موظف',
    ),
    RequestSourceType.unknown => const RequestTypeStyle(
      borderColor: Color(0xFF0EA5E9), // Sky Blue
      shadowColor: Color(0x470EA5E9),
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
    RequestLifecycleState.pending => const Color(0xFFF59E0B),
    RequestLifecycleState.approved ||
    RequestLifecycleState.confirmed => const Color(0xFF10B981),
    RequestLifecycleState.rejected => const Color(0xFFEF4444),
    RequestLifecycleState.cancelled => const Color(0xFF94A3B8),
    RequestLifecycleState.unknown => const Color(0xFF64748B),
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
