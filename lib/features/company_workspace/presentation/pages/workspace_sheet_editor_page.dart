import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/spreadsheet_range.dart';
import '../../domain/entities/workspace_operation.dart';
import '../cubit/workspace_sheet_cubit.dart';
import '../cubit/workspace_sheet_sync_cubit.dart';
import '../widgets/sheet/workspace_sheet_status_bar.dart';
import '../widgets/workspace_sync_status_banner.dart';
import 'workspace_conflict_page.dart';

/// A full-page, keyboard-friendly V2 spreadsheet surface. It deliberately
/// lives beside the legacy dialog editor until the feature switch pilot proves
/// parity for actual company workbooks.
class WorkspaceSheetEditorPage extends StatefulWidget {
  const WorkspaceSheetEditorPage({
    required this.resourceId,
    required this.initialTab,
    super.key,
  });

  final String resourceId;
  final String initialTab;

  @override
  State<WorkspaceSheetEditorPage> createState() =>
      _WorkspaceSheetEditorPageState();
}

class _WorkspaceSheetEditorPageState extends State<WorkspaceSheetEditorPage> {
  SpreadsheetCell? _selected;
  SpreadsheetRange? _selectedRange;
  final _controller = TextEditingController();
  final _findController = TextEditingController();
  final _findFocus = FocusNode();
  final _gridFocus = FocusNode();
  bool _showFind = false;
  final _undo = <_CellChange>[];
  final _redo = <_CellChange>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkspaceSheetCubit>().load(
        resourceId: widget.resourceId,
        tabName: widget.initialTab,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _findController.dispose();
    _findFocus.dispose();
    _gridFocus.dispose();
    super.dispose();
  }

