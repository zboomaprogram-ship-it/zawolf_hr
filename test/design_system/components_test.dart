import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/design_system/components/badge.dart';
import 'package:zawolf_hr/design_system/components/feedback_states.dart';
import 'package:zawolf_hr/design_system/components/filter_bar.dart';
import 'package:zawolf_hr/design_system/components/priority_strip.dart';
import 'package:zawolf_hr/design_system/components/section_header.dart';
import 'package:zawolf_hr/design_system/components/skeletons.dart';
import 'package:zawolf_hr/design_system/components/stat_card.dart';
import 'package:zawolf_hr/design_system/components/status_pill.dart';
import 'package:zawolf_hr/design_system/tokens.dart';
import 'package:zawolf_hr/theme/theme.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ZaWolfTheme.darkTheme,
      home: Scaffold(body: child),
    );

void main() {
  group('StatusPill', () {
    testWidgets('renders label and dot with mapped color', (tester) async {
      await tester.pumpWidget(_wrap(const StatusPill(
        status: DsStatus.approved,
        label: 'موافق عليه',
      )));
      expect(find.text('موافق عليه'), findsOneWidget);
    });
  });

  group('DsBadge', () {
    testWidgets('hidden at zero, shows count otherwise', (tester) async {
      await tester.pumpWidget(_wrap(const Column(children: [DsBadge(count: 0)])));
      expect(find.byType(DsBadge), findsOneWidget);
      expect(find.text('0'), findsNothing);

      await tester.pumpWidget(_wrap(const Column(children: [DsBadge(count: 7)])));
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('caps display at 99+', (tester) async {
      await tester
          .pumpWidget(_wrap(const Column(children: [DsBadge(count: 120)])));
      expect(find.text('99+'), findsOneWidget);
    });
  });

  group('PriorityStrip', () {
    testWidgets('hidden when no item qualifies', (tester) async {
      await tester.pumpWidget(_wrap(PriorityStrip(items: [
        PriorityItem(
            label: 'مخفي', count: 0, icon: Icons.info_outline, onTap: null),
        PriorityItem(
            label: 'بلا هدف',
            count: 4,
            icon: Icons.info_outline,
            onTap: null),
      ])));
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('shows qualifying items and fires tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(PriorityStrip(items: [
        PriorityItem(
          label: 'طلبات معلقة',
          count: 3,
          icon: Icons.approval_outlined,
          onTap: () => tapped = true,
        ),
      ])));
      expect(find.textContaining('3'), findsOneWidget);
      await tester.tap(find.byType(InkWell));
      expect(tapped, isTrue);
    });
  });

  group('FilterBar', () {
    testWidgets('reports selected chip id', (tester) async {
      String? selected;
      await tester.pumpWidget(_wrap(FilterBar(
        selectedId: 'all',
        onSelected: (id) => selected = id,
        chips: const [
          FilterChipItem(id: 'all', label: 'الكل'),
          FilterChipItem(id: 'pending', label: 'معلق', count: 2),
        ],
      )));
      await tester.tap(find.text('معلق'));
      expect(selected, 'pending');
    });
  });

  group('Feedback states', () {
    testWidgets('ErrorState retry callback fires', (tester) async {
      var retried = false;
      await tester.pumpWidget(_wrap(ErrorState(onRetry: () => retried = true)));
      await tester.tap(find.text('إعادة المحاولة'));
      expect(retried, isTrue);
    });

    testWidgets('SkeletonList renders requested item count',
        (tester) async {
      await tester.pumpWidget(
          _wrap(const SkeletonList(itemCount: 3)));
      expect(find.byType(SkeletonCard), findsNWidgets(3));
    });
  });

  group('StatCard', () {
    testWidgets('tap fires navigation callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(StatCard(
        icon: Icons.people_alt_outlined,
        value: '12',
        label: 'الموظفون',
        onTap: () => tapped = true,
      )));
      await tester.tap(find.text('الموظفون'));
      expect(tapped, isTrue);
    });

    testWidgets('without onTap renders inert card', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const StatCard(
            icon: Icons.people_alt_outlined,
            value: '0',
            label: 'x',
          ),
        ),
      );
      expect(find.byType(InkWell), findsNothing);
    });
  });

  group('SectionHeader', () {
    testWidgets('عرض الكل action fires callback when provided',
        (tester) async {
      var actionFired = false;
      await tester.pumpWidget(_wrap(SectionHeader(
        title: 'إجراءات الفريق',
        actionLabel: 'عرض الكل',
        onAction: () => actionFired = true,
      )));
      await tester.tap(find.text('عرض الكل'));
      expect(actionFired, isTrue);
    });

    testWidgets('hides action when onAction missing', (tester) async {
      await tester.pumpWidget(_wrap(const SectionHeader(title: 'عنوان')));
      expect(find.text('عرض الكل'), findsNothing);
    });
  });
}
