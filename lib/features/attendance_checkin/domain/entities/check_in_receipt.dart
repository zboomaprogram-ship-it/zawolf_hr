enum CheckInReceiptStatus { recorded, alreadyRecorded }

class CheckInReceipt {
  const CheckInReceipt({required this.attendanceId, required this.status});

  final String attendanceId;
  final CheckInReceiptStatus status;
}