  void _openFind() {
    setState(() => _showFind = true);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _findFocus.requestFocus(),
    );
  }

  void _select(SpreadsheetCell cell) {
    setState(() {
      _selected = cell;
      _selectedRange = SpreadsheetRange(
        tabName: '',
        startRow: cell.row,
        endRow: cell.row,
        startColumn: cell.column,
        endColumn: cell.column,
      );
      _controller.value = TextEditingValue(text: cell.value);
    });
    _gridFocus.requestFocus();
  }

  void _selectRange(SpreadsheetRange range) {
    setState(() {
      _selectedRange = range;
      _selected = SpreadsheetCell(
        row: range.startRow,
        column: range.startColumn,
        value: _selected?.value ?? '',
      );
    });
  }

  SpreadsheetRange _activeRange(SpreadsheetSnapshot snapshot) {
    final selected = _selectedRange;
    if (selected == null) {
      return SpreadsheetRange(
        tabName: snapshot.tabName,
        startRow: snapshot.viewport.startRow,
        endRow: snapshot.viewport.startRow,
        startColumn: snapshot.viewport.startColumn,
        endColumn: snapshot.viewport.startColumn,
      );
    }
    return SpreadsheetRange(
      tabName: snapshot.tabName,
      startRow: selected.startRow,
      endRow: selected.endRow,
      startColumn: selected.startColumn,
      endColumn: selected.endColumn,
    );
  }

  void _submitAction(
    SpreadsheetSnapshot snapshot,
    SpreadsheetRange viewport, {
    required WorkspaceOperationKind kind,
    required Map<String, Object?> payload,
  }) {
    context.read<WorkspaceSheetSyncCubit>().submitSheetOperation(
      resourceId: widget.resourceId,
      tabName: snapshot.tabName,
      viewport: viewport,
      version: snapshot.version,
      kind: kind,
      payload: payload,
    );
  }

  Future<void> _addTab(
    SpreadsheetSnapshot snapshot,
    SpreadsheetRange viewport,
  ) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة ورقة جديدة'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'اسم الورقة'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    _submitAction(
      snapshot,
      viewport,
      kind: WorkspaceOperationKind.sheetTab,
      payload: {'operation': 'add', 'newName': name.trim()},
    );
  }

  Future<void> _addDropdown(
    SpreadsheetSnapshot snapshot,
    SpreadsheetRange viewport,
  ) async {
    final controller = TextEditingController();
    final values = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('قائمة اختيار للخلايا المحددة'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'مثال: جديد، قيد التنفيذ، مكتمل',
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    controller.dispose();
    final items = values
        ?.split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (items == null || items.isEmpty) return;
    _submitAction(
      snapshot,
      viewport,
      kind: WorkspaceOperationKind.sheetFormat,
      payload: _rangePayload(_activeRange(snapshot), {'dropdownValues': items}),
    );
  }

  void _save(SpreadsheetSnapshot snapshot, SpreadsheetRange viewport) {
    final selected = _selected;
    if (selected == null) return;
    _saveCell(snapshot, viewport, selected, _controller.text);
  }

  void _saveCell(
    SpreadsheetSnapshot snapshot,
    SpreadsheetRange viewport,
    SpreadsheetCell selected,
    String value,
  ) {
    final previous =
        snapshot.cells
            .where(
              (cell) =>
                  cell.row == selected.row && cell.column == selected.column,
            )
            .map((cell) => cell.value)
            .firstOrNull ??
        '';
    if (previous != value) {
      _undo.add(_CellChange(selected.row, selected.column, previous, value));
      _redo.clear();
    }
    final cells = <SpreadsheetCell>[
      SpreadsheetCell(
        row: selected.row,
        column: selected.column,
        value: value,
      ),
    ];
    context.read<WorkspaceSheetCubit>().applyCells(cells);
    context.read<WorkspaceSheetSyncCubit>().saveCells(
      resourceId: widget.resourceId,
      tabName: snapshot.tabName,
      viewport: viewport,
      version: snapshot.version,
      cells: cells,
    );
  }

  void _restoreHistory(
    SpreadsheetSnapshot snapshot,
    SpreadsheetRange viewport, {
    required bool redo,
  }) {
    final source = redo ? _redo : _undo;
    if (source.isEmpty) return;
    final change = source.removeLast();
    (redo ? _undo : _redo).add(change);
    final value = redo ? change.after : change.before;
    final cells = <SpreadsheetCell>[
      SpreadsheetCell(row: change.row, column: change.column, value: value),
    ];
    context.read<WorkspaceSheetCubit>().applyCells(cells);
    context.read<WorkspaceSheetSyncCubit>().saveCells(
      resourceId: widget.resourceId,
      tabName: snapshot.tabName,
      viewport: viewport,
      version: snapshot.version,
      cells: cells,
    );
  }

  void _moveSelection(
    SpreadsheetSnapshot snapshot,
    int rowDelta,
    int columnDelta,
  ) {
    final current =
        _selected ??
        SpreadsheetCell(
          row: snapshot.viewport.startRow,
          column: snapshot.viewport.startColumn,
          value: '',
        );
    final row = (current.row + rowDelta)
        .clamp(1, snapshot.viewport.totalRows)
        .toInt();
    final column = (current.column + columnDelta)
        .clamp(1, snapshot.viewport.totalColumns)
        .toInt();
    _select(SpreadsheetCell(row: row, column: column, value: ''));
  }

  Future<void> _copySelection(SpreadsheetSnapshot snapshot) async {
    final range = _activeRange(snapshot);
    final cells = <String, SpreadsheetCell>{
      for (final cell in snapshot.cells) '${cell.row}:${cell.column}': cell,
    };
    final value = <String>[
      for (var row = range.startRow; row <= range.endRow; row++)
        <String>[
          for (
            var column = range.startColumn;
            column <= range.endColumn;
            column++
          )
            cells['$row:$column']?.value ?? '',
        ].join('\t'),
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم نسخ الخلايا المحددة.')));
    }
  }

  Future<void> _pasteSelection(
    SpreadsheetSnapshot snapshot,
    SpreadsheetRange viewport,
  ) async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboard?.text;
    if (text == null || text.isEmpty) return;
    if (!mounted) return;
    final origin = _activeRange(snapshot);
    final rows = text.replaceAll('\r\n', '\n').split('\n');
    final cells = <SpreadsheetCell>[];
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final values = rows[rowIndex].split('\t');
      for (var columnIndex = 0; columnIndex < values.length; columnIndex++) {
        if (cells.length >= 500) break;
        cells.add(
          SpreadsheetCell(
            row: origin.startRow + rowIndex,
            column: origin.startColumn + columnIndex,
            value: values[columnIndex],
          ),
        );
      }
      if (cells.length >= 500) break;
    }
    if (cells.isNotEmpty) {
      context.read<WorkspaceSheetCubit>().applyCells(cells);
      context.read<WorkspaceSheetSyncCubit>().saveCells(
        resourceId: widget.resourceId,
        tabName: snapshot.tabName,
        viewport: viewport,
        version: snapshot.version,
        cells: cells,
      );
    }
  }

  KeyEventResult _handleGridKey(
    KeyEvent event,
    SpreadsheetSnapshot snapshot,
    SpreadsheetRange viewport,
  ) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final command =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (command && event.logicalKey == LogicalKeyboardKey.keyC) {
      unawaited(_copySelection(snapshot));
      return KeyEventResult.handled;
    }
    if (command && event.logicalKey == LogicalKeyboardKey.keyV) {
      unawaited(_pasteSelection(snapshot, viewport));
      return KeyEventResult.handled;
    }
    if (command &&
        (event.logicalKey == LogicalKeyboardKey.keyY ||
            (event.logicalKey == LogicalKeyboardKey.keyZ &&
                HardwareKeyboard.instance.isShiftPressed))) {
      _restoreHistory(snapshot, viewport, redo: true);
      return KeyEventResult.handled;
    }
    if (command && event.logicalKey == LogicalKeyboardKey.keyZ) {
      _restoreHistory(snapshot, viewport, redo: false);
      return KeyEventResult.handled;
    }
    final delta = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => (-1, 0),
      LogicalKeyboardKey.arrowDown => (1, 0),
      LogicalKeyboardKey.arrowLeft => (0, -1),
      LogicalKeyboardKey.arrowRight => (0, 1),
      _ => null,
    };
    if (delta == null) return KeyEventResult.ignored;
    _moveSelection(snapshot, delta.$1, delta.$2);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: const <ShortcutActivator, Intent>{
      SingleActivator(LogicalKeyboardKey.keyF, control: true): _FindIntent(),
      SingleActivator(LogicalKeyboardKey.keyF, meta: true): _FindIntent(),
    },
    child: Actions(
      actions: <Type, Action<Intent>>{
        _FindIntent: CallbackAction<_FindIntent>(
          onInvoke: (_) {
            _openFind();
            return null;
          },
        ),
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('محرر الجداول'),
          actions: [
            IconButton(
              tooltip: 'بحث (Ctrl/Cmd + F)',
              onPressed: _openFind,
              icon: const Icon(Icons.search),
            ),
            IconButton(
              tooltip: 'تحديث',
              onPressed: () => context.read<WorkspaceSheetCubit>().reload(),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: BlocListener<WorkspaceSheetSyncCubit, WorkspaceSheetSyncState>(
            listener: (context, state) {
              if (state is WorkspaceSheetSyncSaved) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(state.message)));
                context.read<WorkspaceSheetCubit>().scheduleRefresh();
              } else if (state is WorkspaceSheetSyncConflict) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => WorkspaceConflictPage(
                      message: state.message,
                      before: state.before,
                      current: state.current,
                      onReload: () {
                        Navigator.of(context).pop();
                        context.read<WorkspaceSheetCubit>().reload();
                      },
                      onRetry: () => Navigator.of(context).pop(),
                    ),
                  ),
                );
              } else if (state is WorkspaceSheetSyncPending ||
                  state is WorkspaceSheetSyncFailure) {
                final message = switch (state) {
                  WorkspaceSheetSyncPending(:final message) => message,
                  WorkspaceSheetSyncFailure(:final message) => message,
                  _ => '',
                };
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(message)));
              }
            },
            child: BlocBuilder<WorkspaceSheetCubit, WorkspaceSheetState>(
              builder: (context, state) => switch (state) {
                WorkspaceSheetLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
                WorkspaceSheetFailure(:final message) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(message),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () =>
                            context.read<WorkspaceSheetCubit>().load(
                              resourceId: widget.resourceId,
                              tabName: widget.initialTab,
                            ),
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
                WorkspaceSheetReady(:final snapshot, :final range) => Focus(
                  focusNode: _gridFocus,
                  onKeyEvent: (node, event) =>
                      _handleGridKey(event, snapshot, range),
                  child: Column(
                    children: [
                      BlocBuilder<
                        WorkspaceSheetSyncCubit,
                        WorkspaceSheetSyncState
                      >(
                        builder: (context, sync) => switch (sync) {
                          WorkspaceSheetSyncSaved(:final message) =>
                            WorkspaceSyncStatusBanner(
                              message: message,
                              kind: WorkspaceSyncStatusKind.saved,
                            ),
                          WorkspaceSheetSyncPending(:final message) =>
                            WorkspaceSyncStatusBanner(
                              message: message,
                              kind: WorkspaceSyncStatusKind.pending,
                              onAction: () =>
                                  context.read<WorkspaceSheetCubit>().reload(),
                            ),
                          WorkspaceSheetSyncConflict(:final message) =>
                            WorkspaceSyncStatusBanner(
                              message: message,
                              kind: WorkspaceSyncStatusKind.conflict,
                              onAction: () =>
                                  context.read<WorkspaceSheetCubit>().reload(),
                              actionLabel: 'تحديث الورقة',
                            ),
                          WorkspaceSheetSyncFailure(:final message) =>
                            WorkspaceSyncStatusBanner(
                              message: message,
                              kind: WorkspaceSyncStatusKind.failure,
                              onAction: () =>
                                  context.read<WorkspaceSheetCubit>().reload(),
                            ),
                          _ => const SizedBox.shrink(),
                        },
                      ),
                      if (_showFind)
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            12,
                            8,
                            12,
                            0,
                          ),
                          child: TextField(
                            controller: _findController,
                            focusNode: _findFocus,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: 'بحث داخل الورقة',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: IconButton(
                                tooltip: 'إغلاق البحث',
                                onPressed: () => setState(() {
                                  _showFind = false;
                                  _findController.clear();
                                }),
                                icon: const Icon(Icons.close),
                              ),
                            ),
                          ),
                        ),
                      _SheetToolbar(
                        enabled:
                            snapshot.canEdit &&
                            snapshot.compatibility ==
                                SpreadsheetCompatibility.fullyEditable,
                        onAddRow: () => _submitAction(
                          snapshot,
                          range,
                          kind: WorkspaceOperationKind.sheetStructure,
                          payload: {
                            'operation': 'insert_row',
                            'index': _activeRange(snapshot).startRow,
                          },
                        ),
                        onAddColumn: () => _submitAction(
                          snapshot,
                          range,
                          kind: WorkspaceOperationKind.sheetStructure,
                          payload: {
                            'operation': 'insert_column',
                            'index': _activeRange(snapshot).startColumn,
                          },
                        ),
                        onDeleteRow: () => _submitAction(
                          snapshot,
                          range,
                          kind: WorkspaceOperationKind.sheetStructure,
                          payload: {
                            'operation': 'delete_row',
                            'index': _activeRange(snapshot).startRow,
                          },
                        ),
                        onDeleteColumn: () => _submitAction(
                          snapshot,
                          range,
                          kind: WorkspaceOperationKind.sheetStructure,
                          payload: {
                            'operation': 'delete_column',
                            'index': _activeRange(snapshot).startColumn,
                          },
                        ),
                        onToggleBold: () => _submitAction(
                          snapshot,
                          range,
                          kind: WorkspaceOperationKind.sheetFormat,
                          payload: _rangePayload(_activeRange(snapshot), {
                            'bold': true,
                          }),
                        ),
                        onToggleItalic: () => _submitAction(
                          snapshot,
                          range,
                          kind: WorkspaceOperationKind.sheetFormat,
                          payload: _rangePayload(_activeRange(snapshot), {
                            'italic': true,
                          }),
                        ),
                        onColorSelected: (color) => _submitAction(
                          snapshot,
                          range,
                          kind: WorkspaceOperationKind.sheetFormat,
                          payload: _rangePayload(_activeRange(snapshot), {
                            'backgroundColor': color,
                          }),
                        ),
                        onTextColorSelected: (color) => _submitAction(
                          snapshot,
                          range,
                          kind: WorkspaceOperationKind.sheetFormat,
                          payload: _rangePayload(_activeRange(snapshot), {
                            'textColor': color,
                          }),
                        ),
                        onAlignmentSelected: (alignment) => _submitAction(
                          snapshot,
                          range,
                          kind: WorkspaceOperationKind.sheetFormat,
                          payload: _rangePayload(_activeRange(snapshot), {
                            'horizontalAlignment': alignment,
                          }),
                        ),
                        onWrap: () => _submitAction(
                          snapshot,
                          range,
                          kind: WorkspaceOperationKind.sheetFormat,
                          payload: _rangePayload(_activeRange(snapshot), {
                            'wrapStrategy': 'WRAP',
                          }),
                        ),
                        onFilter: () => _submitAction(
                          snapshot,
                          range,
                          kind: WorkspaceOperationKind.sheetStructure,
                          payload: _rangePayload(_activeRange(snapshot), {
                            'operation': 'set_filter',
                          }),
                        ),
                        onClearFilter: () => _submitAction(
                          snapshot,
                          range,
                          kind: WorkspaceOperationKind.sheetStructure,
                          payload: _rangePayload(_activeRange(snapshot), {
                            'operation': 'clear_filter',
                          }),
                        ),
                        onSort: (descending) => _submitAction(
                          snapshot,
                          range,
                          kind: WorkspaceOperationKind.sheetStructure,
                          payload: _rangePayload(_activeRange(snapshot), {
                            'operation': 'sort_range',
                            'sortColumn':
                                _activeRange(snapshot).startColumn,
                            'descending': descending,
                          }),
                        ),
                        onClearFormatting: () => _submitAction(
                          snapshot,
                          range,
                          kind: WorkspaceOperationKind.sheetFormat,
                          payload: _rangePayload(_activeRange(snapshot), {
                            'clearFormatting': true,
                          }),
                        ),
                        onCheckbox: () => _submitAction(
                          snapshot,
                          range,
                          kind: WorkspaceOperationKind.sheetFormat,
                          payload: _rangePayload(_activeRange(snapshot), {
                            'checkbox': true,
                          }),
                        ),
                        onAddTab: () => _addTab(snapshot, range),
                        onAddDropdown: () => _addDropdown(snapshot, range),
                      ),
                      _FormulaBar(
                        controller: _controller,
                        coordinate: _selected == null
                            ? ''
                            : '${_columnName(_selected!.column)}${_selected!.row}',
                        enabled:
                            snapshot.canEdit &&
                            snapshot.compatibility ==
                                SpreadsheetCompatibility.fullyEditable,
                        onSubmitted: (_) => _save(snapshot, range),
                      ),
                      _SheetTabs(
                        tabs: snapshot.tabs,
                        active: snapshot.tabName,
                        onSelected: (tab) =>
                            context.read<WorkspaceSheetCubit>().openTab(tab),
                      ),
                      Expanded(
                        child: _SpreadsheetGrid(
                          snapshot: snapshot,
                          range: range,
                          selected: _selected,
                          selectedRange: _selectedRange,
                          onSelected: _select,
                          onSelectedRange: _selectRange,
                          onEdited: (cell, value) {
                            _select(cell);
                            _saveCell(snapshot, range, cell, value);
                          },
                          findQuery: _findController.text,
                        ),
                      ),
                      WorkspaceSheetStatusBar(canEdit: snapshot.canEdit),
                    ],
                  ),
                ),
              },
            ),
          ),
        ),
      ),
    ),
  );
}

