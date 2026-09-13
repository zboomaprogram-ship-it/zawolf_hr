import 'package:flutter/material.dart';
import '../domain/hiring_request_repository.dart';

class HiringRequestScreen extends StatefulWidget {
  const HiringRequestScreen({required this.repository, super.key});
  final HiringRequestRepository repository;
  @override
  State<HiringRequestScreen> createState() => _HiringRequestScreenState();
}

class _HiringRequestScreenState extends State<HiringRequestScreen> {
  late Future<List<HiringRequest>> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.repository.list();
  }

  void _reload() => setState(() => _future = widget.repository.list());
  Future<void> _decide(HiringRequest row, bool approved) async {
    try {
      await widget.repository.decide(id: row.id, approved: approved);
      _reload();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('طلبات التعيين')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'استخدم نموذج طلب التعيين من لوحة HR بعد تحديث التطبيق.',
                ),
              ),
            ),
        label: const Text('طلب تعيين'),
        icon: const Icon(Icons.person_add),
      ),
      body: FutureBuilder<List<HiringRequest>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(child: Text('${snapshot.error}'));
          final rows = snapshot.data ?? const <HiringRequest>[];
          if (rows.isEmpty)
            return const Center(
              child: Text('لا توجد طلبات تعيين تحتاج إجراء.'),
            );
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                return Card(
                  child: ListTile(
                    title: Text(row.name),
                    subtitle: Text(
                      '${row.jobTitle}\n${row.status}${row.currentApproverName.isEmpty ? '' : ' • بانتظار ${row.currentApproverName}'}',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<bool>(
                      onSelected: (approved) => _decide(row, approved),
                      itemBuilder:
                          (_) => const [
                            PopupMenuItem(value: true, child: Text('موافقة')),
                            PopupMenuItem(value: false, child: Text('رفض')),
                          ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    ),
  );
}
