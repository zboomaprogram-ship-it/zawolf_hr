import 'package:flutter/material.dart';

import '../../domain/entities/company_announcement.dart';
import '../../domain/repositories/company_announcement_repository.dart';

final class AnnouncementsFeedCard extends StatelessWidget {
  const AnnouncementsFeedCard({super.key, required this.repository});

  final CompanyAnnouncementRepository repository;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF818CF8).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF818CF8).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.campaign_rounded,
                  color: Color(0xFF818CF8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'إعلانات وتنويهات الشركة الرسمية',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<CompanyAnnouncement>>(
            stream: repository.watchLatest(),
            builder: (context, snapshot) {
              final announcements = snapshot.data ?? const [];
              if (announcements.isEmpty) {
                return Column(
                  children: const [
                    _AnnouncementTile(
                      title:
                          'مرحباً بك في المنظومة التشغيلية الجديدة ZaWolf HR',
                      body:
                          'يسر الإدارة الإعلان عن تشغيل بوابة الخدمات الذاتية وإدارة الأصول والتذاكر بنجاح.',
                      isPinned: true,
                      category: 'عام',
                    ),
                    SizedBox(height: 8),
                    _AnnouncementTile(
                      title: 'تنويه: مواعيد تسجيل الحضور والانصراف',
                      body:
                          'يرجى الالتزام بتسجيل الحضور عبر البصمة المكانية والجغرافية قبل الساعة 10:00 صباحاً.',
                      isPinned: false,
                      category: 'مهم',
                    ),
                  ],
                );
              }
              return Column(
                children: announcements.map((announcement) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _AnnouncementTile(
                      title: announcement.title,
                      body: announcement.body,
                      isPinned: announcement.isPinned,
                      category: announcement.category,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  const _AnnouncementTile({
    required this.title,
    required this.body,
    required this.isPinned,
    required this.category,
  });

  final String title;
  final String body;
  final bool isPinned;
  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: isPinned
            ? Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isPinned) ...[
                const Icon(
                  Icons.push_pin_rounded,
                  color: Color(0xFFF59E0B),
                  size: 14,
                ),
                const SizedBox(width: 4),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPinned
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                      : const Color(0xFF818CF8).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: isPinned
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF818CF8),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              body,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