class _FindIntent extends Intent {
  const _FindIntent();
}

Map<String, Object?> _rangePayload(
  SpreadsheetRange range,
  Map<String, Object?> values,
) => <String, Object?>{
  'startRow': range.startRow,
  'endRow': range.endRow,
  'startColumn': range.startColumn,
  'endColumn': range.endColumn,
  ...values,
};

class _SheetToolbar extends StatelessWidget {
  const _SheetToolbar({
    required this.enabled,
    required this.onAddRow,
    required this.onAddColumn,
    required this.onDeleteRow,
    required this.onDeleteColumn,
    required this.onToggleBold,
    required this.onToggleItalic,
    required this.onColorSelected,
    required this.onTextColorSelected,
    required this.onAlignmentSelected,
    required this.onWrap,
    required this.onFilter,
    required this.onClearFilter,
    required this.onSort,
    required this.onClearFormatting,
    required this.onCheckbox,
    required this.onAddTab,
    required this.onAddDropdown,
  });
  final bool enabled;
  final VoidCallback onAddRow;
  final VoidCallback onAddColumn;
  final VoidCallback onDeleteRow;
  final VoidCallback onDeleteColumn;
  final VoidCallback onToggleBold;
  final VoidCallback onToggleItalic;
  final ValueChanged<String> onColorSelected;
  final ValueChanged<String> onTextColorSelected;
  final ValueChanged<String> onAlignmentSelected;
  final VoidCallback onWrap;
  final VoidCallback onFilter;
  final VoidCallback onClearFilter;
  final ValueChanged<bool> onSort;
  final VoidCallback onClearFormatting;
  final VoidCallback onCheckbox;
  final VoidCallback onAddTab;
  final VoidCallback onAddDropdown;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      children: [
        IconButton(
          onPressed: enabled ? onAddRow : null,
          tooltip: 'إضافة صف',
          icon: const Icon(Icons.table_rows),
        ),
        IconButton(
          onPressed: enabled ? onAddColumn : null,
          tooltip: 'إضافة عمود',
          icon: const Icon(Icons.view_column_outlined),
        ),
        IconButton(
          onPressed: enabled ? onDeleteRow : null,
          tooltip: 'حذف الصف المحدد',
          icon: const Icon(Icons.delete_sweep_outlined),
        ),
        IconButton(
          onPressed: enabled ? onDeleteColumn : null,
          tooltip: 'حذف العمود المحدد',
          icon: const Icon(Icons.delete_outline),
        ),
        IconButton(
          onPressed: enabled ? onToggleBold : null,
          tooltip: 'غامق',
          icon: const Icon(Icons.format_bold),
        ),
        IconButton(
          onPressed: enabled ? onToggleItalic : null,
          tooltip: 'مائل',
          icon: const Icon(Icons.format_italic),
        ),
        for (final color in const <String>[
          '#FFE082',
          '#F8BBD0',
          '#BBDEFB',
          '#C8E6C9',
        ])
          Tooltip(
            message: 'لون الخلية',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 3),
              child: InkWell(
                onTap: enabled ? () => onColorSelected(color) : null,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 28,
                  decoration: BoxDecoration(
                    color: Color(
                      int.parse('FF${color.substring(1)}', radix: 16),
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black26),
                  ),
                ),
              ),
            ),
          ),
        PopupMenuButton<String>(
          enabled: enabled,
          tooltip: 'لون النص',
          icon: const Icon(Icons.format_color_text),
          onSelected: onTextColorSelected,
          itemBuilder: (context) => const [
            PopupMenuItem(value: '#111827', child: Text('أسود')),
            PopupMenuItem(value: '#B91C1C', child: Text('أحمر')),
            PopupMenuItem(value: '#1D4ED8', child: Text('أزرق')),
            PopupMenuItem(value: '#15803D', child: Text('أخضر')),
          ],
        ),
        PopupMenuButton<String>(
          enabled: enabled,
          tooltip: 'محاذاة النص',
          icon: const Icon(Icons.format_align_center),
          onSelected: onAlignmentSelected,
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'LEFT', child: Text('محاذاة لليسار')),
            PopupMenuItem(value: 'CENTER', child: Text('محاذاة للوسط')),
            PopupMenuItem(value: 'RIGHT', child: Text('محاذاة لليمين')),
          ],
        ),
        IconButton(
          onPressed: enabled ? onWrap : null,
          tooltip: 'التفاف النص',
          icon: const Icon(Icons.wrap_text),
        ),
        IconButton(
          onPressed: enabled ? onFilter : null,
          tooltip: 'تصفية النطاق المحدد',
          icon: const Icon(Icons.filter_alt_outlined),
        ),
        PopupMenuButton<bool>(
          enabled: enabled,
          tooltip: 'فرز النطاق المحدد',
          icon: const Icon(Icons.sort),
          onSelected: onSort,
          itemBuilder: (context) => const [
            PopupMenuItem(value: false, child: Text('فرز تصاعدي')),
            PopupMenuItem(value: true, child: Text('فرز تنازلي')),
          ],
        ),
        IconButton(
          onPressed: enabled ? onClearFilter : null,
          tooltip: 'إزالة التصفية',
          icon: const Icon(Icons.filter_alt_off_outlined),
        ),
        IconButton(
          onPressed: enabled ? onClearFormatting : null,
          tooltip: 'إزالة التنسيق',
          icon: const Icon(Icons.format_clear),
        ),
        IconButton(
          onPressed: enabled ? onCheckbox : null,
          tooltip: 'خانة اختيار',
          icon: const Icon(Icons.check_box_outlined),
        ),
        IconButton(
          onPressed: enabled ? onAddDropdown : null,
          tooltip: 'قائمة اختيار',
          icon: const Icon(Icons.arrow_drop_down_circle_outlined),
        ),
        IconButton(
          onPressed: enabled ? onAddTab : null,
          tooltip: 'إضافة ورقة',
          icon: const Icon(Icons.add_to_photos_outlined),
        ),
      ],
    ),
  );
}

