import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/workspace_resource.dart';
import '../../domain/use_cases/list_accessible_resources.dart';

sealed class WorkspaceBrowserState {
  const WorkspaceBrowserState();
}

final class WorkspaceBrowserLoading extends WorkspaceBrowserState {
  const WorkspaceBrowserLoading();
}

final class WorkspaceBrowserReady extends WorkspaceBrowserState {
  const WorkspaceBrowserReady({
    required this.parentId,
    required this.resources,
    required this.canLoadMore,
  });

  final String? parentId;
  final List<WorkspaceResource> resources;
  final bool canLoadMore;
}

final class WorkspaceBrowserDenied extends WorkspaceBrowserState {
  const WorkspaceBrowserDenied();
}

final class WorkspaceBrowserFailure extends WorkspaceBrowserState {
  const WorkspaceBrowserFailure(this.message);

  final String message;
}

final class WorkspaceBrowserCubit extends Cubit<WorkspaceBrowserState> {
  WorkspaceBrowserCubit(this._listResources)
    : super(const WorkspaceBrowserLoading());

  final ListAccessibleResources _listResources;
  String? _nextPageToken;
  final Map<String, WorkspaceBrowserReady> _pageCache =
      <String, WorkspaceBrowserReady>{};
  final Map<String, String?> _nextTokens = <String, String?>{};

  String _cacheKey(String? parentId) => parentId ?? '__workspace_root__';

  Future<void> load({String? parentId, bool force = false}) async {
    final key = _cacheKey(parentId);
    final cached = _pageCache[key];
    if (!force && cached != null) {
      _nextPageToken = _nextTokens[key];
      emit(cached);
      return;
    }
    // Keep the current folder on-screen while an explicit refresh runs.
    if (state is! WorkspaceBrowserReady) {
      emit(const WorkspaceBrowserLoading());
    }
    try {
      final page = await _listResources(parentId: parentId);
      _nextPageToken = page.nextPageToken;
      final ready = WorkspaceBrowserReady(
          parentId: parentId,
          resources: page.resources,
          canLoadMore: _nextPageToken != null,
        );
      _pageCache[key] = ready;
      _nextTokens[key] = _nextPageToken;
      emit(ready);
    } on WorkspaceAccessDeniedException {
      if (state is! WorkspaceBrowserReady) emit(const WorkspaceBrowserDenied());
    } catch (_) {
      if (state is! WorkspaceBrowserReady) {
        emit(
          const WorkspaceBrowserFailure(
            'تعذر تحميل ملفات الشركة حالياً. أعد المحاولة بعد لحظات.',
          ),
        );
      }
    }
  }

  Future<void> loadMore() async {
    final current = state;
    if (current is! WorkspaceBrowserReady || _nextPageToken == null) return;
    try {
      final page = await _listResources(
        parentId: current.parentId,
        pageToken: _nextPageToken,
      );
      _nextPageToken = page.nextPageToken;
      final ready = WorkspaceBrowserReady(
          parentId: current.parentId,
          resources: [...current.resources, ...page.resources],
          canLoadMore: _nextPageToken != null,
        );
      final key = _cacheKey(current.parentId);
      _pageCache[key] = ready;
      _nextTokens[key] = _nextPageToken;
      emit(ready);
    } catch (_) {
      emit(
        const WorkspaceBrowserFailure(
          'تعذر تحميل المزيد من الملفات. أعد المحاولة.',
        ),
      );
    }
  }

  Future<void> refresh() {
    final current = state;
    return load(
      parentId: current is WorkspaceBrowserReady ? current.parentId : null,
      force: true,
    );
  }
}

final class WorkspaceAccessDeniedException implements Exception {
  const WorkspaceAccessDeniedException();
}
