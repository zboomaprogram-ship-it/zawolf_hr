import 'package:flutter/material.dart';

/// Explicit conflict decision page. The actual provider values stay on the
/// server; this page exposes only safe context and a deliberate user action.
class WorkspaceConflictPage extends StatelessWidget {
  const WorkspaceConflictPage({
    required this.message,
    required this.before,
    required this.current,
    required this.onReload,
    required this.onRetry,
    super.key,
  });

  final String message;
  final String before;
  final String current;
  final VoidCallback onReload;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('تعارض في التعديل')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(message, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 20),
                _ContextCard(title: 'قبل التعديل', value: before),
                _ContextCard(title: 'الحالة الحالية', value: current),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onReload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('تحديث الورقة'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: onRetry,
                  child: const Text('إعادة المحاولة بعد المراجعة'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.title, required this.value});
  final String title;
  final String value;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(title: Text(title), subtitle: Text(value)),
  );
}