class _FormulaBar extends StatelessWidget {
  const _FormulaBar({
    required this.controller,
    required this.coordinate,
    required this.enabled,
    required this.onSubmitted,
  });
  final TextEditingController controller;
  final String coordinate;
  final bool enabled;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(coordinate, textDirection: TextDirection.ltr),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('fx'),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            enabled: enabled,
            onSubmitted: onSubmitted,
            decoration: const InputDecoration(
              hintText: 'اكتب قيمة أو معادلة',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SheetTabs extends StatelessWidget {
  const _SheetTabs({
    required this.tabs,
    required this.active,
    required this.onSelected,
  });
  final List<String> tabs;
  final String active;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: tabs.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) => ChoiceChip(
        label: Text(tabs[index]),
        selected: tabs[index] == active,
        onSelected: (_) => onSelected(tabs[index]),
      ),
    ),
  );
}

class _SpreadsheetGrid extends StatelessWidget {
  const _SpreadsheetGrid({
    required this.snapshot,
    required this.range,
    required this.selected,
    required this.selectedRange,
    required this.onSelected,
    required this.onSelectedRange,
    required this.onEdited,
    required this.findQuery,
  });
  final SpreadsheetSnapshot snapshot;
  final SpreadsheetRange range;
  final SpreadsheetCell? selected;
  final SpreadsheetRange? selectedRange;
  final ValueChanged<SpreadsheetCell> onSelected;
  final ValueChanged<SpreadsheetRange> onSelectedRange;
  final void Function(SpreadsheetCell cell, String value) onEdited;
  final String findQuery;

