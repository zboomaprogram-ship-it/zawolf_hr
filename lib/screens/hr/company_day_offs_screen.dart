import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../models/company_day_off_model.dart';
import '../../services/auth_service.dart';
import '../../services/company_day_off_service.dart';
import '../../theme/theme.dart';

class CompanyDayOffsScreen extends StatefulWidget {
  const CompanyDayOffsScreen({super.key});

  @override
  State<CompanyDayOffsScreen> createState() => _CompanyDayOffsScreenState();
}

class _CompanyDayOffsScreenState extends State<CompanyDayOffsScreen> {
  final _titleController = TextEditingController(text: 'عطلة رسمية');
  final _service = CompanyDayOffService();
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      locale: const Locale('ar'),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      await _service.saveDayOff(
        date: _selectedDate,
        title: _titleController.text,
        createdBy: user.uid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: ZaWolfColors.success,
            content: Text('تم حفظ يوم العطلة.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZaWolfColors.error,
            content: Text(
              'تعذر حفظ يوم العطلة: ${e.toString().replaceAll('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedDateLabel = DateFormat(
      'EEEE yyyy/MM/dd',
      'ar',
    ).format(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: Text('أيام العطلة', style: theme.textTheme.headlineMedium),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          WolfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'إضافة عطلة يدوية',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  textDirection: TextDirection.rtl,
                  decoration: const InputDecoration(
                    labelText: 'اسم العطلة',
                    prefixIcon: Icon(Icons.event_note),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(selectedDateLabel),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('حفظ'),
                ),
                const SizedBox(height: 8),
                Text(
                  'يوم الجمعة مغلق تلقائياً ولا يحتاج إلى إضافة يدوية.',
                  style: theme.textTheme.bodySmall,
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          StreamBuilder<List<CompanyDayOffModel>>(
            stream: _service.watchDayOffs(),
            builder: (context, snapshot) {
              final days = snapshot.data ?? [];
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (days.isEmpty) {
                return const WolfCard(
                  child: Text(
                    'لا توجد عطلات يدوية مسجلة.',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(color: ZaWolfColors.textSecondary),
                  ),
                );
              }
              return Column(
                children: days.map((day) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: WolfCard(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: day.isActive,
                        onChanged: (value) =>
                            _service.setActive(day.dayOffId, value),
                        title: Text(
                          day.title,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          day.date,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            color: ZaWolfColors.textSecondary,
                          ),
                        ),
                        secondary: const Icon(
                          Icons.event_busy,
                          color: ZaWolfColors.warning,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
