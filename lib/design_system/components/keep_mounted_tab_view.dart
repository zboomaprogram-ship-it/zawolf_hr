import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A tab child wrapper that keeps the child mounted once visited,
/// avoiding redundant teardown, state loss, and network refetches when
/// toggling between tabs (Task C013).
class KeepMountedTabItem extends StatefulWidget {
  const KeepMountedTabItem({
    required this.builder,
    this.rebuildOnUpdate = false,
    super.key,
  });

  /// Builder invoked lazily when the tab is first navigated into.
  final WidgetBuilder builder;

  /// Whether changes to the parent widget should invalidate the cached child
  /// (e.g. when search filters, dates, or pagination change).
  final bool rebuildOnUpdate;

  @override
  State<KeepMountedTabItem> createState() => _KeepMountedTabItemState();
}

class _KeepMountedTabItemState extends State<KeepMountedTabItem>
    with AutomaticKeepAliveClientMixin {
  Widget? _cachedChild;

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(covariant KeepMountedTabItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rebuildOnUpdate) {
      _cachedChild = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _cachedChild ??= widget.builder(context);
    return _cachedChild!;
  }
}

/// A TabBarView alternative that lazily builds tabs and keeps them alive
/// once built, satisfying the AGENTS.md shared component rule.
class KeepMountedTabBarView extends StatelessWidget {
  const KeepMountedTabBarView({
    required this.builders,
    this.controller,
    this.physics,
    this.dragStartBehavior = DragStartBehavior.start,
    super.key,
  });

  final List<WidgetBuilder> builders;
  final TabController? controller;
  final ScrollPhysics? physics;
  final DragStartBehavior dragStartBehavior;

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      controller: controller,
      physics: physics,
      dragStartBehavior: dragStartBehavior,
      children: [
        for (final builder in builders)
          KeepMountedTabItem(builder: builder),
      ],
    );
  }
}
