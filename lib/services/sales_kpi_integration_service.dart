import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/sales_kpi_summary.dart';

class SalesKpiIntegrationService {
  static const int historyLimit = 25;

  final FirebaseFirestore _db;

  SalesKpiIntegrationService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  Stream<SalesKpiSummary?> watchCurrentSummary() {
    return _db.collection('salesKpiSummaries').doc('current').snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data();
      return snapshot.exists && data != null
          ? SalesKpiSummary.fromMap(data)
          : null;
    });
  }

  Stream<List<SalesKpiSummary>> watchSummaryHistory() {
    return _db
        .collection('salesKpiSummaries')
        .orderBy('periodKey', descending: true)
        .limit(historyLimit)
        .snapshots()
        .map((snapshot) {
          final summaries = snapshot.docs
              .where((doc) => doc.id != 'current')
              .map((doc) => SalesKpiSummary.fromMap(doc.data()))
              .where((summary) => summary.periodKey.isNotEmpty)
              .toList();
          summaries.sort((a, b) => b.periodKey.compareTo(a.periodKey));
          return summaries;
        });
  }

  Stream<SalesKpiFilters?> watchFilters() {
    return _db
        .collection('salesKpiSettings')
        .doc('current')
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          return snapshot.exists && data != null
              ? SalesKpiFilters.fromMap(data)
              : null;
        });
  }

  Future<void> updateFilters({
    required SalesKpiFilters filters,
    required String actorId,
  }) {
    final periodKey = filters.startDate.length >= 7
        ? filters.startDate.substring(0, 7)
        : '';
    return _db.collection('salesKpiSettings').doc('current').set({
      ...filters.toMap(),
      'periodKey': periodKey,
      'updatedBy': actorId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateActivePeriod({
    required String periodKey,
    required String startDate,
    required String endDate,
    required String actorId,
  }) {
    return _db.collection('salesKpiSettings').doc('current').set({
      'periodKey': periodKey,
      'startDate': startDate,
      'endDate': endDate,
      'updatedBy': actorId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
