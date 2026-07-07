import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/version_gate_service.dart';
import '../theme/app_theme.dart';

class ForceUpdateScreen extends StatelessWidget {
  final VersionGateResult result;
  const ForceUpdateScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final message = result.message?.isNotEmpty == true
        ? result.message!
        : 'กรุณาอัปเดตเป็นเวอร์ชันล่าสุดเพื่อใช้งานต่อ';
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.system_update_rounded,
                size: 84,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 20),
              Text(
                'มีเวอร์ชันใหม่',
                style: appFont(
                  color: AppTheme.onSurface(context),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: appFont(
                  color: AppTheme.mutedText(context),
                  fontSize: 14,
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (result.minVersion != null) ...[
                const SizedBox(height: 12),
                Text(
                  'ต้องใช้เวอร์ชัน ${result.minVersion} ขึ้นไป',
                  style: appFont(
                    color: AppTheme.mutedText(context),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
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
                onPressed: () async {
                  final url = result.resolvedStoreUrl;
                  if (url == null || url.isEmpty) return;
                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                },
                icon: const Icon(Icons.shop_rounded, color: Colors.white),
                label: Text(
                  'อัปเดตทันที',
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
