import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/errors/errors.dart';
import '../../domain/entities/spreadsheet_range.dart';
import 'company_workspace_remote_data_source.dart';

abstract interface class WorkspaceSheetRemoteDataSource {
  Future<SpreadsheetSnapshot> readViewport({
    required String resourceId,
    required SpreadsheetRange range,
  });
}

final class HttpWorkspaceSheetRemoteDataSource
    implements WorkspaceSheetRemoteDataSource {
  HttpWorkspaceSheetRemoteDataSource({
    required http.Client client,
    required WorkspaceSession session,
    required Uri baseUri,
  }) : _client = client,
       _session = session,
       _baseUri = baseUri;

  final http.Client _client;
  final WorkspaceSession _session;
  final Uri _baseUri;

  @override
  Future<SpreadsheetSnapshot> readViewport({
    required String resourceId,
    required SpreadsheetRange range,
  }) async {
    final token = await _session.refreshedBearerToken();
    if (token == null || token.isEmpty) {
      throw WorkspaceRemoteFailure(
        WorkspaceUserFacingError.fromHttpStatus(
          401,
          writeMayHaveStarted: false,
        ),
      );
    }
    final query = <String, String>{
      'tabName': range.tabName,
      'startRow': '${range.startRow}',
      'startColumn': '${range.startColumn}',
      'rowCount': '${range.endRow - range.startRow + 1}',
      'columnCount': '${range.endColumn - range.startColumn + 1}',
    };
    try {
      final response = await _client
          .get(
            _baseUri
                .resolve('/company-workspace/v2/resources/$resourceId/sheet')
                .replace(queryParameters: query),
            headers: <String, String>{
              'authorization': 'Bearer $token',
              'accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw WorkspaceRemoteFailure(
          WorkspaceUserFacingError.fromHttpStatus(
            response.statusCode,
            writeMayHaveStarted: false,
          ),
        );
      }
      final raw = jsonDecode(response.body);
      if (raw is! Map) {
        throw const FormatException('Invalid workspace sheet response');
      }
      return _snapshotFromJson(Map<String, Object?>.from(raw));
    } on WorkspaceRemoteFailure {
      rethrow;
    } on TimeoutException {
      throw WorkspaceRemoteFailure(
        WorkspaceUserFacingError.connectivity(writeMayHaveStarted: false),
      );
    } on http.ClientException {
      throw WorkspaceRemoteFailure(
        WorkspaceUserFacingError.connectivity(writeMayHaveStarted: false),
      );
    } on FormatException {
      throw WorkspaceRemoteFailure(
        WorkspaceUserFacingError.fromHttpStatus(
          502,
          writeMayHaveStarted: false,
        ),
      );
    }
  }

  SpreadsheetSnapshot _snapshotFromJson(Map<String, Object?> json) {
    final viewport = Map<String, Object?>.from(
      json['viewport'] as Map? ?? const {},
    );
    final headers = (json['headers'] as List? ?? const [])
        .map((value) => '$value')
        .toList(growable: false);
    final rows = json['rows'] as List? ?? const [];
    final cells = <SpreadsheetCell>[];
    for (final rawRow in rows) {
      final row = Map<String, Object?>.from(rawRow as Map? ?? const {});
      final rowNumber = _asInt(row['rowNumber']);
      final rawCells = Map<String, Object?>.from(
        row['cells'] as Map? ?? const {},
      );
      for (var index = 0; index < headers.length; index++) {
        final value = Map<String, Object?>.from(
          rawCells[headers[index]] as Map? ?? const {},
        );
        cells.add(
          SpreadsheetCell(
            row: rowNumber,
            column: _asInt(viewport['startColumn']) + index,
            value: '${value['rawValue'] ?? ''}',
            formattedValue: '${value['formattedValue'] ?? ''}',
            note: '${value['note'] ?? ''}',
            hyperlink: '${value['hyperlink'] ?? ''}',
            backgroundColor: value['backgroundColor'] as String?,
            textColor: value['textColor'] as String?,
            bold: value['bold'] == true,
            italic: value['italic'] == true,
            validationType: value['validationType'] as String?,
            validationValues: (value['validationValues'] as List? ?? const [])
                .map((item) => '$item')
                .toList(growable: false),
          ),
        );
      }
    }
    final caps = Map<String, Object?>.from(
      json['capabilities'] as Map? ?? const {},
    );
    return SpreadsheetSnapshot(
      tabName: '${json['tabName'] ?? ''}',
      tabs: (json['tabs'] as List? ?? const [])
          .map((item) => '$item')
          .toList(growable: false),
      headers: headers,
      cells: cells,
      viewport: SpreadsheetViewport(
        startRow: _asInt(viewport['startRow']),
        startColumn: _asInt(viewport['startColumn']),
        rowCount: _asInt(viewport['rowCount']),
        columnCount: _asInt(viewport['columnCount']),
        totalRows: _asInt(viewport['totalRows']),
        totalColumns: _asInt(viewport['totalColumns']),
      ),
      version: SpreadsheetVersion('${json['version'] ?? 'v1'}'),
      compatibility: switch ('${json['compatibility'] ?? 'fullyEditable'}') {
        'protectedReadOnly' => SpreadsheetCompatibility.protectedReadOnly,
        'unsupportedReadOnly' => SpreadsheetCompatibility.unsupportedReadOnly,
        _ => SpreadsheetCompatibility.fullyEditable,
      },
      canEdit: caps['edit'] == true,
      canStructure: caps['structure'] == true,
      canFormat: caps['format'] == true,
    );
  }

  int _asInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}
