import 'package:flutter/material.dart';

/// Caps how far the OS font-size setting can stretch the app's text.
///
/// The trip, booking and payment cards pack a lot of Thai text into rows with
/// fixed heights, and both iOS and Android let the user push text past 2x —
/// far enough that those rows overflow instead of reflowing. Scaling *down* is
/// left alone; it never breaks a layout.
///
/// This is a floor under the problem, not a fix for it: the real fix is making
/// the dense screens reflow, after which [maxScaleFactor] can be raised.
class TextScaleGuard extends StatelessWidget {
  static const double minScaleFactor = 0.8;
  static const double maxScaleFactor = 1.3;

  final Widget child;

  const TextScaleGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: media.textScaler.clamp(
          minScaleFactor: minScaleFactor,
          maxScaleFactor: maxScaleFactor,
        ),
      ),
      child: child,
    );
  }
}
