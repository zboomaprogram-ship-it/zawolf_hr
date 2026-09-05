import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../domain/manual_attendance_repository.dart';
import 'manual_attendance_cubit.dart';

class ManualAttendanceScreen extends StatelessWidget {
  const ManualAttendanceScreen({required this.repository, super.key});

  final ManualAttendanceRepository repository;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ManualAttendanceCubit(repository)..search(''),
    child: const _ManualAttendanceView(),
  );
}

class _ManualAttendanceView extends StatefulWidget {
  const _ManualAttendanceView();

  @override
  State<_ManualAttendanceView> createState() => _ManualAttendanceViewState();
}

class _ManualAttendanceViewState extends State<_ManualAttendanceView> {
  final _search = TextEditingController();
  final _reason = TextEditingController();
  ManualAttendanceEmployee? _employee;
  DateTime _effectiveAt = DateTime.now();
  String _eventType = 'checkIn';
  String _filterMode = 'all';

  @override
  void dispose() {
    _search.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_effectiveAt),
    );
    if (picked == null) return;
    final now = DateTime.now();
    final candidate = DateTime(
      _effectiveAt.year,
      _effectiveAt.month,
      _effectiveAt.day,
      picked.hour,
      picked.minute,
    );
    // Manual attendance is intentionally limited to today and a current (or
    // earlier) time.  Catching this here avoids sending an invalid operation
    // to the server and, more importantly, makes the rule clear to HR.
    if (candidate.isAfter(now.add(const Duration(minutes: 1)))) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يمكن تسجيل حضور اليوم في الوقت الحالي أو وقت سابق فقط.',
          ),
        ),
      );
      return;
    }
    setState(() => _effectiveAt = candidate);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تسجيل حضور يدوي وإجراءات الدوام')),
        body: BlocConsumer<ManualAttendanceCubit, ManualAttendanceState>(
          listenWhen:
              (previous, current) =>
                  previous.error != current.error ||
                  previous.success != current.success,
          listener: (context, state) {
            final message = state.error ?? state.success;
            if (message == null) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor:
                    state.error == null ? Colors.green : Colors.red,
              ),
            );
          },
          builder:
              (context, state) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'للظروف الاستثنائية وإجراءات الحضور. يُسجل اسم HR والسبب تلقائياً مع توثيق التدقيق ولا يمكن استخدام هذه الشاشة لتعديل دورة رواتب مغلقة.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      labelText: 'ابحث عن الموظف',
                      hintText: 'الاسم أو الكود أو القسم أو البريد',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: context.read<ManualAttendanceCubit>().search,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'all',
                        label: Text('الكل'),
                        icon: Icon(Icons.people_outline),
                      ),
                      ButtonSegment(
                        value: 'not_checked_in',
                        label: Text('لم يسجلوا الحضور اليوم'),
                        icon: Icon(Icons.person_off_outlined),
                      ),
                      ButtonSegment(
                        value: 'checked_in',
                        label: Text('الحاضرين الآن'),
                        icon: Icon(Icons.person_pin_circle_outlined),
                      ),
                    ],
                    selected: {_filterMode},
                    onSelectionChanged:
                        (selected) =>
                            setState(() => _filterMode = selected.first),
                  ),
                  const SizedBox(height: 8),
                  if (state.loadingEmployees) const LinearProgressIndicator(),
                  ...state.employees
                      .where((employee) {
                        if (_filterMode == 'not_checked_in') {
                          return !employee.isCheckedIn;
                        } else if (_filterMode == 'checked_in') {
                          return employee.isCheckedIn && !employee.isCheckedOut;
                        }
                        return true;
                      })
                      .map(
                        (employee) => Card(
                          child: ListTile(
                            selected: _employee?.id == employee.id,
                            leading: Icon(
                              _employee?.id == employee.id
                                  ? Icons.check_circle
                                  : Icons.person_outline,
                            ),
                            title: Text(employee.name),
                            subtitle: Text(
                              '${employee.employeeCode} • ${employee.department}\n${_attendanceLabel(employee)}',
                            ),
                            trailing: Icon(
                              employee.isCheckedOut
                                  ? Icons.logout_rounded
                                  : employee.isCheckedIn
                                  ? Icons.login_rounded
                                  : Icons.person_off_outlined,
                              color:
                                  employee.isCheckedOut
                                      ? Colors.blue
                                      : employee.isCheckedIn
                                      ? Colors.green
                                      : Colors.redAccent,
                            ),
                            onTap: () => setState(() => _employee = employee),
                          ),
                        ),
                      ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'checkIn',
                        label: Text('حضور'),
                        icon: Icon(Icons.login),
                      ),
                      ButtonSegment(
                        value: 'checkOut',
                        label: Text('انصراف'),
                        icon: Icon(Icons.logout),
                      ),
                      ButtonSegment(
                        value: 'disableCheckOut',
                        label: Text('إلغاء الانصراف'),
                        icon: Icon(Icons.no_meeting_room),
                      ),
                    ],
                    selected: {_eventType},
                    onSelectionChanged:
                        (selected) =>
                            setState(() => _eventType = selected.first),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule),
                    label: Text(
                      'الوقت: ${DateFormat('yyyy/MM/dd – hh:mm a', 'ar').format(_effectiveAt)}',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _reason,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'سبب التسجيل اليدوي / الإجراء (مطلوب)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed:
                        state.submitting
                            ? null
                            : () {
                              if (_employee == null ||
                                  _reason.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'اختر الموظف واكتب سبب التسجيل.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              if (_effectiveAt.isAfter(
                                DateTime.now().add(const Duration(minutes: 1)),
                              )) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'يمكن تسجيل حضور اليوم في الوقت الحالي أو وقت سابق فقط.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              context.read<ManualAttendanceCubit>().submit(
                                employee: _employee!,
                                eventType: _eventType,
                                effectiveAt: _effectiveAt,
                                reason: _reason.text.trim(),
                              );
                            },
                    icon:
                        state.submitting
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.fact_check_outlined),
                    label: Text(
                      state.submitting ? 'جارٍ الحفظ...' : 'تسجيل العملية',
                    ),
                  ),
                ],
              ),
        ),
      ),
    );
  }

  String _attendanceLabel(ManualAttendanceEmployee employee) {
    if (employee.isCheckedOut) return 'سجل الحضور والانصراف اليوم';
    if (employee.isCheckedIn) return 'حاضر الآن — لم يسجل الانصراف بعد';
    return 'لم يسجل الحضور حتى الآن';
  }
}
