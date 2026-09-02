import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../models/custom_badge_model.dart';
import '../../services/performance_badge_service.dart';
import '../../services/auth_service.dart';
import '../../components/wolf_card.dart';
import 'package:provider/provider.dart';

final class CustomBadgesScreen extends StatefulWidget {
  const CustomBadgesScreen({super.key});

  @override
  State<CustomBadgesScreen> createState() => _CustomBadgesScreenState();
}

class _CustomBadgesScreenState extends State<CustomBadgesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedIcon = 'emoji_events';
  String _selectedColor = '#FFD700';
  static const String _selectedGoal = 'manual';
  static const int _targetValue = 1;
  bool _saving = false;

  static const List<Map<String, dynamic>> _iconOptions = [
    {'name': 'emoji_events', 'label': 'كأس المميز', 'icon': Icons.emoji_events_rounded},
    {'name': 'star', 'label': 'نجم التطور', 'icon': Icons.star_rounded},
    {'name': 'rocket', 'label': 'صاروخ الإنجاز', 'icon': Icons.rocket_launch_rounded},
    {'name': 'military_tech', 'label': 'وسام الشرف', 'icon': Icons.military_tech_rounded},
    {'name': 'workspace_premium', 'label': 'شريط الجودة', 'icon': Icons.workspace_premium_rounded},
    {'name': 'verified_user', 'label': 'حارس الأمان', 'icon': Icons.verified_user_rounded},
  ];

  static const List<Map<String, String>> _colorOptions = [
    {'hex': '#FFD700', 'label': 'ذهبي'},
    {'hex': '#38BDF8', 'label': 'سيبان'},
    {'hex': '#A78BFA', 'label': 'بنفسجي'},
    {'hex': '#10B981', 'label': 'أخضر'},
    {'hex': '#F97316', 'label': 'برتقالي'},
    {'hex': '#EC4899', 'label': 'وردي'},
  ];

  Color _parseHex(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFFFFD700);
    }
  }

  IconData _parseIcon(String name) {
    return switch (name) {
      'star' => Icons.star_rounded,
      'rocket' => Icons.rocket_launch_rounded,
      'military_tech' => Icons.military_tech_rounded,
      'workspace_premium' => Icons.workspace_premium_rounded,
      'verified_user' => Icons.verified_user_rounded,
      _ => Icons.emoji_events_rounded,
    };
  }

  Future<void> _createBadge() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      await PerformanceBadgeService.instance.createCustomBadge(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        iconName: _selectedIcon,
        colorHex: _selectedColor,
        targetGoalType: _selectedGoal,
        targetGoalValue: _targetValue,
        creatorId: user.uid,
        creatorName: user.displayName,
      );

      _titleController.clear();
      _descController.clear();

      if (mounted) {
        setState(() => _saving = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء وتجهيز الكأس/الشارة بنجاح! 🎉')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الإنشاء: $e')),
        );
      }
    }
  }

  void _showCreateDialog() {
    showDialog<void>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setModalState) {
              return Directionality(
                textDirection: TextDirection.rtl,
                child: AlertDialog(
                  backgroundColor: const Color(0xFF0F172A),
                  title: const Row(
                    children: [
                      Icon(Icons.emoji_events, color: Color(0xFFFFD700)),
                      SizedBox(width: 8),
                      Text(
                        'إضافة كأس / شارة تميز جديدة',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _titleController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'اسم الكأس / الشارة',
                              hintText: 'مثال: نجم المبيعات أو بطل الالتزام',
                            ),
                            validator:
                                (v) =>
                                    v == null || v.trim().isEmpty
                                        ? 'يرجى كتابة الاسم'
                                        : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _descController,
                            style: const TextStyle(color: Colors.white),
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'الوصف أو سبب المنح',
                              hintText:
                                  'تُمنح للموظف المتميز في تحقيق المستهدفات',
                            ),
                            validator:
                                (v) =>
                                    v == null || v.trim().isEmpty
                                        ? 'يرجى كتابة الوصف'
                                        : null,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'اختر أيقونة الشارة:',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children:
                                _iconOptions.map((opt) {
                                  final isSel = _selectedIcon == opt['name'];
                                  return ChoiceChip(
                                    label: Icon(
                                      opt['icon'] as IconData,
                                      color: isSel ? Colors.black : Colors.white,
                                      size: 18,
                                    ),
                                    selected: isSel,
                                    selectedColor: const Color(0xFFFFD700),
                                    backgroundColor: Colors.white10,
                                    onSelected:
                                        (_) => setModalState(
                                          () =>
                                              _selectedIcon =
                                                  opt['name'] as String,
                                        ),
                                  );
                                }).toList(),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'اختر لون الشارة المميز:',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children:
                                _colorOptions.map((opt) {
                                  final color = _parseHex(opt['hex']!);
                                  final isSel = _selectedColor == opt['hex'];
                                  return GestureDetector(
                                    onTap:
                                        () => setModalState(
                                          () => _selectedColor = opt['hex']!,
                                        ),
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color:
                                              isSel
                                                  ? Colors.white
                                                  : Colors.transparent,
                                          width: 2.5,
                                        ),
                                      ),
                                      child:
                                          isSel
                                              ? const Icon(
                                                Icons.check,
                                                color: Colors.black,
                                                size: 16,
                                              )
                                              : null,
                                    ),
                                  );
                                }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء', style: TextStyle(color: Colors.white60)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: Colors.black,
                      ),
                      onPressed: _saving ? null : _createBadge,
                      child:
                          _saving
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                              : const Text('حفظ وإنشاء', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة كؤوس وشارات التميز (HR)'),
        actions: [
          IconButton(
            tooltip: 'إضافة كأس جديد',
            icon: const Icon(Icons.add_circle, color: Color(0xFFFFD700)),
            onPressed: _showCreateDialog,
          ),
        ],
      ),
      body: StreamBuilder<List<CustomBadgeModel>>(
        stream: PerformanceBadgeService.instance.watchCustomBadges(),
        builder: (context, snapshot) {
          final customBadges = snapshot.data ?? [];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WolfCard(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.emoji_events,
                          color: Color(0xFFFFD700),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'نظام الكؤوس والأوسمة المخصصة',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'يمكنك إنشاء شارات وكؤوس خاصة بشركتك، وتعيين المستهدفات، ومنحها يدوياً للموظفين من شاشة إدارة الموظفين.',
                              style: TextStyle(
                                color: ZaWolfColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'الكؤوس والشارات المخصصة',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: Colors.black,
                      ),
                      onPressed: _showCreateDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('كأس جديد', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (customBadges.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    alignment: Alignment.center,
                    child: const Column(
                      children: [
                        Icon(Icons.emoji_events_outlined, color: Colors.white38, size: 48),
                        SizedBox(height: 12),
                        Text(
                          'لا توجد كؤوس مخصصة حتى الآن. اضغط "كأس جديد" لإضافة أول وسام مخصص.',
                          style: TextStyle(color: Colors.white60),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: customBadges.length,
                    itemBuilder: (context, index) {
                      final badge = customBadges[index];
                      final color = _parseHex(badge.colorHex);
                      final icon = _parseIcon(badge.iconName);
                      return WolfCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(color: color.withValues(alpha: 0.4)),
                              ),
                              child: Icon(icon, color: color, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    badge.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    badge.description,
                                    style: const TextStyle(
                                      color: ZaWolfColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'أنشأها: ${badge.createdByName}',
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
