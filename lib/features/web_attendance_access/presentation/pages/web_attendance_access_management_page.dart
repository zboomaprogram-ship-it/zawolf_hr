import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../theme/theme.dart';
import '../../domain/entities/web_attendance_access_grant.dart';
import '../cubit/web_attendance_access_cubit.dart';

class WebAttendanceAccessManagementPage extends StatelessWidget {
  const WebAttendanceAccessManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تصاريح الحضور عبر الويب')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _editGrant(context),
          icon: const Icon(Icons.add),
          label: const Text('منح تصريح'),
        ),
        body: BlocBuilder<WebAttendanceAccessCubit, WebAttendanceAccessState>(
          builder: (context, state) {
            if (state.loading && state.grants.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            return RefreshIndicator(
              onRefresh: () => context.read<WebAttendanceAccessCubit>().load(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'يسمح التصريح بتسجيل الحضور والانصراف من الويب فقط. لا يلغي الموقع أو الإجازات أو أيام العطلات أو أوقات الدوام.',
                    style: TextStyle(color: ZaWolfColors.textSecondary),
                  ),
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        state.error!,
                        style: const TextStyle(color: ZaWolfColors.error),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (state.grants.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(
                        child: Text('لا توجد تصاريح حضور عبر الويب.'),
                      ),
                    ),
                  ...state.grants.map(
                    (grant) => Card(
                      child: ListTile(
                        leading: Icon(
                          grant.active
                              ? Icons.language_rounded
                              : Icons.block_rounded,
                          color:
                              grant.active
                                  ? ZaWolfColors.primaryCyan
                                  : ZaWolfColors.textMuted,
                        ),
                        title: Text(
                          grant.employeeName.isEmpty
                              ? grant.employeeCode
                              : grant.employeeName,
                        ),
                        subtitle: Text(_details(grant)),
                        trailing:
                            grant.active
                                ? IconButton(
                                  tooltip: 'إلغاء التصريح',
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: ZaWolfColors.error,
                                  ),
                                  onPressed:
                                      state.saving
                                          ? null
                                          : () => context
                                              .read<WebAttendanceAccessCubit>()
                                              .revoke(grant.employeeId),
                                )
                                : null,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static String _details(WebAttendanceAccessGrant grant) =>
      grant.permanent
          ? 'تصريح دائم • ${grant.employeeCode}'
          : 'من ${grant.startDate ?? ''} إلى ${grant.endDate ?? ''} • ${grant.employeeCode}';

  static Future<void> _editGrant(BuildContext context) async {
    final cubit = context.read<WebAttendanceAccessCubit>();
    final state = cubit.state;
    WebAttendanceEmployee? selected;
    var permanent = false;
    var start = DateTime.now();
    var end = DateTime.now().add(const Duration(days: 30));

    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (modalContext, setModal) => AlertDialog(
                  title: const Text('منح تصريح حضور عبر الويب'),
                  content: SizedBox(
                    width: 440,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<WebAttendanceEmployee>(
                            isExpanded: true,
                            initialValue: selected,
                            decoration: const InputDecoration(
                              labelText: 'الموظف',
                            ),
                            items:
                                state.employees
                                    .map(
                                      (employee) => DropdownMenuItem(
                                        value: employee,
                                        child: Text(
                                          '${employee.name} • ${employee.code}',
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (value) => setModal(() => selected = value),
                          ),
                          SwitchListTile(
                            value: permanent,
                            title: const Text('تصريح دائم'),
                            onChanged:
                                (value) => setModal(() => permanent = value),
                          ),
                          if (!permanent) ...[
                            ListTile(
                              title: const Text('من تاريخ'),
                              subtitle: Text(_date(start)),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: modalContext,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 366),
                                  ),
                                  initialDate: start,
                                );
                                if (picked != null) {
                                  setModal(() {
                                    start = picked;
                                    if (end.isBefore(start)) end = start;
                                  });
                                }
                              },
                            ),
                            ListTile(
                              title: const Text('إلى تاريخ'),
                              subtitle: Text(_date(end)),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: modalContext,
                                  firstDate: start,
                                  lastDate: start.add(
                                    const Duration(days: 365),
                                  ),
                                  initialDate: end,
                                );
                                if (picked != null) {
                                  setModal(() => end = picked);
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('إلغاء'),
                    ),
                    FilledButton(
                      onPressed:
                          selected == null || cubit.state.saving
                              ? null
                              : () async {
                                final ok = await cubit.save(
                                  employeeId: selected!.id,
                                  scope: permanent ? 'permanent' : 'period',
                                  startDate: permanent ? null : _date(start),
                                  endDate: permanent ? null : _date(end),
                                );
                                if (ok && dialogContext.mounted) {
                                  Navigator.pop(dialogContext);
                                }
                              },
                      child: const Text('حفظ'),
                    ),
                  ],
                ),
          ),
    );
  }

  static String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
