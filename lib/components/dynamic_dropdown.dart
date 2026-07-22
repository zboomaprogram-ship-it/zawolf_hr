import 'package:flutter/material.dart';
import '../../theme/theme.dart';

class DynamicDropdown extends StatefulWidget {
  final String label;
  final String actionLabel;
  final String dialogTitle;
  final String? initialValue;
  final ValueChanged<String?> onChanged;
  final Stream<List<String>> stream;
  final Future<void> Function(String) onAdd;
  final Future<void> Function() onInit;
  final bool canAdd;

  const DynamicDropdown({
    super.key,
    required this.label,
    required this.actionLabel,
    required this.dialogTitle,
    this.initialValue,
    required this.onChanged,
    required this.stream,
    required this.onAdd,
    required this.onInit,
    this.canAdd = true,
  });

  @override
  State<DynamicDropdown> createState() => _DynamicDropdownState();
}

class _DynamicDropdownState extends State<DynamicDropdown> {
  String? _selectedValue;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.initialValue;
    widget.onInit();
  }

  Future<void> _showAddDialog() async {
    final controller = TextEditingController();
    final newValue = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: ZaWolfColors.surface01,
          title: Text(
            widget.dialogTitle,
            style: const TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'اكتب هنا...',
              hintStyle: TextStyle(color: ZaWolfColors.textMuted),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'إلغاء',
                style: TextStyle(color: ZaWolfColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text(
                'إضافة',
                style: TextStyle(color: ZaWolfColors.primaryCyan),
              ),
            ),
          ],
        );
      },
    );

    if (newValue != null && newValue.isNotEmpty) {
      await widget.onAdd(newValue);
      setState(() {
        _selectedValue = newValue;
      });
      widget.onChanged(newValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.label,
              style: const TextStyle(
                color: ZaWolfColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.canAdd)
              TextButton.icon(
                onPressed: _showAddDialog,
                icon: const Icon(Icons.add, size: 16),
                label: Text(widget.actionLabel),
                style: TextButton.styleFrom(
                  foregroundColor: ZaWolfColors.primaryCyan,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<String>>(
          stream: widget.stream,
          builder: (context, snapshot) {
            final items = snapshot.data ?? [];
            if (!_isInitialized && items.isNotEmpty) {
              if (_selectedValue != null &&
                  _selectedValue!.isNotEmpty &&
                  !items.contains(_selectedValue)) {
                items.add(_selectedValue!);
              }
              _isInitialized = true;
            }

            return DropdownButtonFormField<String>(
              initialValue: (items.contains(_selectedValue))
                  ? _selectedValue
                  : null,
              decoration: InputDecoration(
                filled: true,
                fillColor: ZaWolfColors.surface01,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              dropdownColor: ZaWolfColors.surface02,
              style: const TextStyle(color: Colors.white),
              items: items.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(item, textDirection: TextDirection.ltr),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedValue = val;
                });
                widget.onChanged(val);
              },
              validator: (val) =>
                  val == null || val.isEmpty ? 'هذا الحقل مطلوب' : null,
            );
          },
        ),
      ],
    );
  }
}
