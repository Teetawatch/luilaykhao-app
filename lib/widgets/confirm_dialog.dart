import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// What the confirm button does, which sets its colour and the icon badge.
enum ConfirmTone {
  /// Normal go-ahead (เริ่มแบ่งจ่าย, เช็คอิน, ประกาศ) — brand emerald.
  primary,

  /// Irreversible or losing something (ลบ, ยกเลิก, ออกจากระบบ, บล็อก) — rose.
  danger,

  /// Allowed but worth a second look (ไปทั้งที่ยังไม่ครบ, ไม่มีใครไปเลย) — amber.
  warning,

  /// Something good happened; the card only needs acknowledging.
  success,
}

/// The app's one confirmation card — replaces the stock [AlertDialog] that
/// every "ลบ…?" / "ยกเลิก…?" prompt used to hand-roll, each with its own
/// title size, button style and colour.
///
/// Layout: tinted icon badge, centred title and message, an optional [detail]
/// box for the thing being acted on (a file name, an amount), and two
/// equal-width buttons. When either label is too long to sit side by side the
/// buttons stack, confirm on top, rather than wrapping Thai mid-word.
///
/// Returns `true` only when the confirm button was pressed; dismissing the
/// card (tap outside, back gesture) counts as cancel. Pass `cancelLabel: null`
/// for a single-button acknowledgement card.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String? detail,
  required String confirmLabel,
  String? cancelLabel = 'ยกเลิก',
  ConfirmTone tone = ConfirmTone.primary,
  IconData? icon,
  bool barrierDismissible = true,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => ConfirmDialog(
      title: title,
      message: message,
      detail: detail,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      tone: tone,
      icon: icon,
    ),
    transitionBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
  return result == true;
}

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String? message;
  final String? detail;
  final String confirmLabel;
  final String? cancelLabel;
  final ConfirmTone tone;
  final IconData? icon;

  const ConfirmDialog({
    super.key,
    required this.title,
    this.message,
    this.detail,
    required this.confirmLabel,
    this.cancelLabel = 'ยกเลิก',
    this.tone = ConfirmTone.primary,
    this.icon,
  });

  static const double _buttonHeight = 48;
  static const double _buttonGap = 10;
  static const double _buttonPadding = 16;

  Color get _hue => switch (tone) {
    ConfirmTone.primary => AppTheme.primaryColor,
    ConfirmTone.danger => AppTheme.dangerColor,
    ConfirmTone.warning => AppTheme.warningColor,
    ConfirmTone.success => AppTheme.successColor,
  };

  IconData get _icon =>
      icon ??
      switch (tone) {
        ConfirmTone.primary => Icons.help_outline_rounded,
        ConfirmTone.danger => Icons.delete_outline_rounded,
        ConfirmTone.warning => Icons.warning_amber_rounded,
        ConfirmTone.success => Icons.check_circle_outline_rounded,
      };

  TextStyle _buttonStyle(Color color) => appFont(
    color: color,
    fontSize: AppText.sizeBody,
    fontWeight: FontWeight.w800,
  );

  /// Side by side only when both labels fit their half without wrapping.
  bool _fitsSideBySide(BuildContext context, double width) {
    final cancel = cancelLabel;
    if (cancel == null) return false;
    final half = (width - _buttonGap) / 2 - _buttonPadding * 2;
    final scaler = MediaQuery.textScalerOf(context);
    for (final label in [confirmLabel, cancel]) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: _buttonStyle(Colors.black)),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final fits = painter.width <= half;
      painter.dispose();
      if (!fits) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final hue = _hue;
    final dark = AppTheme.isDark(context);
    // The amber/emerald fills are light enough that dark ink reads better on
    // them in dark mode; rose keeps white text in both.
    final onHue = dark && tone != ConfirmTone.danger
        ? const Color(0xFF052E24)
        : Colors.white;
    final fill = dark && tone == ConfirmTone.primary
        ? AppTheme.accentColor
        : hue;

    final confirm = SizedBox(
      height: _buttonHeight,
      child: FilledButton(
        onPressed: () {
          tone == ConfirmTone.danger
              ? HapticFeedback.mediumImpact()
              : HapticFeedback.selectionClick();
          Navigator.of(context).pop(true);
        },
        style: FilledButton.styleFrom(
          backgroundColor: fill,
          foregroundColor: onHue,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: _buttonPadding),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
        ),
        child: Text(
          confirmLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _buttonStyle(onHue),
        ),
      ),
    );

    final cancelText = cancelLabel;
    final cancel = cancelText == null
        ? null
        : SizedBox(
            height: _buttonHeight,
            child: TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).pop(false);
              },
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.fieldSurface(context),
                foregroundColor: AppTheme.onSurface(context),
                padding: const EdgeInsets.symmetric(
                  horizontal: _buttonPadding,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  side: BorderSide(
                    color: AppTheme.border(context).withValues(alpha: 0.6),
                  ),
                ),
              ),
              child: Text(
                cancelText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _buttonStyle(AppTheme.onSurface(context)),
              ),
            ),
          );

    return Dialog(
      backgroundColor: AppTheme.surface(context),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: dark
            ? BorderSide(color: AppTheme.border(context))
            : BorderSide.none,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.tintOf(context, hue),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _icon,
                  size: 28,
                  color: AppTheme.onTintOf(context, hue),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppText.title(color: AppTheme.onSurface(context)),
              ),
              if (message != null && message!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: AppText.body(color: AppTheme.mutedText(context)),
                ),
              ],
              if (detail != null && detail!.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.fieldSurface(context),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(
                      color: AppTheme.border(context).withValues(alpha: 0.6),
                    ),
                  ),
                  child: Text(
                    detail!,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label(
                      color: AppTheme.onSurface(context),
                      strong: true,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (cancel != null &&
                      _fitsSideBySide(context, constraints.maxWidth)) {
                    return Row(
                      children: [
                        Expanded(child: cancel),
                        const SizedBox(width: _buttonGap),
                        Expanded(child: confirm),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      confirm,
                      if (cancel != null) ...[
                        const SizedBox(height: _buttonGap),
                        cancel,
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
