import 'package:flutter/material.dart';

import '../../domain/entities/organization_membership.dart';
import '../../domain/repositories/organization_structure_repository.dart';

final class OrganizationPeoplePicker extends StatefulWidget {
  const OrganizationPeoplePicker({
    super.key,
    required this.repository,
    this.multiSelect = false,
    this.initialSelection = const {},
    this.onSelectionChanged,
    this.departmentFilter,
  });
  final OrganizationStructureRepository repository;
  final bool multiSelect;
  final Set<String> initialSelection;
  final ValueChanged<Set<String>>? onSelectionChanged;
  final String? departmentFilter;
  @override
  State<OrganizationPeoplePicker> createState() =>
      _OrganizationPeoplePickerState();
}

final class _OrganizationPeoplePickerState
    extends State<OrganizationPeoplePicker> {
  List<OrganizationMembership> _items = const [];
  late final Set<String> _selected = {...widget.initialSelection};
  bool _loading = false;

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final items = await widget.repository.searchEmployees(query);
      if (mounted) {
        setState(
          () => _items = widget.departmentFilter == null
              ? items
              : items
                    .where(
                      (item) =>
                          item.departmentUnitId == widget.departmentFilter,
                    )
                    .toList(growable: false),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 560,
    height: 520,
    child: Column(
      children: [
        TextField(
          autofocus: true,
          onChanged: _search,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'بحث بالاسم أو الكود',
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        Expanded(
          child: ListView.builder(
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              final selected = _selected.contains(item.employeeUid);
              return CheckboxListTile(
                value: selected,
                title: SelectableText(item.employeeName),
                subtitle: SelectableText(item.employeeCode),
                onChanged: (_) {
                  setState(() {
                    if (!widget.multiSelect) _selected.clear();
                    selected
                        ? _selected.remove(item.employeeUid)
                        : _selected.add(item.employeeUid);
                  });
                  widget.onSelectionChanged?.call(Set.unmodifiable(_selected));
                  if (!widget.multiSelect) Navigator.pop(context, _selected);
                },
              );
            },
          ),
        ),
        if (widget.multiSelect)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.icon(
              onPressed: _selected.isEmpty
                  ? null
                  : () => Navigator.pop(context, _selected),
              icon: const Icon(Icons.check),
              label: Text('اختيار (${_selected.length})'),
            ),
          ),
      ],
    ),
  );
}
