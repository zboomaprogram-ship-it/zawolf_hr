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

    // Update current summary document with new period bounds & target metrics immediately
    try {
      final currentDoc =
          await _db.collection('salesKpiSummaries').doc('current').get();
      if (currentDoc.exists && currentDoc.data() != null) {
        await _db.collection('salesKpiSummaries').doc('current').set({
          'periodStart': filters.startDate,
          'periodEnd': filters.endDate,
          'periodKey': periodKey,
          'filters': filters.toMap(),
          'salesTarget': filters.salesTarget,
          'teleSalesTarget': filters.teleTarget,
          'syncedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {}

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

    try {
      await _db.collection('salesKpiSummaries').doc('current').set({
        'periodStart': startDate,
        'periodEnd': endDate,
        'periodKey': periodKey,
        'syncedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    await triggerSync(startDate: startDate, endDate: endDate);
  }

  Future<bool> triggerSync({
    String? startDate,
    String? endDate,
    SalesKpiFilters? filters,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final periodKey = startDate != null && startDate.length >= 7
        ? startDate.substring(0, 7)
        : '';

    // 1. Write sync request, settings & update summary timestamp in Firestore
    try {
      await _db.collection('salesKpiSettings').doc('current').set({
        if (filters != null) ...filters.toMap(),
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
        if (periodKey.isNotEmpty) 'periodKey': periodKey,
        'lastSyncRequestedAt': FieldValue.serverTimestamp(),
        if (user != null) 'lastSyncRequestedBy': user.uid,
      }, SetOptions(merge: true));

      await _db.collection('salesKpiSummaries').doc('current').set({
        if (startDate != null) 'periodStart': startDate,
        if (endDate != null) 'periodEnd': endDate,
        if (periodKey.isNotEmpty) 'periodKey': periodKey,
        'syncedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _db.collection('salesKpiSyncTriggers').add({
        'requestedAt': FieldValue.serverTimestamp(),
        'requestedBy': user?.uid ?? '',
        'startDate': startDate,
        'endDate': endDate,
        'periodKey': periodKey,
        'status': 'pending',
      });
    } catch (_) {
      // Ignore Firestore permission/network errors if offline
    }

    // 2. Attempt direct HTTP trigger (non-blocking)
    if (user != null) {
      user.getIdToken().then((token) {
        if (token == null) return;
        final body = <String, dynamic>{};
        if (filters != null) body.addAll(filters.toMap());
        if (startDate != null && startDate.trim().isNotEmpty) {
          body['startDate'] = startDate.trim();
        }
        if (endDate != null && endDate.trim().isNotEmpty) {
          body['endDate'] = endDate.trim();
        }
        http
            .post(
              Uri.parse(
                'https://notification.zawolf.ai/operations/sales-indicators/sync',
              ),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 8))
            .catchError((_) => http.Response('', 500));
      }).catchError((_) {});
    }

    return true;
  }
}
