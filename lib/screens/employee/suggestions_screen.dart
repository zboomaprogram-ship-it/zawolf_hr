import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../models/suggestion_model.dart';
import '../../services/auth_service.dart';
import '../../services/suggestion_service.dart';
import '../../theme/theme.dart';

class EmployeeSuggestionsScreen extends StatefulWidget {
  const EmployeeSuggestionsScreen({super.key});

  @override
  State<EmployeeSuggestionsScreen> createState() =>
      _EmployeeSuggestionsScreenState();
}

class _EmployeeSuggestionsScreenState extends State<EmployeeSuggestionsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _service = SuggestionService();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);
    try {
      await _service.submitSuggestion(
        employee: user,
        title: _titleController.text,
        body: _bodyController.text,
      );
      _titleController.clear();
      _bodyController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: ZaWolfColors.success,
            content: Text('تم إرسال المقترح بنجاح.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZaWolfColors.error,
            content: Text(
              'تعذر إرسال المقترح: ${e.toString().replaceAll('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = Provider.of<AuthService>(context).currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('المقترحات', style: theme.textTheme.headlineMedium),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WolfCard(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'إرسال مقترح جديد',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _titleController,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(
                        labelText: 'عنوان المقترح',
                        prefixIcon: Icon(Icons.lightbulb_outline),
                      ),
                      validator: (value) =>
                          value == null || value.trim().length < 3
                          ? 'اكتب عنواناً واضحاً'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _bodyController,
                      minLines: 4,
                      maxLines: 7,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(
                        labelText: 'تفاصيل المقترح',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.notes),
                      ),
                      validator: (value) =>
                          value == null || value.trim().length < 10
                          ? 'اكتب تفاصيل أكثر للمقترح'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: const Text('إرسال'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'مقترحاتي',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 10),
            StreamBuilder<List<SuggestionModel>>(
              stream: _service.watchMySuggestions(user.uid),
              builder: (context, snapshot) {
                final suggestions = snapshot.data ?? [];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (suggestions.isEmpty) {
                  return const WolfCard(
                    child: Text(
                      'لا توجد مقترحات مرسلة بعد.',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(color: ZaWolfColors.textSecondary),
                    ),
                  );
                }
                return Column(
                  children: suggestions.map((suggestion) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SuggestionTile(suggestion: suggestion),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final SuggestionModel suggestion;

  const _SuggestionTile({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final submittedAt = suggestion.submittedAt == null
        ? ''
        : DateFormat(
            'yyyy/MM/dd - hh:mm a',
            'ar',
          ).format(suggestion.submittedAt!);

    return WolfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                suggestion.status == 'reviewed'
                    ? Icons.done_all
                    : Icons.lightbulb_outline,
                color: suggestion.status == 'reviewed'
                    ? ZaWolfColors.success
                    : ZaWolfColors.primaryCyan,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  suggestion.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            suggestion.body,
            style: theme.textTheme.bodyMedium,
            textDirection: TextDirection.rtl,
          ),
          if (submittedAt.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              submittedAt,
              style: theme.textTheme.bodySmall,
              textDirection: TextDirection.rtl,
            ),
          ],
        ],
      ),
    );
  }
}
