import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Toast feedback with a consistent shape and an explicit intent.
///
/// The base look — floating, rounded, flat, white-on-slate — comes from
/// `snackBarTheme` in [AppTheme], so a plain `SnackBar(content: Text(...))`
/// already looks right. This helper adds the two things a theme cannot:
///
/// * an **intent** (neutral / success / error) carried by a leading icon and
///   accent, so the user reads the outcome before the sentence, and
/// * **replacement instead of queueing** — Flutter queues snackbars by default,
///   so two quick failures make the user wait through the first before seeing
///   the second. Every call here clears the current toast first.
class AppSnack {
  AppSnack._();

  /// Neutral confirmation — "คัดลอกแล้ว", "บันทึกแล้ว".
  static void show(
    BuildContext context,
    String message, {
    SnackBarAction? action,
  }) {
    _show(context, message, icon: null, accent: null, action: action);
  }

  /// A completed action the user cares about — booked, paid, submitted.
  static void success(
    BuildContext context,
    String message, {
    SnackBarAction? action,
  }) {
    _show(
      context,
      message,
      icon: Icons.check_circle_rounded,
      accent: AppTheme.brandSoft,
      action: action,
    );
  }

  /// A failure the user needs to notice and usually retry.
  static void error(
    BuildContext context,
    String message, {
    SnackBarAction? action,
  }) {
    _show(
      context,
      message,
      icon: Icons.error_rounded,
      accent: const Color(0xFFFDA4AF), // Rose 300 — readable on the dark toast
      action: action,
    );
  }

  static void _show(
    BuildContext context,
    String message, {
    required IconData? icon,
    required Color? accent,
    SnackBarAction? action,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: Duration(seconds: icon == Icons.error_rounded ? 5 : 3),
          action: action,
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: accent),
                const SizedBox(width: 10),
              ],
              // The toast inherits contentTextStyle from snackBarTheme, so the
              // message needs no style of its own.
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}
