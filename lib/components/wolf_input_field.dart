import 'package:flutter/material.dart';
import '../theme/theme.dart';

class WolfInputField extends StatefulWidget {
  final TextEditingController? controller;
  final String labelText;
  final String? englishLabel;
  final String? hintText;
  final bool isPassword;
  final TextInputType keyboardType;
  final IconData? prefixIcon;
  final FormFieldValidator<String>? validator;
  final bool readOnly;
  final VoidCallback? onTap;
  final TextDirection? textDirection;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const WolfInputField({
    super.key,
    this.controller,
    required this.labelText,
    this.englishLabel,
    this.hintText,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.validator,
    this.readOnly = false,
    this.onTap,
    this.textDirection,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  State<WolfInputField> createState() => _WolfInputFieldState();
}

class _WolfInputFieldState extends State<WolfInputField> {
  TextEditingController? _localController;
  bool _obscureText = true;
  bool _isFocused = false;

  TextEditingController get _effectiveController =>
      widget.controller ?? (_localController ??= TextEditingController());

  @override
  void dispose() {
    _localController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.labelText,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: ZaWolfColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.englishLabel != null)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(
                  widget.englishLabel!.toUpperCase(),
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: ZaWolfColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Focus(
          onFocusChange: (hasFocus) {
            setState(() {
              _isFocused = hasFocus;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: ZaWolfColors.primaryCyan.withValues(alpha: 0.12),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: TextFormField(
              controller: _effectiveController,
              obscureText: widget.isPassword ? _obscureText : false,
              keyboardType: widget.keyboardType,
              readOnly: widget.readOnly,
              onTap: widget.onTap,
              onChanged: widget.onChanged,
              onFieldSubmitted: widget.onSubmitted,
              maxLines: widget.isPassword ? 1 : widget.maxLines,
              textDirection: widget.textDirection ?? TextDirection.rtl,
              style: theme.textTheme.bodyLarge,
              validator: widget.validator,
              decoration: InputDecoration(
                hintText: widget.hintText,
                prefixIcon: widget.prefixIcon != null
                    ? Icon(
                        widget.prefixIcon,
                        color: _isFocused
                            ? ZaWolfColors.primaryCyan
                            : ZaWolfColors.textSecondary,
                      )
                    : null,
                suffixIcon: widget.isPassword
                    ? IconButton(
                        icon: Icon(
                          _obscureText
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: ZaWolfColors.textSecondary,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureText = !_obscureText;
                          });
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
