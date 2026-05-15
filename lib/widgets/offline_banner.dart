import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/connectivity_service.dart';
import '../theme/app_theme.dart';

/// Persistent banner that surfaces when the device loses network.
///
/// Mounts as an overlay above the child so screens don't need to manually
/// reserve layout space for it — it slides in/out as connectivity flips.
class OfflineBanner extends StatelessWidget {
  final Widget child;
  const OfflineBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService.instance.isOnline,
      builder: (context, isOnline, _) {
        return Stack(
          children: [
            child,
            if (!isOnline)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Container(
                    width: double.infinity,
                    color: AppTheme.errorColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.cloud_off_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'ออฟไลน์อยู่ ข้อมูลบางส่วนอาจไม่อัปเดต',
                            style: GoogleFonts.anuphan(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
