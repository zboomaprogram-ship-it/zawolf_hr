import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../../theme/theme.dart';
import '../tokens.dart';
import 'rtl_navigation.dart';

/// One row model shared by both presentations so data code never branches on
/// platform. [leading] is an icon; cells render text right-to-left by default.
class AppRow {
  const AppRow({
    required this.id,
    required this.title,
    required this.cells,
    this.leading,
    this.accentColor,
    this.onTap,
  });

  final String id;
  final String title;

  /// Column values in order, matching the columns passed to [AppDataTable].
  /// First cell may be hidden on mobile presentation.
  final List<String> cells;
  final IconData? leading;
  final Color? accentColor;
  final VoidCallback? onTap;
}

/// Column definition shared across presentations.
class AppColumn {
  const AppColumn(this.title, {this.width, this.numeric = false});

  final String title;
  final double? width;
  final bool numeric;
}

/// Mobile/narrow presentation of an [AppRow]: card with title row + cell
/// key/value lines. Used below the 980px breakpoint.
class AppListTile extends StatelessWidget {
  const AppListTile({
    required this.row,
    required this.columns,
    this.trailing,
    super.key,
  });

  final AppRow row;
  final List<AppColumn> columns;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final details = <Widget>[];
    for (var i = 1; i < row.cells.length && i < columns.length; i++) {
      if (row.cells[i].isEmpty) continue;
      details.add(
        Padding(
          padding: const EdgeInsets.only(top: DsSpacing.xs),
          child: Row(
            children: [
              Text(
                columns[i].title,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  row.cells[i],
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.start,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.md),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: row.onTap,
          borderRadius: DsRadius.cardBorder,
          child: Container(
            padding: const EdgeInsets.all(DsSpacing.lg),
            decoration: BoxDecoration(
              color: ZaWolfColors.surface01,
              borderRadius: DsRadius.cardBorder,
              border: Border.all(color: ZaWolfColors.surface03),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (row.leading != null) ...[
                      Icon(
                        row.leading,
                        size: 20,
                        color: row.accentColor ?? ZaWolfColors.primaryCyan,
                      ),
                      const SizedBox(width: DsSpacing.md),
                    ],
                    Expanded(
                      child: Text(
                        row.title,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
                if (details.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: DsSpacing.sm),
                    child: Column(children: details),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Desktop/wide presentation (>=980px): pre-themed PlutoGrid over the same
/// [AppRow]/[AppColumn] models. Wrap in a bounded-height container.
class AppDataTable extends StatelessWidget {
  const AppDataTable({
    required this.columns,
    required this.rows,
    this.onRowTap,
    super.key,
  });

  final List<AppColumn> columns;
  final List<AppRow> rows;
  final ValueChanged<AppRow>? onRowTap;

  List<PlutoColumn> get _plutoColumns => [
        for (final column in columns)
          PlutoColumn(
            title: column.title,
            field: column.title,
            type: PlutoColumnType.text(),
            width: column.width ?? 160,
            textAlign:
                column.numeric ? PlutoColumnTextAlign.right : PlutoColumnTextAlign.start,
            titleTextAlign:
                column.numeric ? PlutoColumnTextAlign.right : PlutoColumnTextAlign.start,
          ),
      ];

  List<PlutoRow> get _plutoRows => [
        for (final row in rows)
          PlutoRow(cells: {
            for (var i = 0; i < columns.length; i++)
              columns[i].title:
                  PlutoCell(value: i < row.cells.length ? row.cells[i] : ''),
          }),
      ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: DsRadius.cardBorder,
        border: Border.all(color: ZaWolfColors.surface03),
      ),
      clipBehavior: Clip.antiAlias,
      child: PlutoGrid(
        columns: _plutoColumns,
        rows: _plutoRows,
        configuration: const PlutoGridConfiguration(
          style: PlutoGridStyleConfig(
            gridBackgroundColor: ZaWolfColors.surface01,
            rowColor: ZaWolfColors.surface01,
            oddRowColor: ZaWolfColors.surface02,
            activatedColor: ZaWolfColors.surface03,
            borderColor: ZaWolfColors.surface02,
            gridBorderColor: ZaWolfColors.surface03,
            cellColorInEditState: ZaWolfColors.surface02,
            cellTextStyle: TextStyle(
              color: ZaWolfColors.textPrimary,
              fontSize: DsType.secondary,
            ),
          ),
        ),
        onLoaded: (event) {},
        onRowDoubleTap: (event) {
          final index = event.rowIdx;
          if (onRowTap != null && index >= 0 && index < rows.length) {
            onRowTap!(rows[index]);
          }
        },
      ),
    );
  }
}

/// Responsive list/table presentation for request management surfaces
/// (specs/ui_redesign/06 R2): at >=980px renders [AppDataTable] beside a side
/// detail panel opened by row double-tap; below that renders [AppListTile]s
/// whose tap opens the same detail full-screen.
class DsMasterDetailView extends StatefulWidget {
  const DsMasterDetailView({
    required this.columns,
    required this.rows,
    required this.detailBuilder,
    this.emptyDetailLabel = 'اختر عنصراً لعرض التفاصيل',
    this.initiallySelectedId,
    super.key,
  });

  final List<AppColumn> columns;
  final List<AppRow> rows;
  final Widget Function(AppRow row) detailBuilder;
  final String emptyDetailLabel;

  /// Row id shown in the side panel before any user selection.
  final String? initiallySelectedId;

  @override
  State<DsMasterDetailView> createState() => _DsMasterDetailViewState();
}

class _DsMasterDetailViewState extends State<DsMasterDetailView> {
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initiallySelectedId;
  }

  @override
  void didUpdateWidget(covariant DsMasterDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedId != null &&
        !widget.rows.any((row) => row.id == _selectedId)) {
      _selectedId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;
    if (!wide) return _buildNarrow(context);
    return _buildWide(context);
  }

  Widget _detailFor(AppRow row) => widget.detailBuilder(row);

  Widget _buildWide(BuildContext context) {
    AppRow? selected;
    if (_selectedId != null) {
      for (final row in widget.rows) {
        if (row.id == _selectedId) {
          selected = row;
          break;
        }
      }
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.all(DsSpacing.lg),
            child: AppDataTable(
              columns: widget.columns,
              rows: widget.rows,
              onRowTap: (row) => setState(() => _selectedId = row.id),
            ),
          ),
        ),
        const VerticalDivider(width: 1, color: ZaWolfColors.surface03),
        Expanded(
          flex: 4,
          child: selected == null
              ? Center(
                  child: Text(
                    widget.emptyDetailLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ZaWolfColors.textMuted,
                        ),
                    textAlign: TextAlign.center,
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(DsSpacing.lg),
                  child: _detailFor(selected),
                ),
        ),
      ],
    );
  }

  Widget _buildNarrow(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.rows.length,
      itemBuilder: (context, index) {
        final row = widget.rows[index];
        return AppListTile(
          row: AppRow(
            id: row.id,
            title: row.title,
            cells: row.cells,
            leading: row.leading,
            accentColor: row.accentColor,
            onTap: () => _openDetailPage(context, row),
          ),
          columns: widget.columns,
          trailing: Icon(RtlNavigation.chevronEnd(context), size: 18),
        );
      },
    );
  }

  void _openDetailPage(BuildContext context, AppRow row) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (routeContext) => Scaffold(
          appBar: AppBar(title: Text(row.title)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _detailFor(row),
          ),
        ),
      ),
    );
  }
}
