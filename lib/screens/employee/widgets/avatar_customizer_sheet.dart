import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../theme/theme.dart';
import '../../../models/user_model.dart';
import '../../../components/wolf_button.dart';
import '../../../services/auth_service.dart';

class AvatarCustomizerSheet extends StatefulWidget {
  const AvatarCustomizerSheet({super.key, required this.user});

  final UserModel user;

  @override
  State<AvatarCustomizerSheet> createState() => _AvatarCustomizerSheetState();
}

class _AvatarCustomizerSheetState extends State<AvatarCustomizerSheet> {
  late String _selectedGender;
  late String _selectedAccent;
  String? _faceUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _selectedGender = widget.user.avatarGender;
    _selectedAccent = widget.user.avatarAccent;
    _faceUrl = widget.user.avatarFaceUrl;
  }

  Future<void> _pickFaceImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final fileBytes = result.files.first.bytes;
    if (fileBytes != null) {
      final base64Image = 'data:image/jpeg;base64,${base64Encode(fileBytes)}';
      setState(() {
        _faceUrl = base64Image;
      });
    }
  }

  Future<void> _saveAvatar() async {
    setState(() => _isUploading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.updateAvatarCustomization(
        gender: _selectedGender,
        faceUrl: _faceUrl,
        accent: _selectedAccent,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الشخصية الافتراضية بنجاح!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر الحفظ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'تخصيص الشخصية الافتراضية (Avatar)',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          // Preview Widget
          CircleAvatar(
            radius: 46,
            backgroundColor: ZaWolfColors.primaryCyan.withValues(alpha: 0.2),
            backgroundImage: _faceUrl != null ? NetworkImage(_faceUrl!) : null,
            child: _faceUrl == null
                ? Icon(
                    _selectedGender == 'male' ? Icons.face : Icons.face_3,
                    size: 52,
                    color: ZaWolfColors.primaryCyan,
                  )
                : null,
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _isUploading ? null : _pickFaceImage,
            icon: const Icon(
              Icons.camera_alt_outlined,
              color: ZaWolfColors.primaryCyan,
            ),
            label: Text(
              _faceUrl == null ? 'اختيار صورة الوجه' : 'تغيير صورة الوجه',
              style: const TextStyle(color: ZaWolfColors.primaryCyan),
            ),
          ),
          const SizedBox(height: 20),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'لون الزي:',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 10,
            runSpacing: 8,
            children:
                [
                      ('cyan', const Color(0xFF22D3EE), 'سماوي'),
                      ('violet', const Color(0xFFA78BFA), 'بنفسجي'),
                      ('amber', const Color(0xFFFBBF24), 'ذهبي'),
                      ('rose', const Color(0xFFFB7185), 'وردي'),
                    ]
                    .map(
                      (choice) => ChoiceChip(
                        selected: _selectedAccent == choice.$1,
                        onSelected: (_) =>
                            setState(() => _selectedAccent = choice.$1),
                        label: Text(choice.$3),
                        avatar: CircleAvatar(
                          backgroundColor: choice.$2,
                          radius: 7,
                        ),
                      ),
                    )
                    .toList(growable: false),
          ),
          const SizedBox(height: 20),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'اختر نوع الشخصية:',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedGender = 'male'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _selectedGender == 'male'
                          ? ZaWolfColors.primaryCyan.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                        color: _selectedGender == 'male'
                            ? ZaWolfColors.primaryCyan
                            : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.man, color: Colors.white, size: 36),
                        SizedBox(height: 4),
                        Text(
                          'موظف (ذكر)',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedGender = 'female'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _selectedGender == 'female'
                          ? ZaWolfColors.primaryCyan.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                        color: _selectedGender == 'female'
                            ? ZaWolfColors.primaryCyan
                            : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.woman, color: Colors.white, size: 36),
                        SizedBox(height: 4),
                        Text(
                          'موظفة (أنثى)',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          WolfButton(text: 'حفظ التغييرات', onPressed: _saveAvatar),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
