import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/user_model.dart';
import '../domain/dashboard_visual_analysis.dart';
import '../domain/dashboard_visual_analysis_repository.dart';

class DashboardVisualAnalysisState extends Equatable {
  const DashboardVisualAnalysisState({
    required this.period,
    this.analysis,
    this.error,
    this.isLoading = false,
    this.isRefreshing = false,
  });

  final DashboardPeriod period;
  final DashboardVisualAnalysis? analysis;
  final Object? error;
  final bool isLoading;
  final bool isRefreshing;

  DashboardVisualAnalysisState copyWith({
    DashboardPeriod? period,
    DashboardVisualAnalysis? analysis,
    Object? error,
    bool clearError = false,
    bool? isLoading,
    bool? isRefreshing,
  }) => DashboardVisualAnalysisState(
    period: period ?? this.period,
    analysis: analysis ?? this.analysis,
    error: clearError ? null : (error ?? this.error),
    isLoading: isLoading ?? this.isLoading,
    isRefreshing: isRefreshing ?? this.isRefreshing,
  );

  @override
  List<Object?> get props => [period, analysis, error, isLoading, isRefreshing];
}

class DashboardVisualAnalysisCubit extends Cubit<DashboardVisualAnalysisState> {
  DashboardVisualAnalysisCubit({
    required DashboardVisualAnalysisRepository repository,
    required UserModel reviewer,
  }) : _repository = repository,
       _reviewer = reviewer,
       super(DashboardVisualAnalysisState(period: DashboardPeriod.sevenDays())) {
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) => refresh());
    refresh();
  }

  final DashboardVisualAnalysisRepository _repository;
  final UserModel _reviewer;
  Timer? _refreshTimer;
  int _refreshSequence = 0;

  Future<void> selectPeriod(DashboardPeriod period) async {
    emit(state.copyWith(period: period, clearError: true));
    await refresh();
  }

  Future<void> refresh() async {
    final sequence = ++_refreshSequence;
    final hasData = state.analysis != null;
    emit(state.copyWith(
      isLoading: !hasData,
      isRefreshing: hasData,
      clearError: true,
    ));
    try {
      final analysis = await _repository.loadManagement(
        reviewer: _reviewer,
        period: state.period,
      );
      if (isClosed || sequence != _refreshSequence) return;
      emit(state.copyWith(analysis: analysis, isLoading: false, isRefreshing: false, clearError: true));
    } catch (error) {
      if (isClosed || sequence != _refreshSequence) return;
      emit(state.copyWith(error: error, isLoading: false, isRefreshing: false));
    }
  }

  @override
  Future<void> close() {
    _refreshTimer?.cancel();
    return super.close();
  }
}
