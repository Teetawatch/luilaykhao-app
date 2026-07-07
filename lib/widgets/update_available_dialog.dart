import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/version_gate_service.dart';
import '../theme/app_theme.dart';

/// Dismissible "มีเวอร์ชันใหม่" prompt shown when a newer build is on the store
/// but the installed one is still usable (see [VersionGateResult.updateAvailable]).
///
/// Unlike the blocking [ForceUpdateScreen] this can be postponed. To avoid
/// nagging, tapping "ไว้ภายหลัง" records the offered version so the prompt stays
/// hidden until an even newer version ships.
class UpdateAvailableDialog extends StatelessWidget {
  final VersionGateResult result;
  const UpdateAvailableDialog({super.key, required this.result});

  static const String _dismissedVersionKey = 'update_prompt_dismissed_version';

  /// Shows the prompt at most once per app session, and never again for a
  /// version the user already chose to skip. Safe to call unconditionally — it
  /// no-ops when there's nothing to offer.
  static Future<void> maybeShow(
    BuildContext context,
    VersionGateResult result,
  ) async {
    if (!result.updateAvailable) return;
    if (result.resolvedStoreUrl == null) return;

    final latest = result.latestVersion;
    if (latest == null || latest.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_dismissedVersionKey) == latest) return;

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => UpdateAvailableDialog(result: result),
    );
  }

  Future<void> _remindLater() async {
    final latest = result.latestVersion;
    if (latest == null || latest.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedVersionKey, latest);
  }

  @override
  Widget build(BuildContext context) {
    final message = result.message?.isNotEmpty == true
        ? result.message!
        : 'มีเวอร์ชันใหม่ให้อัปเดต เพื่อประสบการณ์ใช้งานที่ดีขึ้นและฟีเจอร์ล่าสุด';

    return Dialog(
      backgroundColor: AppTheme.surface(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.system_update_rounded,
                size: 34,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'มีเวอร์ชันใหม่',
              style: appFont(
                color: AppTheme.onSurface(context),
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: appFont(
                color: AppTheme.mutedText(context),
                fontSize: 13.5,
                height: 1.55,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (result.latestVersion != null) ...[
              const SizedBox(height: 10),
              Text(
                'เวอร์ชัน ${result.latestVersion}',
                style: appFont(
                  color: AppTheme.mutedText(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
                  if (context.mounted) Navigator.of(context).pop();
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
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () async {
                await _remindLater();
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Text(
                'ไว้ภายหลัง',
                style: appFont(
                  color: AppTheme.mutedText(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
