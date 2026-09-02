import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/theme.dart';
import '../services/performance_badge_service.dart';

final class BadgeCelebrationDialog extends StatefulWidget {
  const BadgeCelebrationDialog({
    super.key,
    required this.userId,
    required this.userName,
    required this.department,
    required this.badgeId,
    required this.badgeTitle,
    required this.badgeDescription,
    required this.iconData,
    required this.color,
  });

  final String userId;
  final String userName;
  final String department;
  final String badgeId;
  final String badgeTitle;
  final String badgeDescription;
  final IconData iconData;
  final Color color;

  static Future<void> show(
    BuildContext context, {
    required String userId,
    required String userName,
    required String department,
    required String badgeId,
    required String badgeTitle,
    required String badgeDescription,
    required IconData iconData,
    required Color color,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => BadgeCelebrationDialog(
            userId: userId,
            userName: userName,
            department: department,
            badgeId: badgeId,
            badgeTitle: badgeTitle,
            badgeDescription: badgeDescription,
            iconData: iconData,
            color: color,
          ),
    );
  }

  @override
  State<BadgeCelebrationDialog> createState() => _BadgeCelebrationDialogState();
}

class _BadgeCelebrationDialogState extends State<BadgeCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _sharing = false;
  bool _shared = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // Mark celebration as seen so it doesn't trigger again on reload
    PerformanceBadgeService.instance.markCelebrationBadgeAsSeen(
      userId: widget.userId,
      badgeId: widget.badgeId,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _shareToChat() async {
    setState(() => _sharing = true);
    try {
      await PerformanceBadgeService.instance.shareBadgeToDepartmentChat(
        senderId: widget.userId,
        senderName: widget.userName,
        department: widget.department,
        badgeTitle: widget.badgeTitle,
        badgeDescription: widget.badgeDescription,
      );
      if (mounted) {
        setState(() {
          _sharing = false;
          _shared = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Confetti sparkles background
            AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(340, 420),
                  painter: _ConfettiPainter(progress: _animController.value),
                );
              },
            ),

            // Card body
            Container(
              width: 320,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: widget.color.withValues(alpha: 0.6),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.35),
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Glowing Badge Icon Avatar
                  AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      final scale = 1.0 + (_animController.value * 0.08);
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.color.withValues(alpha: 0.2),
                            border: Border.all(color: widget.color, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: widget.color.withValues(alpha: 0.5),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            widget.iconData,
                            color: widget.color,
                            size: 46,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    '🎉 مبروك! إنجاز جديد',
                    style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),

                  Text(
                    widget.badgeTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  Text(
                    widget.badgeDescription,
                    style: const TextStyle(
                      color: ZaWolfColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Share to Department Chat Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.color,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      onPressed: _sharing || _shared ? null : _shareToChat,
                      icon:
                          _sharing
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                              : Icon(
                                _shared
                                    ? Icons.check_circle_rounded
                                    : Icons.send_rounded,
                              ),
                      label: Text(
                        _shared
                            ? 'تمت المشاركة في الشات! ✓'
                            : 'مشاركة الإنجاز في شات القسم',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Close button
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'إغلاق',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  _ConfettiPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(42);
    final colors = [
      const Color(0xFFFFD700),
      const Color(0xFF38BDF8),
      const Color(0xFFA78BFA),
      const Color(0xFF10B981),
      const Color(0xFFFB7185),
    ];

    for (var i = 0; i < 36; i++) {
      final angle = (i * 10) * math.pi / 180;
      final dist = (80 + rand.nextDouble() * 120) * (0.8 + (progress * 0.2));
      final dx = size.width / 2 + math.cos(angle) * dist;
      final dy = size.height / 2 + math.sin(angle) * dist;
      final paint =
          Paint()..color = colors[i % colors.length].withValues(alpha: 0.85);

      if (i % 2 == 0) {
        canvas.drawCircle(Offset(dx, dy), 4 + rand.nextDouble() * 4, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(dx, dy),
            width: 7,
            height: 7,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
