import 'package:flutter/material.dart';

import '../domain/meeting_repository.dart';

class MeetingRoomsManagementScreen extends StatefulWidget {
  const MeetingRoomsManagementScreen({required this.repository, super.key});
  final MeetingRepository repository;

  @override
  State<MeetingRoomsManagementScreen> createState() =>
      _MeetingRoomsManagementScreenState();
}

class _MeetingRoomsManagementScreenState
    extends State<MeetingRoomsManagementScreen> {
  bool _loading = true;
  List<MeetingRoom> _rooms = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rooms = await widget.repository.rooms();
      if (mounted) setState(() => _rooms = rooms);
    } catch (error) {
      if (mounted) _message('$error', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editRoom([MeetingRoom? room]) async {
    final name = TextEditingController(text: room?.name ?? '');
    final description = TextEditingController(text: room?.description ?? '');
    final capacityValue = room?.capacity ?? 0;
    final capacity = TextEditingController(
      text: capacityValue == 0 ? '' : '$capacityValue',
    );
    var isActive = room?.isActive ?? true;
    final accepted = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text(
                room == null ? 'إضافة قاعة اجتماع' : 'تعديل قاعة الاجتماع',
              ),
              content: StatefulBuilder(
                builder:
                    (context, setDialogState) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: name,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'اسم القاعة',
                          ),
                        ),
                        TextField(
                          controller: capacity,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'السعة (اختياري)',
                          ),
                        ),
                        TextField(
                          controller: description,
                          decoration: const InputDecoration(
                            labelText: 'وصف (اختياري)',
                          ),
                        ),
                        if (room != null)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: isActive,
                            onChanged:
                                (value) =>
                                    setDialogState(() => isActive = value),
                            title: const Text('متاحة للحجز'),
                            subtitle: const Text(
                              'إيقافها يمنع أي حجوزات جديدة مع حفظ السجل السابق.',
                            ),
                          ),
                      ],
                    ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('حفظ'),
                ),
              ],
            ),
          ),
    );
    if (accepted != true || name.text.trim().isEmpty) return;
    try {
      await widget.repository.saveRoom(
        name: name.text.trim(),
        description: description.text.trim(),
        capacity: int.tryParse(capacity.text.trim()),
        roomId: room?.id,
        isActive: isActive,
      );
      _message(room == null ? 'تمت إضافة القاعة.' : 'تم حفظ تعديلات القاعة.');
      await _load();
    } catch (error) {
      if (mounted) _message('$error', error: true);
    } finally {
      name.dispose();
      description.dispose();
      capacity.dispose();
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('إدارة قاعات الاجتماعات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _editRoom,
        icon: const Icon(Icons.add),
        label: const Text('إضافة قاعة'),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _load,
                child:
                    _rooms.isEmpty
                        ? ListView(
                          children: const [
                            SizedBox(height: 180),
                            Center(child: Text('لا توجد قاعات متاحة.')),
                          ],
                        )
                        : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _rooms.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 8),
                          itemBuilder:
                              (_, index) => Card(
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.meeting_room_outlined,
                                  ),
                                  title: Text(_rooms[index].name),
                                  subtitle: Text(
                                    _rooms[index].isActive
                                        ? (_rooms[index].capacity > 0
                                            ? 'متاحة للطلبات الجديدة · السعة ${_rooms[index].capacity}'
                                            : 'متاحة للطلبات الجديدة')
                                        : 'غير متاحة للحجوزات الجديدة',
                                  ),
                                  trailing: IconButton(
                                    tooltip: 'تعديل',
                                    onPressed: () => _editRoom(_rooms[index]),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                ),
                              ),
                        ),
              ),
    ),
  );
}
