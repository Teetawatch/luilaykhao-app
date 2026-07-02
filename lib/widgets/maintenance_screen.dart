import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Full-screen gate shown when the backend is in maintenance mode
/// (`php artisan down`, e.g. during a deploy or database cutover). Mirrors
/// [ForceUpdateScreen] so both "hard stop" states feel like one system.
class MaintenanceScreen extends StatelessWidget {
  /// Whether a re-check request is currently in flight (drives the button
  /// spinner). Wired to `AppProvider.recheckMaintenance()`.
  final bool checking;
  final VoidCallback onRetry;

  const MaintenanceScreen({
    super.key,
    required this.checking,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.build_rounded,
                  size: 46,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'ปิดปรับปรุงชั่วคราว',
                style: appFont(
                  color: AppTheme.onSurface(context),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'เรากำลังพัฒนาระบบให้ดียิ่งขึ้น\nจะกลับมาให้บริการอีกครั้งในไม่ช้า ขออภัยในความไม่สะดวก',
                textAlign: TextAlign.center,
                style: appFont(
                  color: AppTheme.mutedText(context),
                  fontSize: 14,
                  height: 1.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: checking ? null : onRetry,
                icon: checking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, color: Colors.white),
                label: Text(
                  checking ? 'กำลังตรวจสอบ...' : 'ลองอีกครั้ง',
                  style: appFont(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
