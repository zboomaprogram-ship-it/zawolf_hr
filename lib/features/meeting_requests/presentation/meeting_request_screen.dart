import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../theme/theme.dart';

import '../domain/meeting_repository.dart';

class MeetingRequestScreen extends StatefulWidget {
  const MeetingRequestScreen({required this.repository, super.key});
  final MeetingRepository repository;

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
              onPrimary: Colors.black,
              surface: ZaWolfColors.surface01,
              onSurface: Colors.white,
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
              onPrimary: Colors.black,
              surface: ZaWolfColors.surface01,
              onSurface: Colors.white,
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
          backgroundColor: error ? Colors.red : Colors.green,
        ),
      );

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('طلب اجتماع')),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
              ? Center(
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
              )
              : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<String>(
                    value:
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
                    value:
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
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      DateFormat('EEEE yyyy/MM/dd', 'ar').format(_date),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _pickTime(true),
                          child: Text('من ${_from.format(context)}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _pickTime(false),
                          child: Text('إلى ${_to.format(context)}'),
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
                        color: _available! ? Colors.green : Colors.red,
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
                  FilledButton.icon(
                    onPressed: _saving ? null : _submit,
                    icon:
                        _saving
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.send),
                    label: Text(
                      _saving ? 'جارٍ الإرسال...' : 'إرسال طلب الاجتماع',
                    ),
                  ),
                ],
              ),
    ),
  );
}
