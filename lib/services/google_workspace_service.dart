import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class GoogleWorkspaceException implements Exception {
  final int statusCode;
  final String message;

  const GoogleWorkspaceException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class GoogleWorkspaceService {
  static const String defaultBaseUrl = 'https://notification.zawolf.ai';

  final FirebaseAuth auth;
  final http.Client client;
  final String baseUrl;

  GoogleWorkspaceService({
    FirebaseAuth? auth,
    http.Client? client,
    this.baseUrl = defaultBaseUrl,
  }) : auth = auth ?? FirebaseAuth.instance,
       client = client ?? http.Client();

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<Map<String, String>> _headers() async {
    final user = auth.currentUser;
    if (user == null) {
      throw const GoogleWorkspaceException(401, 'يجب تسجيل الدخول أولاً.');
    }
    // Browser sessions can retain an old token after a deployment, password
    // change, or role update. Refresh before calling the separate Hostinger
    // origin so the backend verifies the current Firebase session.
    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw const GoogleWorkspaceException(401, 'تعذر التحقق من جلسة الدخول.');
    }
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  dynamic _decode(http.Response response) {
    Map<String, dynamic> body = const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {
      // The status code still provides a useful safe error below.
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = (body['error'] ?? 'تعذر الاتصال بخدمات Google.')
          .toString();
      throw GoogleWorkspaceException(response.statusCode, message);
    }
    return body;
  }

  Future<http.Response> _postWithRetry(String path) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await client
            .post(Uri.parse('$baseUrl$path'), headers: await _headers())
            // Workspace discovery can inspect hundreds of existing folders.
            // The server runs it in parallel, but a 20-second browser timeout
            // still cuts off a legitimate first sync on a large company Drive.
            .timeout(const Duration(seconds: 75));
        // Do not retry authentication or validation responses. A retry is
        // useful only when the browser/network or server is briefly busy.
        if (response.statusCode < 500 || attempt == 2) return response;
      } catch (error) {
        if (error is! TimeoutException && error is! http.ClientException) {
          rethrow;
        }
      }
      await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
    }
    throw GoogleWorkspaceException(
      503,
      'تعذر الوصول لخدمة ملفات الشركة مؤقتاً. لم تُنشأ أو تُكرر أي ملفات؛ أعد المحاولة بعد لحظات.',
    );
  }

  Future<List<Map<String, dynamic>>> readSheetRows() async {
    final response = await client.get(
      Uri.parse('$baseUrl/google-sheets/test/rows'),
      headers: await _headers(),
    );
    final body = _decode(response) as Map<String, dynamic>;
    return (body['rows'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<GoogleDailyReport> generateDailyReport(DateTime date) async {
    final dateKey =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final response = await client.post(
      Uri.parse('$baseUrl/google-sheets/reports/daily'),
      headers: await _headers(),
      body: jsonEncode({'date': dateKey}),
    );
    final body = _decode(response) as Map<String, dynamic>;
    final report = Map<String, dynamic>.from(
      body['report'] as Map? ?? const {},
    );
    final preview = (body['preview'] as List? ?? const [])
        .whereType<List>()
        .map((row) => row.toList(growable: false))
        .toList(growable: false);
    return GoogleDailyReport(
      spreadsheetUrl: '${report['spreadsheetUrl'] ?? ''}',
      tabTitle: '${report['tabTitle'] ?? ''}',
      rowCount: (report['rowCount'] as num?)?.toInt() ?? preview.length,
      preview: preview,
    );
  }

  Future<Map<String, dynamic>> updateTestRow(
    String recordId, {
    String? taskName,
    String? status,
    num? amount,
    String? notes,
  }) async {
    final updates = <String, dynamic>{};
    if (taskName != null) updates['task_name'] = taskName;
    if (status != null) updates['status'] = status;
    if (amount != null) updates['amount'] = amount;
    if (notes != null) updates['notes'] = notes;
    if (updates.isEmpty) {
      throw const GoogleWorkspaceException(400, 'اختر قيمة لتحديثها أولاً.');
    }
    final response = await client.patch(
      Uri.parse(
        '$baseUrl/google-sheets/test/rows/${Uri.encodeComponent(recordId)}',
      ),
      headers: await _headers(),
      body: jsonEncode(updates),
    );
    final body = _decode(response) as Map<String, dynamic>;
    return Map<String, dynamic>.from(body['row'] as Map? ?? const {});
  }

  Future<List<Map<String, dynamic>>> listDriveFiles() async {
    final response = await client.get(
      Uri.parse('$baseUrl/google-drive/test/files'),
      headers: await _headers(),
    );
    final body = _decode(response) as Map<String, dynamic>;
    return (body['files'] as List? ?? const [])
        .whereType<Map>()
        .map((file) => Map<String, dynamic>.from(file))
        .toList();
  }

  Future<GoogleDriveDownload> downloadDriveFile(
    String fileId, {
    required String fileName,
    required String mimeType,
  }) async {
    final response = await client.get(
      Uri.parse(
        '$baseUrl/google-drive/test/files/${Uri.encodeComponent(fileId)}/content',
      ),
      headers: await _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decode(response);
    }
    final disposition = response.headers['content-disposition'] ?? '';
    final encodedName = RegExp(
      r"filename\*=UTF-8''([^;]+)",
      caseSensitive: false,
    ).firstMatch(disposition)?.group(1);
    final resolvedName = encodedName == null
        ? fileName
        : Uri.decodeComponent(encodedName);
    return GoogleDriveDownload(
      bytes: response.bodyBytes,
      fileName: resolvedName,
      mimeType: response.headers['content-type'] ?? mimeType,
    );
  }

  Future<Map<String, dynamic>> createDriveTestFile({
    String name = 'ZaWolf HR Drive API Test from App.txt',
    String contents = 'ZaWolf HR Drive connection test from the app',
  }) async {
    final response = await client.post(
      Uri.parse('$baseUrl/google-drive/test/file'),
      headers: await _headers(),
      body: jsonEncode({'name': name, 'contents': contents}),
    );
    final body = _decode(response) as Map<String, dynamic>;
    return Map<String, dynamic>.from(body['file'] as Map? ?? const {});
  }

  Future<WorkspaceSheetData> readWorkspaceSheet(
    String resourceId, {
    String? fileId,
    String? tabName,
    List<String> path = const [],
  }) async {
    final query = <String, String>{
      if (fileId != null && fileId.isNotEmpty) 'fileId': fileId,
      if (tabName != null && tabName.isNotEmpty) 'tabName': tabName,
      if (path.isNotEmpty) 'path': path.join(','),
    };
    final suffix = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
    final response = await client.get(
      Uri.parse(
        '$baseUrl/company-workspace/resources/${Uri.encodeComponent(resourceId)}/sheet$suffix',
      ),
      headers: await _headers(),
    );
    final body = _decode(response) as Map<String, dynamic>;
    return WorkspaceSheetData(
      tabName: '${body['tabName'] ?? ''}',
      headers: (body['headers'] as List? ?? const [])
          .map((value) => '$value')
          .toList(growable: false),
      rows: (body['rows'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false),
      headerCells: (body['headerCells'] as List? ?? const [])
          .whereType<Map>()
          .map((cell) => Map<String, dynamic>.from(cell))
          .toList(growable: false),
      merges: (body['merges'] as List? ?? const [])
          .whereType<Map>()
          .map((range) => Map<String, dynamic>.from(range))
          .toList(growable: false),
      editableFields: (body['editableFields'] as List? ?? const [])
          .map((value) => '$value')
          .toList(growable: false),
      tabs: (body['tabs'] as List? ?? const [])
          .map((value) => '$value')
          .toList(growable: false),
      canEdit: (body['capabilities'] as Map?)?['edit'] == true,
      canChangeStructure: (body['capabilities'] as Map?)?['structure'] == true,
      canFormat: (body['capabilities'] as Map?)?['format'] == true,
    );
  }

  Future<void> updateWorkspaceSheetRow({
    required String resourceId,
    required String tabName,
    required int rowNumber,
    required Map<String, String> updates,
    String? fileId,
    List<String> path = const [],
  }) async {
    final query = <String, String>{
      if (fileId != null && fileId.isNotEmpty) 'fileId': fileId,
      if (path.isNotEmpty) 'path': path.join(','),
    };
    final suffix = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
    final response = await client.patch(
      Uri.parse(
        '$baseUrl/company-workspace/resources/${Uri.encodeComponent(resourceId)}/sheet/rows/$rowNumber$suffix',
      ),
      headers: await _headers(),
      body: jsonEncode({'tabName': tabName, 'updates': updates}),
    );
    _decode(response);
  }

  Future<void> formatWorkspaceSheetRange({
    required String resourceId,
    required String tabName,
    required int startRow,
    required int endRow,
    required int startColumn,
    required int endColumn,
    String? backgroundColor,
    String? textColor,
    bool? bold,
    bool? italic,
    String? horizontalAlignment,
    String? wrapStrategy,
    List<String>? dropdownValues,
    bool? checkbox,
    bool? clearValidation,
    bool? clearFormatting,
    String? fileId,
    List<String> path = const [],
  }) async {
    final query = <String, String>{
      if (fileId != null && fileId.isNotEmpty) 'fileId': fileId,
      if (path.isNotEmpty) 'path': path.join(','),
    };
    final suffix = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
    final response = await client.post(
      Uri.parse(
        '$baseUrl/company-workspace/resources/${Uri.encodeComponent(resourceId)}/sheet/format$suffix',
      ),
      headers: await _headers(),
      body: jsonEncode({
        'tabName': tabName,
        'startRow': startRow,
        'endRow': endRow,
        'startColumn': startColumn,
        'endColumn': endColumn,
        if (backgroundColor != null) 'backgroundColor': backgroundColor,
        if (textColor != null) 'textColor': textColor,
        if (bold != null) 'bold': bold,
        if (italic != null) 'italic': italic,
        if (horizontalAlignment != null)
          'horizontalAlignment': horizontalAlignment,
        if (wrapStrategy != null) 'wrapStrategy': wrapStrategy,
        if (dropdownValues != null) 'dropdownValues': dropdownValues,
        if (checkbox != null) 'checkbox': checkbox,
        if (clearValidation != null) 'clearValidation': clearValidation,
        if (clearFormatting != null) 'clearFormatting': clearFormatting,
      }),
    );
    _decode(response);
  }

  Future<void> changeWorkspaceSheetStructure({
    required String resourceId,
    required String tabName,
    required String operation,
    required int index,
    int count = 1,
    int headerRow = 1,
    String? headerValue,
    String? fileId,
    List<String> path = const [],
  }) async {
    final query = <String, String>{
      if (fileId != null && fileId.isNotEmpty) 'fileId': fileId,
      if (path.isNotEmpty) 'path': path.join(','),
    };
    final suffix = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
    final response = await client.post(
      Uri.parse(
        '$baseUrl/company-workspace/resources/${Uri.encodeComponent(resourceId)}/sheet/structure$suffix',
      ),
      headers: await _headers(),
      body: jsonEncode({
        'tabName': tabName,
        'operation': operation,
        'index': index,
        'count': count,
        'headerRow': headerRow,
        if (headerValue != null) 'headerValue': headerValue,
      }),
    );
    _decode(response);
  }

  Future<String> changeWorkspaceSheetTab({
    required String resourceId,
    required String operation,
    required String tabName,
    String? newName,
    String? fileId,
    List<String> path = const [],
  }) async {
    final query = <String, String>{
      if (fileId != null && fileId.isNotEmpty) 'fileId': fileId,
      if (path.isNotEmpty) 'path': path.join(','),
    };
    final suffix = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
    final response = await client.post(
      Uri.parse(
        '$baseUrl/company-workspace/resources/${Uri.encodeComponent(resourceId)}/sheet/tabs$suffix',
      ),
      headers: await _headers(),
      body: jsonEncode({
        'operation': operation,
        'tabName': tabName,
        if (newName != null) 'newName': newName,
      }),
    );
    final body = _decode(response) as Map<String, dynamic>;
    return '${body['tabName'] ?? ''}';
  }

  Future<WorkspaceAuditReport> generateWorkspaceAuditReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await client.post(
      Uri.parse('$baseUrl/company-workspace/reports/audit'),
      headers: await _headers(),
      body: jsonEncode({
        'startDate': _dateKey(startDate),
        'endDate': _dateKey(endDate),
      }),
    );
    final body = _decode(response) as Map<String, dynamic>;
    final resource = Map<String, dynamic>.from(
      body['resource'] as Map? ?? const {},
    );
    return WorkspaceAuditReport(
      rowCount: (body['rowCount'] as num?)?.toInt() ?? 0,
      resourceId: '${resource['id'] ?? ''}',
      name: '${resource['name'] ?? 'ZaWolf - سجل التدقيق'}',
      sheetTab: '${resource['sheetTab'] ?? 'سجل التدقيق'}',
    );
  }

  Future<List<Map<String, dynamic>>> listWorkspaceFolderFiles(
    String resourceId,
  ) async {
    return (await listWorkspaceFolder(resourceId)).files;
  }

  Future<WorkspaceFolderListing> listWorkspaceFolder(String resourceId) async {
    return listWorkspaceFolderAt(resourceId);
  }

  Future<WorkspaceFolderListing> listWorkspaceFolderAt(
    String resourceId, {
    List<String> path = const [],
  }) async {
    final suffix = path.isEmpty
        ? ''
        : '?path=${Uri.encodeQueryComponent(path.join(','))}';
    final response = await client.get(
      Uri.parse(
        '$baseUrl/company-workspace/resources/${Uri.encodeComponent(resourceId)}/files$suffix',
      ),
      headers: await _headers(),
    );
    final body = _decode(response) as Map<String, dynamic>;
    final files = (body['files'] as List? ?? const [])
        .whereType<Map>()
        .map((file) => Map<String, dynamic>.from(file))
        .toList(growable: false);
    final capabilities = Map<String, dynamic>.from(
      body['capabilities'] as Map? ?? const {},
    );
    return WorkspaceFolderListing(
      files: files,
      canEdit: capabilities['edit'] == true,
      canDownload: capabilities['download'] == true,
      canManage: capabilities['manage'] == true,
    );
  }

  Future<GoogleDriveDownload> downloadWorkspaceFile({
    required String resourceId,
    required String fileId,
    required String fileName,
    required String mimeType,
    List<String> path = const [],
  }) async {
    final suffix = path.isEmpty
        ? ''
        : '?path=${Uri.encodeQueryComponent(path.join(','))}';
    final response = await client.get(
      Uri.parse(
        '$baseUrl/company-workspace/resources/${Uri.encodeComponent(resourceId)}/files/${Uri.encodeComponent(fileId)}/content$suffix',
      ),
      headers: await _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decode(response);
    }
    final disposition = response.headers['content-disposition'] ?? '';
    final encodedName = RegExp(
      r"filename\*=UTF-8''([^;]+)",
      caseSensitive: false,
    ).firstMatch(disposition)?.group(1);
    return GoogleDriveDownload(
      bytes: response.bodyBytes,
      fileName: encodedName == null
          ? fileName
          : Uri.decodeComponent(encodedName),
      mimeType: response.headers['content-type'] ?? mimeType,
    );
  }

  Future<void> uploadWorkspaceFile({
    required String resourceId,
    required String name,
    required String mimeType,
    required List<int> bytes,
    List<String> path = const [],
  }) async {
    if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
      throw const GoogleWorkspaceException(
        400,
        'الملف يجب أن يكون بين 1 بايت و20 MB.',
      );
    }
    final suffix = path.isEmpty
        ? ''
        : '?path=${Uri.encodeQueryComponent(path.join(','))}';
    final response = await client.post(
      Uri.parse(
        '$baseUrl/company-workspace/resources/${Uri.encodeComponent(resourceId)}/files$suffix',
      ),
      headers: await _headers(),
      body: jsonEncode({
        'name': name,
        'mimeType': mimeType,
        'contentsBase64': base64Encode(bytes),
      }),
    );
    _decode(response);
  }

  Future<void> createWorkspaceFolder({
    required String resourceId,
    required String name,
    List<String> path = const [],
  }) async {
    final suffix = path.isEmpty
        ? ''
        : '?path=${Uri.encodeQueryComponent(path.join(','))}';
    final response = await client.post(
      Uri.parse(
        '$baseUrl/company-workspace/resources/${Uri.encodeComponent(resourceId)}/folders$suffix',
      ),
      headers: await _headers(),
      body: jsonEncode({'name': name}),
    );
    _decode(response);
  }

  Future<void> renameWorkspaceFile({
    required String resourceId,
    required String fileId,
    required String name,
    List<String> path = const [],
  }) async {
    final suffix = path.isEmpty
        ? ''
        : '?path=${Uri.encodeQueryComponent(path.join(','))}';
    final response = await client.patch(
      Uri.parse(
        '$baseUrl/company-workspace/resources/${Uri.encodeComponent(resourceId)}/files/${Uri.encodeComponent(fileId)}$suffix',
      ),
      headers: await _headers(),
      body: jsonEncode({'name': name}),
    );
    _decode(response);
  }

  Future<void> deleteWorkspaceFile({
    required String resourceId,
    required String fileId,
    List<String> path = const [],
  }) async {
    final suffix = path.isEmpty
        ? ''
        : '?path=${Uri.encodeQueryComponent(path.join(','))}';
    final request = http.Request(
      'DELETE',
      Uri.parse(
        '$baseUrl/company-workspace/resources/${Uri.encodeComponent(resourceId)}/files/${Uri.encodeComponent(fileId)}$suffix',
      ),
    );
    request.headers.addAll(await _headers());
    final streamed = await client.send(request);
    final response = await http.Response.fromStream(streamed);
    _decode(response);
  }

  Future<WorkspaceDiscoveryResult> discoverCompanyWorkspace() async {
    final response = await _postWithRetry('/company-workspace/discover');
    final body = _decode(response) as Map<String, dynamic>;
    return WorkspaceDiscoveryResult(
      discovered: (body['discovered'] as num?)?.toInt() ?? 0,
      created: (body['created'] as num?)?.toInt() ?? 0,
      updated: (body['updated'] as num?)?.toInt() ?? 0,
      grants: (body['grants'] as num?)?.toInt() ?? 0,
    );
  }

  Future<WorkspaceBootstrapResult> bootstrapCompanyWorkspace() async {
    final response = await _postWithRetry('/company-workspace/bootstrap');
    final body = _decode(response) as Map<String, dynamic>;
    final structure = Map<String, dynamic>.from(
      body['structure'] as Map? ?? const {},
    );
    final discovery = Map<String, dynamic>.from(
      body['discovery'] as Map? ?? const {},
    );
    return WorkspaceBootstrapResult(
      createdFolders: (structure['created'] as num?)?.toInt() ?? 0,
      departmentFolders: (structure['departmentFolders'] as num?)?.toInt() ?? 0,
      employeeFolders: (structure['employeeFolders'] as num?)?.toInt() ?? 0,
      discovered: (discovery['discovered'] as num?)?.toInt() ?? 0,
      grants: (discovery['grants'] as num?)?.toInt() ?? 0,
      skippedWithoutEmployeeId:
          (structure['skippedWithoutEmployeeId'] as num?)?.toInt() ?? 0,
    );
  }
}

class GoogleDriveDownload {
  final List<int> bytes;
  final String fileName;
  final String mimeType;

  const GoogleDriveDownload({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });
}

class WorkspaceFolderListing {
  final List<Map<String, dynamic>> files;
  final bool canEdit;
  final bool canDownload;
  final bool canManage;

  const WorkspaceFolderListing({
    required this.files,
    required this.canEdit,
    required this.canDownload,
    required this.canManage,
  });
}

class GoogleDailyReport {
  final String spreadsheetUrl;
  final String tabTitle;
  final int rowCount;
  final List<List<dynamic>> preview;

  const GoogleDailyReport({
    required this.spreadsheetUrl,
    required this.tabTitle,
    required this.rowCount,
    required this.preview,
  });
}

class WorkspaceSheetData {
  final String tabName;
  final List<String> headers;
  final List<Map<String, dynamic>> rows;
  final List<Map<String, dynamic>> headerCells;
  final List<Map<String, dynamic>> merges;
  final List<String> editableFields;
  final List<String> tabs;
  final bool canEdit;
  final bool canChangeStructure;
  final bool canFormat;

  const WorkspaceSheetData({
    required this.tabName,
    required this.headers,
    required this.rows,
    this.headerCells = const [],
    this.merges = const [],
    required this.editableFields,
    this.tabs = const [],
    this.canEdit = false,
    this.canChangeStructure = false,
    this.canFormat = false,
  });
}

class WorkspaceAuditReport {
  final int rowCount;
  final String resourceId;
  final String name;
  final String sheetTab;

  const WorkspaceAuditReport({
    required this.rowCount,
    required this.resourceId,
    required this.name,
    required this.sheetTab,
  });
}

class WorkspaceDiscoveryResult {
  final int discovered;
  final int created;
  final int updated;
  final int grants;

  const WorkspaceDiscoveryResult({
    required this.discovered,
    required this.created,
    required this.updated,
    required this.grants,
  });
}

class WorkspaceBootstrapResult {
  final int createdFolders;
  final int departmentFolders;
  final int employeeFolders;
  final int discovered;
  final int grants;
  final int skippedWithoutEmployeeId;

  const WorkspaceBootstrapResult({
    required this.createdFolders,
    required this.departmentFolders,
    required this.employeeFolders,
    required this.discovered,
    required this.grants,
    required this.skippedWithoutEmployeeId,
  });
}
