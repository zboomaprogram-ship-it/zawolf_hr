import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/models/user_model.dart';

void main() {
  test(
    'session cache preserves the profile needed to restore a signed-in user',
    () {
      final user = UserModel(
        uid: 'user-1',
        email: 'employee@example.com',
        displayName: 'Test Employee',
        role: 'employee',
        employeeId: 'EMP-001',
        department: 'Engineering',
        position: 'Developer',
        locationId: 'seg',
        locationName: 'SEG',
        baseMonthlySalary: 10000,
        workSchedule: WorkSchedule(
          startTime: '09:00',
          endTime: '17:00',
          workDays: const [1, 2, 3, 4, 5, 6],
        ),
        leaveBalance: LeaveBalance(
          annual: 21,
          sick: 14,
          casual: 7,
          daysOff: 21,
        ),
        permissionBalance: PermissionBalance(
          usedThisMonth: 1,
          usedHoursThisMonth: 2,
          lastResetMonth: '2026-07',
        ),
        managerIds: const ['manager-1'],
        teamLeaderId: 'leader-1',
      );

      final restored = UserModel.fromSessionCache(user.toSessionCache());

      expect(restored.uid, user.uid);
      expect(restored.role, user.role);
      expect(restored.locationId, user.locationId);
      expect(restored.managerIds, user.managerIds);
      expect(restored.teamLeaderId, user.teamLeaderId);
      expect(restored.workSchedule.startTime, '09:00');
    },
  );
}
