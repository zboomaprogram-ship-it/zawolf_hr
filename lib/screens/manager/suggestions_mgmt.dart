import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../models/suggestion_model.dart';
import '../../services/auth_service.dart';
import '../../services/suggestion_service.dart';
import '../../theme/theme.dart';

class SuggestionsManagementScreen extends StatelessWidget {
  const SuggestionsManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = SuggestionService();
    final reviewerId = Provider.of<AuthService>(context).currentUser?.uid ?? '';
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('المقترحات', style: theme.textTheme.headlineMedium),
      ),
      body: StreamBuilder<List<SuggestionModel>>(
        stream: service.watchAllSuggestions(),
        builder: (context, snapshot) {
          final suggestions = snapshot.data ?? [];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (suggestions.isEmpty) {
            return const Center(
              child: Text(
                'لا توجد مقترحات حالياً.',
                style: TextStyle(color: ZaWolfColors.textSecondary),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: suggestions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];
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
                              : ZaWolfColors.warning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            suggestion.title,
                            style: theme.textTheme.titleMedium?.copyWith(
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
                    const SizedBox(height: 10),
                    Text(
                      '${suggestion.employeeName} · ${suggestion.department}'
                      '${submittedAt.isEmpty ? '' : ' · $submittedAt'}',
                      style: theme.textTheme.bodySmall,
                      textDirection: TextDirection.rtl,
                    ),
                    if (suggestion.status != 'reviewed') ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: reviewerId.isEmpty
                              ? null
                              : () => service.markReviewed(
                                  suggestion.suggestionId,
                                  reviewerId,
                                ),
                          icon: const Icon(Icons.done),
                          label: const Text('تمت المراجعة'),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
