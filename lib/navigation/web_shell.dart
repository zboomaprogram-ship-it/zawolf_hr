import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/employee_role.dart';
import '../models/user_model.dart';
import '../design_system/tokens.dart';
import '../design_system/components/app_logo.dart';
import '../design_system/components/badge.dart';
import '../theme/theme.dart';
import '../features/conversations/presentation/widgets/web_chat_notification_overlay.dart';
import '../services/notification_service.dart';
import 'nav_config.dart';

/// Desktop web shell for management roles (width >= 980).
///
/// Grouped, collapsible domain sidebar + top bar with search entry,
/// notifications bell, and profile menu. Preserves the legacy shell's
/// constructor contract so NavigationWrapper can swap implementations.
/// Specs: specs/ui_redesign/02_navigation_ia_spec.md
class WebManagementShell extends StatefulWidget {
  final UserModel user;
  final List<NavigationItem> items;
  final String matchedLocation;
  final Widget child;
  final bool canGoBack;
  final VoidCallback onBack;
  final Future<void> Function() onSignOut;

  const WebManagementShell({
    super.key,
    required this.user,
    required this.items,
    required this.matchedLocation,
    required this.child,
    required this.canGoBack,
    required this.onBack,
    required this.onSignOut,
  });

  @override
  State<WebManagementShell> createState() => _WebManagementShellState();
}

class _WebManagementShellState extends State<WebManagementShell> {
  String _query = '';
  final Set<NavDomain> _collapsed = <NavDomain>{};
  bool _sidebarCollapsed = false;

