import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/company_day_off_model.dart';
import '../models/company_day_off_status.dart';

class CompanyDayOffService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<CompanyDayOffStatus> getDayOffStatus(DateTime date) async {
    if (date.weekday == DateTime.friday) {
      return const CompanyDayOffStatus(isDayOff: true, reason: 'عطلة الجمعة');
    }

    final key = CompanyDayOffModel.keyFor(date);

    try {
      final doc = await _db.collection('companyDayOffs').doc(key).get();
      if (doc.exists) {
        final dayOff = CompanyDayOffModel.fromFirestore(doc);
        if (dayOff.isActive) {
          return CompanyDayOffStatus(isDayOff: true, reason: dayOff.title);
        }
      }
    } catch (_) {
      final cached = await _db
          .collection('companyDayOffs')
          .doc(key)
          .get(const GetOptions(source: Source.cache));
      if (cached.exists) {
        final dayOff = CompanyDayOffModel.fromFirestore(cached);
        if (dayOff.isActive) {
          return CompanyDayOffStatus(isDayOff: true, reason: dayOff.title);
        }
      }
    }

    return const CompanyDayOffStatus.workDay();
  }

  Stream<List<CompanyDayOffModel>> watchDayOffs() {
    return _db.collection('companyDayOffs').snapshots().map((snapshot) {
      final days = snapshot.docs
          .map((doc) => CompanyDayOffModel.fromFirestore(doc))
          .toList();
      days.sort((a, b) => b.date.compareTo(a.date));
      return days;
    });
  }

  Future<void> saveDayOff({
    required DateTime date,
    required String title,
    required String createdBy,
  }) async {
    final key = CompanyDayOffModel.keyFor(date);
    await _db
        .collection('companyDayOffs')
        .doc(key)
        .set(
          CompanyDayOffModel(
            dayOffId: key,
            date: key,
            title: title.trim().isEmpty ? 'عطلة رسمية' : title.trim(),
            isActive: true,
            createdBy: createdBy,
          ).toFirestore(),
        );
  }

  Future<void> setActive(String dayOffId, bool isActive) async {
    await _db.collection('companyDayOffs').doc(dayOffId).update({
      'isActive': isActive,
    });
  }
}
