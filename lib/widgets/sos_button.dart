import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/sos_alert.dart';
import '../providers/app_provider.dart';
import '../services/sos_outbox.dart';
import '../theme/app_theme.dart';
import 'sos_fallback_sheet.dart';

/// Emergency "ขอความช่วยเหลือฉุกเฉิน" action. Captures GPS, lets the traveller
/// pick a message + optional photo, and dispatches an SOS for the schedule —
/// notifying staff and fellow travellers. Shared by the booking detail sheet
/// and the Trip Day screen so the safety-critical flow lives in one place.
class SosButton extends StatefulWidget {
  final int scheduleId;

  /// ชื่อทริป — ใส่ลงในข้อความ SMS สำรอง เพื่อให้คนรับรู้ว่าเป็นรอบไหนโดยไม่ต้อง
  /// เปิดระบบดู (ซึ่งเป็นสิ่งที่ทำไม่ได้ถ้าเขาก็อยู่ในที่ไม่มีสัญญาณเหมือนกัน)
  final String? tripTitle;

  const SosButton({super.key, required this.scheduleId, this.tripTitle});

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> {
  static const _sosRed = Color(0xFFE11D48);
  bool _sending = false;

  /// This traveller's own alert on this trip that is still open. Kept in view so
  /// a false alarm — or a situation that resolved itself — can be closed by the
  /// person who raised it, instead of leaving the whole round on edge.
  SosAlert? _myOpenAlert;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _refreshMyOpenAlert();
  }

  Future<void> _refreshMyOpenAlert() async {
    if (widget.scheduleId == 0) return;
    try {
      final alerts = await context.read<AppProvider>().activeSosAlerts();
      if (!mounted) return;
      setState(() {
        _myOpenAlert = alerts
            .where(
              (a) =>
                  a.isMine && a.isActive && a.scheduleId == widget.scheduleId,
            )
            .firstOrNull;
      });
    } catch (_) {
      // Offline — the SOS button itself still works, which is what matters.
    }
  }

