import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../theme/theme.dart';
import '../../../models/user_model.dart';
import 'avatar_customizer_sheet.dart';

enum OfficeDepartmentHotspot {
  companyGate,
  hrOffice,
  itDesk,
  financeOffice,
  managerOffice,
  archiveDept,
  chatRoom,
}

class VirtualOfficeGameWidget extends StatefulWidget {
  const VirtualOfficeGameWidget({
    super.key,
    required this.user,
    required this.onHotspotTapped,
    this.fullScreen = false,
    this.attendedToday = false,
    this.completedTasksThisWeek = 0,
  });

  final UserModel user;
  final ValueChanged<OfficeDepartmentHotspot> onHotspotTapped;
  final bool fullScreen;

  /// Visual progress only; it is never written to appraisal, payroll, or
  /// attendance records.
  final bool attendedToday;
  final int completedTasksThisWeek;

  @override
  State<VirtualOfficeGameWidget> createState() =>
      _VirtualOfficeGameWidgetState();
}

class _VirtualOfficeGameWidgetState extends State<VirtualOfficeGameWidget>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  late AnimationController _pulseController;
  late final ValueNotifier<Offset> _avatarPosition;
  Offset _targetPos = const Offset(512, 820);
  OfficeDepartmentHotspot? _approachingHotspot;
  bool _isMoving = false;
  double _avatarFacing = 1.0; // 1.0 for facing right, -1.0 for left
  OfficeDepartmentHotspot? _nearbyHotspot;

  Color get _avatarAccent => switch (widget.user.avatarAccent) {
    'violet' => const Color(0xFFA78BFA),
    'amber' => const Color(0xFFFBBF24),
    'rose' => const Color(0xFFFB7185),
    _ => ZaWolfColors.primaryCyan,
  };

  int get _visualXp =>
      (widget.attendedToday ? 50 : 0) +
      (widget.completedTasksThisWeek.clamp(0, 5) * 10);

  // Analog Joystick State
  Offset _joystickDelta = Offset.zero;
  bool _isDraggingJoystick = false;

  // The source office artwork is square. Keeping the interaction map in the
  // same coordinate space lets the entire game surface use BoxFit.cover on
  // desktop, instead of shrinking a portrait mini-map in the middle of a
  // wide dashboard.
  static const _mapSize = Size(1024, 1024);

  late final AnimationController _walkController;

  static final Map<OfficeDepartmentHotspot, Rect> _hotspots = {
    OfficeDepartmentHotspot.hrOffice: Rect.fromLTWH(128, 86, 230, 145),
    OfficeDepartmentHotspot.managerOffice: Rect.fromLTWH(408, 28, 230, 145),
    OfficeDepartmentHotspot.chatRoom: Rect.fromLTWH(694, 110, 220, 145),
    OfficeDepartmentHotspot.financeOffice: Rect.fromLTWH(185, 355, 220, 155),
    OfficeDepartmentHotspot.archiveDept: Rect.fromLTWH(650, 530, 235, 155),
    OfficeDepartmentHotspot.itDesk: Rect.fromLTWH(678, 755, 230, 150),
    OfficeDepartmentHotspot.companyGate: Rect.fromLTWH(378, 758, 255, 175),
  };

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_moveAvatarStep);

    _walkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _avatarPosition = ValueNotifier(const Offset(512, 820));
  }

  @override
  void dispose() {
    _animController.dispose();
    _walkController.dispose();
    _pulseController.dispose();
    _avatarPosition.dispose();
    super.dispose();
  }

  void _onTapCanvas(TapDownDetails details) {
    if (_isDraggingJoystick) return;
    final newTarget = Offset(
      details.localPosition.dx.clamp(38.0, _mapSize.width - 38.0).toDouble(),
      details.localPosition.dy.clamp(38.0, _mapSize.height - 38.0).toDouble(),
    );
    final dx = newTarget.dx - _avatarPosition.value.dx;
    if (dx.abs() > 2) {
      _avatarFacing = dx >= 0 ? 1.0 : -1.0;
    }

    setState(() {
      _targetPos = newTarget;
      _approachingHotspot = null;
      _isMoving = true;
    });

    if (!_animController.isAnimating) {
      _animController.repeat();
    }
  }

  void _updateJoystickOffset(Offset localPos) {
    const center = Offset(45, 45); // 90x90 Joystick Container
    final rawDelta = localPos - center;
    const maxRadius = 32.0;
    final distance = rawDelta.distance;
    final clampedDelta =
        distance > maxRadius
            ? Offset.fromDirection(rawDelta.direction, maxRadius)
            : rawDelta;

    final normX = clampedDelta.dx / maxRadius;
    final normY = clampedDelta.dy / maxRadius;

    if (normX.abs() > 0.05) {
      _avatarFacing = normX >= 0 ? 1.0 : -1.0;
    }

    setState(() {
      _joystickDelta = clampedDelta;
      _isDraggingJoystick = true;
      _targetPos = Offset(
        (_avatarPosition.value.dx + normX * 34)
            .clamp(38.0, _mapSize.width - 38.0)
            .toDouble(),
        (_avatarPosition.value.dy + normY * 34)
            .clamp(38.0, _mapSize.height - 38.0)
            .toDouble(),
      );
      _approachingHotspot = null;
      _isMoving = true;
    });

    if (!_animController.isAnimating) {
      _animController.repeat();
    }
  }

  void _resetJoystick() {
    setState(() {
      _joystickDelta = Offset.zero;
      _isDraggingJoystick = false;
    });
  }

  void _moveToHotspot(OfficeDepartmentHotspot hotspot) {
    final rect = _hotspots[hotspot]!;
    final target = rect.center;
    final dx = target.dx - _avatarPosition.value.dx;
    if (dx.abs() > 2) {
      _avatarFacing = dx >= 0 ? 1.0 : -1.0;
    }

    setState(() {
      _targetPos = target;
      _approachingHotspot = hotspot;
      _isMoving = true;
    });

    if (!_animController.isAnimating) {
      _animController.repeat();
    }
  }

  bool _hasPendingAction(OfficeDepartmentHotspot hotspot) =>
      widget.user.unreadNotifications > 0 &&
      (hotspot == OfficeDepartmentHotspot.hrOffice ||
          hotspot == OfficeDepartmentHotspot.archiveDept);

  Widget _buildQuickTravel() => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: const Color(0xFF0F172A).withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
    ),
    child: Wrap(
      spacing: 4,
      runSpacing: 4,
      children: _hotspots.keys
          .map((hotspot) {
            final config = _departmentConfig(hotspot);
            return Tooltip(
              message: config.title,
              child: Badge(
                isLabelVisible: _hasPendingAction(hotspot),
                alignment: Alignment.topRight,
                label: const Text('!'),
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _moveToHotspot(hotspot),
                  icon: Icon(config.icon, color: config.color, size: 19),
                ),
              ),
            );
          })
          .toList(growable: false),
    ),
  );

  void _moveAvatarStep() {
    final avatarPos = _avatarPosition.value;
    final dx = _targetPos.dx - avatarPos.dx;
    final dy = _targetPos.dy - avatarPos.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    // Check nearby hotspot
    OfficeDepartmentHotspot? foundNearby;
    for (final entry in _hotspots.entries) {
      final expandedRect = entry.value.inflate(25);
      if (expandedRect.contains(avatarPos)) {
        foundNearby = entry.key;
        break;
      }
    }
    if (_nearbyHotspot != foundNearby && mounted) {
      setState(() {
        _nearbyHotspot = foundNearby;
      });
    }

    if (_isDraggingJoystick) {
      // Continuous joystick update
      final normX = _joystickDelta.dx / 32.0;
      final normY = _joystickDelta.dy / 32.0;
      const speed = 11.0;
      final nextX =
          (avatarPos.dx + normX * speed)
              .clamp(38.0, _mapSize.width - 38.0)
              .toDouble();
      final nextY =
          (avatarPos.dy + normY * speed)
              .clamp(38.0, _mapSize.height - 38.0)
              .toDouble();
      _avatarPosition.value = Offset(nextX, nextY);
      _targetPos = Offset(
        (nextX + normX * 34).clamp(38.0, _mapSize.width - 38.0).toDouble(),
        (nextY + normY * 34).clamp(38.0, _mapSize.height - 38.0).toDouble(),
      );
      return;
    }

    if (_isMoving || _isDraggingJoystick) {
      if (!_walkController.isAnimating) {
        _walkController.repeat(reverse: true);
      }
    } else {
      if (_walkController.isAnimating) {
        _walkController.stop();
      }
    }

    if (distance < 6) {
      _avatarPosition.value = _targetPos;
      _animController.stop();
      if (_walkController.isAnimating) {
        _walkController.stop();
      }
      if (_isMoving && mounted) {
        setState(() {
          _isMoving = false;
        });
      }
      if (_approachingHotspot != null) {
        widget.onHotspotTapped(_approachingHotspot!);
        _approachingHotspot = null;
      }
      return;
    }

    const speed = 11.0;
    final stepX = (dx / distance) * speed;
    final stepY = (dy / distance) * speed;

    _avatarPosition.value = Offset(avatarPos.dx + stepX, avatarPos.dy + stepY);
  }

  void _openAvatarCustomizer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AvatarCustomizerSheet(user: widget.user),
    );
  }

  void _toggleFullScreen() {
    if (widget.fullScreen) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder:
            (context) => Scaffold(
              backgroundColor: const Color(0xFF050914),
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: VirtualOfficeGameWidget(
                    user: widget.user,
                    onHotspotTapped: widget.onHotspotTapped,
                    fullScreen: true,
                    attendedToday: widget.attendedToday,
                    completedTasksThisWeek: widget.completedTasksThisWeek,
                  ),
                ),
              ),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Game Header Controls with RPG Character HUD
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: ZaWolfColors.primaryCyan.withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: ZaWolfColors.primaryCyan.withValues(alpha: 0.15),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Avatar Character Button
                  Semantics(
                    button: true,
                    label: 'تخصيص الشخصية الافتراضية',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: _openAvatarCustomizer,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _avatarAccent,
                                  width: 1.5,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: _avatarAccent.withValues(
                                  alpha: 0.25,
                                ),
                                backgroundImage:
                                    widget.user.avatarFaceUrl != null
                                        ? NetworkImage(
                                          widget.user.avatarFaceUrl!,
                                        )
                                        : null,
                                child:
                                    widget.user.avatarFaceUrl == null
                                        ? Icon(
                                          widget.user.avatarGender == 'female'
                                              ? Icons.face_3
                                              : Icons.face,
                                          color: _avatarAccent,
                                          size: 20,
                                        )
                                        : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.user.displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.edit_outlined,
                                      color: _avatarAccent,
                                      size: 12,
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      'تخصيص الشخصية',
                                      style: TextStyle(
                                        color: _avatarAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip:
                        widget.fullScreen
                            ? 'إغلاق ملء الشاشة'
                            : 'فتح المكتب بملء الشاشة',
                    onPressed: _toggleFullScreen,
                    icon: Icon(
                      widget.fullScreen
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                      color: _avatarAccent,
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: ZaWolfColors.primaryCyan.withValues(
                              alpha: 0.2 + (_pulseController.value * 0.3),
                            ),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.gamepad_rounded,
                              color: ZaWolfColors.primaryCyan,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'استخدم عصا التحكم Joystick أو المس الخريطة',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Display-only game progress. It never changes performance,
              // payroll, or attendance data.
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _avatarAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _avatarAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.verified_user_rounded,
                          color: _avatarAccent,
                          size: 12,
                        ),
                        SizedBox(width: 4),
                        Text(
                          widget.user.position.isEmpty
                              ? 'عضو الفريق'
                              : widget.user.position,
                          style: TextStyle(
                            color: _avatarAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.amberAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: Colors.amberAccent,
                          size: 12,
                        ),
                        SizedBox(width: 4),
                        Text(
                          widget.attendedToday
                              ? 'حضور اليوم ✓'
                              : 'لم يُسجل حضور اليوم',
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'تقدم مرئي فقط ولا يغيّر تقييم الأداء',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.purpleAccent.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        'XP $_visualXp · مهام ${widget.completedTasksThisWeek}',
                        style: const TextStyle(
                          color: Colors.purpleAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Interactive 3D Isometric Map Canvas
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0B101D),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.topCenter,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: 0.30,
                    child: Image.asset(
                      'assets/images/iso_office_floor_bg.png',
                      fit: BoxFit.cover,
                      errorBuilder:
                          (context, error, stackTrace) =>
                              const SizedBox.shrink(),
                    ),
                  ),
                  ValueListenableBuilder<Offset>(
                    valueListenable: _avatarPosition,
                    builder:
                        (
                          context,
                          avatarPos,
                          _,
                        ) => TweenAnimationBuilder<Offset>(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          tween: Tween(
                            end: Offset(
                              (512 - avatarPos.dx) * 0.16,
                              (512 - avatarPos.dy) * 0.16,
                            ),
                          ),
                          builder:
                              (
                                context,
                                cameraOffset,
                                child,
                              ) => Transform.translate(
                                offset: cameraOffset,
                                child: Transform.scale(
                                  // A modest zoom plus the animated offset gives a
                                  // room-follow camera without hiding the navigation.
                                  scale: widget.fullScreen ? 1.16 : 1.08,
                                  child: child,
                                ),
                              ),
                          child: FittedBox(
                            // The playable map gets every available vertical pixel,
                            // while the same artwork fills unused desktop width behind
                            // it. This avoids both the old tiny portrait map and the
                            // cropping caused by a cover-fitted interactive surface.
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: _mapSize.width,
                              height: _mapSize.height,
                              child: GestureDetector(
                                behavior: HitTestBehavior.deferToChild,
                                onTapDown: _onTapCanvas,
                                child: Stack(
                                  children: [
                                    // Layer 0: High-Resolution 2.5D Isometric Office Floor Background Map Asset
                                    Positioned.fill(
                                      child: Image.asset(
                                        'assets/images/iso_office_floor_bg.png',
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const SizedBox.shrink(),
                                      ),
                                    ),

                                    // Layer 1: Target Trail & Path Painter
                                    ValueListenableBuilder<Offset>(
                                      valueListenable: _avatarPosition,
                                      builder: (context, avatarPos, _) {
                                        return CustomPaint(
                                          size: Size.infinite,
                                          painter: _IsometricOfficePainter(
                                            hotspots: _hotspots,
                                            avatarPos: avatarPos,
                                            targetPos: _targetPos,
                                            isMoving: _isMoving,
                                            pulseProgress:
                                                _pulseController.value,
                                          ),
                                        );
                                      },
                                    ),

                                    // Layer 2: Standalone 2.5D Department Assets
                                    ..._hotspots.entries.map((entry) {
                                      final type = entry.key;
                                      final rect = entry.value;
                                      return Positioned(
                                        left: rect.left,
                                        top: rect.top,
                                        width: rect.width,
                                        height: rect.height,
                                        child: Semantics(
                                          button: true,
                                          label: _hotspotSemantics(type),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () => _moveToHotspot(type),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              child: _buildDepartmentBadge(
                                                type,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),

                                    // Layer 3: Animated 2.5D Male Main Character Sprite with Speech Bubble
                                    ValueListenableBuilder<Offset>(
                                      valueListenable: _avatarPosition,
                                      builder: (context, avatarPos, _) {
                                        final bob =
                                            _isMoving
                                                ? math.sin(avatarPos.dx * 0.1) *
                                                    4.0
                                                : 0.0;
                                        return Positioned(
                                          left: avatarPos.dx - 60,
                                          top: avatarPos.dy - 75 + bob,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Floating RPG Speech Bubble
                                              _buildSpeechBubble(),
                                              const SizedBox(height: 4),
                                              Transform.scale(
                                                scaleX: _avatarFacing,
                                                child:
                                                    _buildAnimatedAvatarSprite(),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                  ),
                  // HUD controls intentionally live outside the transformed
                  // world. The camera follows the employee, while controls
                  // must remain anchored to the device screen.
                  Positioned(left: 14, top: 14, child: _buildQuickTravel()),
                  if (_nearbyHotspot != null)
                    Positioned(
                      right: 14,
                      bottom: 18,
                      child: _buildNearbyActionBanner(_nearbyHotspot!),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 18,
                    child: SafeArea(
                      top: false,
                      child: Center(child: _buildAnalogJoystick()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpeechBubble() {
    final nearby = _nearbyHotspot;
    final text =
        nearby != null
            ? _speechForDepartment(nearby)
            : 'المس أي قسم للتحرك وإرسال الطلبات 💬';

    return Container(
      constraints: const BoxConstraints(maxWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ZaWolfColors.primaryCyan.withValues(alpha: 0.8),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAnalogJoystick() {
    // iOS can let a parent viewport win the gesture arena.  Listening to the
    // physical pointer lifecycle guarantees the thumb returns to centre even
    // when GestureDetector does not receive its normal pan-end callback.
    return Listener(
      onPointerUp: (_) => _resetJoystick(),
      onPointerCancel: (_) => _resetJoystick(),
      child: GestureDetector(
        onPanStart: (details) => _updateJoystickOffset(details.localPosition),
        onPanUpdate: (details) => _updateJoystickOffset(details.localPosition),
        onPanEnd: (_) => _resetJoystick(),
        onPanCancel: () => _resetJoystick(),
        child: Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.75),
            shape: BoxShape.circle,
            border: Border.all(
              color: ZaWolfColors.primaryCyan.withValues(alpha: 0.6),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: ZaWolfColors.primaryCyan.withValues(alpha: 0.2),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Directional Arrow Indicators
              const Positioned(
                top: 4,
                child: Icon(
                  Icons.arrow_drop_up_rounded,
                  color: Colors.white38,
                  size: 20,
                ),
              ),
              const Positioned(
                bottom: 4,
                child: Icon(
                  Icons.arrow_drop_down_rounded,
                  color: Colors.white38,
                  size: 20,
                ),
              ),
              const Positioned(
                left: 4,
                child: Icon(
                  Icons.arrow_left_rounded,
                  color: Colors.white38,
                  size: 20,
                ),
              ),
              const Positioned(
                right: 4,
                child: Icon(
                  Icons.arrow_right_rounded,
                  color: Colors.white38,
                  size: 20,
                ),
              ),

              // Draggable Inner Thumbstick Knob
              Transform.translate(
                offset: _joystickDelta,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        ZaWolfColors.primaryCyan,
                        ZaWolfColors.primaryCyan.withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white, width: 2.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: CircleAvatar(
                      radius: 6,
                      backgroundColor: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNearbyActionBanner(OfficeDepartmentHotspot hotspot) {
    final config = _departmentConfig(hotspot);
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: config.color,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 6,
      ),
      onPressed: () => widget.onHotspotTapped(hotspot),
      icon: Icon(config.icon, size: 16),
      label: Text(
        'دخول ${config.title} ⚡',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _speechForDepartment(OfficeDepartmentHotspot type) => switch (type) {
    OfficeDepartmentHotspot.companyGate =>
      '🚪 بوابة الشركة: انقر لتسجيل الحضور',
    OfficeDepartmentHotspot.hrOffice => '📄 الموارد البشرية: إجازة، إذن، تصحيح',
    OfficeDepartmentHotspot.itDesk => '💻 الدعم التقني: عهدة أو طلب دعم',
    OfficeDepartmentHotspot.financeOffice =>
      '💰 المكتب المالي: طلب سلفة أو اعتراض',
    OfficeDepartmentHotspot.managerOffice => '👔 مكتب الإدارة: مهمة أو استقالة',
    OfficeDepartmentHotspot.archiveDept => '🗄️ قسم الأرشيف: سجل الطلبات',
    OfficeDepartmentHotspot.chatRoom => '💬 قاعة المحادثات: شات الفريق',
  };

  String _hotspotSemantics(OfficeDepartmentHotspot type) => switch (type) {
    OfficeDepartmentHotspot.companyGate => 'بوابة الشركة: فتح تسجيل الحضور',
    OfficeDepartmentHotspot.hrOffice =>
      'مكتب الموارد البشرية: طلبات الإجازة والإذن وتصحيح الحضور',
    OfficeDepartmentHotspot.itDesk => 'الدعم التقني: طلب دعم أو جهاز عهدة',
    OfficeDepartmentHotspot.financeOffice => 'المكتب المالي: السلف والاعتراضات',
    OfficeDepartmentHotspot.managerOffice =>
      'مكتب الإدارة: مهمة ميدانية أو استقالة',
    OfficeDepartmentHotspot.archiveDept => 'قسم الأرشيف: سجل الطلبات الكامل',
    OfficeDepartmentHotspot.chatRoom => 'قاعة المحادثات: شات الفريق والقسم',
  };

  Widget _buildDepartmentBadge(OfficeDepartmentHotspot type) {
    final config = _departmentConfig(type);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Standalone 2.5D Asset Model with subtle floor glow
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: config.color.withValues(alpha: 0.35),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Image.asset(
                config.assetPath,
                width: 58,
                height: 58,
                fit: BoxFit.contain,
                errorBuilder:
                    (context, error, stackTrace) => Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: config.color.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(config.icon, color: config.color, size: 28),
                    ),
              ),
            ),
            const SizedBox(height: 2),
            // Clean Floating 2.5D Title Label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: config.color.withValues(alpha: 0.6),
                  width: 1.0,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    config.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    config.subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: config.color,
                      fontSize: 8.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_hasPendingAction(type))
          const Positioned(
            top: -6,
            right: -4,
            child: Badge(
              alignment: Alignment.topRight,
              label: Text('!'),
              child: Icon(
                Icons.notifications_active,
                color: Colors.white,
                size: 17,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAnimatedAvatarSprite() {
    return AnimatedBuilder(
      animation: _walkController,
      builder: (context, child) {
        final walkValue = _walkController.value;
        final tiltAngle =
            (_isMoving || _isDraggingJoystick)
                ? math.sin(walkValue * math.pi * 2) * 0.12
                : 0.0;
        final stepY =
            (_isMoving || _isDraggingJoystick)
                ? (math.sin(walkValue * math.pi * 2).abs() * -6.0)
                : 0.0;
        final legScale =
            (_isMoving || _isDraggingJoystick)
                ? (1.0 + math.sin(walkValue * math.pi * 2) * 0.08)
                : 1.0;

        return Transform.translate(
          offset: Offset(0, stepY),
          child: Transform.rotate(
            angle: tiltAngle,
            child: Transform.scale(
              scaleY: legScale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Character Head Avatar Badge Overlay
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: ZaWolfColors.primaryCyan.withValues(
                            alpha: 0.7,
                          ),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: ZaWolfColors.primaryCyan,
                      backgroundImage:
                          widget.user.avatarFaceUrl != null
                              ? NetworkImage(widget.user.avatarFaceUrl!)
                              : null,
                      child:
                          widget.user.avatarFaceUrl == null
                              ? Icon(
                                widget.user.avatarGender == 'female'
                                    ? Icons.face_3
                                    : Icons.face,
                                size: 16,
                                color: Colors.black,
                              )
                              : null,
                    ),
                  ),
                  const SizedBox(height: 1),

                  // 2.5D Isometric Male Main Character Sprite (Default)
                  Image.asset(
                    widget.user.avatarGender == 'female'
                        ? 'assets/images/iso_main_character.png'
                        : 'assets/images/iso_male_character.png',
                    width: 46,
                    height: 52,
                    fit: BoxFit.contain,
                    errorBuilder:
                        (context, error, stackTrace) => Container(
                          width: 24,
                          height: 28,
                          decoration: BoxDecoration(
                            color:
                                widget.user.avatarGender == 'female'
                                    ? const Color(0xFFEC4899)
                                    : const Color(0xFF0EA5E9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1.2),
                          ),
                          child: Icon(
                            widget.user.avatarGender == 'female'
                                ? Icons.female
                                : Icons.male,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                  ),

                  // Animated Dynamic Drop Shadow Floor Projection
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width:
                        28.0 +
                        ((_isMoving || _isDraggingJoystick)
                            ? math.sin(walkValue * math.pi * 2).abs() * 4
                            : 0),
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: const BorderRadius.all(
                        Radius.elliptical(14, 3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  _DeptConfig _departmentConfig(OfficeDepartmentHotspot type) => switch (type) {
    OfficeDepartmentHotspot.companyGate => (
      title: '🚪 بوابة الشركة',
      subtitle: 'تسجيل الحضور',
      icon: Icons.sensor_door,
      color: Colors.greenAccent,
      assetPath: 'assets/images/iso_gate_entrance.png',
    ),
    OfficeDepartmentHotspot.hrOffice => (
      title: '📄 الموارد البشرية',
      subtitle: 'الإجازات والخصومات',
      icon: Icons.badge_outlined,
      color: Colors.cyanAccent,
      assetPath: 'assets/images/iso_hr_desk.png',
    ),
    OfficeDepartmentHotspot.itDesk => (
      title: '💻 الدعم التقني',
      subtitle: 'الأجهزة والمستندات',
      icon: Icons.computer,
      color: Colors.purpleAccent,
      assetPath: 'assets/images/iso_it_server.png',
    ),
    OfficeDepartmentHotspot.financeOffice => (
      title: '💰 المكتب المالي',
      subtitle: 'السلف والاعتراضات',
      icon: Icons.account_balance_wallet_outlined,
      color: Colors.amberAccent,
      assetPath: 'assets/images/iso_finance_vault.png',
    ),
    OfficeDepartmentHotspot.managerOffice => (
      title: '👔 مكتب الإدارة',
      subtitle: 'المهمات والهيكل',
      icon: Icons.business_center_outlined,
      color: Colors.blueAccent,
      assetPath: 'assets/images/iso_manager_suite.png',
    ),
    OfficeDepartmentHotspot.archiveDept => (
      title: '🗄️ قسم الأرشيف',
      subtitle: 'سجل الطلبات',
      icon: Icons.archive_outlined,
      color: Colors.orangeAccent,
      assetPath: 'assets/images/iso_archive_dept.png',
    ),
    OfficeDepartmentHotspot.chatRoom => (
      title: '💬 قاعة المحادثات',
      subtitle: 'شات القسم',
      icon: Icons.chat_bubble_outline_rounded,
      color: Colors.purpleAccent,
      assetPath: 'assets/images/iso_chat_lounge.png',
    ),
  };
}

typedef _DeptConfig =
    ({
      String title,
      String subtitle,
      IconData icon,
      Color color,
      String assetPath,
    });

/// CustomPainter rendering 3D Isometric floor grid, 3D room slabs, isometric furniture,
/// corridor pathways, and destination pulse targets.
class _IsometricOfficePainter extends CustomPainter {
  _IsometricOfficePainter({
    required this.hotspots,
    required this.avatarPos,
    required this.targetPos,
    required this.isMoving,
    required this.pulseProgress,
  });

  final Map<OfficeDepartmentHotspot, Rect> hotspots;
  final Offset avatarPos;
  final Offset targetPos;
  final bool isMoving;
  final double pulseProgress;

  @override
  void paint(Canvas canvas, Size size) {
    _drawCorridorPathways(canvas);
    _drawTargetMarker(canvas);
  }

  void _drawCorridorPathways(Canvas canvas) {
    // Neon Main Corridor Carpet Lines
    final pathPaint =
        Paint()
          ..color = ZaWolfColors.primaryCyan.withValues(alpha: 0.15)
          ..strokeWidth = 24
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

    final glowPaint =
        Paint()
          ..color = ZaWolfColors.primaryCyan.withValues(alpha: 0.3)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;

    // Central Vertical Corridor
    canvas.drawLine(const Offset(200, 50), const Offset(200, 480), pathPaint);
    canvas.drawLine(const Offset(200, 50), const Offset(200, 480), glowPaint);

    // Horizontal Room Connectors
    canvas.drawLine(const Offset(100, 100), const Offset(300, 100), pathPaint);
    canvas.drawLine(const Offset(100, 230), const Offset(300, 230), pathPaint);
    canvas.drawLine(const Offset(100, 350), const Offset(300, 350), pathPaint);
  }

  void _drawTargetMarker(Canvas canvas) {
    if (!isMoving) return;

    final ringPaint =
        Paint()
          ..color = ZaWolfColors.primaryCyan.withValues(
            alpha: 0.8 - (pulseProgress * 0.4),
          )
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;

    final radius = 10.0 + (pulseProgress * 8.0);
    canvas.drawCircle(targetPos, radius, ringPaint);
    canvas.drawCircle(targetPos, 3, Paint()..color = ZaWolfColors.primaryCyan);

    // Path Line Dotted Trail from Avatar to Target
    final trailPaint =
        Paint()
          ..color = ZaWolfColors.primaryCyan.withValues(alpha: 0.4)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;

    final dx = targetPos.dx - avatarPos.dx;
    final dy = targetPos.dy - avatarPos.dy;
    final dist = math.sqrt(dx * dx + dy * dy);

    if (dist > 15) {
      const dashWidth = 6.0;
      const dashSpace = 4.0;
      double distance = 0.0;
      final unitX = dx / dist;
      final unitY = dy / dist;

      while (distance < dist) {
        final start = Offset(
          avatarPos.dx + unitX * distance,
          avatarPos.dy + unitY * distance,
        );
        distance += dashWidth;
        final end = Offset(
          avatarPos.dx + unitX * math.min(distance, dist),
          avatarPos.dy + unitY * math.min(distance, dist),
        );
        distance += dashSpace;
        canvas.drawLine(start, end, trailPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IsometricOfficePainter oldDelegate) {
    return oldDelegate.avatarPos != avatarPos ||
        oldDelegate.targetPos != targetPos ||
        oldDelegate.isMoving != isMoving ||
        oldDelegate.pulseProgress != pulseProgress;
  }
}
