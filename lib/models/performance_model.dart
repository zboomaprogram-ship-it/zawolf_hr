import 'package:cloud_firestore/cloud_firestore.dart';

class PerformanceModel {
  final String performanceId;
  final String userId;
  final String employeeId;
  final String employeeName;
  final String monthKey; // YYYY-MM
  final double attendanceScore;
  final double punctualityScore;
  final double qualityScore;
  final double teamworkScore;
  final double commitmentScore;
  final double overallScore;
  final String grade; // 'A' | 'B' | 'C' | 'D' | 'F'
  final String? comments;
  final DateTime? publishedAt;
  final String managerId;

  PerformanceModel({
    required this.performanceId,
    required this.userId,
    required this.employeeId,
    required this.employeeName,
    required this.monthKey,
    required this.attendanceScore,
    required this.punctualityScore,
    required this.qualityScore,
    required this.teamworkScore,
    required this.commitmentScore,
    required this.overallScore,
    required this.grade,
    this.comments,
    this.publishedAt,
    required this.managerId,
  });

  factory PerformanceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PerformanceModel(
      performanceId: doc.id,
      userId: data['userId'] as String? ?? '',
      employeeId: data['employeeId'] as String? ?? '',
      employeeName: data['employeeName'] as String? ?? '',
      monthKey: data['monthKey'] as String? ?? '',
      attendanceScore: (data['attendanceScore'] as num? ?? 100.0).toDouble(),
      punctualityScore: (data['punctualityScore'] as num? ?? 100.0).toDouble(),
      qualityScore: (data['qualityScore'] as num? ?? 100.0).toDouble(),
      teamworkScore: (data['teamworkScore'] as num? ?? 100.0).toDouble(),
      commitmentScore: (data['commitmentScore'] as num? ?? 100.0).toDouble(),
      overallScore: (data['overallScore'] as num? ?? 100.0).toDouble(),
      grade: data['grade'] as String? ?? 'A',
      comments: data['comments'] as String?,
      publishedAt: (data['publishedAt'] as Timestamp?)?.toDate(),
      managerId: data['managerId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'monthKey': monthKey,
      'attendanceScore': attendanceScore,
      'punctualityScore': punctualityScore,
      'qualityScore': qualityScore,
      'teamworkScore': teamworkScore,
      'commitmentScore': commitmentScore,
      'overallScore': overallScore,
      'grade': grade,
      if (comments != null) 'comments': comments,
      'publishedAt': publishedAt != null
          ? Timestamp.fromDate(publishedAt!)
          : FieldValue.serverTimestamp(),
      'managerId': managerId,
    };
  }
}
