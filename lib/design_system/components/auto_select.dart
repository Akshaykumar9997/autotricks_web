import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_typography.dart';

/// Canonical selector/dropdown button conforming to DESIGN.md and Stitch A05.
class AutoSelect<T> extends StatelessWidget {
  final String? label;
  final bool isRequired;
  final String placeholder;
  final T? value;
  final List<DropdownMenuItem<T>>? items;
  final ValueChanged<T?>? onChanged;
  final VoidCallback? onTap;
  final Widget? leadingIcon;
  final String? helperText;
  final Widget? helperWidget;
  final String? errorText;

  const AutoSelect({
    super.key,
    this.label,
    this.isRequired = false,
    required this.placeholder,
    this.value,
    this.items,
    this.onChanged,
    this.onTap,
    this.leadingIcon,
    this.helperText,
    this.helperWidget,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          RichText(
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
          const SizedBox(height: 6),
        ],
        if (items != null && onChanged != null)
          DropdownButtonFormField<T>(
            isExpanded: true,
            initialValue: value,
            items: items,
            onChanged: onChanged,
            style: AppTypography.bodyMediumEmphasis.copyWith(
              color: AppColors.textPrimary,
            ),
            dropdownColor: AppColors.surface2,
            icon: const Icon(Icons.expand_more, color: AppColors.textSecondary, size: 20),
            decoration: InputDecoration(
              hintText: placeholder,
              prefixIcon: leadingIcon,
              errorText: errorText,
              fillColor: AppColors.surface2,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.radiusMd,
                borderSide: BorderSide(
                  color: errorText != null ? AppColors.danger : AppColors.border,
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
            ),
          )
        else
          InkWell(
            onTap: onTap,
            borderRadius: AppRadius.radiusMd,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: AppRadius.radiusMd,
                border: Border.all(
                  color: errorText != null ? AppColors.danger : AppColors.border,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  if (leadingIcon != null) ...[
                    leadingIcon!,
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      value?.toString() ?? placeholder,
                      style: AppTypography.bodyMediumEmphasis.copyWith(
                        color: value != null
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.unfold_more, color: AppColors.textSecondary, size: 20),
                ],
              ),
            ),
          ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: AppTypography.caption.copyWith(color: AppColors.danger),
          ),
        ],
        if (helperWidget != null) ...[
          const SizedBox(height: 6),
          helperWidget!,
        ] else if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            helperText!,
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}
