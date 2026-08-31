import '../entities/company_announcement.dart';

abstract interface class CompanyAnnouncementRepository {
  Stream<List<CompanyAnnouncement>> watchLatest({int limit = 3});
}
