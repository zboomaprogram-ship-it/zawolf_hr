import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/company_workspace_models.dart';
import '../../services/google_workspace_service.dart';
import '../../utils/binary_file_action.dart';
import '../../utils/user_facing_error.dart';
import 'workspace_sheet_editor_screen.dart';

/// Folder-first company Drive browser. It requests children only after the
/// folder is opened, keeping the workspace landing page fast and uncluttered.
class WorkspaceFolderBrowserScreen extends StatefulWidget {
  final CompanyWorkspaceResource resource;
  final List<String> folderPath;
  final List<String> labels;

  const WorkspaceFolderBrowserScreen({
    super.key,
    required this.resource,
    this.folderPath = const [],
    this.labels = const [],
  });

  @override
  State<WorkspaceFolderBrowserScreen> createState() =>
      _WorkspaceFolderBrowserScreenState();
}

class _WorkspaceFolderBrowserScreenState
    extends State<WorkspaceFolderBrowserScreen> {
  final _service = GoogleWorkspaceService();
  WorkspaceFolderListing? _listing;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final listing = await _service.listWorkspaceFolderAt(
        widget.resource.id,
        path: widget.folderPath,
      );
      if (mounted) setState(() => _listing = listing);
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isFolder(Map<String, dynamic> file) =>
      '${file['mimeType']}' == 'application/vnd.google-apps.folder';
  bool _isSheet(Map<String, dynamic> file) =>
      '${file['mimeType']}' == 'application/vnd.google-apps.spreadsheet';

  Future<void> _open(Map<String, dynamic> file) async {
    final id = '${file['id'] ?? ''}';
    if (id.isEmpty) return;
    if (_isFolder(file)) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WorkspaceFolderBrowserScreen(
            resource: widget.resource,
            folderPath: [...widget.folderPath, id],
            labels: [...widget.labels, '${file['name'] ?? ''}'],
          ),
        ),
      );
      return;
    }
    if (_isSheet(file)) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WorkspaceSheetEditorScreen(
            resource: widget.resource,
            fileId: id,
            fileName: '${file['name'] ?? ''}',
            folderPath: widget.folderPath,
          ),
        ),
      );
      return;
    }
    await _previewOrDownload(file);
  }

  Future<void> _previewOrDownload(Map<String, dynamic> file) async {
    try {
      final download = await _service.downloadWorkspaceFile(
        resourceId: widget.resource.id,
        fileId: '${file['id']}',
        fileName: '${file['name'] ?? 'download'}',
        mimeType: '${file['mimeType'] ?? 'application/octet-stream'}',
        path: widget.folderPath,
      );
      final mime = download.mimeType.toLowerCase();
      final name = download.fileName.toLowerCase();
      if (mime.startsWith('image/') ||
          RegExp(r'\.(png|jpe?g|gif|webp)$').hasMatch(name)) {
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text(download.fileName)),
              body: Center(
                child: InteractiveViewer(
                  child: Image.memory(Uint8List.fromList(download.bytes)),
                ),
              ),
            ),
          ),
        );
      } else if (mime.startsWith('text/') ||
          RegExp(r'\.(txt|md|csv|json|log)$').hasMatch(name)) {
        if (!mounted) return;
        final text = utf8.decode(download.bytes, allowMalformed: true);
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text(download.fileName)),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: SelectableText(text.isEmpty ? 'الملف فارغ' : text),
              ),
            ),
          ),
        );
      } else {
        final saved = await downloadBinaryFile(
          download.bytes,
          download.fileName,
          download.mimeType,
        );
        if (!saved && mounted) {
          setState(() => _error = 'تعذر تنزيل الملف على هذا الجهاز.');
        }
      }
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = _listing;
    final title = widget.labels.isEmpty
        ? widget.resource.name
        : widget.labels.last;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : listing == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.labels.isNotEmpty)
                  Text(
                    widget.labels.join(' / '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 12),
                const Text(
                  'المجلدات',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...listing.files.where(_isFolder).map(_tile),
                const SizedBox(height: 20),
                const Text(
                  'الملفات',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...listing.files.where((file) => !_isFolder(file)).map(_tile),
                if (listing.files.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('هذا المجلد فارغ.')),
                  ),
              ],
            ),
    );
  }

  Widget _tile(Map<String, dynamic> file) => Card(
    child: ListTile(
      leading: Icon(
        _isFolder(file)
            ? Icons.folder_outlined
            : _isSheet(file)
            ? Icons.table_chart_outlined
            : Icons.insert_drive_file_outlined,
      ),
      title: Text('${file['name'] ?? ''}'),
      subtitle: Text('${file['modifiedTime'] ?? ''}'),
      trailing: const Icon(Icons.chevron_left),
      onTap: () => _open(file),
    ),
  );
}
