import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../theme/theme.dart';
import '../../../components/wolf_button.dart';

import '../domain/meeting_repository.dart';

class MeetingRequestScreen extends StatefulWidget {
  const MeetingRequestScreen({
    required this.repository,
    this.isEmbedded = false,
    this.onSubmitted,
    super.key,
  });
  final MeetingRepository repository;
  final bool isEmbedded;
  final VoidCallback? onSubmitted;

  @override
  State<MeetingRequestScreen> createState() => _MeetingRequestScreenState();
}

class _MeetingRequestScreenState extends State<MeetingRequestScreen> {
  final _purpose = TextEditingController();
  MeetingRoom? _room;
  MeetingApprover? _approver;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _from = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _to = const TimeOfDay(hour: 11, minute: 0);
  bool _loading = true;
  bool _saving = false;
  bool? _available;
  String? _loadError;
  List<MeetingRoom> _rooms = const [];
  List<MeetingApprover> _approvers = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _purpose.dispose();
    super.dispose();
  }

  DateTime get _start =>
      DateTime(_date.year, _date.month, _date.day, _from.hour, _from.minute);
  DateTime get _end =>
      DateTime(_date.year, _date.month, _date.day, _to.hour, _to.minute);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final values = await Future.wait([
        widget.repository.rooms(),
        widget.repository.approvers(),
      ]);
      if (mounted) {
        setState(() {
          _rooms = values[0] as List<MeetingRoom>;
          _approvers = values[1] as List<MeetingApprover>;
          _loading = false;
          _loadError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'تعذر تحميل القاعات والمسؤولين. تحقق من الاتصال ثم أعد المحاولة.';
        });
      }
    }
  }

  Future<void> _checkAvailability() async {
    if (_room == null || !_end.isAfter(_start)) return;
    setState(() => _available = null);
    try {
      final available = await widget.repository.isAvailable(
        roomId: _room!.id,
        start: _start,
        end: _end,
      );
      if (mounted) setState(() => _available = available);
    } catch (error) {
      if (mounted) _message('$error', error: true);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(today) ? today : _date,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      locale: const Locale('ar'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: ZaWolfColors.primaryCyan,
              onPrimary: ZaWolfColors.background,
              surface: ZaWolfColors.surface01,
              onSurface: ZaWolfColors.textPrimary,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) {
      setState(() => _date = picked);
      _checkAvailability();
    }
  }

  Future<void> _pickTime(bool isFrom) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isFrom ? _from : _to,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: ZaWolfColors.primaryCyan,
              onPrimary: ZaWolfColors.background,
              surface: ZaWolfColors.surface01,
              onSurface: ZaWolfColors.textPrimary,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _from = picked;
        } else {
          _to = picked;
        }
      });
      _checkAvailability();
    }
  }

  Future<void> _submit() async {
    if (_room == null ||
        _approver == null ||
        _purpose.text.trim().isEmpty ||
        !_end.isAfter(_start)) {
      _message(
        'اختر المسؤول والقاعة ووقت بداية ونهاية صحيحين واكتب سبب الاجتماع.',
        error: true,
      );
      return;
    }
    await _checkAvailability();
    if (_available == false) {
      _message(
        'القاعة مشغولة في هذا الوقت. اختر وقتاً أو قاعة أخرى.',
        error: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repository.create(
        managerId: _approver!.id,
        roomId: _room!.id,
        start: _start,
        end: _end,
        purpose: _purpose.text.trim(),
      );
      if (mounted) {
        _message('تم إرسال طلب الاجتماع وإشعار المسؤول المختار.');
        setState(() {
          _purpose.clear();
          _available = null;
        });
        widget.onSubmitted?.call();
      }
    } catch (error) {
      if (mounted) _message('$error', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String message, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? ZaWolfColors.error : ZaWolfColors.success,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_loading) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    } else if (_loadError != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 42),
              const SizedBox(height: 12),
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    } else {
      final formChildren = [
                  DropdownButtonFormField<String>(
                    initialValue:
                        _approvers.any((a) => a.id == _approver?.id)
                            ? _approver?.id
                            : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'المسؤول المطلوب للاجتماع',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        _approvers
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item.id,
                                child: Text('${item.name} — ${item.roleLabel}'),
                              ),
                            )
                            .toList(),
                    hint: const Text('اختر المسؤول'),
                    onChanged:
                        _approvers.isEmpty
                            ? null
                            : (id) {
                              if (id == null) return;
                              setState(
                                () =>
                                    _approver = _approvers.firstWhere(
                                      (a) => a.id == id,
                                    ),
                              );
                            },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue:
                        _rooms.any((r) => r.id == _room?.id) ? _room?.id : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'مكان الاجتماع',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        _rooms
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item.id,
                                child: Text(item.name),
                              ),
                            )
                            .toList(),
                    hint: const Text('اختر القاعة'),
                    onChanged:
                        _rooms.isEmpty
                            ? null
                            : (id) {
                              if (id == null) return;
                              setState(
                                () => _room = _rooms.firstWhere((r) => r.id == id),
                              );
                              _checkAvailability();
                            },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6366F1),
                      side: BorderSide(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month, color: Color(0xFF6366F1)),
                    label: Text(
                      DateFormat('EEEE yyyy/MM/dd', 'ar').format(_date),
                      style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6366F1),
                            side: BorderSide(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.6),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          onPressed: () => _pickTime(true),
                          child: Text(
                            'من ${_from.format(context)}',
                            style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6366F1),
                            side: BorderSide(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.6),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          onPressed: () => _pickTime(false),
                          child: Text(
                            'إلى ${_to.format(context)}',
                            style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_available != null)
                    Text(
                      _available!
                          ? 'القاعة متاحة في هذا الوقت.'
                          : 'القاعة مشغولة في هذا الوقت. اختر وقتاً أو قاعة أخرى.',
                      style: TextStyle(
                        color: _available! ? ZaWolfColors.success : ZaWolfColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _purpose,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'سبب الاجتماع',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  WolfButton(
                    onPressed: _saving ? null : _submit,
                    text: _saving ? 'جارٍ الإرسال...' : 'إرسال طلب الاجتماع',
                    secondaryText: 'SUBMIT MEETING REQUEST',
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.centerStart,
                      end: AlignmentDirectional.centerEnd,
                      colors: [
                        const Color(0xFF6366F1),
                        Color.alphaBlend(
                          Colors.white.withValues(alpha: 0.18),
                          const Color(0xFF6366F1),
                        ),
                      ],
                    ),
                    glowColor: const Color(0xFF6366F1),
                    textColor: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    loading: _saving,
                  ),
                ];
      body = widget.isEmbedded
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: formChildren,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: formChildren,
            );
    }

    final content = widget.isEmbedded
        ? body
        : Scaffold(
            appBar: AppBar(title: const Text('طلب اجتماع')),
            body: body,
          );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: content,
    );
  }
}
