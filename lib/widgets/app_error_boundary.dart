import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Replaces Flutter's default red error screen with a friendlier surface in
/// production. In debug we keep the framework default so stack traces are
/// still visible during development.
class AppErrorBoundary {
  static void install() {
    if (kDebugMode) return;
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return _FriendlyErrorScreen(details: details);
    };
  }
}

class _FriendlyErrorScreen extends StatelessWidget {
  final FlutterErrorDetails details;
  const _FriendlyErrorScreen({required this.details});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.background(context),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 72,
                color: AppTheme.errorColor,
              ),
              const SizedBox(height: 16),
              Text(
                'ขออภัย เกิดข้อผิดพลาดบางอย่าง',
                textAlign: TextAlign.center,
                style: appFont(
                  color: AppTheme.onSurface(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ทีมงานได้รับรายงานข้อผิดพลาดแล้ว ลองปิดและเปิดแอปอีกครั้ง',
                textAlign: TextAlign.center,
                style: appFont(
                  color: AppTheme.mutedText(context),
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
