import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:zawolf_hr/design_system/components/feedback_states.dart';
import 'package:zawolf_hr/design_system/components/filter_bar.dart';
import 'package:zawolf_hr/design_system/components/keep_mounted_tab_view.dart';
import 'package:zawolf_hr/design_system/components/skeletons.dart';
import 'package:zawolf_hr/design_system/components/stale_while_refresh.dart';
import 'package:zawolf_hr/design_system/components/status_pill.dart';
import 'package:zawolf_hr/design_system/tokens.dart';
import 'package:zawolf_hr/theme/theme.dart';
import '../../domain/entities/request_record.dart';
import '../../domain/repositories/request_repository.dart';
import '../cubits/request_browse_cubit.dart';
import '../cubits/request_detail_cubit.dart';
import '../cubits/request_queue_cubit.dart';
import 'request_detail_page.dart';

/// Unified Requests Hub consolidating the 18 legacy request screens (Task C018).
///
/// Features:
/// - "طلبات عليا" (Action Required / Queue)
/// - "كل الطلبات" (Browse & Filter with DsFilterBar)
/// - "سجل طلباتي" (My History)
/// - Responsive: Master-Detail view on desktop (>=980), card list on mobile.
/// - Conforms strictly to AGENTS.md: zero data/infrastructure dependencies in presentation.
class RequestsHubPage extends StatefulWidget {
  const RequestsHubPage({
    required this.actorId,
    required this.companyId,
    this.initialTabIndex = 0,
    super.key,
  });

  final String actorId;
  final String companyId;
  final int initialTabIndex;

  @override
  State<RequestsHubPage> createState() => _RequestsHubPageState();
}

class _RequestsHubPageState extends State<RequestsHubPage> {
  RequestRecord? _selectedRecord;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 980;

    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTabIndex,
      child: Scaffold(
        backgroundColor: ZaWolfColors.background,
        appBar: AppBar(
          backgroundColor: ZaWolfColors.surface01,
          title: const Text('مركز الطلبات الموحد', style: TextStyle(color: Colors.white)),
          centerTitle: false,
          bottom: const TabBar(
            indicatorColor: ZaWolfColors.primaryCyan,
            labelColor: ZaWolfColors.primaryCyan,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'طلبات عليا'),
              Tab(text: 'كل الطلبات'),
              Tab(text: 'سجل طلباتي'),
            ],
          ),
        ),
        body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: _buildTabs(),
        ),
        VerticalDivider(width: 1, color: ZaWolfColors.surface02),
        Expanded(
          flex: 5,
          child: _selectedRecord == null
              ? const Center(
                  child: EmptyState(
                    title: 'اختر طلباً من القائمة',
                    subtitle: 'انقر على أي طلب من القائمة اليمنى لعرض تفاصيله وسجل موافقاته هنا.',
                  ),
                )
              : RequestDetailPage(
                  collection: _selectedRecord!.collection,
                  requestId: _selectedRecord!.id,
                  actorId: widget.actorId,
                  isEmbedded: true,
                  onActionSuccess: () {
                    context.read<RequestQueueCubit>().onItemActionCompleted(_selectedRecord!.id);
                    setState(() => _selectedRecord = null);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return _buildTabs();
  }

  Widget _buildTabs() {
    return KeepMountedTabBarView(
      builders: [
        (context) => _QueueTabView(
              actorId: widget.actorId,
              companyId: widget.companyId,
              selectedId: _selectedRecord?.id,
              onSelect: (record) => _handleSelect(record),
            ),
        (context) => _BrowseTabView(
              actorId: widget.actorId,
              companyId: widget.companyId,
              selectedId: _selectedRecord?.id,
              onSelect: (record) => _handleSelect(record),
            ),
        (context) => _HistoryTabView(
              actorId: widget.actorId,
              companyId: widget.companyId,
              selectedId: _selectedRecord?.id,
              onSelect: (record) => _handleSelect(record),
            ),
      ],
    );
  }

  void _handleSelect(RequestRecord record) {
    final isDesktop = MediaQuery.of(context).size.width >= 980;
    if (isDesktop) {
      setState(() => _selectedRecord = record);
      context.read<RequestDetailCubit>().loadDetail(
            collection: record.collection,
            requestId: record.id,
          );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BlocProvider.value(
            value: context.read<RequestDetailCubit>()
              ..loadDetail(collection: record.collection, requestId: record.id),
            child: RequestDetailPage(
              collection: record.collection,
              requestId: record.id,
              actorId: widget.actorId,
              onActionSuccess: () {
                context.read<RequestQueueCubit>().onItemActionCompleted(record.id);
              },
            ),
          ),
        ),
      );
    }
  }
}

class _QueueTabView extends StatefulWidget {
  const _QueueTabView({
    required this.actorId,
    required this.companyId,
    required this.onSelect,
    this.selectedId,
  });

