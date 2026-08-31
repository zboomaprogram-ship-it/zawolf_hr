import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zawolf_hr/design_system/components/data_presentations.dart';

AppRow _row(String id) => AppRow(
      id: id,
      title: 'موظف $id',
      leading: Icons.beach_access_outlined,
      cells: ['إجازة', '2026-01-01 → 2026-01-03', 'بانتظار المدير'],
    );

const _columns = [
  AppColumn('الموظف'),
  AppColumn('النوع'),
  AppColumn('الفترة'),
  AppColumn('المرحلة'),
];

Widget _detail(AppRow row) => Text('تفاصيل ${row.title}', key: ValueKey(row.id));

Future<void> _pump(
  WidgetTester tester,
  Size size, {
  String? initiallySelectedId,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DsMasterDetailView(
          columns: _columns,
          rows: [_row('a'), _row('b')],
          detailBuilder: _detail,
          emptyDetailLabel: 'اختر طلباً',
          initiallySelectedId: initiallySelectedId,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('wide layout shows table with side detail panel',
      (tester) async {
    await _pump(tester, const Size(1440, 900), initiallySelectedId: 'a');
    expect(find.byType(AppDataTable), findsOneWidget);
    expect(find.text('تفاصيل موظف a'), findsOneWidget);
    expect(find.text('اختر طلباً'), findsNothing);
  });

  testWidgets('wide layout shows empty hint when nothing is selected',
      (tester) async {
    await _pump(tester, const Size(1440, 900));
    expect(find.byType(AppDataTable), findsOneWidget);
    expect(find.text('اختر طلباً'), findsOneWidget);
  });

  testWidgets('narrow layout renders list tiles instead of the grid',
      (tester) async {
    await _pump(tester, const Size(480, 900));
    expect(find.byType(AppListTile), findsNWidgets(2));
    expect(find.byType(AppDataTable), findsNothing);
    expect(find.text('اختر طلباً'), findsNothing);
  });

  testWidgets('selection clears when its row disappears', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    var rows = [_row('a'), _row('b')];
    late StateSetter setter;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setter = setState;
              return DsMasterDetailView(
                columns: _columns,
                rows: rows,
                detailBuilder: _detail,
                initiallySelectedId: 'a',
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('تفاصيل موظف a'), findsOneWidget);

    setter(() => rows = [_row('b')]);
    await tester.pumpAndSettle();
    expect(find.text('تفاصيل موظف a'), findsNothing);
    expect(find.text('اختر عنصراً لعرض التفاصيل'), findsOneWidget);
  });
}
