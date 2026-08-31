import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/company_workspace_models.dart';
import '../../services/google_workspace_service.dart';
import '../../utils/user_facing_error.dart';
import '../../theme/theme.dart';
import '../../design_system/components/skeletons.dart' show SkeletonList;

/// Audited spreadsheet editor. Google IDs remain on the server and every
/// mutation is sent through the ZaWolf permission/audit gateway.
class WorkspaceSheetEditorScreen extends StatefulWidget {
  final CompanyWorkspaceResource resource;
  final String? fileId;
  final String? fileName;
  final List<String> folderPath;

  const WorkspaceSheetEditorScreen({
    super.key,
    required this.resource,
    this.fileId,
    this.fileName,
    this.folderPath = const [],
  });

  @override
  State<WorkspaceSheetEditorScreen> createState() =>
      _WorkspaceSheetEditorScreenState();
}

class _WorkspaceSheetEditorScreenState
    extends State<WorkspaceSheetEditorScreen> {
  static const _rowNumberField = '__row_number__';
  final _service = GoogleWorkspaceService();
  final Map<String, String> _headersByField = {};
  final Map<Key, int> _rowNumbers = {};
  final Map<int, Map<String, String>> _pendingUpdates = {};
  final Map<String, Color> _localCellColors = {};
  final Set<String> _localBoldCells = {};
  final Map<String, Map<String, dynamic>> _cellMetadata = {};
  final TextEditingController _formulaController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _formulaFocus = FocusNode();
  final FocusNode _searchFocus = FocusNode();

  WorkspaceSheetData? _sheet;
  List<PlutoColumn> _gridColumns = const [];
  List<PlutoRow> _gridRows = const [];
  PlutoGridStateManager? _stateManager;
  Timer? _saveTimer;
  bool _loading = true;
  bool _saving = false;
  bool _allowPop = false;
  String? _error;
  int _gridRevision = 0;
  String? _selectedTab;
  bool _showSearch = false;
  int _lastSearchRow = -1;
  int _lastSearchColumn = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _stateManager?.removeListener(_onGridSelectionChanged);
    _formulaController.dispose();
    _searchController.dispose();
    _formulaFocus.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoader = true, String? tabName}) async {
    await _flushPendingUpdates();
    if (mounted) {
      setState(() {
        if (showLoader) _loading = true;
        _error = null;
      });
    }
    try {
      final data = await _service.readWorkspaceSheet(
        widget.resource.id,
        fileId: widget.fileId,
        tabName: tabName ?? _selectedTab,
        path: widget.folderPath,
      );
      if (!mounted) return;
      _localCellColors.clear();
      _localBoldCells.clear();
      final columns = _columns(data);
      final rows = _rows(data);
      setState(() {
        _stateManager?.removeListener(_onGridSelectionChanged);
        _sheet = data;
        _selectedTab = data.tabName;
        _gridColumns = columns;
        _gridRows = rows;
        _stateManager = null;
        _gridRevision++;
      });
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<PlutoColumn> _columns(WorkspaceSheetData sheet) {
    _headersByField.clear();
    final columns = <PlutoColumn>[
      PlutoColumn(
        title: '#',
        field: _rowNumberField,
        type: PlutoColumnType.number(),
        width: 72,
        minWidth: 60,
        frozen: PlutoColumnFrozen.start,
        readOnly: true,
        enableSorting: false,
        enableContextMenu: false,
        enableDropToResize: false,
      ),
    ];
    for (var index = 0; index < sheet.headers.length; index++) {
      final header = sheet.headers[index];
      final field = 'column_$index';
      _headersByField[field] = header;
      final labelValues = sheet.rows
          .map(
            (row) => Map<String, dynamic>.from(
              (row['cells'] as Map?)?[header] as Map? ?? const {},
            ),
          )
          .where((cell) => cell['validationType'] == 'ONE_OF_LIST')
          .expand((cell) => (cell['validationValues'] as List? ?? const []))
          .map((value) => '$value')
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList(growable: false);
      columns.add(
        PlutoColumn(
          title: header,
          field: field,
          type: labelValues.isEmpty
              ? PlutoColumnType.text()
              : PlutoColumnType.select(labelValues),
          width: 190,
          minWidth: 90,
          readOnly: !sheet.canEdit || !sheet.editableFields.contains(header),
          // A single click starts editing, matching desktop spreadsheet apps.
          enableAutoEditing: true,
          enableEditingMode: true,
          renderer: (context) {
            final rowNumber = _rowNumbers[context.row.key] ?? 0;
            final styleKey = '$rowNumber:${context.column.field}';
            final metadata = _cellMetadata[styleKey] ?? const {};
            final background =
                _localCellColors[styleKey] ??
                _parseSheetColor(metadata['backgroundColor']);
            final textColor = _parseSheetColor(metadata['textColor']);
            final formatted =
                '${metadata['formattedValue'] ?? context.cell.value ?? ''}';
            final labels = (metadata['validationValues'] as List? ?? const [])
                .map((value) => '$value')
                .toList(growable: false);
            final isCheckbox = metadata['validationType'] == 'BOOLEAN';
            final hyperlink = '${metadata['hyperlink'] ?? ''}';
            return Container(
              alignment: AlignmentDirectional.centerStart,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              color: background,
              child: Row(
                children: [
                  if (isCheckbox)
                    Icon(
                      formatted.toLowerCase() == 'true'
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 20,
                      color: ZaWolfColors.editorAccent,
                    )
                  else
                    Expanded(
                      child: labels.contains(formatted)
                          ? Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Chip(
                                label: Text(formatted),
                                visualDensity: VisualDensity.compact,
                              ),
                            )
                          : Text(
                              formatted,
                              maxLines: metadata['wrapStrategy'] == 'WRAP'
                                  ? 2
                                  : 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textColor,
                                fontStyle: metadata['italic'] == true
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                                fontWeight:
                                    _localBoldCells.contains(styleKey) ||
                                        metadata['bold'] == true
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                    ),
                  if (hyperlink.isNotEmpty)
                    InkWell(
                      onTap: () => launchUrl(Uri.parse(hyperlink)),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.open_in_new, size: 16),
                      ),
                    ),
                  if ('${metadata['note'] ?? ''}'.isNotEmpty)
                    Tooltip(
                      message: '${metadata['note']}',
                      child: const Icon(Icons.comment_outlined, size: 16),
                    ),
                ],
              ),
            );
          },
        ),
      );
    }
    return columns;
  }

  List<PlutoRow> _rows(WorkspaceSheetData sheet) {
    _rowNumbers.clear();
    _cellMetadata.clear();
    return sheet.rows
        .map((source) {
          final values = Map<String, dynamic>.from(
            source['values'] as Map? ?? const {},
          );
          final rowNumber =
              (source['rowNumber'] as num?)?.toInt() ?? _rowNumbers.length + 2;
          final cells = Map<String, dynamic>.from(
            source['cells'] as Map? ?? const {},
          );
          final row = PlutoRow(
            cells: {
              _rowNumberField: PlutoCell(value: rowNumber),
              for (var index = 0; index < sheet.headers.length; index++)
                'column_$index': PlutoCell(
                  value:
                      '${(cells[sheet.headers[index]] as Map?)?['rawValue'] ?? values[sheet.headers[index]] ?? ''}',
                ),
            },
          );
          _rowNumbers[row.key] = rowNumber;
          for (var index = 0; index < sheet.headers.length; index++) {
            _cellMetadata['$rowNumber:column_$index'] =
                Map<String, dynamic>.from(
                  cells[sheet.headers[index]] as Map? ?? const {},
                );
          }
          return row;
        })
        .toList(growable: false);
  }

  Color? _parseSheetColor(dynamic raw) {
    final value = '$raw';
    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) return null;
    return Color(int.parse('FF${value.substring(1)}', radix: 16));
  }

  void _onCellChanged(PlutoGridOnChangedEvent event) {
    final header = _headersByField[event.column.field];
    final rowNumber = _rowNumbers[event.row.key];
    if (header == null || rowNumber == null || event.value == event.oldValue) {
      return;
    }
    _pendingUpdates.putIfAbsent(rowNumber, () => {})[header] =
        '${event.value ?? ''}';
    final styleKey = '$rowNumber:${event.column.field}';
    _cellMetadata.putIfAbsent(styleKey, () => {})
      ..['rawValue'] = event.value
      ..['formattedValue'] = event.value;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 650), _flushPendingUpdates);
    if (mounted) setState(() => _saving = true);
  }

  void _onGridSelectionChanged() {
    if (_formulaFocus.hasFocus) return;
    final manager = _stateManager;
    final cell = manager?.currentCell;
    if (cell == null) return;
    final value = '${cell.value ?? ''}';
    if (_formulaController.text != value) {
      _formulaController.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  void _applyFormulaValue(String value) {
    final manager = _stateManager;
    final rowIndex = manager?.currentRowIdx;
    final cell = manager?.currentCell;
    final column = manager?.currentColumn;
    if (manager == null || rowIndex == null || cell == null || column == null) {
      return;
    }
    if (column.field == _rowNumberField || column.readOnly) return;
    manager.changeCellValue(cell, value, force: true);
    _formulaFocus.unfocus();
  }

  void _openSearch() {
    setState(() {
      _showSearch = true;
      _lastSearchRow = -1;
      _lastSearchColumn = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
      _searchController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchController.text.length,
      );
    });
  }

  void _findNext() {
    final manager = _stateManager;
    final query = _searchController.text.trim().toLowerCase();
    if (manager == null || query.isEmpty || manager.rows.isEmpty) return;
    final total = manager.rows.length * math.max(1, _headersByField.length);
    var flat = math.max(
      0,
      _lastSearchRow * _headersByField.length + _lastSearchColumn + 1,
    );
    for (var checked = 0; checked < total; checked++, flat++) {
      final rowIndex = flat ~/ _headersByField.length % manager.rows.length;
      final columnOffset = flat % _headersByField.length;
      final field = 'column_$columnOffset';
      final cell = manager.rows[rowIndex].cells[field];
      if ('${cell?.value ?? ''}'.toLowerCase().contains(query)) {
        _lastSearchRow = rowIndex;
        _lastSearchColumn = columnOffset;
        manager.setCurrentCell(cell, rowIndex);
        manager.moveScrollByRow(PlutoMoveDirection.up, manager.rows.length);
        manager.moveScrollByRow(PlutoMoveDirection.down, rowIndex);
        manager.moveScrollByColumn(
          PlutoMoveDirection.left,
          manager.refColumns.length,
        );
        manager.moveScrollByColumn(PlutoMoveDirection.right, columnOffset + 1);
        manager.notifyListeners();
        return;
      }
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('لا توجد نتيجة مطابقة أخرى.')));
  }

  Future<void> _flushPendingUpdates() async {
    _saveTimer?.cancel();
    if (_pendingUpdates.isEmpty) return;
    final pending = {
      for (final entry in _pendingUpdates.entries)
        entry.key: Map<String, String>.from(entry.value),
    };
    _pendingUpdates.clear();
    if (mounted) setState(() => _saving = true);
    try {
      for (final entry in pending.entries) {
        await _service.updateWorkspaceSheetRow(
          resourceId: widget.resource.id,
          tabName: _selectedTab ?? _sheet?.tabName ?? '',
          rowNumber: entry.key,
          updates: entry.value,
          fileId: widget.fileId,
          path: widget.folderPath,
        );
      }
      if (mounted) setState(() => _error = null);
    } catch (error) {
      for (final entry in pending.entries) {
        _pendingUpdates.putIfAbsent(entry.key, () => {}).addAll(entry.value);
      }
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _saving = _pendingUpdates.isNotEmpty);
    }
  }

  _SheetRange? _currentRange({bool fullRow = false, bool fullColumn = false}) {
    final manager = _stateManager;
    final sheet = _sheet;
    if (manager == null || sheet == null || manager.currentRowIdx == null) {
      return null;
    }
    var rowStart = manager.currentRowIdx!;
    var rowEnd = rowStart;
    var columnStart = manager.currentCellPosition?.columnIdx ?? 1;
    var columnEnd = columnStart;
    final positions = manager.currentSelectingPositionList;
    if (positions.isNotEmpty) {
      final rowIndexes = positions
          .map((item) => item.rowIdx)
          .whereType<int>()
          .toList();
      final columnIndexes = positions
          .map(
            (item) => manager.refColumns.originalList.indexWhere(
              (column) => column.field == item.field,
            ),
          )
          .where((index) => index >= 0)
          .toList();
      if (rowIndexes.isNotEmpty) {
        rowStart = rowIndexes.reduce(math.min);
        rowEnd = rowIndexes.reduce(math.max);
      }
      if (columnIndexes.isNotEmpty) {
        columnStart = columnIndexes.reduce(math.min);
        columnEnd = columnIndexes.reduce(math.max);
      }
    }
    columnStart = math.max(1, columnStart);
    columnEnd = math.max(1, columnEnd);
    if (fullRow) {
      columnStart = 1;
      columnEnd = sheet.headers.length;
    }
    if (fullColumn) {
      rowStart = 0;
      rowEnd = math.max(0, sheet.rows.length - 1);
    }
    final firstRowNumber = _rowNumberAt(rowStart);
    final lastRowNumber = _rowNumberAt(rowEnd);
    if (firstRowNumber == null || lastRowNumber == null) return null;
    return _SheetRange(
      startRow: math.min(firstRowNumber, lastRowNumber),
      endRow: math.max(firstRowNumber, lastRowNumber),
      startColumn: math.min(columnStart, columnEnd),
      endColumn: math.max(columnStart, columnEnd),
    );
  }

  int? _rowNumberAt(int visibleIndex) {
    final manager = _stateManager;
    if (manager == null ||
        visibleIndex < 0 ||
        visibleIndex >= manager.rows.length) {
      return null;
    }
    return _rowNumbers[manager.rows[visibleIndex].key];
  }

  void _selectFullRow() {
    final manager = _stateManager;
    if (manager == null || manager.rows.isEmpty) return;
    final rowIndex = manager.currentRowIdx ?? 0;
    final firstField = _headersByField.keys.firstOrNull;
    if (firstField == null) return;
    final firstCell = manager.rows[rowIndex].cells[firstField];
    if (firstCell == null) return;
    manager.setCurrentCell(firstCell, rowIndex, notify: false);
    manager.setCurrentSelectingPosition(
      cellPosition: PlutoGridCellPosition(
        columnIdx: _gridColumns.length - 1,
        rowIdx: rowIndex,
      ),
    );
  }

  void _selectFullColumn() {
    final manager = _stateManager;
    if (manager == null || manager.rows.isEmpty) return;
    final columnIndex = math.max(
      1,
      manager.currentCellPosition?.columnIdx ?? 1,
    );
    final field = _gridColumns[columnIndex].field;
    final firstCell = manager.rows.first.cells[field];
    if (firstCell == null) return;
    manager.setCurrentCell(firstCell, 0, notify: false);
    manager.setCurrentSelectingPosition(
      cellPosition: PlutoGridCellPosition(
        columnIdx: columnIndex,
        rowIdx: manager.rows.length - 1,
      ),
    );
  }

  Future<void> _requestPop<T>(T? result) async {
    if (_saving || _pendingUpdates.isNotEmpty) {
      await _flushPendingUpdates();
      if (_pendingUpdates.isNotEmpty) return;
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    Navigator.of(context).pop(result);
  }

  Future<void> _formatSelected({
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
    bool fullRow = false,
    bool fullColumn = false,
  }) async {
    final sheet = _sheet;
    final range = _currentRange(fullRow: fullRow, fullColumn: fullColumn);
    if (sheet == null || range == null || !sheet.canFormat) return;
    await _flushPendingUpdates();
    if (mounted) setState(() => _saving = true);
    try {
      await _service.formatWorkspaceSheetRange(
        resourceId: widget.resource.id,
        tabName: sheet.tabName,
        startRow: range.startRow,
        endRow: range.endRow,
        startColumn: range.startColumn,
        endColumn: range.endColumn,
        backgroundColor: backgroundColor,
        textColor: textColor,
        bold: bold,
        italic: italic,
        horizontalAlignment: horizontalAlignment,
        wrapStrategy: wrapStrategy,
        dropdownValues: dropdownValues,
        checkbox: checkbox,
        clearValidation: clearValidation,
        clearFormatting: clearFormatting,
        fileId: widget.fileId,
        path: widget.folderPath,
      );
      final color = backgroundColor == null
          ? null
          : Color(int.parse('FF${backgroundColor.substring(1)}', radix: 16));
      for (var row = range.startRow; row <= range.endRow; row++) {
        for (
          var column = range.startColumn;
          column <= range.endColumn;
          column++
        ) {
          final key = '$row:column_${column - 1}';
          if (color != null) _localCellColors[key] = color;
          if (bold == true) _localBoldCells.add(key);
          if (bold == false) _localBoldCells.remove(key);
        }
      }
      _stateManager?.notifyListeners();
      if (italic != null ||
          horizontalAlignment != null ||
          wrapStrategy != null ||
          dropdownValues != null ||
          checkbox == true ||
          clearValidation == true ||
          clearFormatting == true) {
        await _load(showLoader: false);
      }
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _structure(
    String operation, {
    int? index,
    int count = 1,
    String? headerValue,
  }) async {
    final sheet = _sheet;
    final range = _currentRange();
    if (sheet == null || !sheet.canChangeStructure) return;
    if (range == null && index == null) return;
    await _flushPendingUpdates();
    final targetIndex =
        index ??
        (operation.contains('column') ? range!.startColumn : range!.startRow);
    if (mounted) setState(() => _saving = true);
    try {
      await _service.changeWorkspaceSheetStructure(
        resourceId: widget.resource.id,
        tabName: sheet.tabName,
        operation: operation,
        index: targetIndex,
        count: count,
        headerValue: headerValue,
        fileId: widget.fileId,
        path: widget.folderPath,
      );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addRows({required bool after}) async {
    final range = _currentRange();
    final sheet = _sheet;
    if (sheet == null || !sheet.canChangeStructure) return;
    final count = await _askCount('عدد الصفوف الجديدة');
    if (count == null) return;
    await _structure(
      'insert_row',
      index: range == null ? 2 : (after ? range.endRow + 1 : range.startRow),
      count: count,
    );
  }

  Future<void> _addColumns({required bool after}) async {
    final sheet = _sheet;
    final range = _currentRange();
    if (sheet == null || !sheet.canChangeStructure) return;
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(after ? 'إضافة عمود بعد المحدد' : 'إضافة عمود قبل المحدد'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: 'عنوان العمود',
            hintText: 'مثال: حالة التنفيذ',
          ),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null || title.isEmpty) return;
    await _structure(
      'insert_column',
      index: range == null
          ? (after ? sheet.headers.length + 1 : 1)
          : (after ? range.endColumn + 1 : range.startColumn),
      headerValue: title,
    );
  }

  Future<int?> _askCount(String label) async {
    final controller = TextEditingController(text: '1');
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(helperText: 'من 1 إلى 100'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              Navigator.pop(context, value?.clamp(1, 100));
            },
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _createLabels() async {
    final controller = TextEditingController();
    final labels = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة labels / قائمة منسدلة'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'جديد، قيد التنفيذ، مكتمل',
            helperText: 'افصل القيم بفاصلة أو سطر جديد.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              controller.text
                  .split(RegExp(r'[,،\n]'))
                  .map((value) => value.trim())
                  .where((value) => value.isNotEmpty)
                  .toSet()
                  .toList(),
            ),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (labels == null || labels.isEmpty) return;
    await _formatSelected(dropdownValues: labels);
  }

  Future<String?> _askTabName(String title, {String initialValue = ''}) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 100,
          decoration: const InputDecoration(
            labelText: 'اسم Sheet',
            hintText: 'مثال: Sheet2',
          ),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result?.trim();
  }

  Future<void> _changeTab(String operation, {String? newName}) async {
    final sheet = _sheet;
    if (sheet == null || !sheet.canChangeStructure) return;
    await _flushPendingUpdates();
    if (mounted) setState(() => _saving = true);
    try {
      final selected = await _service.changeWorkspaceSheetTab(
        resourceId: widget.resource.id,
        operation: operation,
        tabName: sheet.tabName,
        newName: newName,
        fileId: widget.fileId,
        path: widget.folderPath,
      );
      await _load(tabName: selected);
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addSheetTab() async {
    final sheet = _sheet;
    if (sheet == null) return;
    var sequence = sheet.tabs.length + 1;
    var suggested = 'Sheet$sequence';
    while (sheet.tabs.any(
      (tab) => tab.toLowerCase() == suggested.toLowerCase(),
    )) {
      suggested = 'Sheet${++sequence}';
    }
    final name = await _askTabName('إضافة Sheet جديد', initialValue: suggested);
    if (name == null || name.isEmpty) return;
    await _changeTab('add', newName: name);
  }

  Future<void> _renameCurrentTab() async {
    final sheet = _sheet;
    if (sheet == null) return;
    final name = await _askTabName(
      'إعادة تسمية ${sheet.tabName}',
      initialValue: sheet.tabName,
    );
    if (name == null || name.isEmpty || name == sheet.tabName) return;
    await _changeTab('rename', newName: name);
  }

  Future<void> _deleteCurrentTab() async {
    final sheet = _sheet;
    if (sheet == null || sheet.tabs.length <= 1) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حذف ${sheet.tabName}؟'),
        content: const Text(
          'سيتم حذف هذا التبويب ومحتواه من Google Sheets. لا يمكن التراجع من داخل ZaWolf.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _changeTab('delete');
  }

  @override
  Widget build(BuildContext context) {
    final sheet = _sheet;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _openSearch,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): _openSearch,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
            unawaited(_flushPendingUpdates()),
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () =>
            unawaited(_flushPendingUpdates()),
      },
      child: PopScope(
        canPop: _allowPop,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) unawaited(_requestPop(result));
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.fileName ?? widget.resource.name),
            actions: [
              IconButton(
                tooltip: 'بحث (Ctrl+F)',
                onPressed: _openSearch,
                icon: const Icon(Icons.search),
              ),
              IconButton(
                tooltip: 'تحديث',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: _loading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SkeletonList(itemCount: 6, itemHeight: 40),
                )
              : sheet == null
              ? _errorPanel()
              : Column(
                  children: [
                    _toolbar(sheet),
                    _formulaBar(sheet),
                    if (_saving) const LinearProgressIndicator(minHeight: 3),
                    if (_error != null)
                      MaterialBanner(
                        content: Text(_error!),
                        actions: [
                          TextButton(
                            onPressed: _load,
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    Expanded(
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: PlutoGrid(
                          key: ValueKey(_gridRevision),
                          columns: _gridColumns,
                          rows: _gridRows,
                          onLoaded: (event) {
                            _stateManager?.removeListener(
                              _onGridSelectionChanged,
                            );
                            _stateManager = event.stateManager;
                            event.stateManager.setSelectingMode(
                              PlutoGridSelectingMode.cell,
                            );
                            event.stateManager.addListener(
                              _onGridSelectionChanged,
                            );
                            _onGridSelectionChanged();
                          },
                          onChanged: _onCellChanged,
                          configuration: const PlutoGridConfiguration.dark(
                            enableMoveHorizontalInEditing: true,
                            enterKeyAction:
                                PlutoGridEnterKeyAction.editingAndMoveDown,
                            tabKeyAction:
                                PlutoGridTabKeyAction.moveToNextOnEdge,
                            scrollbar: PlutoGridScrollbarConfig(
                              isAlwaysShown: true,
                              draggableScrollbar: true,
                              onlyDraggingThumb: false,
                              scrollbarThickness: 12,
                              scrollbarThicknessWhileDragging: 16,
                            ),
                            style: PlutoGridStyleConfig.dark(
                              rowHeight: 52,
                              columnHeight: 52,
                              activatedColor: ZaWolfColors.editorActivated,
                              activatedBorderColor: ZaWolfColors.editorAccent,
                              gridBorderColor: ZaWolfColors.editorGridBorder,
                              borderColor: ZaWolfColors.editorGridBorder,
                              cellColorInEditState: ZaWolfColors.editorCellEdit,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (sheet.tabs.isNotEmpty) _sheetTabs(sheet),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _errorPanel() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error ?? 'تعذر فتح الجدول.', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    ),
  );

  Widget _toolbar(WorkspaceSheetData sheet) {
    return Material(
      color: ZaWolfColors.editorSurface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${sheet.tabName} · ${sheet.rows.length} صف',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              _toolButton('بحث', Icons.search, _openSearch),
              if (sheet.canChangeStructure) ...[
                _toolButton(
                  'صف قبل',
                  Icons.add_box_outlined,
                  () => _addRows(after: false),
                ),
                _toolButton(
                  'صف بعد',
                  Icons.playlist_add,
                  () => _addRows(after: true),
                ),
                _toolButton(
                  'عمود قبل',
                  Icons.view_column_outlined,
                  () => _addColumns(after: false),
                ),
                _toolButton(
                  'عمود بعد',
                  Icons.add_to_photos_outlined,
                  () => _addColumns(after: true),
                ),
                _toolButton(
                  'حذف صف',
                  Icons.delete_sweep_outlined,
                  () => _structure('delete_row'),
                ),
                _toolButton(
                  'حذف عمود',
                  Icons.delete_outline,
                  () => _structure('delete_column'),
                ),
              ],
              if (sheet.canFormat) ...[
                _toolButton(
                  'تحديد الصف',
                  Icons.table_rows_outlined,
                  _selectFullRow,
                ),
                _toolButton(
                  'تحديد العمود',
                  Icons.view_column_outlined,
                  _selectFullColumn,
                ),
                _toolButton(
                  'غامق',
                  Icons.format_bold,
                  () => _formatSelected(bold: true),
                ),
                _toolButton(
                  'مائل',
                  Icons.format_italic,
                  () => _formatSelected(italic: true),
                ),
                _toolButton(
                  'محاذاة',
                  Icons.format_align_center,
                  () => _formatSelected(horizontalAlignment: 'CENTER'),
                ),
                _toolButton(
                  'التفاف النص',
                  Icons.wrap_text,
                  () => _formatSelected(wrapStrategy: 'WRAP'),
                ),
                _toolButton('Labels', Icons.label_outline, _createLabels),
                _toolButton(
                  'Checkbox',
                  Icons.check_box_outlined,
                  () => _formatSelected(checkbox: true),
                ),
                const SizedBox(width: 8),
                for (final color in const [
                  '#FFF59D',
                  '#A5D6A7',
                  '#90CAF9',
                  '#F8BBD0',
                  '#FFCC80',
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Tooltip(
                      message: 'تلوين النطاق المحدد',
                      child: InkWell(
                        onTap: () => _formatSelected(backgroundColor: color),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Color(
                              int.parse('FF${color.substring(1)}', radix: 16),
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white54),
                          ),
                        ),
                      ),
                    ),
                  ),
                _toolButton(
                  'إزالة التنسيق',
                  Icons.format_clear,
                  () => _formatSelected(clearFormatting: true),
                ),
                _toolButton(
                  'إزالة Labels',
                  Icons.label_off_outlined,
                  () => _formatSelected(clearValidation: true),
                ),
              ],
              _toolButton(
                'حفظ الآن',
                Icons.save_outlined,
                _flushPendingUpdates,
              ),
              _toolButton('تحديث', Icons.refresh, _load),
              if (!sheet.canEdit)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('عرض فقط — اطلب صلاحية تعديل من المدير.'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formulaBar(WorkspaceSheetData sheet) => Material(
    color: ZaWolfColors.editorSurfaceDeep,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          const SizedBox(
            width: 44,
            child: Text('fx', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: TextField(
              controller: _formulaController,
              focusNode: _formulaFocus,
              enabled: sheet.canEdit,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'القيمة أو الصيغة =SUM(A1:A5)',
              ),
              onSubmitted: _applyFormulaValue,
            ),
          ),
          IconButton(
            tooltip: 'تطبيق',
            onPressed: sheet.canEdit
                ? () => _applyFormulaValue(_formulaController.text)
                : null,
            icon: const Icon(Icons.check),
          ),
          if (_showSearch) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 260,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search),
                  hintText: 'بحث في الجدول',
                ),
                onChanged: (_) {
                  _lastSearchRow = -1;
                  _lastSearchColumn = 0;
                },
                onSubmitted: (_) => _findNext(),
              ),
            ),
            IconButton(
              tooltip: 'النتيجة التالية',
              onPressed: _findNext,
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
            IconButton(
              tooltip: 'إغلاق البحث',
              onPressed: () => setState(() => _showSearch = false),
              icon: const Icon(Icons.close),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _sheetTabs(WorkspaceSheetData sheet) => Material(
    color: ZaWolfColors.editorSurface,
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 58,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              if (sheet.canChangeStructure)
                IconButton.filledTonal(
                  tooltip: 'إضافة Sheet جديد',
                  onPressed: _saving ? null : _addSheetTab,
                  icon: const Icon(Icons.add),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  itemCount: sheet.tabs.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final tab = sheet.tabs[index];
                    return ChoiceChip(
                      selected: tab == sheet.tabName,
                      label: Text(tab),
                      onSelected: tab == sheet.tabName || _saving
                          ? null
                          : (_) => _load(showLoader: false, tabName: tab),
                    );
                  },
                ),
              ),
              if (sheet.canChangeStructure) ...[
                const VerticalDivider(indent: 9, endIndent: 9),
                IconButton(
                  tooltip: 'إعادة تسمية ${sheet.tabName}',
                  onPressed: _saving ? null : _renameCurrentTab,
                  icon: const Icon(Icons.drive_file_rename_outline),
                ),
                IconButton(
                  tooltip: sheet.tabs.length <= 1
                      ? 'لا يمكن حذف آخر Sheet'
                      : 'حذف ${sheet.tabName}',
                  onPressed: _saving || sheet.tabs.length <= 1
                      ? null
                      : _deleteCurrentTab,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _toolButton(String label, IconData icon, VoidCallback action) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: FilledButton.tonalIcon(
          onPressed: _saving ? null : action,
          style: const ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(0, 48)),
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          icon: Icon(icon, size: 22),
          label: Text(label, style: const TextStyle(fontSize: 15)),
        ),
      );
}

class _SheetRange {
  final int startRow;
  final int endRow;
  final int startColumn;
  final int endColumn;

  const _SheetRange({
    required this.startRow,
    required this.endRow,
    required this.startColumn,
    required this.endColumn,
  });
}
