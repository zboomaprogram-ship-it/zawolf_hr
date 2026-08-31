import 'package:flutter/material.dart';

import '../../domain/entities/knowledge_article.dart';
import '../../domain/repositories/employee_portal_repository.dart';

class CompanyKnowledgePage extends StatefulWidget {
  const CompanyKnowledgePage({super.key, required this.repository});
  final EmployeePortalRepository repository;

  @override
  State<CompanyKnowledgePage> createState() => _CompanyKnowledgePageState();
}

class _CompanyKnowledgePageState extends State<CompanyKnowledgePage> {
  final _search = TextEditingController();
  late Future<List<KnowledgeArticle>> _articles = _load();

  Future<List<KnowledgeArticle>> _load() async =>
      (await widget.repository.knowledge(query: _search.text.trim())).items;

  void _refresh() => setState(() => _articles = _load());

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('قاعدة المعرفة')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchBar(
              controller: _search,
              hintText: 'ابحث في المقالات المنشورة',
              onSubmitted: (_) => _refresh(),
              trailing: [
                IconButton(onPressed: _refresh, icon: const Icon(Icons.search)),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<KnowledgeArticle>>(
              future: _articles,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: TextButton(
                      onPressed: _refresh,
                      child: const Text('تعذر التحميل — إعادة المحاولة'),
                    ),
                  );
                }
                final items = snapshot.data ?? const [];
                if (items.isEmpty) {
                  return const Center(child: Text('لا توجد مقالات منشورة.'));
                }
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final article = items[index];
                    return ExpansionTile(
                      title: Text(article.title),
                      subtitle: Text(article.category),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: SelectableText(article.content),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
