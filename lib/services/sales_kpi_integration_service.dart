import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

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
  }) async {
    final periodKey = filters.startDate.length >= 7
        ? filters.startDate.substring(0, 7)
        : '';
    await _db.collection('salesKpiSettings').doc('current').set({
      ...filters.toMap(),
      'periodKey': periodKey,
      'updatedBy': actorId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await triggerSync(
      startDate: filters.startDate,
      endDate: filters.endDate,
      filters: filters,
    );
  }

  Future<void> updateActivePeriod({
    required String periodKey,
    required String startDate,
    required String endDate,
    required String actorId,
  }) async {
    await _db.collection('salesKpiSettings').doc('current').set({
      'periodKey': periodKey,
      'startDate': startDate,
      'endDate': endDate,
      'updatedBy': actorId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await triggerSync(startDate: startDate, endDate: endDate);
  }

  Future<bool> triggerSync({
    String? startDate,
    String? endDate,
    SalesKpiFilters? filters,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final token = await user.getIdToken();
      final body = <String, dynamic>{};
      if (filters != null) {
        body.addAll(filters.toMap());
      }
      if (startDate != null && startDate.trim().isNotEmpty) {
        body['startDate'] = startDate.trim();
      }
      if (endDate != null && endDate.trim().isNotEmpty) {
        body['endDate'] = endDate.trim();
      }
      final response = await http.post(
        Uri.parse('https://notification.zawolf.ai/operations/sales-indicators/sync'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
      return response.statusCode == 200 || response.statusCode == 202;
    } catch (_) {
      return false;
    }
  }
}