  final String actorId;
  final String companyId;
  final String? selectedId;
  final ValueChanged<RequestRecord> onSelect;

  @override
  State<_QueueTabView> createState() => _QueueTabViewState();
}

class _QueueTabViewState extends State<_QueueTabView> {
  @override
  void initState() {
    super.initState();
    context.read<RequestQueueCubit>().loadQueue(
          actorId: widget.actorId,
          companyId: widget.companyId,
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RequestQueueCubit, RequestQueueState>(
      builder: (context, state) {
        if (state is RequestQueueLoading && state.staleRecords.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(DsSpacing.md),
            child: ListView.separated(
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(height: DsSpacing.sm),
              itemBuilder: (_, __) => const SkeletonEmployeeRow(),
            ),
          );
        }

        if (state is RequestQueueEmpty) {
          return const Center(
            child: EmptyState(
              title: 'لا توجد طلبات معلقة',
              subtitle: 'رائع! لقد تم البت في جميع الطلبات المطلوبة منك حالياً.',
            ),
          );
        }

        if (state is RequestQueueFailure && state.staleRecords.isEmpty) {
          return Center(
            child: ErrorState(
              message: state.errorMessage,
              onRetry: () => context.read<RequestQueueCubit>().loadQueue(
                    actorId: widget.actorId,
                    companyId: widget.companyId,
                    refresh: true,
                  ),
            ),
          );
        }

        final records = switch (state) {
          RequestQueueLoaded(:final records) => records,
          RequestQueueLoading(:final staleRecords) => staleRecords,
          RequestQueueFailure(:final staleRecords) => staleRecords,
          _ => const <RequestRecord>[],
        };

        return StaleWhileRefresh(
          hasData: records.isNotEmpty,
          isRefreshing: state is RequestQueueLoaded && state.isRefreshing,
          errorMessage: state is RequestQueueFailure ? state.errorMessage : null,
          child: RefreshIndicator(
            onRefresh: () => context.read<RequestQueueCubit>().loadQueue(
                  actorId: widget.actorId,
                  companyId: widget.companyId,
                  refresh: true,
                ),
            child: ListView.separated(
              padding: const EdgeInsets.all(DsSpacing.md),
              itemCount: records.length,
              separatorBuilder: (_, __) => const SizedBox(height: DsSpacing.sm),
              itemBuilder: (context, index) {
                final item = records[index];
                return _RequestListCard(
                  record: item,
                  isSelected: item.id == widget.selectedId,
                  onTap: () => widget.onSelect(item),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _BrowseTabView extends StatefulWidget {
  const _BrowseTabView({
    required this.actorId,
    required this.companyId,
    required this.onSelect,
    this.selectedId,
  });

  final String actorId;
  final String companyId;
  final String? selectedId;
  final ValueChanged<RequestRecord> onSelect;

  @override
  State<_BrowseTabView> createState() => _BrowseTabViewState();
}

class _BrowseTabViewState extends State<_BrowseTabView> {
  String _selectedFilterId = 'all';

  static const _filterChips = <FilterChipItem>[
    FilterChipItem(id: 'all', label: 'الكل'),
    FilterChipItem(id: 'leaves', label: 'الإجازات'),
    FilterChipItem(id: 'permissions', label: 'الأذونات'),
    FilterChipItem(id: 'advances', label: 'السلف'),
    FilterChipItem(id: 'remote', label: 'العمل عن بعد'),
  ];

  @override
  void initState() {
    super.initState();
    context.read<RequestBrowseCubit>().load(
          actorId: widget.actorId,
          companyId: widget.companyId,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FilterBar(
          chips: _filterChips,
          selectedId: _selectedFilterId,
          onSelected: (id) {
            setState(() => _selectedFilterId = id);
            final category = switch (id) {
              'leaves' => RequestWorkspaceCategory.leave,
              'permissions' => RequestWorkspaceCategory.permission,
              'advances' => RequestWorkspaceCategory.advance,
              'remote' => RequestWorkspaceCategory.remoteWork,
              _ => null,
            };
            context.read<RequestBrowseCubit>().updateFilter(
                  RequestWorkspaceFilter(category: category),
                  actorId: widget.actorId,
                  companyId: widget.companyId,
                );
          },
        ),
        Expanded(
          child: BlocBuilder<RequestBrowseCubit, RequestBrowseState>(
            builder: (context, state) {
              if (state is RequestBrowseLoading && state.staleRecords.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(DsSpacing.md),
                  child: ListView.separated(
                    itemCount: 6,
                    separatorBuilder: (_, __) => const SizedBox(height: DsSpacing.sm),
                    itemBuilder: (_, __) => const SkeletonEmployeeRow(),
                  ),
                );
              }

              if (state is RequestBrowseEmpty) {
                return const Center(
                  child: EmptyState(
                    title: 'لا توجد طلبات تطابق الفلتر',
                    subtitle: 'جرب تغيير خيارات التصفية أو البحث.',
                  ),
                );
              }

              if (state is RequestBrowseFailure && state.staleRecords.isEmpty) {
                return Center(
                  child: ErrorState(
                    message: state.errorMessage,
                    onRetry: () => context.read<RequestBrowseCubit>().load(
                          actorId: widget.actorId,
                          companyId: widget.companyId,
                          refresh: true,
                        ),
                  ),
                );
              }

              final records = switch (state) {
                RequestBrowseLoaded(:final records) => records,
                RequestBrowseLoading(:final staleRecords) => staleRecords,
                RequestBrowseFailure(:final staleRecords) => staleRecords,
                _ => const <RequestRecord>[],
              };

              return StaleWhileRefresh(
                hasData: records.isNotEmpty,
                isRefreshing: state is RequestBrowseLoaded && state.isRefreshing,
                errorMessage: state is RequestBrowseFailure ? state.errorMessage : null,
                child: RefreshIndicator(
                  onRefresh: () => context.read<RequestBrowseCubit>().load(
                        actorId: widget.actorId,
                        companyId: widget.companyId,
                        refresh: true,
                      ),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(DsSpacing.md),
                    itemCount: records.length,
                    separatorBuilder: (_, __) => const SizedBox(height: DsSpacing.sm),
                    itemBuilder: (context, index) {
                      final item = records[index];
                      return _RequestListCard(
                        record: item,
                        isSelected: item.id == widget.selectedId,
                        onTap: () => widget.onSelect(item),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HistoryTabView extends StatefulWidget {
  const _HistoryTabView({
    required this.actorId,
    required this.companyId,
    required this.onSelect,
    this.selectedId,
  });

  final String actorId;
  final String companyId;
  final String? selectedId;
  final ValueChanged<RequestRecord> onSelect;

  @override
  State<_HistoryTabView> createState() => _HistoryTabViewState();
}

class _HistoryTabViewState extends State<_HistoryTabView> {
  @override
  void initState() {
    super.initState();
    context.read<RequestBrowseCubit>().load(
          actorId: widget.actorId,
          companyId: widget.companyId,
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RequestBrowseCubit, RequestBrowseState>(
      builder: (context, state) {
        if (state is RequestBrowseLoading && state.staleRecords.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(DsSpacing.md),
            child: ListView.separated(
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(height: DsSpacing.sm),
              itemBuilder: (_, __) => const SkeletonEmployeeRow(),
            ),
          );
        }

        final records = switch (state) {
          RequestBrowseLoaded(:final records) =>
            records.where((r) => r.requesterId == widget.actorId).toList(),
          _ => const <RequestRecord>[],
        };

        if (records.isEmpty) {
          return const Center(
            child: EmptyState(
              title: 'لا يوجد سجل طلبات سابقة',
              subtitle: 'لم تقدم أي طلبات من حسابك حتى الآن.',
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(DsSpacing.md),
          itemCount: records.length,
          separatorBuilder: (_, __) => const SizedBox(height: DsSpacing.sm),
          itemBuilder: (context, index) {
            final item = records[index];
            return _RequestListCard(
              record: item,
              isSelected: item.id == widget.selectedId,
              onTap: () => widget.onSelect(item),
            );
          },
        );
      },
    );
  }
}

class _RequestListCard extends StatelessWidget {
  const _RequestListCard({
    required this.record,
    required this.onTap,
    this.isSelected = false,
  });

  final RequestRecord record;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: DsRadius.cardBorder,
      child: Container(
        padding: const EdgeInsets.all(DsSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? ZaWolfColors.surface02 : ZaWolfColors.surface01,
          borderRadius: DsRadius.cardBorder,
          border: Border.all(
            color: isSelected ? ZaWolfColors.primaryCyan : ZaWolfColors.surface02,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: ZaWolfColors.surface02,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.description_outlined,
                color: ZaWolfColors.primaryCyan,
                size: 20,
              ),
            ),
            const SizedBox(width: DsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        record.category.localizedArabicTitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      StatusPill(
                        label: record.status.localizedArabicLabel,
                        status: switch (record.status) {
                          RequestWorkspaceStatus.approved => DsStatus.approved,
                          RequestWorkspaceStatus.rejected => DsStatus.rejected,
                          RequestWorkspaceStatus.cancelled => DsStatus.rejected,
                          RequestWorkspaceStatus.confirmed => DsStatus.approved,
                          _ => DsStatus.pendingAction,
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    record.requesterName ?? 'موظف',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  if (record.summary != null && record.summary!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      record.summary!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
