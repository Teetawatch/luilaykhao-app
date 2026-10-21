import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/version_gate_service.dart';
import '../theme/app_theme.dart';
import 'gate_layout.dart';

/// บังคับอัปเดต — เวอร์ชันที่ติดตั้งต่ำกว่า min_version จนใช้งานต่อไม่ได้
///
/// อยู่ใน `MaterialApp.builder` (เหนือ Navigator) จึงไม่ใช้ dialog/snackbar —
/// เปิดร้านค้าไม่สำเร็จบอกเป็นข้อความในหน้าแทน
class ForceUpdateScreen extends StatefulWidget {
  final VersionGateResult result;
  const ForceUpdateScreen({super.key, required this.result});

  @override
  State<ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}

class _ForceUpdateScreenState extends State<ForceUpdateScreen> {
  bool _opening = false;
  bool _failed = false;

  bool get _isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  String get _storeName => _isIos ? 'App Store' : 'Google Play';

  Future<void> _openStore() async {
    final url = widget.result.resolvedStoreUrl;
    if (url == null || url.isEmpty) {
      setState(() => _failed = true);
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _opening = true;
      _failed = false;
    });
    var ok = false;
    try {
      ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _opening = false;
      _failed = !ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final message = r.message?.isNotEmpty == true
        ? r.message!
        // ขึ้นบรรทัดเอง — ไม่งั้นจอกว้างตัด "เลย" ไปอยู่บรรทัดสุดท้ายคำเดียว
        : 'เวอร์ชันที่คุณใช้อยู่เก่าเกินไปแล้ว\nอัปเดตเป็นเวอร์ชันล่าสุดเพื่อใช้งานต่อได้เลย';
    final target = (r.latestVersion?.isNotEmpty ?? false)
        ? r.latestVersion
        : r.minVersion;
    final muted = AppTheme.mutedText(context);

    return PopScope(
      canPop: false,
      child: GateLayout(
        children: [
          const _AppMark(),
          const SizedBox(height: 24),
          Text(
            'อัปเดตแอปก่อนใช้งานต่อ',
            textAlign: TextAlign.center,
            style: appFont(
              color: AppTheme.onSurface(context),
              fontSize: AppText.sizeH2,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: appFont(
              color: muted,
              fontSize: AppText.sizeBody,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
          if ((r.currentVersion?.isNotEmpty ?? false) ||
              (target?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 24),
            _VersionCard(current: r.currentVersion, target: target),
          ],
          const SizedBox(height: 16),
          const _Reassurance(),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              onPressed: _opening ? null : _openStore,
              icon: _opening
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _isIos ? Icons.apple : Icons.shop_rounded,
                      color: Colors.white,
                    ),
              label: Text(
                'อัปเดตใน $_storeName',
                style: appFont(
                  color: Colors.white,
                  fontSize: AppText.sizeSubtitle,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _failed
                ? 'เปิด $_storeName ไม่ได้ — ลองเปิด $_storeName เองแล้วค้นหา "ลุยเลเขา"'
                : 'อัปเดตเสร็จแล้วเปิดแอปใหม่อีกครั้ง',
            textAlign: TextAlign.center,
            style: appFont(
              color: _failed ? AppTheme.errorColor : muted,
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// โลโก้แอปในกรอบมน + ป้ายลูกศรขึ้นมุมขวาล่าง — บอกว่า "แอปนี้แหละที่ต้องอัปเดต"
class _AppMark extends StatelessWidget {
  const _AppMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 112,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(32),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 80,
              height: 80,
              // พื้นขาวเสมอเหมือนไอคอนแอปจริง — โลโก้สีเข้มจมหายบนพื้นมืดในโหมดมืด
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppTheme.border(context)),
              ),
              padding: const EdgeInsets.all(10),
              child: Image.asset(
                'assets/images/logo_mark.png',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.terrain_rounded,
                  size: 40,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.background(context),
                  width: 3,
                ),
              ),
              child: const Icon(
                Icons.arrow_upward_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "เวอร์ชันของคุณ 1.14.0 → เวอร์ชันใหม่ 1.16.0"
class _VersionCard extends StatelessWidget {
  final String? current;
  final String? target;

  const _VersionCard({required this.current, required this.target});

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, String? value, {bool highlight = false}) =>
        Expanded(
          child: Column(
            children: [
              Text(
                label,
                style: appFont(
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mutedText(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                (value?.isNotEmpty ?? false) ? value! : '-',
                style: appFont(
                  fontSize: AppText.sizeSubtitle,
                  fontWeight: FontWeight.w800,
                  color: highlight
                      ? AppTheme.primaryColor
                      : AppTheme.onSurface(context),
                ),
              ),
            ],
          ),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        children: [
          cell('เวอร์ชันของคุณ', current),
          Icon(
            Icons.arrow_forward_rounded,
            size: 20,
            color: AppTheme.mutedText(context),
          ),
          cell('เวอร์ชันใหม่', target, highlight: true),
        ],
      ),
    );
  }
}

/// คลายกังวลเรื่องที่คนกลัวเวลาโดนบังคับอัปเดต — ข้อมูลหายไหม ต้องล็อกอินใหม่ไหม
class _Reassurance extends StatelessWidget {
  const _Reassurance();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.verified_user_rounded,
          size: 16,
          color: AppTheme.primaryColor,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'ข้อมูลการจองและบัญชีของคุณอยู่ครบ ไม่ต้องสมัครใหม่',
            textAlign: TextAlign.center,
            style: appFont(
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w600,
              color: AppTheme.mutedText(context),
            ),
          ),
        ),
      ],
    );
  }
}
