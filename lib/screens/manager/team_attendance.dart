import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../services/auth_service.dart';
import '../../theme/theme.dart';
import '../../components/wolf_card.dart';

class TeamAttendanceScreen extends StatefulWidget {
  const TeamAttendanceScreen({super.key});

  @override
  State<TeamAttendanceScreen> createState() => _TeamAttendanceScreenState();
}

class _TeamAttendanceScreenState extends State<TeamAttendanceScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DateTime _selectedDate = DateTime.now();
  String _selectedStatus =
      'all'; // 'all' | 'present' | 'late' | 'absent' | 'on-leave'

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: ZaWolfColors.primaryCyan,
              onPrimary: ZaWolfColors.background,
              surface: ZaWolfColors.surface01,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final manager = authService.currentUser;
    final theme = Theme.of(context);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    if (manager == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
        ),
      );
    }

    // Build Firestore query
    Query query = _db
        .collection('attendance')
        .where('managerId', isEqualTo: manager.uid)
        .where('date', isEqualTo: dateStr);

    if (_selectedStatus != 'all') {
      query = query.where('status', isEqualTo: _selectedStatus);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'حضور وانصراف الفريق',
          style: theme.textTheme.headlineMedium,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Section Panel
          Container(
            padding: const EdgeInsets.all(16),
            color: ZaWolfColors.surface01,
            child: Column(
              children: [
                // Date picker trigger
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () => _selectDate(context),
                      icon: const Icon(
                        Icons.calendar_today,
                        color: ZaWolfColors.primaryCyan,
                        size: 18,
                      ),
                      label: Text(
                        DateFormat('yyyy-MM-dd').format(_selectedDate),
                        style: const TextStyle(
                          color: ZaWolfColors.primaryCyan,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      'التاريخ المختار',
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: ZaWolfColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Status Filter Chips
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('الكل', 'all'),
                        const SizedBox(width: 8),
                        _buildFilterChip('حاضر', 'present'),
                        const SizedBox(width: 8),
                        _buildFilterChip('متأخر', 'late'),
                        const SizedBox(width: 8),
                        _buildFilterChip('غائب', 'absent'),
                        const SizedBox(width: 8),
                        _buildFilterChip('إجازة', 'on-leave'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Stream Results
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: ZaWolfColors.primaryCyan,
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.group_off_outlined,
                          color: ZaWolfColors.textMuted,
                          size: 56,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'لا توجد سجلات مطابقة للفلاتر المحددة.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final name = data['employeeName'] as String? ?? '';
                    final empId = data['employeeId'] as String? ?? '';
                    final status = data['status'] as String? ?? 'present';
                    final checkIn = data['checkInTime'] as Timestamp?;
                    final checkOut = data['checkOutTime'] as Timestamp?;
                    final totalHours = (data['totalWorkHours'] as num?)
                        ?.toDouble();
                    final inGeofence =
                        data['isWithinGeofence'] as bool? ?? true;
                    final lateMinutes = data['lateMinutes'] as int? ?? 0;

                    Color statusColor = ZaWolfColors.success;
                    String statusLabel = 'في الميعاد';

                    if (status == 'late') {
                      statusColor = ZaWolfColors.warning;
                      statusLabel = 'متأخر $lateMinutes دقيقة';
                    } else if (status == 'absent') {
                      statusColor = ZaWolfColors.error;
                      statusLabel = 'غائب';
                    } else if (status == 'on-leave') {
                      statusColor = ZaWolfColors.primaryBlue;
                      statusLabel = 'إجازة رسمية';
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      key: ValueKey(docs[index].id),
                      child: WolfCard(
                        hasBorderGlow: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          name,
                                          style: theme.textTheme.titleMedium!
                                              .copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        Text(
                                          'كود: $empId',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 10),
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: ZaWolfColors.surface02,
                                      child: Text(
                                        name.substring(0, 1),
                                        style: const TextStyle(
                                          color: ZaWolfColors.primaryCyan,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(
                              color: ZaWolfColors.surface02,
                              height: 20,
                            ),

                            // Log Details
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'الانصراف: ${checkOut != null ? DateFormat('hh:mm a').format(checkOut.toDate()) : '—'}',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    Text(
                                      'ساعات العمل: ${totalHours != null ? '${totalHours.toStringAsFixed(1)} ساعة' : '—'}',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'الحضور: ${checkIn != null ? DateFormat('hh:mm a').format(checkIn.toDate()) : '—'}',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          inGeofence
                                              ? 'داخل النطاق ✓'
                                              : 'خارج النطاق ⚠️',
                                          style: TextStyle(
                                            color: inGeofence
                                                ? ZaWolfColors.success
                                                : ZaWolfColors.error,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          ' :النطاق الجغرافي',
                                          style: theme.textTheme.bodyMedium!
                                              .copyWith(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final active = _selectedStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedStatus = value;
          });
        }
      },
      selectedColor: ZaWolfColors.primaryCyan,
      backgroundColor: ZaWolfColors.surface02,
      labelStyle: TextStyle(
        color: active ? ZaWolfColors.background : ZaWolfColors.textSecondary,
        fontWeight: active ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
