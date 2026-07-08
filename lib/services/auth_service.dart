import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/employee_role.dart';
import 'audit_log_service.dart';
import 'notification_service.dart';
import 'daily_reminder_service.dart';
import 'onesignal_service.dart';
import '../models/attendance_policy.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  UserModel? _currentUser;
  bool _loading = true;
  StreamSubscription<User?>? _authStateSubscription;
  int _authSessionVersion = 0;

  UserModel? get currentUser => _currentUser;
  bool get loading => _loading;
  bool get isAuthenticated => _currentUser != null;

  AuthService() {
    _init();
  }

  void _init() {
    _authStateSubscription = _auth.authStateChanges().listen((
      User? user,
    ) async {
      final sessionVersion = ++_authSessionVersion;
      NotificationService.instance.stopListening();
      await DailyReminderService.instance.cancelAll();
      if (user == null) {
        _currentUser = null;
        _loading = false;
        await OneSignalService.instance.logout();
        notifyListeners();
      } else {
        _currentUser = null;
        _loading = true;
        notifyListeners();

        await fetchUserData(user.uid, sessionVersion: sessionVersion);
        if (sessionVersion != _authSessionVersion) return;
        if (_currentUser != null) {
          NotificationService.instance.startListening(user.uid);
          await OneSignalService.instance.login(user.uid);
          // Schedule smart daily reminders based on employee's work schedule
          final startTime = _currentUser!.workSchedule.startTime ?? '09:00';
          final endTime = _currentUser!.workSchedule.endTime ?? '17:00';
          await DailyReminderService.instance.scheduleForUser(
            userId: user.uid,
            startTime: startTime,
            endTime: endTime,
          );
        }
      }
    });
  }

  Future<void> fetchUserData(String uid, {int? sessionVersion}) async {
    try {
      _loading = true;
      notifyListeners();

      final doc = await _db.collection('users').doc(uid).get();
      if (sessionVersion != null && sessionVersion != _authSessionVersion) {
        return;
      }
      if (doc.exists) {
        _currentUser = UserModel.fromFirestore(doc);
      } else {
        _currentUser = null;
      }
    } catch (e) {
      if (sessionVersion != null && sessionVersion != _authSessionVersion) {
        return;
      }
      if (kDebugMode) print('Error fetching user data: $e');
      _currentUser = null;
    } finally {
      if (sessionVersion == null || sessionVersion == _authSessionVersion) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  // Sign in
  Future<void> signIn(String email, String password) async {
    try {
      _loading = true;
      notifyListeners();
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      final user = _auth.currentUser;
      if (user != null) {
        await fetchUserData(user.uid);
        if (_currentUser == null || !_currentUser!.isActive) {
          await _auth.signOut();
          throw Exception('Account is disabled');
        }
      }
    } catch (e) {
      _loading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    _authSessionVersion++;
    _currentUser = null;
    _loading = false;
    NotificationService.instance.stopListening();
    await OneSignalService.instance.logout();
    await DailyReminderService.instance.cancelAll();
    notifyListeners();
    await _auth.signOut();
  }

  // Change password (reauthenticate first)
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user currently logged in');

    // Reauthenticate
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);

    // Update password in Auth
    await user.updatePassword(newPassword);

    // Log the change in Firestore
    await _db.collection('users').doc(user.uid).update({
      'passwordChangedAt': FieldValue.serverTimestamp(),
    });

    await AuditLogService.instance.record(
      actorId: user.uid,
      action: 'password_changed',
      targetCollection: 'users',
      targetId: user.uid,
    );

    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(passwordChangedAt: DateTime.now());
      notifyListeners();
    }
  }

  // Send password reset email
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // HR Admin creates a new employee account.
  // Uses a secondary temporary FirebaseApp to prevent logging out the current admin.
  Future<UserModel> createEmployeeAccount({
    required String email,
    required String displayName,
    required String role,
    required String employeeId,
    required String department,
    required String position,
    required String locationId,
    required String locationName,
    required double baseMonthlySalary,
    String salaryCurrency = 'EGP',
    int daysOffBalance = 21,
    String? managerId,
    String? managerName,
    List<String> managerIds = const [],
    List<String> managerNames = const [],
    List<String> managerCodes = const [],
  }) async {
    const initialPassword = 'ZW@0000';
    FirebaseApp? tempApp;

    try {
      const allowedRoles = [
        EmployeeRole.employee,
        EmployeeRole.manager,
        EmployeeRole.hrAdmin,
        EmployeeRole.superAdmin,
      ];
      if (!allowedRoles.contains(role)) {
        throw Exception('Invalid employee role');
      }
      if (role == EmployeeRole.superAdmin &&
          _currentUser?.role != EmployeeRole.superAdmin) {
        throw Exception('Only super admin can create super admin accounts');
      }
      if (email.trim().isEmpty ||
          displayName.trim().isEmpty ||
          employeeId.trim().isEmpty) {
        throw Exception('Email, name, and employee ID are required');
      }
      if (baseMonthlySalary < 0) {
        throw Exception('Base monthly salary cannot be negative');
      }

      // 1. Create a secondary temporary FirebaseApp
      tempApp = await Firebase.initializeApp(
        name: 'TempUserCreation_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );

      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);

      // 2. Create the user credential inside the secondary app
      final userCred = await tempAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: initialPassword,
      );

      final uid = userCred.user!.uid;

      // 3. Create the Firestore user profile document
      final userModel = UserModel(
        uid: uid,
        email: email.trim(),
        displayName: displayName.trim(),
        role: role,
        employeeId: employeeId.trim(),
        department: department.trim(),
        position: position.trim(),
        locationId: locationId,
        locationName: locationName,
        baseMonthlySalary: baseMonthlySalary,
        salaryCurrency: salaryCurrency,
        managerId: managerId,
        managerName: managerName,
        managerIds: managerIds,
        managerNames: managerNames,
        managerCodes: managerCodes,
        workSchedule: WorkSchedule(
          startTime: AttendancePolicy.defaultStartTime,
          endTime: AttendancePolicy.defaultEndTime,
          workDays: AttendancePolicy.saturdayToThursdayWorkDays,
        ),
        leaveBalance: LeaveBalance(
          annual: 21,
          sick: 14,
          casual: 7,
          daysOff: daysOffBalance,
        ),
        permissionBalance: PermissionBalance(
          usedThisMonth: 0,
          usedHoursThisMonth: 0.0,
          lastResetMonth:
              '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}',
        ),
      );

      await _db.collection('users').doc(uid).set(userModel.toFirestore());

      await AuditLogService.instance.record(
        actorId: _auth.currentUser?.uid ?? '',
        action: 'employee_created',
        targetCollection: 'users',
        targetId: uid,
        metadata: {
          'role': role,
          'employeeId': employeeId,
          'locationId': locationId,
          'baseMonthlySalary': baseMonthlySalary,
          'salaryCurrency': salaryCurrency,
        },
      );

      return userModel.copyWith(initialPassword: initialPassword);
    } catch (e) {
      if (kDebugMode) print('Error creating employee: $e');
      rethrow;
    } finally {
      // 4. Delete the temporary app
      if (tempApp != null) {
        await tempApp.delete();
      }
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }
}
