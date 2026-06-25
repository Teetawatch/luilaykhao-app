import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

/// Emergency "ขอความช่วยเหลือฉุกเฉิน" action. Captures GPS, lets the traveller
/// pick a message + optional photo, and dispatches an SOS for the schedule —
/// notifying staff and fellow travellers. Shared by the booking detail sheet
/// and the Trip Day screen so the safety-critical flow lives in one place.
class SosButton extends StatefulWidget {
  final int scheduleId;

  const SosButton({super.key, required this.scheduleId});

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> {
  static const _sosRed = Color(0xFFE11D48);
  bool _sending = false;

  Future<void> _onPressed() async {
    if (_sending || widget.scheduleId == 0) return;

    final result = await _confirmDialog();
    if (result == null || !mounted) return;

    await _dispatchSos(result.message, result.photoPath);
  }

  Future<void> _dispatchSos(String message, String? photoPath) async {
    if (_sending) return;

    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<AppProvider>();

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
      );
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      await SystemSound.play(SystemSoundType.alert);
      await _successDialog(hasLocation: lat != null);
    } catch (e) {
      // triggerSos already retried with backoff; offer a manual retry too.
      messenger.showSnackBar(
        SnackBar(
          content: Text('ส่ง SOS ไม่สำเร็จ: $e'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'ลองอีกครั้ง',
            onPressed: () => _dispatchSos(message, photoPath),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
          style: appFont(fontSize: 13, height: 1.5),
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

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _sending ? null : _onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: _sosRed.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
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
                        fontSize: 15,
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
                        fontSize: 12,
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                    borderRadius: BorderRadius.circular(2),
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
                      fontSize: 18,
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
                  fontSize: 13,
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
                        borderRadius: BorderRadius.circular(14),
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
                          Text(opt.emoji, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              opt.label,
                              style: appFont(
                                fontSize: 13,
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
                  style: appFont(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'อธิบายสถานการณ์โดยย่อ...',
                    hintStyle: appFont(color: Colors.grey.shade400),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
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
                  borderRadius: BorderRadius.circular(12),
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
                          fontSize: 12,
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
                      borderRadius: BorderRadius.circular(12),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
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
                          borderRadius: BorderRadius.circular(14),
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
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.sos_rounded, size: 20),
                      label: Text(
                        'ส่งสัญญาณ SOS',
                        style: appFont(
                          fontSize: 15,
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
