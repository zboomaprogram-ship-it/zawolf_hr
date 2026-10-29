import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zawolf_hr/design_system/components/confirmation_sheet.dart';
import 'package:zawolf_hr/design_system/components/feedback_states.dart';
import 'package:zawolf_hr/design_system/components/skeletons.dart';
import 'package:zawolf_hr/design_system/components/status_pill.dart';
import 'package:zawolf_hr/design_system/tokens.dart';
import 'package:zawolf_hr/theme/theme.dart';

import '../../domain/entities/request_record.dart';
import '../cubits/request_detail_cubit.dart';

/// Standalone and embeddable Request Detail surface (Task C019).
/// Conforms to AGENTS.md: zero data/infrastructure dependencies; uses ConfirmationSheet.
class RequestDetailPage extends StatelessWidget {
  const RequestDetailPage({
    required this.collection,
    required this.requestId,
    this.actorId = '',
    this.isEmbedded = false,
    this.onActionSuccess,
    super.key,
  });

  final String collection;
  final String requestId;
  final String actorId;
  final bool isEmbedded;
  final VoidCallback? onActionSuccess;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RequestDetailCubit, RequestDetailState>(
      listener: (context, state) {
        if (state is RequestDetailActionSuccessState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: ZaWolfColors.primaryCyan,
            ),
          );
          onActionSuccess?.call();
        } else if (state is RequestDetailFailureState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage),
              backgroundColor: ZaWolfColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        final content = switch (state) {
          RequestDetailLoading() => const Padding(
              padding: EdgeInsets.all(DsSpacing.lg),
              child: SkeletonDetailPane(),
            ),
          RequestDetailNotFoundState() => const Center(
              child: EmptyState(
                title: 'الطلب غير موجود',
                subtitle: 'قد يكون تم حذف الطلب أو نقل مرجعه.',
              ),
            ),
          RequestDetailFailureState(:final errorMessage) => Center(
              child: ErrorState(
                message: errorMessage,
                onRetry: () => context.read<RequestDetailCubit>().loadDetail(
                      collection: collection,
                      requestId: requestId,
                    ),
              ),
            ),
          RequestDetailReady(:final record, :final isActionInProgress) =>
            _DetailBody(
              record: record,
              actorId: actorId,
              isActionInProgress: isActionInProgress,
            ),
          RequestDetailActionSuccessState(:final record) => _DetailBody(
              record: record,
              actorId: actorId,
              isActionInProgress: false,
            ),
          _ => const SizedBox.shrink(),
        };

        if (isEmbedded) return content;

        return Scaffold(
          backgroundColor: ZaWolfColors.background,
          appBar: AppBar(
            backgroundColor: ZaWolfColors.surface01,
            title: const Text('تفاصيل الطلب', style: TextStyle(color: Colors.white)),
            centerTitle: true,
          ),
          body: content,
        );
      },
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.record,
    required this.actorId,
    required this.isActionInProgress,
  });

  final RequestRecord record;
  final String actorId;
  final bool isActionInProgress;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(DsSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderCard(),
          const SizedBox(height: DsSpacing.lg),
          _buildDetailsCard(),
          const SizedBox(height: DsSpacing.lg),
          _buildTimelineCard(),
          if (record.isActionableByMe) ...[
            const SizedBox(height: DsSpacing.xl),
            _buildActionButtons(context),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(DsSpacing.lg),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: DsRadius.cardBorder,
        border: Border.all(color: ZaWolfColors.surface02),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                record.category.localizedArabicTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              StatusPill(
                label: record.status.localizedArabicLabel,
                status: _toPillStatus(record.status),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.md),
          Text(
            record.requesterName ?? 'موظف غير محدد',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          if (record.requesterCode != null)
            Text(
              'الرقم الوظيفي: ${record.requesterCode}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(DsSpacing.lg),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: DsRadius.cardBorder,
        border: Border.all(color: ZaWolfColors.surface02),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'بيانات الطلب',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: DsSpacing.md),
          if (record.summary != null && record.summary!.isNotEmpty)
            _buildInfoRow('السبب / البيان', record.summary!),
          _buildInfoRow(
            'تاريخ التقديم',
            '${record.createdAt.year}/${record.createdAt.month}/${record.createdAt.day}',
          ),
          _buildInfoRow('المرحلة الحالية', record.stage.localizedArabicLabel),
        ],
      ),
    );
  }

  Widget _buildTimelineCard() {
    return Container(
      padding: const EdgeInsets.all(DsSpacing.lg),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: DsRadius.cardBorder,
        border: Border.all(color: ZaWolfColors.surface02),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'سجل الموافقات والتحديثات',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: DsSpacing.md),
          if (record.historyEvents.isEmpty)
            Text(
              'لا توجد أحداث سابقة مسجلة لهذا الطلب.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            )
          else
            for (final event in record.historyEvents)
              Padding(
                padding: const EdgeInsets.only(bottom: DsSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: ZaWolfColors.primaryCyan,
                    ),
                    const SizedBox(width: DsSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          if (event.actorName != null)
                            Text(
                              'بواسطة: ${event.actorName}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          if (event.note != null && event.note!.isNotEmpty)
                            Text(
                              'ملاحظة: ${event.note}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: ZaWolfColors.warning,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${event.timestamp.hour}:${event.timestamp.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    if (isActionInProgress) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: DsSpacing.md),
        child: SkeletonCard(height: 48, width: double.infinity),
      );
    }

    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ZaWolfColors.primaryCyan,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: DsSpacing.md),
              shape: const RoundedRectangleBorder(borderRadius: DsRadius.inputBorder),
            ),
            onPressed: () async {
              final confirmed = await showConfirmationSheet(
                context,
                title: 'تأكيد اعتماد الطلب',
                message: 'هل أنت متأكد من اعتماد هذا الطلب نهائياً؟',
                confirmLabel: 'اعتماد',
                destructive: false,
              );
              if (confirmed && context.mounted) {
                context.read<RequestDetailCubit>().approve(actorId: actorId);
              }
            },
            child: const Text('اعتماد', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: DsSpacing.md),
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: ZaWolfColors.error,
              side: const BorderSide(color: ZaWolfColors.error),
              padding: const EdgeInsets.symmetric(vertical: DsSpacing.md),
              shape: const RoundedRectangleBorder(borderRadius: DsRadius.inputBorder),
            ),
            onPressed: () async {
              final noteCtrl = TextEditingController();
              final confirmed = await showConfirmationSheet(
                context,
                title: 'تأكيد رفض الطلب',
                message: 'يرجى توضيح سبب رفض الطلب:',
                confirmLabel: 'تأكيد الرفض',
                destructive: true,
                requireComment: true,
                commentHint: 'أدخل سبب الرفض هنا...',
                commentController: noteCtrl,
              );
              if (confirmed && context.mounted) {
                context.read<RequestDetailCubit>().reject(
                      actorId: actorId,
                      note: noteCtrl.text.trim(),
                    );
              }
            },
            child: const Text('رفض', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  DsStatus _toPillStatus(RequestWorkspaceStatus status) => switch (status) {
        RequestWorkspaceStatus.approved => DsStatus.approved,
        RequestWorkspaceStatus.rejected => DsStatus.rejected,
        RequestWorkspaceStatus.cancelled => DsStatus.rejected,
        RequestWorkspaceStatus.confirmed => DsStatus.approved,
        _ => DsStatus.pendingAction,
      };
}
