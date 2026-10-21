import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../theme/theme.dart';
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
  final Set<String> _selectedEmployeeIds = <String>{};
  DateTime _effectiveAt = DateTime.now();
  String _eventType = 'checkIn';
  String _filterMode = 'all';

  @override
  void dispose() {
    _search.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveAt.isAfter(now) ? now : _effectiveAt,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: now,
    );
    if (picked == null) return;
    final candidate = DateTime(
      picked.year,
      picked.month,
      picked.day,
      _effectiveAt.hour,
      _effectiveAt.minute,
    );
    final adjusted = candidate.isAfter(now.add(const Duration(minutes: 1)))
        ? DateTime(picked.year, picked.month, picked.day, now.hour, now.minute)
        : candidate;

    setState(() {
      _effectiveAt = adjusted;
      _selectedEmployeeIds.clear();
    });
    if (mounted) {
      context.read<ManualAttendanceCubit>().changeDate(picked);
    }
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
    if (candidate.isAfter(now.add(const Duration(minutes: 1)))) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لا يمكن تسجيل وقت في المستقبل.',
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
            if (state.success != null) {
              setState(() {
                _selectedEmployeeIds.clear();
                _reason.clear();
              });
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor:
                    state.error == null
                        ? ZaWolfColors.success
                        : ZaWolfColors.error,
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
                        label: Text('لم يسجلوا الحضور'),
                        icon: Icon(Icons.person_off_outlined),
                      ),
                      ButtonSegment(
                        value: 'checked_in',
                        label: Text('حاضرين (بدون انصراف)'),
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
                            selected: _selectedEmployeeIds.contains(
                              employee.id,
                            ),
                            leading: Checkbox(
                              value: _selectedEmployeeIds.contains(employee.id),
                              onChanged:
                                  (checked) => setState(() {
                                    if (checked == true) {
                                      _selectedEmployeeIds.add(employee.id);
                                    } else {
                                      _selectedEmployeeIds.remove(employee.id);
                                    }
                                  }),
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
                                      ? ZaWolfColors.primaryBlue
                                      : employee.isCheckedIn
                                      ? ZaWolfColors.success
                                      : ZaWolfColors.error,
                            ),
                            onTap:
                                () => setState(() {
                                  if (_selectedEmployeeIds.contains(employee.id)) {
                                    _selectedEmployeeIds.remove(employee.id);
                                  } else {
                                    _selectedEmployeeIds.add(employee.id);
                                  }
                                }),
                          ),
                        ),
                      ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('تم اختيار ${_selectedEmployeeIds.length} موظفاً'),
                      const Spacer(),
                      TextButton(
                        onPressed:
                            _selectedEmployeeIds.isEmpty
                                ? null
                                : () => setState(_selectedEmployeeIds.clear),
                        child: const Text('إلغاء التحديد'),
                      ),
                    ],
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
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.event_outlined),
                          label: Text(
                            'التاريخ: ${DateFormat('yyyy/MM/dd', 'ar').format(_effectiveAt)}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickTime,
                          icon: const Icon(Icons.schedule),
                          label: Text(
                            'الوقت: ${DateFormat('hh:mm a', 'ar').format(_effectiveAt)}',
                          ),
                        ),
                      ),
                    ],
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
                              if (_selectedEmployeeIds.isEmpty ||
                                  _reason.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'اختر موظفاً واحداً أو أكثر واكتب سبب التسجيل.',
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
                                      'لا يمكن تسجيل الحضور في تاريخ أو وقت مستقبلي.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              context.read<ManualAttendanceCubit>().submitBatch(
                                employeeIds: _selectedEmployeeIds.toList(growable: false),
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
                      state.submitting
                          ? 'جارٍ الحفظ...'
                          : 'تسجيل العملية للمختارين',
                    ),
                  ),
                ],
              ),
        ),
      ),
    );
  }

  String _attendanceLabel(ManualAttendanceEmployee employee) {
    final isToday = DateUtils.isSameDay(_effectiveAt, DateTime.now());
    if (employee.isCheckedOut) {
      final timeStr = employee.checkOutAt != null
          ? ' (انصراف: ${DateFormat('hh:mm a', 'ar').format(employee.checkOutAt!.toLocal())})'
          : '';
      return isToday
          ? 'سجل الحضور والانصراف اليوم$timeStr'
          : 'سجل الحضور والانصراف$timeStr';
    }
    if (employee.isCheckedIn) {
      final timeStr = employee.checkInAt != null
          ? ' (حضور: ${DateFormat('hh:mm a', 'ar').format(employee.checkInAt!.toLocal())})'
          : '';
      return isToday
          ? 'حاضر الآن — لم يسجل الانصراف بعد$timeStr'
          : 'حاضر — لم يسجل الانصراف$timeStr';
    }
    return isToday
        ? 'لم يسجل الحضور حتى الآن'
        : 'غائب / لم يسجل حضور في هذا اليوم';
  }
}
