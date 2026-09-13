import 'package:flutter/material.dart';

import '../../../services/payroll_pre_audit_service.dart';
import '../../../theme/theme.dart';

final class PayrollPreAuditDialog extends StatefulWidget {
  const PayrollPreAuditDialog({super.key});

  @override
  State<PayrollPreAuditDialog> createState() => _PayrollPreAuditDialogState();
}

class _PayrollPreAuditDialogState extends State<PayrollPreAuditDialog> {
  bool _loading = true;
  int _pendingLeaves = 0;
  int _pendingPermissions = 0;
  int _pendingCorrections = 0;
  int _unassignedSalaryEmployees = 0;

  @override
  void initState() {
    super.initState();
    _runPreAuditScan();
  }

  Future<void> _runPreAuditScan() async {
    setState(() => _loading = true);
    try {
      final summary = await PayrollPreAuditService().load();
      _pendingLeaves = summary.pendingLeaves;
      _pendingPermissions = summary.pendingPermissions;
      _pendingCorrections = summary.pendingCorrections;
      _unassignedSalaryEmployees = summary.unassignedSalaryEmployees;
    } catch (_) {
      // Safe fallback
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasIssues =
        _pendingLeaves > 0 ||
        _pendingPermissions > 0 ||
        _pendingCorrections > 0 ||
        _unassignedSalaryEmployees > 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: ZaWolfColors.surface01,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.fact_check_outlined, color: ZaWolfColors.primaryCyan, size: 26),
            SizedBox(width: 10),
            Text(
              'التدقيق المالي قبل الاعتماد',
              style: TextStyle(color: ZaWolfColors.textPrimary, fontSize: 18),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: hasIssues
                            ? ZaWolfColors.warning.withValues(alpha: 0.15)
                            : ZaWolfColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: hasIssues
                              ? ZaWolfColors.warning.withValues(alpha: 0.4)
                              : ZaWolfColors.success.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            hasIssues
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_outline_rounded,
                            color: hasIssues
                                ? ZaWolfColors.warning
                                : ZaWolfColors.success,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              hasIssues
                                  ? 'تنبيه: توجد طلبات معلقة قد تؤثر على دقة الرواتب.'
                                  : 'جاهز للاحتساب: جميع البيانات مكتملة ولا توجد طلبات معلقة.',
                              style: TextStyle(
                                color: hasIssues
                                    ? ZaWolfColors.warning
                                    : ZaWolfColors.success,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _AuditCheckRow(
                      label: 'إجازات معلقة بانتظار الاعتماد',
                      count: _pendingLeaves,
                    ),
                    const SizedBox(height: 8),
                    _AuditCheckRow(
                      label: 'أذونات معلقة بانتظار الاعتماد',
                      count: _pendingPermissions,
                    ),
                    const SizedBox(height: 8),
                    _AuditCheckRow(
                      label: 'طلبات تصحيح حضور معلقة',
                      count: _pendingCorrections,
                    ),
                    const SizedBox(height: 8),
                    _AuditCheckRow(
                      label: 'موظفون بدون راتب أساسي محدد',
                      count: _unassignedSalaryEmployees,
                    ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق', style: TextStyle(color: ZaWolfColors.textSecondary)),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: ZaWolfColors.primaryCyan,
              foregroundColor: ZaWolfColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('متابعة احتساب الرواتب'),
          ),
        ],
      ),
    );
  }
}

class _AuditCheckRow extends StatelessWidget {
  const _AuditCheckRow({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final isClear = count == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface02,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            isClear ? Icons.check_rounded : Icons.priority_high_rounded,
            color: isClear ? ZaWolfColors.success : ZaWolfColors.warning,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: ZaWolfColors.textPrimary, fontSize: 13),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isClear
                  ? ZaWolfColors.success.withValues(alpha: 0.2)
                  : ZaWolfColors.warning.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: isClear ? ZaWolfColors.success : ZaWolfColors.warning,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
