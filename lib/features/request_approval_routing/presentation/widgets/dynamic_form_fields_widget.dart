import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../domain/entities/custom_request_template.dart';

/// Reusable dynamic form renderer for custom and template request fields.
class DynamicFormFieldsWidget extends StatelessWidget {
  const DynamicFormFieldsWidget({
    required this.fields,
    required this.values,
    required this.onChanged,
    this.isEnabled = true,
    super.key,
  });

  final List<CustomRequestField> fields;
  final Map<String, dynamic> values;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final bool isEnabled;

  void _updateValue(String key, dynamic value) {
    final next = Map<String, dynamic>.from(values);
    if (value == null) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    if (fields.isEmpty) return const SizedBox.shrink();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(Icons.dynamic_form_outlined, size: 18, color: Colors.blueGrey),
                SizedBox(width: 8),
                Text(
                  'معلومات إضافية مطلوبة (حقول مخصصة):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey),
                ),
              ],
            ),
          ),
          ...fields.map((field) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: _buildFieldWidget(context, field),
              )),
        ],
      ),
    );
  }

  Widget _buildFieldWidget(BuildContext context, CustomRequestField field) {
    final type = field.type;
    if (type == 'number') {
      return _buildNumberField(field);
    } else if (type == 'date') {
      return _buildDateField(context, field);
    } else if (type == 'date_range') {
      return _buildDateRangeField(context, field);
    } else if (type == 'select' || type == 'dropdown') {
      return _buildSelectField(field);
    } else if (type == 'checkbox') {
      return _buildCheckboxField(field);
    } else if (type == 'file' || type == 'upload') {
      return _buildFileUploadField(context, field);
    }
    return _buildTextField(field);
  }

  Widget _buildTextField(CustomRequestField field) {
    final current = values[field.key]?.toString() ?? '';
    return TextFormField(
      initialValue: current,
      enabled: isEnabled,
      decoration: InputDecoration(
        labelText: '${field.labelAr}${field.isRequired ? ' *' : ''}',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      validator: (val) {
        if (field.isRequired && (val == null || val.trim().isEmpty)) {
          return 'يرجى إدخال ${field.labelAr}';
        }
        return null;
      },
      onChanged: (val) => _updateValue(field.key, val.trim()),
    );
  }

  Widget _buildNumberField(CustomRequestField field) {
    final current = values[field.key]?.toString() ?? '';
    return TextFormField(
      initialValue: current,
      enabled: isEnabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: '${field.labelAr}${field.isRequired ? ' *' : ''}',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      validator: (val) {
        if (field.isRequired && (val == null || val.trim().isEmpty)) {
          return 'يرجى إدخال ${field.labelAr}';
        }
        if (val != null && val.trim().isNotEmpty && double.tryParse(val.trim()) == null) {
          return 'يرجى إدخال رقم صحيح أو عشري';
        }
        return null;
      },
      onChanged: (val) {
        final parsed = double.tryParse(val.trim());
        _updateValue(field.key, parsed ?? val.trim());
      },
    );
  }

  Widget _buildDateField(BuildContext context, CustomRequestField field) {
    final rawDate = values[field.key];
    DateTime? selectedDate;
    if (rawDate is DateTime) {
      selectedDate = rawDate;
    } else if (rawDate is String) {
      selectedDate = DateTime.tryParse(rawDate);
    }

    return InkWell(
      onTap: isEnabled
          ? () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (picked != null) {
                _updateValue(field.key, DateFormat('yyyy-MM-dd').format(picked));
              }
            }
          : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '${field.labelAr}${field.isRequired ? ' *' : ''}',
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: const Icon(Icons.calendar_today, size: 20),
        ),
        child: Text(
          selectedDate != null
              ? DateFormat('yyyy/MM/dd', 'ar').format(selectedDate)
              : 'اضغط لاختيار التاريخ',
          style: TextStyle(
            color: selectedDate != null ? null : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangeField(BuildContext context, CustomRequestField field) {
    final startKey = '${field.key}_start';
    final endKey = '${field.key}_end';
    final startStr = values[startKey]?.toString();
    final endStr = values[endKey]?.toString();

    return InkWell(
      onTap: isEnabled
          ? () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (picked != null) {
                _updateValue(startKey, DateFormat('yyyy-MM-dd').format(picked.start));
                _updateValue(endKey, DateFormat('yyyy-MM-dd').format(picked.end));
              }
            }
          : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '${field.labelAr}${field.isRequired ? ' *' : ''}',
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: const Icon(Icons.date_range, size: 20),
        ),
        child: Text(
          startStr != null && endStr != null
              ? 'من $startStr إلى $endStr'
              : 'اضغط لاختيار الفترة (من - إلى)',
          style: TextStyle(
            color: startStr != null ? null : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectField(CustomRequestField field) {
    final current = values[field.key]?.toString();
    return DropdownButtonFormField<String>(
      initialValue: field.dropdownOptions.contains(current) ? current : null,
      decoration: InputDecoration(
        labelText: '${field.labelAr}${field.isRequired ? ' *' : ''}',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: field.dropdownOptions
          .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
          .toList(),
      validator: (val) {
        if (field.isRequired && (val == null || val.trim().isEmpty)) {
          return 'يرجى اختيار ${field.labelAr}';
        }
        return null;
      },
      onChanged: isEnabled ? (val) => _updateValue(field.key, val) : null,
    );
  }

  Widget _buildCheckboxField(CustomRequestField field) {
    final isChecked = values[field.key] == true;
    return CheckboxListTile(
      title: Text('${field.labelAr}${field.isRequired ? ' *' : ''}'),
      value: isChecked,
      dense: true,
      contentPadding: EdgeInsets.zero,
      onChanged: isEnabled ? (val) => _updateValue(field.key, val ?? false) : null,
    );
  }

  Widget _buildFileUploadField(BuildContext context, CustomRequestField field) {
    final currentFile = values[field.key]?.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(
            currentFile != null ? Icons.check_circle : Icons.upload_file,
            color: currentFile != null ? Colors.green : Colors.blueGrey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${field.labelAr}${field.isRequired ? ' *' : ''}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  currentFile != null ? 'تم إرفاق: $currentFile' : 'يرجى رفع المستند المطلوب',
                  style: TextStyle(
                    fontSize: 11,
                    color: currentFile != null ? Colors.green.shade800 : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          if (isEnabled)
            TextButton(
              onPressed: () {
                // In web/mobile, simulate or invoke file attach
                _updateValue(field.key, 'attached_doc_${DateTime.now().millisecondsSinceEpoch}.pdf');
              },
              child: Text(currentFile != null ? 'تغيير' : 'إرفاق'),
            ),
        ],
      ),
    );
  }
}
