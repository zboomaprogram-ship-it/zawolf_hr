import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../cubit/developer_tools_admin_cubit.dart';

final class DeveloperToolsAdminPage extends StatefulWidget {
  const DeveloperToolsAdminPage({super.key});
  @override
  State<DeveloperToolsAdminPage> createState() =>
      _DeveloperToolsAdminPageState();
}

final class _DeveloperToolsAdminPageState
    extends State<DeveloperToolsAdminPage> {
  DateTime _expiry = DateTime.now().add(const Duration(hours: 8));
  // Developer diagnostics are deliberately permanent by default. They remain
  // diagnostic-only and do not change USB, mock-location, or attendance rules.
  bool _permanent = true;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إدارة أدوات المطوّر')),
    body: Directionality(
      textDirection: TextDirection.rtl,
      child: BlocConsumer<DeveloperToolsAdminCubit, DeveloperToolsAdminState>(
        listener: (context, state) {
          if (state.status == DeveloperToolsAdminStatus.saved) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('تم تحديث الصلاحية.')));
          } else if (state.status == DeveloperToolsAdminStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'تعذر تحديث الصلاحية. تحقق من الحساب ثم أعد المحاولة.',
                ),
              ),
            );
          }
        },
        builder: (context, state) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            OutlinedButton.icon(
              onPressed: () => context.push('/hr/diagnostics'),
              icon: const Icon(Icons.monitor_heart_outlined),
              label: const Text('عرض تقارير سلامة النظام'),
            ),
            const SizedBox(height: 12),
            const Text(
              'صلاحية تشخيص داخل التطبيق فقط. لا تمنح أي استثناء للحضور أو الموقع أو USB debugging.',
            ),
            const SizedBox(height: 16),
            if (state.status == DeveloperToolsAdminStatus.loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Autocomplete(
                displayStringForOption: (employee) => employee.label,
                optionsBuilder: (value) {
                  final query = value.text.trim().toLowerCase();
                  if (query.isEmpty) return state.employees.take(100);
                  return state.employees
                      .where((employee) {
                        final searchable =
                            '${employee.displayName} ${employee.employeeCode} ${employee.department}'
                                .toLowerCase();
                        return searchable.contains(query);
                      })
                      .take(100);
                },
                onSelected: context
                    .read<DeveloperToolsAdminCubit>()
                    .selectEmployee,
                fieldViewBuilder:
                    (context, controller, focusNode, onSubmitted) => TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'اختر الموظف',
                        hintText: 'ابحث بالاسم أو كود الموظف أو القسم',
                        prefixIcon: Icon(Icons.person_search_outlined),
                      ),
                    ),
                optionsViewBuilder: (context, onSelected, options) => Align(
                  alignment: Alignment.topRight,
                  child: Material(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 300,
                        maxWidth: 520,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final employee = options.elementAt(index);
                          return ListTile(
                            title: Text(employee.label),
                            subtitle: Text(employee.department),
                            onTap: () => onSelected(employee),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            if (state.selectedEmployee case final employee?) ...[
              const SizedBox(height: 8),
              Text(
                'الموظف المحدد: ${employee.label}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              title: const Text('صلاحية دائمة'),
              subtitle: const Text('لأدوات المطوّر داخل التطبيق فقط.'),
              value: _permanent,
              onChanged: (value) => setState(() => _permanent = value),
            ),
            if (!_permanent)
              ListTile(
                title: const Text('تنتهي الصلاحية'),
                subtitle: Text(_expiry.toLocal().toString().split('.').first),
                trailing: const Icon(Icons.timer_outlined),
                onTap: () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: _expiry,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 7)),
                  );
                  if (selected != null && mounted) {
                    setState(
                      () => _expiry = DateTime(
                        selected.year,
                        selected.month,
                        selected.day,
                        18,
                      ),
                    );
                  }
                },
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: state.status == DeveloperToolsAdminStatus.saving
                  ? null
                  : () => context.read<DeveloperToolsAdminCubit>().grant(
                      expiresAt: _permanent ? null : _expiry,
                      permanent: _permanent,
                    ),
              child: Text(_permanent ? 'منح صلاحية دائمة' : 'منح صلاحية مؤقتة'),
            ),
            TextButton(
              onPressed: state.status == DeveloperToolsAdminStatus.saving
                  ? null
                  : () => context.read<DeveloperToolsAdminCubit>().revoke(),
              child: const Text('سحب الصلاحية'),
            ),
          ],
        ),
      ),
    ),
  );
}
