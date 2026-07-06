import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;
import '../../services/auth_service.dart';
import '../../services/request_log_service.dart';
import '../../theme/theme.dart';
import '../../components/wolf_card.dart';

class RequestsLogScreen extends StatefulWidget {
  const RequestsLogScreen({super.key});

  @override
  State<RequestsLogScreen> createState() => _RequestsLogScreenState();
}

class _RequestsLogScreenState extends State<RequestsLogScreen> {
  late Future<List<RequestLogItem>> _logsFuture;
  String _statusFilter = 'all'; // 'all' | 'approved' | 'rejected'
  String _typeFilter = 'all'; // 'all' | 'leave' | 'permission' | 'advance'

  @override
  void initState() {
    super.initState();
    _refreshLogs();
  }

  void _refreshLogs() {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user != null) {
      setState(() {
        _logsFuture = RequestLogService.instance.getMonthlyLogs(user);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل طلبات الشهر'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner informing users it's current month only
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: ZaWolfColors.primaryCyan.withValues(alpha: 0.1),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, color: ZaWolfColors.primaryCyan, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'يعرض هذا السجل الطلبات التي تم البت فيها خلال الشهر الحالي فقط لتسريع الأداء.',
                    style: TextStyle(color: ZaWolfColors.primaryCyan, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          // Filters row
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // Type Filter Dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _typeFilter,
                    dropdownColor: ZaWolfColors.surface01,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: ZaWolfColors.surface01,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('جميع الأنواع')),
                      DropdownMenuItem(value: 'leave', child: Text('الإجازات')),
                      DropdownMenuItem(value: 'permission', child: Text('الأذونات')),
                      DropdownMenuItem(value: 'advance', child: Text('السلف')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _typeFilter = val);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Status Filter Dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _statusFilter,
                    dropdownColor: ZaWolfColors.surface01,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: ZaWolfColors.surface01,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('جميع الحالات')),
                      DropdownMenuItem(value: 'approved', child: Text('المقبولة')),
                      DropdownMenuItem(value: 'rejected', child: Text('المرفوضة')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _statusFilter = val);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: FutureBuilder<List<RequestLogItem>>(
              future: _logsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'حدث خطأ أثناء تحميل السجلات: ${snapshot.error}',
                      style: const TextStyle(color: ZaWolfColors.error),
                    ),
                  );
                }

                final allLogs = snapshot.data ?? [];
                
                // Filter client side
                final filteredLogs = allLogs.where((log) {
                  final matchesType = _typeFilter == 'all' || log.type == _typeFilter;
                  final matchesStatus = _statusFilter == 'all' || log.status == _statusFilter;
                  return matchesType && matchesStatus;
                }).toList();

                if (filteredLogs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off, color: ZaWolfColors.textMuted, size: 64),
                        SizedBox(height: 16),
                        Text(
                          'لا توجد سجلات مطابقة للشهر الحالي.',
                          style: TextStyle(color: ZaWolfColors.textMuted),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _refreshLogs(),
                  color: ZaWolfColors.primaryCyan,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      final item = filteredLogs[index];
                      final isApproved = item.status == 'approved';
                      final dateStr = intl.DateFormat('yyyy/MM/dd hh:mm a').format(item.reviewedAt);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: WolfCard(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Status Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: (isApproved ? ZaWolfColors.success : ZaWolfColors.error).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: (isApproved ? ZaWolfColors.success : ZaWolfColors.error).withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Text(
                                        isApproved ? 'مقبول' : 'مرفوض',
                                        style: TextStyle(
                                          color: isApproved ? ZaWolfColors.success : ZaWolfColors.error,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    // Request Type Badge
                                    Row(
                                      children: [
                                        Icon(_getTypeIcon(item.type), color: ZaWolfColors.primaryCyan, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          item.requestType,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Details
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      item.details,
                                      style: const TextStyle(color: ZaWolfColors.primaryCyan, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      'الموظف: ${item.employeeName}',
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                  ],
                                ),
                                const Divider(color: ZaWolfColors.surface02, height: 20),
                                // Metadata
                                if (item.reason.isNotEmpty) ...[
                                  Text(
                                    'السبب: ${item.reason}',
                                    style: const TextStyle(color: ZaWolfColors.textSecondary, fontSize: 12),
                                    textDirection: TextDirection.rtl,
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'تاريخ الرد: $dateStr',
                                      style: const TextStyle(color: ZaWolfColors.textMuted, fontSize: 11),
                                    ),
                                    if (item.reviewedBy.isNotEmpty)
                                      Text(
                                        'بواسطة: ${item.reviewedBy}',
                                        style: const TextStyle(color: ZaWolfColors.textMuted, fontSize: 11),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'leave': return Icons.beach_access;
      case 'permission': return Icons.access_time;
      case 'advance': return Icons.monetization_on;
      default: return Icons.help_outline;
    }
  }
}
