import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../theme/theme.dart';
import '../../domain/entities/remote_work_models.dart';
import '../../domain/repositories/remote_work_repository.dart';
import '../cubit/remote_day_cubit.dart';
import '../widgets/remote_attendance_status_card.dart';
import '../widgets/remote_checkpoints_card.dart';

class RemoteAttendancePage extends StatelessWidget {
  const RemoteAttendancePage({
    required this.repository,
    required this.employeeId,
    this.targetDate,
    super.key,
  });

  final RemoteWorkRepository repository;
  final String employeeId;
  final DateTime? targetDate;

  @override
  Widget build(BuildContext context) {
    final date = targetDate ?? DateTime.now();
    return BlocProvider(
      create: (_) => RemoteDayCubit(repository: repository)
        ..loadDay(employeeId: employeeId, date: date),
      child: _RemoteAttendanceView(employeeId: employeeId, date: date),
    );
  }
}

class _RemoteAttendanceView extends StatefulWidget {
  const _RemoteAttendanceView({
    required this.employeeId,
    required this.date,
  });

  final String employeeId;
  final DateTime date;

  @override
  State<_RemoteAttendanceView> createState() => _RemoteAttendanceViewState();
}

class _RemoteAttendanceViewState extends State<_RemoteAttendanceView> {
  final _goalController = TextEditingController();
  final _summaryController = TextEditingController();
  final List<String> _goals = [];

  @override
  void dispose() {
    _goalController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  void _addGoal() {
    final text = _goalController.text.trim();
    if (text.isNotEmpty && _goals.length < 10) {
      setState(() {
        _goals.add(text);
        _goalController.clear();
      });
    }
  }

  void _removeGoal(int index) {
    setState(() {
      _goals.removeAt(index);
    });
  }

  void _handleCheckIn(BuildContext context) {
    const mockProof = RemoteProof(
      challengeId: 'webauthn_ch_local',
      credentialId: 'cred_pc_approved',
      assertion: {'clientDataJSON': 'passkey_assertion'},
    );
    context.read<RemoteDayCubit>().performCheckIn(
      employeeId: widget.employeeId,
      date: widget.date,
      proof: mockProof,
    );
  }

  void _handleCheckOut(BuildContext context) {
    const mockProof = RemoteProof(
      challengeId: 'webauthn_ch_out',
      credentialId: 'cred_pc_approved',
      assertion: {'clientDataJSON': 'passkey_out'},
    );
    context.read<RemoteDayCubit>().performCheckOut(
      employeeId: widget.employeeId,
      date: widget.date,
      proof: mockProof,
      summary: _summaryController.text.trim(),
    );
  }

  void _handleSavePlan(BuildContext context) {
    if (_goals.isEmpty) return;
    context.read<RemoteDayCubit>().savePlan(
      employeeId: widget.employeeId,
      goals: List.unmodifiable(_goals),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ أهداف خطة اليوم بنجاح.')),
    );
  }

  void _handleSubmitCheckpoint(BuildContext context, String checkpointId, String text, int slotIndex) {
    context.read<RemoteDayCubit>().submitCheckpointUpdate(
      checkpointId: checkpointId,
      text: text,
      slotIndex: slotIndex,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إرسال المتابعة بنجاح.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${widget.date.year}/${widget.date.month.toString().padLeft(2, '0')}/${widget.date.day.toString().padLeft(2, '0')}';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: ZaWolfColors.background,
        appBar: AppBar(
          title: const Text('تسجيل الدوام عن بُعد'),
          backgroundColor: ZaWolfColors.surface01,
          elevation: 0,
          actions: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: ZaWolfColors.primaryCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ZaWolfColors.borderGlow),
              ),
              child: const Row(
                children: [
                  Icon(Icons.laptop_chromebook, size: 16, color: ZaWolfColors.primaryCyan),
                  SizedBox(width: 6),
                  Text(
                    'العمل عن بُعد',
                    style: TextStyle(
                      color: ZaWolfColors.primaryCyan,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: BlocConsumer<RemoteDayCubit, RemoteDayState>(
          listener: (context, state) {
            if (state.goals.isNotEmpty && _goals.isEmpty) {
              setState(() {
                _goals.addAll(state.goals);
              });
            }
          },
          builder: (context, state) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header info banner
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'تاريخ اليوم: $dateStr',
                            style: const TextStyle(
                              color: ZaWolfColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, color: ZaWolfColors.primaryCyan),
                            onPressed: () => context.read<RemoteDayCubit>().loadDay(
                              employeeId: widget.employeeId,
                              date: widget.date,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Status & CheckIn/CheckOut Card
                      RemoteAttendanceStatusCard(
                        state: state,
                        onCheckIn: () => _handleCheckIn(context),
                        onCheckOut: () => _handleCheckOut(context),
                      ),
                      const SizedBox(height: 24),

                      // Goals and Plan panel (visible when checked in)
                      if (state.status == RemoteDayStatus.checkedIn) ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: ZaWolfColors.surface02,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: ZaWolfColors.surface03),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.playlist_add_check, color: ZaWolfColors.primaryCyan),
                                  SizedBox(width: 8),
                                  Text(
                                    'خطة أهداف اليوم (العمل عن بُعد)',
                                    style: TextStyle(
                                      color: ZaWolfColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _goalController,
                                      decoration: InputDecoration(
                                        hintText: 'أدخل هدفاً أو مهمة لليوم...',
                                        hintStyle: const TextStyle(color: ZaWolfColors.textMuted),
                                        filled: true,
                                        fillColor: ZaWolfColors.surface03,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      ),
                                      style: const TextStyle(color: ZaWolfColors.textPrimary),
                                      onSubmitted: (_) => _addGoal(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filled(
                                    onPressed: _addGoal,
                                    icon: const Icon(Icons.add),
                                    style: IconButton.styleFrom(backgroundColor: ZaWolfColors.primaryBlue),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_goals.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    'لم تتم إضافة أي أهداف بعد. حدد خطتك لبدء إنجاز اليوم.',
                                    style: TextStyle(color: ZaWolfColors.textMuted, fontSize: 13),
                                  ),
                                )
                              else
                                ..._goals.asMap().entries.map(
                                      (entry) => ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(Icons.circle, size: 8, color: ZaWolfColors.primaryCyan),
                                        title: Text(entry.value, style: const TextStyle(color: ZaWolfColors.textPrimary)),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.close, size: 18, color: ZaWolfColors.error),
                                          onPressed: () => _removeGoal(entry.key),
                                        ),
                                      ),
                                    ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _goals.isNotEmpty ? () => _handleSavePlan(context) : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ZaWolfColors.primaryCyan,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('حفظ خطة العمل'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Checkpoints Card
                        RemoteCheckpointsCard(
                          checkpoints: state.eligibility?.checkpoints ?? const [],
                          completedUpdates: state.checkpointUpdates,
                          onSubmit: (cpId, text, slot) => _handleSubmitCheckpoint(context, cpId, text, slot),
                        ),
                        const SizedBox(height: 24),

                        // Evening summary input
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: ZaWolfColors.surface02,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: ZaWolfColors.surface03),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'ملخص إنجاز اليوم (اختياري قبل الانصراف)',
                                style: TextStyle(
                                  color: ZaWolfColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _summaryController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText: 'سجل ملخص ما أنجزته خلال ساعات العمل اليوم...',
                                  hintStyle: const TextStyle(color: ZaWolfColors.textMuted),
                                  filled: true,
                                  fillColor: ZaWolfColors.surface03,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                style: const TextStyle(color: ZaWolfColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
