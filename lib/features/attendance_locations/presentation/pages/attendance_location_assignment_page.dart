import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../theme/theme.dart';
import '../../domain/entities/attendance_assignment_option.dart';
import '../../domain/repositories/attendance_location_assignment_repository.dart';
import '../cubit/attendance_location_assignment_cubit.dart';

class AttendanceLocationAssignmentPage extends StatefulWidget {
  const AttendanceLocationAssignmentPage({
    super.key,
    required this.employees,
    required this.locations,
    required this.repository,
  });

  final List<AttendanceEmployeeOption> employees;
  final List<AttendanceSiteOption> locations;
  final AttendanceLocationAdministrationRepository repository;

  @override
  State<AttendanceLocationAssignmentPage> createState() =>
      _AttendanceLocationAssignmentPageState();
}

class _AttendanceLocationAssignmentPageState
    extends State<AttendanceLocationAssignmentPage> {
  final _searchController = TextEditingController();
  final _employeeUids = <String>{};
  final _locationIds = <String>{};
  DateTime _effectiveFrom = DateTime.now();
  DateTime? _effectiveTo;
  String? _defaultLocationId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AttendanceLocationAssignmentCubit(widget.repository),
      child: Builder(builder: _buildBody),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('إسناد مواقع الحضور')),
        body:
            BlocConsumer<
              AttendanceLocationAssignmentCubit,
              AttendanceLocationAssignmentState
            >(
              listener: (context, state) {
                final message = state.message;
                if (message != null) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(message)));
                }
              },
              builder: (context, state) {
                final query = _searchController.text.trim().toLowerCase();
                final employees = widget.employees
                    .where((employee) {
                      if (query.isEmpty) return true;
                      return '${employee.name} ${employee.employeeCode} ${employee.department}'
                          .toLowerCase()
                          .contains(query);
                    })
                    .toList(growable: false);
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'بحث باسم الموظف أو الكود أو القسم',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Section(
                      title: 'الموظفون (${_employeeUids.length})',
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 260),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: employees.length,
                          itemBuilder: (_, index) {
                            final employee = employees[index];
                            return CheckboxListTile(
                              value: _employeeUids.contains(employee.uid),
                              title: Text(employee.name),
                              subtitle: Text(
                                '${employee.employeeCode} · ${employee.department}',
                              ),
                              onChanged: state.busy
                                  ? null
                                  : (selected) => setState(() {
                                      selected == true
                                          ? _employeeUids.add(employee.uid)
                                          : _employeeUids.remove(employee.uid);
                                      context
                                          .read<
                                            AttendanceLocationAssignmentCubit
                                          >()
                                          .edit();
                                    }),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Section(
                      title: 'المواقع المسموحة (${_locationIds.length})',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.locations
                            .map((location) {
                              return FilterChip(
                                label: Text(location.name),
                                selected: _locationIds.contains(location.id),
                                onSelected: state.busy
                                    ? null
                                    : (selected) => setState(() {
                                        selected
                                            ? _locationIds.add(location.id)
                                            : _locationIds.remove(location.id);
                                        if (!_locationIds.contains(
                                          _defaultLocationId,
                                        )) {
                                          _defaultLocationId = null;
                                        }
                                        context
                                            .read<
                                              AttendanceLocationAssignmentCubit
                                            >()
                                            .edit();
                                      }),
                              );
                            })
                            .toList(growable: false),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _defaultLocationId,
                      decoration: const InputDecoration(
                        labelText: 'الموقع الافتراضي (اختياري)',
                      ),
                      items: widget.locations
                          .where(
                            (location) => _locationIds.contains(location.id),
                          )
                          .map(
                            (location) => DropdownMenuItem(
                              value: location.id,
                              child: Text(location.name),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: state.busy
                          ? null
                          : (value) =>
                                setState(() => _defaultLocationId = value),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _DateButton(
                            label: 'يبدأ من',
                            date: _effectiveFrom,
                            onPressed: () => _pickDate(context, start: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateButton(
                            label: 'ينتهي في (اختياري)',
                            date: _effectiveTo,
                            onPressed: () => _pickDate(context, start: false),
                          ),
                        ),
                      ],
                    ),
                    if (state.preview.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _PreviewCard(data: state.preview),
                    ],
                    const SizedBox(height: 24),
                    if (state.busy)
                      const Center(child: CircularProgressIndicator())
                    else if (state.phase ==
                        AttendanceLocationAssignmentPhase.previewed)
                      FilledButton.icon(
                        onPressed: () => context
                            .read<AttendanceLocationAssignmentCubit>()
                            .apply(
                              employeeUids: _employeeUids.toList(),
                              locationIds: _locationIds.toList(),
                              effectiveFrom: _effectiveFrom,
                              effectiveTo: _effectiveTo,
                              defaultLocationId: _defaultLocationId,
                            ),
                        icon: const Icon(Icons.verified_outlined),
                        label: Text(
                          state.preview['mode'] == 'remove'
                              ? 'تأكيد إزالة الإسنادات'
                              : 'تأكيد وحفظ الإسنادات',
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _canPreview
                                  ? () => context
                                        .read<
                                          AttendanceLocationAssignmentCubit
                                        >()
                                        .preview(
                                          employeeUids: _employeeUids.toList(),
                                          locationIds: _locationIds.toList(),
                                          effectiveFrom: _effectiveFrom,
                                          effectiveTo: _effectiveTo,
                                          defaultLocationId: _defaultLocationId,
                                        )
                                  : null,
                              icon: const Icon(Icons.preview_outlined),
                              label: const Text('معاينة الإسناد'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _canPreview
                                  ? () => _previewRemoval(context)
                                  : null,
                              icon: const Icon(Icons.remove_circle_outline),
                              label: const Text('معاينة الإزالة'),
                            ),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
      ),
    );
  }

  bool get _canPreview => _employeeUids.isNotEmpty && _locationIds.isNotEmpty;

  Future<void> _previewRemoval(BuildContext context) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('معاينة إزالة المواقع'),
            content: Text(
              'سيتم إعداد إزالة ${_locationIds.length} موقع من ${_employeeUids.length} موظف. لن يتغير سجل الحضور السابق.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('متابعة للمعاينة'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    await context.read<AttendanceLocationAssignmentCubit>().preview(
      employeeUids: _employeeUids.toList(),
      locationIds: _locationIds.toList(),
      effectiveFrom: _effectiveFrom,
      effectiveTo: _effectiveTo,
      remove: true,
    );
  }

  Future<void> _pickDate(BuildContext context, {required bool start}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _effectiveFrom : (_effectiveTo ?? _effectiveFrom),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _effectiveFrom = picked;
        if (_effectiveTo?.isBefore(picked) == true) _effectiveTo = null;
      } else {
        _effectiveTo = picked;
      }
    });
    if (context.mounted) {
      context.read<AttendanceLocationAssignmentCubit>().edit();
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          child,
        ],
      ),
    ),
  );
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.date,
    required this.onPressed,
  });
  final String label;
  final DateTime? date;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: const Icon(Icons.event),
    label: Text(
      '$label: ${date == null ? 'غير محدد' : '${date!.year}-${date!.month}-${date!.day}'}',
    ),
  );
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) => Card(
    color: ZaWolfColors.primaryCyan.withValues(alpha: .08),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        '${data['mode'] == 'remove' ? 'إزالة' : 'إسناد'} · الموظفون: ${data['employeeCount'] ?? '-'} · المواقع: ${data['locationCount'] ?? '-'} · الإسنادات: ${data['assignmentCount'] ?? '-'}',
      ),
    ),
  );
}
