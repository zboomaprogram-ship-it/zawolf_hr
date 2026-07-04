import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../services/auth_service.dart';
import '../../services/performance_service.dart';
import '../../models/user_model.dart';
import '../../models/performance_model.dart';
import '../../theme/theme.dart';
import '../../components/wolf_card.dart';
import '../../components/wolf_button.dart';
import '../../components/wolf_input_field.dart';

class RatePerformanceScreen extends StatefulWidget {
  const RatePerformanceScreen({super.key});

  @override
  State<RatePerformanceScreen> createState() => _RatePerformanceScreenState();
}

class _RatePerformanceScreenState extends State<RatePerformanceScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final PerformanceService _performanceService = PerformanceService();

  List<UserModel> _teamMembers = [];
  UserModel? _selectedEmployee;
  bool _loadingTeam = true;

  DateTime _selectedMonth = DateTime.now();

  // Scoring parameters
  double _autoAttendance = 100.0;
  double _autoPunctuality = 100.0;
  double _quality = 80.0;
  double _teamwork = 80.0;
  double _commitment = 80.0;
  bool _loadingAutoScores = false;

  final _commentController = TextEditingController();
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    _fetchTeamMembers();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchTeamMembers() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final managerId = authService.currentUser?.uid;
    if (managerId == null) return;

    try {
      final teamSnap = await _db
          .collection('users')
          .where('managerId', isEqualTo: managerId)
          .get();

      setState(() {
        _teamMembers = teamSnap.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList();
        _loadingTeam = false;
        if (_teamMembers.isNotEmpty) {
          _selectedEmployee = _teamMembers.first;
          _loadAutoScores();
        }
      });
    } catch (_) {
      setState(() {
        _loadingTeam = false;
      });
    }
  }

  Future<void> _loadAutoScores() async {
    if (_selectedEmployee == null) return;

    setState(() {
      _loadingAutoScores = true;
    });

    final monthKey = DateFormat('yyyy-MM').format(_selectedMonth);

    try {
      final scores = await _performanceService.calculateAutoScores(
        _selectedEmployee!.uid,
        monthKey,
      );
      setState(() {
        _autoAttendance = scores.attendanceScore;
        _autoPunctuality = scores.punctualityScore;
        _loadingAutoScores = false;
      });
    } catch (e) {
      setState(() {
        _loadingAutoScores = false;
      });
    }
  }

  double get _overallScore =>
      (_autoAttendance +
          _autoPunctuality +
          _quality +
          _teamwork +
          _commitment) /
      5.0;

  String get _gradeLetter =>
      _performanceService.calculateGradeLetter(_overallScore);

  Future<void> _publish() async {
    if (_selectedEmployee == null) return;

    setState(() {
      _isPublishing = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final monthKey = DateFormat('yyyy-MM').format(_selectedMonth);

    final evaluation = PerformanceModel(
      performanceId: '',
      userId: _selectedEmployee!.uid,
      employeeId: _selectedEmployee!.employeeId,
      employeeName: _selectedEmployee!.displayName,
      monthKey: monthKey,
      attendanceScore: _autoAttendance,
      punctualityScore: _autoPunctuality,
      qualityScore: _quality,
      teamworkScore: _teamwork,
      commitmentScore: _commitment,
      overallScore: _overallScore,
      grade: _gradeLetter,
      comments: _commentController.text.trim(),
      managerId: authService.currentUser!.uid,
    );

    try {
      await _performanceService.publishEvaluation(evaluation);
      _commentController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم نشر تقييم شهر $monthKey للموظف ${_selectedEmployee!.displayName} بنجاح.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل نشر التقييم: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPublishing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthStr = DateFormat('yyyy-MM').format(_selectedMonth);

    if (_loadingTeam) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'تقييم أداء أعضاء الفريق',
          style: theme.textTheme.headlineMedium,
        ),
      ),
      body: _teamMembers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.people_outline,
                    color: ZaWolfColors.textMuted,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا يوجد موظفون مسندون إليك لتقييمهم حالياً.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Month Picker Card
                  WolfCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedMonth,
                              firstDate: DateTime(2025),
                              lastDate: DateTime.now().add(
                                const Duration(days: 30),
                              ),
                              initialDatePickerMode: DatePickerMode.year,
                            );
                            if (picked != null) {
                              setState(() {
                                _selectedMonth = picked;
                              });
                              _loadAutoScores();
                            }
                          },
                          icon: const Icon(
                            Icons.calendar_today,
                            color: ZaWolfColors.primaryCyan,
                            size: 18,
                          ),
                          label: Text(
                            monthStr,
                            style: const TextStyle(
                              color: ZaWolfColors.primaryCyan,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(
                          'الشهر المستهدف للتقييم',
                          style: theme.textTheme.titleMedium!.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Employee Selector Dropdown
                  DropdownButtonFormField<UserModel>(
                    initialValue: _selectedEmployee,
                    dropdownColor: ZaWolfColors.surface01,
                    decoration: const InputDecoration(
                      labelText: 'الموظف المطلوب تقييمه',
                      labelStyle: TextStyle(color: ZaWolfColors.primaryCyan),
                    ),
                    style: const TextStyle(color: Colors.white),
                    items: _teamMembers.map((emp) {
                      return DropdownMenuItem(
                        value: emp,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text('${emp.displayName} (${emp.employeeId})'),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedEmployee = val;
                        });
                        _loadAutoScores();
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  // Live Score radial card display
                  _buildLiveGradeCard(theme),
                  const SizedBox(height: 24),

                  // Automated Attendance scores
                  Text(
                    'المؤشرات التلقائية (نظام الحضور والانصراف)',
                    style: theme.textTheme.titleMedium!.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 12),

                  if (_loadingAutoScores)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(
                          color: ZaWolfColors.primaryCyan,
                        ),
                      ),
                    )
                  else ...[
                    _buildDisabledSlider(
                      'حضور الموظف (Attendance)',
                      _autoAttendance,
                      ZaWolfColors.success,
                    ),
                    const SizedBox(height: 16),
                    _buildDisabledSlider(
                      'الالتزام بالمواعيد (Punctuality)',
                      _autoPunctuality,
                      ZaWolfColors.warning,
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Manager sliders
                  Text(
                    'التقييم الفني والالتزام (مدخلات المدير)',
                    style: theme.textTheme.titleMedium!.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 12),

                  _buildActiveSlider(
                    'جودة الإنتاجية والمهام (Quality)',
                    _quality,
                    (val) => setState(() => _quality = val),
                    ZaWolfColors.primaryCyan,
                  ),
                  const SizedBox(height: 16),

                  _buildActiveSlider(
                    'التعاون والعمل الجماعي (Teamwork)',
                    _teamwork,
                    (val) => setState(() => _teamwork = val),
                    ZaWolfColors.primaryBlue,
                  ),
                  const SizedBox(height: 16),

                  _buildActiveSlider(
                    'الالتزام والمبادرة (Commitment)',
                    _commitment,
                    (val) => setState(() => _commitment = val),
                    ZaWolfColors.dayoffPurple,
                  ),
                  const SizedBox(height: 24),

                  // Comments
                  WolfInputField(
                    controller: _commentController,
                    labelText: 'ملاحظات وتوصيات للموظف (Comments)',
                    englishLabel: 'Feedback',
                    hintText: 'اكتب ملاحظاتك لمساعدة الموظف على التطوير...',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),

                  // Publish actions
                  WolfButton(
                    onPressed: _isPublishing ? null : _publish,
                    text: 'نشر وإرسال التقييم',
                    secondaryText: 'PUBLISH GRADE',
                    loading: _isPublishing,
                    height: 52,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLiveGradeCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ZaWolfColors.primaryCyan.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: ZaWolfColors.primaryCyan.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Letter Grade Circle
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ZaWolfColors.surface02,
              border: Border.all(color: ZaWolfColors.primaryCyan, width: 2),
            ),
            child: Center(
              child: Text(
                _gradeLetter,
                style: const TextStyle(
                  color: ZaWolfColors.primaryCyan,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Rajdhani',
                ),
              ),
            ),
          ),

          // Numerical grade details
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'التقييم العام المباشر',
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: ZaWolfColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_overallScore.toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'التقييم مركب (معدل 20% لكل عنصر)',
                style: TextStyle(color: ZaWolfColors.textMuted, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDisabledSlider(String title, double value, Color activeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${value.toInt()}%',
              style: TextStyle(color: activeColor, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 0,
          max: 100,
          activeColor: activeColor.withValues(alpha: 0.6),
          inactiveColor: ZaWolfColors.surface02,
          onChanged: null, // Disabled
        ),
      ],
    );
  }

  Widget _buildActiveSlider(
    String title,
    double value,
    ValueChanged<double> onChanged,
    Color activeColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${value.toInt()}%',
              style: TextStyle(
                color: activeColor,
                fontWeight: FontWeight.bold,
                fontFamily: 'JetBrains Mono',
              ),
            ),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 0,
          max: 100,
          divisions: 20,
          activeColor: activeColor,
          inactiveColor: ZaWolfColors.surface02,
          label: '${value.toInt()}%',
          onChanged: onChanged,
        ),
      ],
    );
  }
}
