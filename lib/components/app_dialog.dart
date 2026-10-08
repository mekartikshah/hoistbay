import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class AppDialog extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget content;
  final List<Widget>? actions;
  final double? maxWidth;
  final EdgeInsets? padding;

  const AppDialog({
    super.key,
    this.title,
    this.subtitle,
    required this.content,
    this.actions,
    this.maxWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.dialogRadius),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? 480,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title!,
                            style: AppTypography.headline,
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle!,
                              style: AppTypography.caption,
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                      splashRadius: 16,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              Flexible(child: content),
              if (actions != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: _buildActions(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActions() {
    if (actions == null || actions!.isEmpty) return [];

    final spaced = <Widget>[];
    for (int i = 0; i < actions!.length; i++) {
      if (i > 0) spaced.add(const SizedBox(width: AppSpacing.sm));
      spaced.add(actions![i]);
    }
    return spaced;
  }
}

class AppConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;

  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: title,
      content: Text(message, style: AppTypography.body),
      actions: [
        TextButton(
          onPressed: () {
            // Pop before the callback so a route it pushes isn't popped instead.
            final VoidCallback? cancel = onCancel;
            Navigator.of(context).pop(false);
            cancel?.call();
          },
          child: Text(cancelLabel),
        ),
        ElevatedButton(
          onPressed: () {
            // Pop before the callback so a route it pushes isn't popped instead.
            final VoidCallback? confirm = onConfirm;
            Navigator.of(context).pop(true);
            confirm?.call();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isDestructive ? AppColors.error : AppColors.primary,
            foregroundColor: AppColors.textInverse,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            ),
          ),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
