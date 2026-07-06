import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';

class SmartAssistantService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String> ask(String query, UserModel user) async {
    final q = query.toLowerCase().trim();

    final isManager = user.role == 'manager' || user.role == 'hr_admin' || user.role == 'super_admin';
    if (!isManager) {
      return 'عذراً، هذا المساعد مخصص للمديرين ومسؤولي الموارد البشرية فقط.';
    }
    if (isManager) {
      if (q.contains('مين غايب') || q.contains('الغياب')) {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        
        // Find users with check-in today
        final attendanceSnap = await _db.collection('attendance')
            .where('date', isEqualTo: today)
            .get();
        final presentIds = attendanceSnap.docs.map((doc) => doc.data()['userId'] as String).toSet();

        // Get all active users
        Query<Map<String, dynamic>> usersQuery = _db.collection('users').where('isActive', isEqualTo: true);
        if (user.role == 'manager') {
          usersQuery = usersQuery.where('managerId', isEqualTo: user.uid);
        }
        final usersSnap = await usersQuery.get();
        final allUsers = usersSnap.docs.map(UserModel.fromFirestore).toList();

        final absentUsers = allUsers.where((u) => !presentIds.contains(u.uid) && u.role != 'super_admin').toList();

        if (absentUsers.isEmpty) {
          return 'الجميع حاضر اليوم!';
        }
        final names = absentUsers.map((u) => u.displayName).join('، ');
        return 'الموظفون الغائبون اليوم: $names.';
      }

      if (q.contains('مين حضر') || q.contains('حضور')) {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        
        Query<Map<String, dynamic>> usersQuery = _db.collection('users').where('isActive', isEqualTo: true);
        if (user.role == 'manager') {
          usersQuery = usersQuery.where('managerId', isEqualTo: user.uid);
        }
        final usersSnap = await usersQuery.get();
        final relevantUserIds = usersSnap.docs.map((d) => d.id).toSet();

        final attendanceSnap = await _db.collection('attendance')
            .where('date', isEqualTo: today)
            .get();
            
        final presentCount = attendanceSnap.docs
            .map((doc) => doc.data()['userId'] as String)
            .where((uid) => relevantUserIds.contains(uid))
            .length;

        if (presentCount == 0) {
          return 'لم يحضر أحد حتى الآن.';
        }
        return 'حضر اليوم $presentCount موظفاً.';
      }
      
      if (q.contains('مهام متاخرة') || q.contains('مهام متأخرة')) {
        Query<Map<String, dynamic>> query = _db.collection('tasks')
            .where('dueDate', isLessThan: Timestamp.now())
            .where('status', whereIn: ['new', 'in_progress']);
            
        if (user.role == 'manager') {
          query = query.where('managerId', isEqualTo: user.uid);
        }
        final snap = await query.get();
        if (snap.docs.isEmpty) {
          return 'لا توجد مهام متأخرة!';
        }
        return 'هناك ${snap.docs.length} مهام متأخرة عن موعدها التسليم.';
      }
    }

    // Default response
    return 'عذراً، لم أفهم سؤالك. يمكنك سؤالي عن:\n- مين غايب اليوم\n- المهام المتأخرة\n- نسبة الحضور';
  }
}
