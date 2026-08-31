import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/company_announcement.dart';
import '../../domain/repositories/company_announcement_repository.dart';

final class FirestoreCompanyAnnouncementRepository
    implements CompanyAnnouncementRepository {
  FirestoreCompanyAnnouncementRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<CompanyAnnouncement>> watchLatest({int limit = 3}) => _firestore
      .collection('announcements')
      .orderBy('createdAt', descending: true)
      .limit(limit.clamp(1, 20))
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(
              (doc) => CompanyAnnouncement(
                id: doc.id,
                title: doc.data()['title']?.toString() ?? 'تنويه رسمي',
                body: doc.data()['body']?.toString() ?? '',
                category: doc.data()['category']?.toString() ?? 'عام',
                isPinned: doc.data()['isPinned'] == true,
              ),
            )
            .toList(growable: false),
      );
}