  @override
  Widget build(BuildContext context) {
    final headers = List<String>.generate(
      range.endColumn - range.startColumn + 1,
      (index) => index < snapshot.headers.length
          ? snapshot.headers[index]
          : _columnName(range.startColumn + index),
    );
    final byCoordinate = <String, SpreadsheetCell>{
      for (final cell in snapshot.cells) '${cell.row}:${cell.column}': cell,
    };
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: (headers.length * 150).toDouble() + 64,
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              child: Table(
                defaultColumnWidth: const FixedColumnWidth(150),
                border: TableBorder.all(color: Theme.of(context).dividerColor),
                children: [
                  TableRow(
                    children: [
                      const SizedBox(
                        height: 48,
                        child: Center(child: Text('#')),
                      ),
                      ...headers.asMap().entries.map(
                        (entry) => InkWell(
                          onTap: () => onSelectedRange(
                            SpreadsheetRange(
                              tabName: snapshot.tabName,
                              startRow: range.startRow,
                              endRow: range.endRow,
                              startColumn: range.startColumn + entry.key,
                              endColumn: range.startColumn + entry.key,
                            ),
                          ),
                          child: SizedBox(
                            height: 48,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                entry.value,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  for (var row = range.startRow; row <= range.endRow; row++)
                    TableRow(
                      children: [
                        InkWell(
                          onTap: () => onSelectedRange(
                            SpreadsheetRange(
                              tabName: snapshot.tabName,
                              startRow: row,
                              endRow: row,
                              startColumn: range.startColumn,
                              endColumn: range.endColumn,
                            ),
                          ),
                          child: SizedBox(
                            height: 42,
                            child: Center(child: Text('$row')),
                          ),
                        ),
                        for (
                          var column = range.startColumn;
                          column <= range.endColumn;
                          column++
                        )
                          _GridCell(
                            cell:
                                byCoordinate['$row:$column'] ??
                                SpreadsheetCell(
                                  row: row,
                                  column: column,
                                  value: '',
                                ),
                            selected:
                                _isSelected(
                                  selectedRange,
                                  row: row,
                                  column: column,
                                ) ||
                                (selectedRange == null &&
                                    selected?.row == row &&
                                    selected?.column == column),
                            onTap: onSelected,
                            onEdited: onEdited,
                            matchesFind:
                                findQuery.trim().isNotEmpty &&
                                (byCoordinate['$row:$column']?.formattedValue ??
                                        byCoordinate['$row:$column']?.value ??
                                        '')
                                    .toLowerCase()
                                    .contains(findQuery.trim().toLowerCase()),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool _isSelected(
  SpreadsheetRange? range, {
  required int row,
  required int column,
}) =>
    range != null &&
    row >= range.startRow &&
    row <= range.endRow &&
    column >= range.startColumn &&
    column <= range.endColumn;

class _GridCell extends StatefulWidget {
  const _GridCell({
    required this.cell,
    required this.selected,
    required this.onTap,
    required this.onEdited,
    required this.matchesFind,
  });
  final SpreadsheetCell cell;
  final bool selected;
  final ValueChanged<SpreadsheetCell> onTap;
  final void Function(SpreadsheetCell cell, String value) onEdited;
  final bool matchesFind;

  @override
  State<_GridCell> createState() => _GridCellState();
}

class _GridCellState extends State<_GridCell> {
  bool _editing = false;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.cell.value);
  }

  @override
  void didUpdateWidget(covariant _GridCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.cell.value != widget.cell.value) {
      _controller.text = widget.cell.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit(String value) {
    setState(() => _editing = false);
    widget.onEdited(widget.cell, value);
  }

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => widget.onTap(widget.cell),
    onDoubleTap: () => setState(() => _editing = true),
    child: Container(
      height: 42,
      color: widget.selected
          ? Theme.of(context).colorScheme.primaryContainer
          : widget.matchesFind
          ? Theme.of(context).colorScheme.tertiaryContainer
          : null,
      padding: const EdgeInsets.all(4),
      alignment: AlignmentDirectional.centerStart,
      child: _editing
          ? TextField(
              controller: _controller,
              autofocus: true,
              onSubmitted: _commit,
              onEditingComplete: () => _commit(_controller.text),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
              ),
            )
          : Text(
              widget.cell.formattedValue ?? widget.cell.value,
              overflow: TextOverflow.ellipsis,
            ),
    ),
  );
}

class _CellChange {
  const _CellChange(this.row, this.column, this.before, this.after);
  final int row;
  final int column;
  final String before;
  final String after;
}

String _columnName(int index) {
  var value = index;
  var result = '';
  while (value > 0) {
    value -= 1;
    result = String.fromCharCode(65 + value % 26) + result;
    value ~/= 26;
  }
  return result;
}
