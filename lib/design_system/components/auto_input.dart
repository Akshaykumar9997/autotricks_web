import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_typography.dart';

/// Canonical form input component conforming to DESIGN.md Section 10 and Stitch.
class AutoInput extends StatelessWidget {
  final String? label;
  final bool isRequired;
  final String? hint;
  final String? errorText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int maxLines;
  final int? maxLength;
  final bool readOnly;
  final VoidCallback? onTap;
  final FormFieldValidator<String>? validator;
  final FocusNode? focusNode;

  const AutoInput({
    super.key,
    this.label,
    this.isRequired = false,
    this.hint,
    this.errorText,
    this.controller,
    this.onChanged,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.maxLength,
    this.readOnly = false,
    this.onTap,
    this.validator,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: RichText(
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    text: label,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    children: [
                      if (isRequired)
                        const TextSpan(
                          text: ' *',
                          style: TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (maxLength != null && maxLines > 1 && controller != null) ...[
                const SizedBox(width: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller!,
                  builder: (context, value, _) {
                    return Text(
                      '${value.text.length}/$maxLength',
                      style: AppTypography.caption.copyWith(
                        fontFamily: 'monospace',
                        color: AppColors.textMuted,
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          maxLength: maxLines == 1 ? maxLength : null,
          buildCounter: maxLines == 1
              ? (_, {required currentLength, required isFocused, maxLength}) => null
              : null,
          readOnly: readOnly,
          onTap: onTap,
          validator: validator,
          style: AppTypography.bodyMediumEmphasis.copyWith(
            color: AppColors.textPrimary,
          ),
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            fillColor: AppColors.surface2,
            filled: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: maxLines > 1 ? 14 : 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.radiusMd,
              borderSide: BorderSide(
                color: errorText != null
                    ? AppColors.danger
                    : AppColors.border.withValues(alpha: 0.8),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.radiusMd,
              borderSide: BorderSide(
                color: errorText != null ? AppColors.danger : AppColors.primary,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppRadius.radiusMd,
              borderSide: const BorderSide(color: AppColors.danger, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: AppRadius.radiusMd,
              borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
