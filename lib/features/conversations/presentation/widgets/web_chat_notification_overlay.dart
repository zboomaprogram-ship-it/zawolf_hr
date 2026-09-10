import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../components/wolf_card.dart';
import '../../../../theme/theme.dart';
import '../../domain/in_app_notification_alert.dart';

/// Floating in-app toast notification overlay for Web and Desktop.
/// Listens to incoming chat messages and alerts, showing an interactive popup
/// that allows immediate reply and navigation.
class WebChatNotificationOverlay extends StatefulWidget {
  final Widget child;
  final InAppNotificationAlerts notifications;

  const WebChatNotificationOverlay({
    super.key,
    required this.child,
    required this.notifications,
  });

  @override
  State<WebChatNotificationOverlay> createState() =>
      _WebChatNotificationOverlayState();
}

class _WebChatNotificationOverlayState
    extends State<WebChatNotificationOverlay> {
  StreamSubscription<InAppNotificationAlert>? _subscription;
  InAppNotificationAlert? _activeToast;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _subscription = widget.notifications.alerts.listen(_handleIncomingToast);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _handleIncomingToast(InAppNotificationAlert toast) {
    if (!mounted) return;
    _dismissTimer?.cancel();
    setState(() {
      _activeToast = toast;
    });

    _dismissTimer = Timer(const Duration(seconds: 7), () {
      if (mounted && _activeToast?.id == toast.id) {
        setState(() {
          _activeToast = null;
        });
      }
    });
  }

  void _dismissActiveToast() {
    _dismissTimer?.cancel();
    if (mounted) {
      setState(() {
        _activeToast = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final toast = _activeToast;

    return Stack(
      children: [
        widget.child,
        if (toast != null)
          PositionedDirectional(
            top: 24,
            end: 24,
            child: Material(
              type: MaterialType.transparency,
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                tween: Tween<double>(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, -20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: SizedBox(
                  width: 360,
                  child: WolfCard(
                    borderColor:
                        toast.isChatMessage
                            ? ZaWolfColors.primaryCyan
                            : ZaWolfColors.warning,
                    borderWidth: 1.5,
                    shadowColor:
                        toast.isChatMessage
                            ? ZaWolfColors.primaryCyan
                            : ZaWolfColors.warning,
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: (toast.isChatMessage
                                    ? ZaWolfColors.primaryCyan
                                    : ZaWolfColors.warning)
                                .withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  toast.isChatMessage
                                      ? ZaWolfColors.primaryCyan
                                      : ZaWolfColors.warning,
                              width: 1.2,
                            ),
                          ),
                          child: Icon(
                            toast.isChatMessage
                                ? Icons.mark_chat_unread_rounded
                                : Icons.notifications_active_rounded,
                            color:
                                toast.isChatMessage
                                    ? ZaWolfColors.primaryCyan
                                    : ZaWolfColors.warning,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      toast.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textDirection: TextDirection.rtl,
                                    ),
                                  ),
                                  Text(
                                    toast.isChatMessage ? 'رسالة' : 'تنبيه',
                                    style: TextStyle(
                                      color:
                                          toast.isChatMessage
                                              ? ZaWolfColors.primaryCyan
                                              : ZaWolfColors.warning,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                toast.body,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textDirection: TextDirection.rtl,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: _dismissActiveToast,
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                    ),
                                    child: const Text(
                                      'إغلاق',
                                      style: TextStyle(
                                        color: ZaWolfColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      _dismissActiveToast();
                                      unawaited(
                                        widget.notifications.open(toast),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.reply_rounded,
                                      size: 15,
                                    ),
                                    label: const Text('عرض الرد'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: ZaWolfColors.primaryCyan,
                                      foregroundColor: Colors.black,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
