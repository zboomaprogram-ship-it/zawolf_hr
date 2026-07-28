import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../models/productivity_score_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/productivity_service.dart';
import '../../theme/theme.dart';
import '../../utils/payroll_cycle.dart';
import '../shared/productivity_score_details_sheet.dart';

class ProductivityRankingScreen extends StatefulWidget {
  const ProductivityRankingScreen({super.key});

  @override
  State<ProductivityRankingScreen> createState() =>
      _ProductivityRankingScreenState();
}

class _ProductivityRankingScreenState extends State<ProductivityRankingScreen> {
  final ProductivityService _service = ProductivityService();
  late final String _monthKey = PayrollCycle.keyFor(DateTime.now());
  bool _refreshing = false;
  bool _autoRefreshAttempted = false;

  Future<void> _refresh(
    UserModel reviewer, {
    bool showConfirmation = true,
  }) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final count = await _service.refreshRanking(reviewer, _monthKey);
      if (mounted && showConfirmation) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تحديث إنتاجية $count موظف.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر تحديث الإنتاجية. تحقق من الاتصال والصلاحيات ثم أعد المحاولة.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _refreshEmptyCacheOnce(UserModel reviewer) {
    if (_autoRefreshAttempted || _refreshing) return;
    _autoRefreshAttempted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh(reviewer, showConfirmation: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reviewer = context.watch<AuthService>().currentUser;
    final theme = Theme.of(context);
    if (reviewer == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('ترتيب الإنتاجية', style: theme.textTheme.headlineMedium),
        actions: [
          IconButton(
            tooltip: 'تحديث الحساب',
            onPressed: _refreshing ? null : () => _refresh(reviewer),
            icon: _refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, color: ZaWolfColors.primaryCyan),
          ),
        ],
      ),
      body: StreamBuilder<List<ProductivityScoreModel>>(
        stream: _service.watchRanking(reviewer, _monthKey),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
            );
          }
          if (snapshot.hasError) {
            return _LoadError(onRetry: () => _refresh(reviewer));
          }
          final scores = snapshot.data ?? [];
          if (scores.isEmpty) {
            _refreshEmptyCacheOnce(reviewer);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.leaderboard_outlined,
                      size: 56,
                      color: ZaWolfColors.textMuted,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _refreshing
                          ? 'جارٍ تجهيز ترتيب شهر $_monthKey لأول مرة…'
                          : 'لا توجد بيانات متاحة لشهر $_monthKey',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final best = scores.first;
          final needsFollowUp = [...scores]
            ..sort((a, b) => a.overallScore.compareTo(b.overallScore));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _HighlightCard(
                      title: 'أفضل موظف',
                      value: best.employeeName,
                      subtitle: '${best.overallScore.toStringAsFixed(0)}%',
                      color: ZaWolfColors.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HighlightCard(
                      title: 'يحتاج متابعة',
                      value: needsFollowUp.first.employeeName,
                      subtitle:
                          '${needsFollowUp.first.overallScore.toStringAsFixed(0)}%',
                      color: ZaWolfColors.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...scores.asMap().entries.map((entry) {
                final rank = entry.key + 1;
                final score = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: WolfCard(
                    onTap: () => showProductivityScoreDetails(context, score),
                    child: Row(
                      children: [
                        _RankBadge(rank: rank),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                score.employeeName,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${score.department} · ${score.statusLabel}',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: (score.overallScore / 100).clamp(0, 1),
                                minHeight: 7,
                                borderRadius: BorderRadius.circular(8),
                                color: _scoreColor(score.overallScore),
                                backgroundColor: ZaWolfColors.surface03,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${score.overallScore.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: _scoreColor(score.overallScore),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_left,
                          color: ZaWolfColors.textMuted,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Color _scoreColor(double value) {
    if (value >= 85) return ZaWolfColors.success;
    if (value >= 70) return ZaWolfColors.warning;
    return ZaWolfColors.error;
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('تعذر تحميل الإنتاجية، أعد المحاولة'),
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _HighlightCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(title, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;

  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ZaWolfColors.primaryCyan.withValues(alpha: 0.12),
        border: Border.all(
          color: ZaWolfColors.primaryCyan.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        '$rank',
        style: const TextStyle(
          color: ZaWolfColors.primaryCyan,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
