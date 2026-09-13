import 'package:flutter/material.dart';

import '../../../../theme/theme.dart';
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
        color: ZaWolfColors.surface01,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ZaWolfColors.surface03,
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
                  color: ZaWolfColors.primaryCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.campaign_rounded,
                  color: ZaWolfColors.primaryCyan,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'إعلانات وتنويهات الشركة الرسمية',
                style: TextStyle(
                  color: ZaWolfColors.textPrimary,
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
        color: ZaWolfColors.surface02,
        borderRadius: BorderRadius.circular(12),
        border: isPinned
            ? Border.all(color: ZaWolfColors.warning.withValues(alpha: 0.4))
            : Border.all(color: ZaWolfColors.surface03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isPinned) ...[
                const Icon(
                  Icons.push_pin_rounded,
                  color: ZaWolfColors.warning,
                  size: 14,
                ),
                const SizedBox(width: 4),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPinned
                      ? ZaWolfColors.warning.withValues(alpha: 0.2)
                      : ZaWolfColors.dayoffPurple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: isPinned
                        ? ZaWolfColors.warning
                        : ZaWolfColors.dayoffPurple,
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
                    color: ZaWolfColors.textPrimary,
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
              style: const TextStyle(color: ZaWolfColors.textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