  Future<void> _closeMyAlert() async {
    final alert = _myOpenAlert;
    if (alert == null || _closing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'ปิดเคส SOS?',
          style: appFont(fontWeight: FontWeight.w900),
        ),
        content: Text(
          'ยืนยันว่าคุณปลอดภัยแล้ว ระบบจะแจ้งสตาฟและเพื่อนร่วมทริปว่าเคสนี้ปิดแล้ว',
          style: appFont(fontSize: AppText.sizeLabel, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('ยังไม่ปิด', style: appFont()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ฉันปลอดภัยแล้ว'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _closing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AppProvider>().resolveSos(alert.id);
      if (!mounted) return;
      setState(() => _myOpenAlert = null);
      messenger.showSnackBar(
        const SnackBar(content: Text('ปิดเคส SOS แล้ว')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('ปิดเคสไม่สำเร็จ: $e')));
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  Future<void> _onPressed() async {
    if (_sending || widget.scheduleId == 0) return;

    final result = await _confirmDialog();
    if (result == null || !mounted) return;

    await _dispatchSos(result.message, result.photoPath);
  }

  Future<void> _dispatchSos(String message, String? photoPath) async {
    if (_sending) return;

    setState(() => _sending = true);
    final provider = context.read<AppProvider>();

    // ตราไว้ตั้งแต่ตอนกด ไม่ใช่ตอนที่คำขอไปถึงเซิร์ฟเวอร์ — ถ้าต้องเข้าคิวรอ
    // สัญญาณสองชั่วโมง เวลานี้คือเวลาเดียวที่มีความหมายกับทีมค้นหา
    final occurredAt = DateTime.now();
    final clientToken = SosOutbox.newToken();

    double? lat;
    double? lng;
    try {
      final pos = await _currentPosition();
      lat = pos?.latitude;
      lng = pos?.longitude;
    } catch (_) {}

    try {
      await provider.triggerSos(
        scheduleId: widget.scheduleId,
        latitude: lat,
        longitude: lng,
        message: message.isEmpty ? null : message,
        photoPath: photoPath,
        occurredAt: occurredAt,
        clientToken: clientToken,
      );
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      await SystemSound.play(SystemSoundType.alert);
      unawaited(_refreshMyOpenAlert());
      await _successDialog(hasLocation: lat != null);
    } catch (e) {
      // ส่งไม่ผ่าน — เก็บเข้าคิวไว้ส่งเองเมื่อสัญญาณกลับมา แล้วเปิดทางสำรอง
      // ทันที ไม่ใช่ขึ้น SnackBar ให้กด "ลองอีกครั้ง" ในที่ที่ลองอีกกี่ครั้ง
      // ก็ไม่มีเน็ตเหมือนเดิม
      await SosOutbox.instance.enqueue(
        scheduleId: widget.scheduleId,
        clientToken: clientToken,
        occurredAt: occurredAt,
        latitude: lat,
        longitude: lng,
        message: message.isEmpty ? null : message,
        photoPath: photoPath,
      );

      if (!mounted) return;
      HapticFeedback.heavyImpact();
      await _openFallback(
        provider: provider,
        message: message,
        latitude: lat,
        longitude: lng,
        occurredAt: occurredAt,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// เปิดแผ่นทางสำรอง — โทร/ส่งข้อความหาทีมงานจากเบอร์ที่แคชไว้ในเครื่อง
  Future<void> _openFallback({
    required AppProvider provider,
    required String message,
    double? latitude,
    double? longitude,
    required DateTime occurredAt,
  }) async {
    final book = await provider.sosContacts(widget.scheduleId);
    if (!mounted) return;

    await SosFallbackSheet.show(
      context,
      contacts: book.contacts,
      emergencyNumbers: book.emergency,
      smsBody: SosFallbackSheet.composeSms(
        travellerName: '${provider.user?['name'] ?? 'ผู้เดินทาง'}',
        tripTitle: widget.tripTitle,
        message: message,
        latitude: latitude,
        longitude: longitude,
        occurredAt: occurredAt,
      ),
    );
  }

  Future<_SosSheetResult?> _confirmDialog() {
    return showModalBottomSheet<_SosSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _SosMessageSheet(),
    );
  }

  Future<void> _successDialog({required bool hasLocation}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              'ส่ง SOS แล้ว',
              style: appFont(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        content: Text(
          hasLocation
              ? 'สตาฟและเพื่อนร่วมทริปได้รับการแจ้งเตือนพร้อมตำแหน่งของคุณแล้ว'
              : 'สตาฟและเพื่อนร่วมทริปได้รับการแจ้งเตือนแล้ว '
                    '(ไม่สามารถระบุตำแหน่ง GPS ได้)',
          style: appFont(fontSize: AppText.sizeLabel, height: 1.5),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  /// How long we're willing to wait for a GPS fix before sending the SOS
  /// without one. On a ridge or in a valley a cold fix can take minutes —
  /// getting the alert out matters far more than getting it out with a pin.
  static const _gpsTimeout = Duration(seconds: 8);

  Future<Position?> _currentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _gpsTimeout,
        ),
      ).timeout(_gpsTimeout);
    } catch (_) {
      // No fresh fix in time — a slightly stale position still puts responders
      // in the right valley, which beats sending nothing.
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _button(context),

        // SOS ที่ยังส่งไม่ออกต้องมองเห็นได้ ไม่ใช่ค้างอยู่เงียบ ๆ ในเครื่อง —
        // ผู้ใช้ต้องรู้ว่าทีมงาน "ยังไม่ได้รับ" เพื่อจะได้ตัดสินใจโทรเอง
        ValueListenableBuilder<int>(
          valueListenable: SosOutbox.instance.pendingCount,
          builder: (context, count, _) {
            if (count == 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _QueuedBanner(
                count: count,
                onOpenFallback: _openFallbackForQueued,
              ),
            );
          },
        ),

        if (_myOpenAlert != null) ...[
          const SizedBox(height: 10),
          _OpenCaseBanner(
            closing: _closing,
            onClose: _closeMyAlert,
          ),
        ],
      ],
    );
  }

  /// เปิดทางสำรองอีกครั้งจากแถบเตือน — ผู้ใช้ที่ปิดแผ่นไปแล้วต้องกลับมาได้
  Future<void> _openFallbackForQueued() async {
    final provider = context.read<AppProvider>();
    final queued = SosOutbox.instance.pending();
    final latest = queued.isEmpty ? null : queued.last;

    await _openFallback(
      provider: provider,
      message: latest?['message']?.toString() ?? '',
      latitude: (latest?['latitude'] as num?)?.toDouble(),
      longitude: (latest?['longitude'] as num?)?.toDouble(),
      occurredAt:
          DateTime.tryParse('${latest?['occurred_at']}')?.toLocal() ??
          DateTime.now(),
    );
  }

  Widget _button(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _sending ? null : _onPressed,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: _sosRed.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: _sosRed.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: _sosRed,
                  shape: BoxShape.circle,
                ),
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.sos_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ขอความช่วยเหลือฉุกเฉิน',
                      style: appFont(
                        fontSize: AppText.sizeSubtitle,
                        fontWeight: FontWeight.w900,
                        color: _sosRed,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _sending
                          ? 'กำลังส่งสัญญาณ SOS...'
                          : 'แจ้งเตือนสตาฟและเพื่อนร่วมทริปทันที',
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: _sosRed.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// แถบสถานะเมื่อผู้ใช้มีเคส SOS ที่ยังเปิดอยู่ในรอบนี้ — บอกว่าทีมงานเห็นแล้ว
/// และให้ปิดเคสเองได้เมื่อปลอดภัย
class _OpenCaseBanner extends StatelessWidget {
  final bool closing;
  final VoidCallback onClose;

  const _OpenCaseBanner({required this.closing, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: const Color(0xFFE11D48).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.record_voice_over_rounded,
                size: 18,
                color: Color(0xFFE11D48),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'เคส SOS ของคุณยังเปิดอยู่',
                  style: appFont(
                    fontSize: AppText.sizeBody,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'สตาฟและทีมงานได้รับแจ้งแล้ว ถ้าปลอดภัยแล้วช่วยกดปิดเคสเพื่อให้ทุกคนรู้',
            style: appFont(
              fontSize: AppText.sizeCaption,
              height: 1.5,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: closing ? null : onClose,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: BorderSide(
                  color: AppTheme.primaryColor.withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
              icon: closing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: Text(
                closing ? 'กำลังปิดเคส...' : 'ฉันปลอดภัยแล้ว — ปิดเคส',
                style: appFont(fontSize: AppText.sizeLabel, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// SOS ที่ค้างอยู่ในเครื่องเพราะยังไม่มีสัญญาณ
///
/// ข้อความตรงนี้ระวังเป็นพิเศษ: ห้ามทำให้ผู้ใช้เข้าใจว่าทีมงานได้รับแล้ว และห้าม
/// สัญญาว่าจะส่งเองแม้ปิดแอป เพราะคิวเดินได้เฉพาะตอนแอปทำงานอยู่จริง ๆ
class _QueuedBanner extends StatelessWidget {
  final int count;
  final Future<void> Function() onOpenFallback;

  const _QueuedBanner({required this.count, required this.onOpenFallback});

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFB45309);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: amber.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_off_rounded, size: 18, color: amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  count > 1
                      ? 'SOS $count รายการยังส่งไม่สำเร็จ'
                      : 'SOS ของคุณยังส่งไม่สำเร็จ',
                  style: appFont(
                    fontSize: AppText.sizeBody,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'ทีมงานยังไม่ได้รับสัญญาณนี้ ระบบจะส่งให้เองทันทีที่กลับมามีสัญญาณ '
            '(เปิดแอปค้างไว้) ถ้าเร่งด่วนให้โทรหาทีมงานโดยตรง',
            style: appFont(
              fontSize: AppText.sizeCaption,
              height: 1.5,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpenFallback,
              style: OutlinedButton.styleFrom(
                foregroundColor: amber,
                side: BorderSide(color: amber.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
              icon: const Icon(Icons.call_rounded, size: 18),
              label: Text(
                'โทร / ส่งข้อความหาทีมงาน',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── SOS message bottom sheet ──────────────────────────────────────────────────

class _SosOption {
  final String value;
  final String label;
  final String emoji;
  const _SosOption(this.value, this.label, this.emoji);
}

/// What the SOS sheet returns when the user confirms: the chosen message plus
/// an optional photo (a local file path) to attach.
class _SosSheetResult {
  final String message;
  final String? photoPath;
  const _SosSheetResult({required this.message, this.photoPath});
}

class _SosMessageSheet extends StatefulWidget {
  const _SosMessageSheet();

  @override
  State<_SosMessageSheet> createState() => _SosMessageSheetState();
}

class _SosMessageSheetState extends State<_SosMessageSheet> {
  static const _sosRed = Color(0xFFE11D48);

  static const _options = [
    _SosOption('ช่วยด้วย', 'ช่วยด้วย', '🆘'),
    _SosOption('ฉันหลงทาง', 'ฉันหลงทาง', '🗺️'),
    _SosOption('ฉันกังวล', 'ฉันกังวล', '😟'),
    _SosOption('ฉันรู้สึกไม่ปลอดภัย', 'ฉันรู้สึกไม่ปลอดภัย', '⚠️'),
    _SosOption('other', 'อื่น ๆ', '💬'),
  ];

  String? _selected;
  final _controller = TextEditingController();
  final _picker = ImagePicker();
  String? _photoPath;
  bool _pickingPhoto = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSend {
    if (_selected == null) return false;
    if (_selected == 'other') return _controller.text.trim().isNotEmpty;
    return true;
  }

  String get _message =>
      _selected == 'other' ? _controller.text.trim() : (_selected ?? '');

  Future<void> _pickPhoto(ImageSource source) async {
    if (_pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      // Keep the file small so it uploads on a weak (3G) connection — the photo
      // only needs to show the surroundings, not be print-quality.
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 45,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (image == null || !mounted) return;
      setState(() => _photoPath = image.path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ไม่สามารถเปิดรูปได้')));
      }
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<void> _choosePhotoSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_camera_outlined,
                  color: _sosRed,
                ),
                title: Text(
                  'ถ่ายรูป',
                  style: appFont(fontWeight: FontWeight.w700),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: _sosRed,
                ),
                title: Text(
                  'เลือกจากคลังภาพ',
                  style: appFont(fontWeight: FontWeight.w700),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source != null) await _pickPhoto(source);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      // Lift the whole sheet above the keyboard so the send button stays
      // reachable when the "อื่น ๆ" text field is focused.
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Row(
                children: [
                  const Icon(Icons.sos_rounded, color: _sosRed, size: 26),
                  const SizedBox(width: 10),
                  Text(
                    'ขอความช่วยเหลือ SOS',
                    style: appFont(
                      fontSize: AppText.sizeTitle,
                      fontWeight: FontWeight.w900,
                      color: _sosRed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'เลือกข้อความที่ต้องการส่งให้สตาฟและผู้ร่วมทริป',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Option grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.4,
                children: _options.map((opt) {
                  final selected = _selected == opt.value;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selected = opt.value;
                      if (opt.value != 'other') _controller.clear();
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: selected
                            ? _sosRed.withValues(alpha: 0.08)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                          color: selected ? _sosRed : Colors.grey.shade200,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Text(opt.emoji, style: const TextStyle(fontSize: AppText.sizeTitle)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              opt.label,
                              style: appFont(
                                fontSize: AppText.sizeLabel,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? _sosRed
                                    : Colors.grey.shade800,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Custom text field (shown when "อื่น ๆ" selected)
              if (_selected == 'other') ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _controller,
                  maxLength: 255,
                  maxLines: 2,
                  onChanged: (_) => setState(() {}),
                  style: appFont(fontSize: AppText.sizeBody),
                  decoration: InputDecoration(
                    hintText: 'อธิบายสถานการณ์โดยย่อ...',
                    hintStyle: appFont(color: Colors.grey.shade400),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: const BorderSide(color: _sosRed, width: 2),
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Info note
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'สตาฟและผู้โดยสารในทริปจะได้รับการแจ้งเตือนพร้อมตำแหน่ง GPS ทันที',
                        style: appFont(
                          fontSize: AppText.sizeCaption,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Optional photo attachment — helps responders see the surroundings.
              if (_photoPath == null)
                OutlinedButton.icon(
                  onPressed: _pickingPhoto ? null : _choosePhotoSource,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    minimumSize: const Size.fromHeight(0),
                  ),
                  icon: _pickingPhoto
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.add_a_photo_outlined,
                          size: 19,
                          color: Colors.grey.shade700,
                        ),
                  label: Text(
                    'แนบรูปสถานที่ (ไม่บังคับ)',
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: Stack(
                    children: [
                      Image.file(
                        File(_photoPath!),
                        width: double.infinity,
                        height: 160,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => setState(() => _photoPath = null),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                      child: Text(
                        'ยกเลิก',
                        style: appFont(
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _canSend
                          ? () => Navigator.pop(
                              context,
                              _SosSheetResult(
                                message: _message,
                                photoPath: _photoPath,
                              ),
                            )
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: _sosRed,
                        disabledBackgroundColor: Colors.grey.shade200,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                      icon: const Icon(Icons.sos_rounded, size: 20),
                      label: Text(
                        'ส่งสัญญาณ SOS',
                        style: appFont(
                          fontSize: AppText.sizeSubtitle,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