  bool _isSelected(NavigationItem item) {
    return widget.matchedLocation == item.path ||
        widget.matchedLocation.startsWith('${item.path}/');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _query.trim();
    final filtered =
        query.isEmpty
            ? widget.items
            : widget.items
                .where(
                  (item) =>
                      item.label.contains(query) ||
                      item.englishLabel.toLowerCase().contains(
                        query.toLowerCase(),
                      ),
                )
                .toList();
    final groups = groupNavItems(filtered);
    final unread = widget.user.unreadNotifications;
    final portalTitle =
        widget.user.role == EmployeeRole.employee
            ? 'بوابة الموظف'
            : 'مساحة الإدارة';

    return WebChatNotificationOverlay(
      notifications: NotificationService.instance,
      child: Scaffold(
        backgroundColor: ZaWolfColors.background,
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOutCubic,
                width: _sidebarCollapsed ? 76 : 278,
                child: ColoredBox(
                  color: ZaWolfColors.surface01,
                  child: SafeArea(
                    child:
                        _sidebarCollapsed
                            ? _buildCollapsedSidebar(
                              theme,
                              filtered,
                              portalTitle,
                            )
                            : _buildExpandedSidebar(theme, groups, portalTitle),
                  ),
                ),
              ),
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: ZaWolfColors.surface03,
              ),
              Expanded(
                child: ColoredBox(
                  color: ZaWolfColors.background,
                  child: Column(
                    children: [
                      Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(
                          horizontal: DsSpacing.lg,
                        ),
                        decoration: const BoxDecoration(
                          color: ZaWolfColors.surface01,
                          border: Border(
                            bottom: BorderSide(color: ZaWolfColors.surface03),
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed:
                                  () => setState(
                                    () =>
                                        _sidebarCollapsed = !_sidebarCollapsed,
                                  ),
                              tooltip:
                                  _sidebarCollapsed
                                      ? 'توسيع القائمة الجانبية'
                                      : 'تصغير القائمة الجانبية',
                              icon: Icon(
                                _sidebarCollapsed
                                    ? Icons.menu_open_rounded
                                    : Icons.menu_rounded,
                                color: ZaWolfColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: DsSpacing.xs),
                            IconButton(
                              onPressed:
                                  widget.canGoBack ? widget.onBack : null,
                              tooltip: 'رجوع',
                              icon: Directionality(
                                textDirection: TextDirection.ltr,
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  color:
                                      widget.canGoBack
                                          ? ZaWolfColors.textSecondary
                                          : ZaWolfColors.disabled,
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Notifications bell with unread badge
                            IconButton(
                              tooltip: 'الإشعارات',
                              onPressed: () => context.go('/notifications'),
                              icon:
                                  unread > 0
                                      ? Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          const Icon(
                                            Icons.notifications_outlined,
                                            color: ZaWolfColors.textSecondary,
                                          ),
                                          Positioned(
                                            top: -4,
                                            left: -6,
                                            child: DsBadge(
                                              count: unread,
                                              accent: ZaWolfColors.error,
                                            ),
                                          ),
                                        ],
                                      )
                                      : const Icon(
                                        Icons.notifications_outlined,
                                        color: ZaWolfColors.textSecondary,
                                      ),
                            ),
                            const SizedBox(width: DsSpacing.sm),
                            // Profile menu
                            PopupMenuButton<String>(
                              tooltip: 'الحساب',
                              shape: RoundedRectangleBorder(
                                borderRadius: DsRadius.inputBorder,
                              ),
                              color: ZaWolfColors.surface02,
                              onSelected: (value) async {
                                if (value == 'profile') {
                                  context.go('/employee/profile');
                                } else if (value == 'signout') {
                                  await widget.onSignOut();
                                }
                              },
                              itemBuilder:
                                  (context) => [
                                    PopupMenuItem(
                                      value: 'profile',
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.person_outline,
                                            size: 19,
                                          ),
                                          const SizedBox(width: DsSpacing.sm),
                                          Text(
                                            'حسابي',
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'signout',
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.logout,
                                            size: 19,
                                            color: ZaWolfColors.error,
                                          ),
                                          const SizedBox(width: DsSpacing.sm),
                                          Text(
                                            'تسجيل الخروج',
                                            style: theme.textTheme.bodyMedium!
                                                .copyWith(
                                                  color: ZaWolfColors.error,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor: ZaWolfColors.primaryCyan
                                    .withValues(alpha: 0.12),
                                child: Text(
                                  widget.user.displayName.isEmpty
                                      ? 'Z'
                                      : widget
                                          .user
                                          .displayName
                                          .characters
                                          .first,
                                  style: const TextStyle(
                                    color: ZaWolfColors.primaryCyan,
                                    fontWeight: FontWeight.bold,
                                    fontSize: DsType.secondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(child: SizedBox.expand(child: widget.child)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedSidebar(
    ThemeData theme,
    List<NavigationItem> items,
    String portalTitle,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Tooltip(
              message: 'ZaWolf HR • $portalTitle',
              child: const AppLogo(size: 38),
            ),
          ),
        ),
        const Divider(height: 1, color: ZaWolfColors.surface03),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: DsSpacing.md),
          child: Center(
            child: Tooltip(
              message:
                  '${widget.user.displayName}\n${EmployeeRole.arabicLabel(widget.user.role)}',
              child: CircleAvatar(
                radius: 18,
                backgroundColor: ZaWolfColors.primaryCyan.withValues(
                  alpha: 0.12,
                ),
                child: Text(
                  widget.user.displayName.isEmpty
                      ? 'Z'
                      : widget.user.displayName.characters.first,
                  style: const TextStyle(
                    color: ZaWolfColors.primaryCyan,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ),
        const Divider(height: 1, color: ZaWolfColors.surface03),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: DsSpacing.xs),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final selected = _isSelected(item);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Center(
                  child: Tooltip(
                    message: '${item.label} (${item.englishLabel})',
                    child: Material(
                      color:
                          selected
                              ? ZaWolfColors.primaryCyan.withValues(alpha: 0.15)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: IconButton(
                        icon: Icon(
                          selected ? item.activeIcon : item.icon,
                          color:
                              selected
                                  ? ZaWolfColors.primaryCyan
                                  : ZaWolfColors.textSecondary,
                          size: 22,
                        ),
                        onPressed:
                            selected ? null : () => context.go(item.path),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1, color: ZaWolfColors.surface03),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: DsSpacing.sm),
          child: Center(
            child: Tooltip(
              message: 'تسجيل الخروج',
              child: IconButton(
                icon: const Icon(
                  Icons.logout,
                  size: 20,
                  color: ZaWolfColors.error,
                ),
                onPressed: () async => widget.onSignOut(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedSidebar(
    ThemeData theme,
    List<NavDomainGroup> groups,
    String portalTitle,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Row(
            children: [
              const AppLogo(size: 42),
              const SizedBox(width: DsSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ZaWolf HR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: DsType.h2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      portalTitle,
                      style: const TextStyle(
                        color: ZaWolfColors.textMuted,
                        fontSize: DsType.caption,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: ZaWolfColors.surface03),
        // User identity block
        Padding(
          padding: const EdgeInsets.all(DsSpacing.lg),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: ZaWolfColors.primaryCyan.withValues(
                  alpha: 0.12,
                ),
                child: Text(
                  widget.user.displayName.isEmpty
                      ? 'Z'
                      : widget.user.displayName.characters.first,
                  style: const TextStyle(
                    color: ZaWolfColors.primaryCyan,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: DsSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      EmployeeRole.arabicLabel(widget.user.role),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ZaWolfColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Sidebar search filters groups locally
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
          child: SizedBox(
            height: 40,
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              style: theme.textTheme.bodyMedium,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'بحث في القائمة…',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: EdgeInsets.zero,
                filled: true,
                fillColor: ZaWolfColors.surface02,
                border: OutlineInputBorder(
                  borderRadius: DsRadius.inputBorder,
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: DsSpacing.sm),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: DsSpacing.md,
              vertical: DsSpacing.xs,
            ),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              return _buildDomainGroup(groups[index]);
            },
          ),
        ),
        const Divider(height: 1, color: ZaWolfColors.surface03),
        Padding(
          padding: const EdgeInsets.all(DsSpacing.md),
          child: OutlinedButton.icon(
            onPressed: () async {
              await widget.onSignOut();
            },
            icon: const Icon(Icons.logout, size: 19),
            label: const Text('تسجيل الخروج'),
            style: OutlinedButton.styleFrom(
              foregroundColor: ZaWolfColors.error,
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDomainGroup(NavDomainGroup group) {
    final collapsed = _collapsed.contains(group.domain);
    final groupActive = group.items.any(_isSelected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap:
                () => setState(() {
                  collapsed
                      ? _collapsed.remove(group.domain)
                      : _collapsed.add(group.domain);
                }),
            borderRadius: DsRadius.inputBorder,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DsSpacing.md,
                vertical: DsSpacing.sm + 2,
              ),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: collapsed ? -0.25 : 0,
                    duration: DsMotion.fast,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color:
                          groupActive
                              ? ZaWolfColors.primaryCyan
                              : ZaWolfColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: DsSpacing.sm),
                  Icon(
                    groupActive ? group.domain.activeIcon : group.domain.icon,
                    size: 18,
                    color:
                        groupActive
                            ? ZaWolfColors.primaryCyan
                            : ZaWolfColors.textSecondary,
                  ),
                  const SizedBox(width: DsSpacing.sm),
                  Expanded(
                    child: Text(
                      group.domain.arabicLabel,
                      style: TextStyle(
                        color:
                            groupActive
                                ? Colors.white
                                : ZaWolfColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: DsType.secondary,
                      ),
                    ),
                  ),
                  Text(
                    '${group.items.length}',
                    style: const TextStyle(
                      color: ZaWolfColors.textMuted,
                      fontSize: DsType.caption,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: DsMotion.fast,
          sizeCurve: DsMotion.curve,
          crossFadeState:
              collapsed ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: Column(
            children: [
              for (final item in group.items)
                _SidebarItem(
                  item: item,
                  selected: _isSelected(item),
                  onTap: _isSelected(item) ? null : () => context.go(item.path),
                ),
            ],
          ),
          secondChild: const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: DsSpacing.xs),
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final NavigationItem item;
  final bool selected;
  final VoidCallback? onTap;

  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: item.englishLabel,
      child: Material(
        color:
            selected
                ? ZaWolfColors.primaryCyan.withValues(alpha: 0.10)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 44,
            padding: const EdgeInsets.only(
              right: DsSpacing.lg + DsSpacing.xl,
              left: DsSpacing.md,
            ),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color:
                      selected ? ZaWolfColors.primaryCyan : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? item.activeIcon : item.icon,
                  size: 20,
                  color:
                      selected
                          ? ZaWolfColors.primaryCyan
                          : ZaWolfColors.textSecondary,
                ),
                const SizedBox(width: DsSpacing.md),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          selected ? Colors.white : ZaWolfColors.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: DsType.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
