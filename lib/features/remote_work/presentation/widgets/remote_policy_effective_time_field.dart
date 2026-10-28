import 'package:flutter/material.dart';

/// Date and time are reviewed together; cancelling either picker changes neither.
class RemotePolicyEffectiveTimeField extends StatelessWidget {
  const RemotePolicyEffectiveTimeField({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final local = value.toLocal();
    final label = local
        .toIso8601String()
        .substring(0, 16)
        .replaceFirst('T', ' ');
    return OutlinedButton.icon(
      icon: const Icon(Icons.event_available_outlined),
      label: Text('تاريخ ووقت السريان: $label (${local.timeZoneName})'),
      onPressed: enabled ? () => _pick(context, local) : null,
    );
  }

  Future<void> _pick(BuildContext context, DateTime local) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final latest = DateTime(now.year + 10, now.month, now.day);
    final initial =
        local.isBefore(today)
            ? today
            : local.isAfter(latest)
            ? latest
            : local;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: latest,
      helpText: 'تاريخ بدء سريان السياسة',
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(local),
      initialEntryMode: TimePickerEntryMode.input,
      helpText: 'وقت بدء سريان السياسة',
    );
    if (time == null || !context.mounted) return;
    onChanged(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }
}
