import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/models/task_model.dart';

void main() {
  test('legacy task projection retains a stable linked outcome reference', () {
    final task = EmployeeTaskModel(
      taskId: 'task-1',
      title: 'متابعة العميل',
      description: '',
      assigneeId: 'employee-1',
      assigneeName: 'موظف',
      assigneeEmployeeId: 'EMP-1',
      department: 'Sales',
      managerId: 'manager-1',
      createdBy: 'manager-1',
      createdByName: 'مدير',
      priority: TaskPriority.medium,
      status: TaskStatus.inProgress,
      dueDate: DateTime(2026, 8, 25),
      source: 'work_outcome',
      sourceId: 'outcome-1',
      sourceMetricKey: 'kpi-1',
    );

    final data = task.toFirestore();
    expect(data['source'], 'work_outcome');
    expect(data['sourceId'], 'outcome-1');
    expect(data['sourceMetricKey'], 'kpi-1');
  });
}
