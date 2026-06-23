import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/travel_widgets.dart';

/// Lets a staff member log an on-trip incident (accident / injury) for a
/// schedule. Captures severity, a description, who was affected, the current
/// GPS location and an optional photo, then notifies ops/admin/staff.
class ReportIncidentScreen extends StatefulWidget {
  final int scheduleId;
  final String scheduleTitle;

  /// Passenger / contact names lifted from the manifest, offered as quick picks
  /// for "who was affected".
  final List<String> passengerNames;

  const ReportIncidentScreen({
    super.key,
    required this.scheduleId,
    this.scheduleTitle = '',
    this.passengerNames = const [],
  });

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _Severity {
  final String value;
  final String label;
  final Color color;
  const _Severity(this.value, this.label, this.color);
}

const _severities = <_Severity>[
  _Severity('minor', 'เล็กน้อย', Color(0xFF059669)),
  _Severity('moderate', 'ปานกลาง', AppTheme.warningColor),
  _Severity('severe', 'รุนแรง', Color(0xFFEA580C)),
  _Severity('critical', 'วิกฤต', AppTheme.errorColor),
];

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _personController = TextEditingController();
  final _descController = TextEditingController();

  String _severity = 'moderate';
  bool _attachLocation = true;
  Position? _position;
  bool _locating = false;
  String? _photoPath;
  bool _submitting = false;

  /// Passenger quick-pick names. Seeded from the caller, or fetched from the
  /// manifest when this screen is opened from the staff hub (which has no
  /// manifest loaded to hand them over).
  late List<String> _passengerNames = widget.passengerNames
      .where((n) => n.trim().isNotEmpty)
      .toList();

  @override
  void initState() {
    super.initState();
    _captureLocation();
    if (_passengerNames.isEmpty) _loadPassengerNames();
  }

  /// Build "คำนำหน้า ชื่อ-นามสกุล (ชื่อเล่น)" quick picks from the schedule
  /// manifest — same shape as StaffManifestScreen, so the staff-hub entry point
  /// shows the names too. Best-effort: a failure just leaves the field manual.
  Future<void> _loadPassengerNames() async {
    try {
      final data =
          await context.read<AppProvider>().loadStaffManifest(widget.scheduleId);
      final names = <String>{};
      for (final b in asList(data['bookings']).map(asMap)) {
        for (final p in asList(b['passengers']).map(asMap)) {
          final name = textOf(p['name']);
          if (name.isEmpty) continue;
          final nickname = textOf(p['nickname']);
          names.add(nickname.isEmpty ? name : '$name ($nickname)');
        }
      }
      if (mounted && names.isNotEmpty) {
        setState(() => _passengerNames = names.toList());
      }
    } catch (_) {
      // Leave the person field as free text on any manifest-load failure.
    }
  }

  @override
  void dispose() {
    _personController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    setState(() => _locating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _position = null);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _position = null);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) setState(() => _position = pos);
    } catch (_) {
      if (mounted) setState(() => _position = null);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (file != null) setState(() => _photoPath = file.path);
  }

  Future<void> _submit() async {
    final description = _descController.text.trim();
    if (description.isEmpty) {
      _snack('กรุณากรอกรายละเอียดเหตุการณ์', isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await context.read<AppProvider>().reportIncident(
        scheduleId: widget.scheduleId,
        severity: _severity,
        description: description,
        passengerName: _personController.text.trim().isEmpty
            ? null
            : _personController.text.trim(),
        latitude: _attachLocation ? _position?.latitude : null,
        longitude: _attachLocation ? _position?.longitude : null,
        photoPath: _photoPath,
      );
      if (!mounted) return;
      _snack('ส่งแจ้งเหตุเรียบร้อยแล้ว แจ้งทีมงานแล้ว');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) _snack(e.message, isError: true);
    } catch (e) {
      if (mounted) _snack('ส่งแจ้งเหตุไม่สำเร็จ', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.primaryColor,
        content: Text(message, style: appFont(color: Colors.white)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final names = _passengerNames
        .where((n) => n.trim().isNotEmpty)
        .toSet();

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(title: const Text('แจ้งเหตุฉุกเฉิน')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          if (widget.scheduleTitle.isNotEmpty) ...[
            Text(
              widget.scheduleTitle,
              style: appFont(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.mutedText(context),
              ),
            ),
            const SizedBox(height: 16),
          ],

          _label('ระดับความรุนแรง'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _severities)
                _SeverityChip(
                  severity: s,
                  selected: _severity == s.value,
                  onTap: () => setState(() => _severity = s.value),
                ),
            ],
          ),
          const SizedBox(height: 20),

          _label('ผู้ประสบเหตุ (ถ้ามี)'),
          const SizedBox(height: 8),
          TextField(
            controller: _personController,
            style: appFont(fontSize: 14.5),
            decoration: const InputDecoration(hintText: 'ชื่อผู้โดยสาร'),
          ),
          if (names.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final name in names)
                  ActionChip(
                    label: Text(
                      name,
                      style: appFont(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                    onPressed: () =>
                        setState(() => _personController.text = name),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),

          _label('รายละเอียดเหตุการณ์'),
          const SizedBox(height: 8),
          TextField(
            controller: _descController,
            style: appFont(fontSize: 14.5),
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'เกิดอะไรขึ้น อาการ และสิ่งที่ดำเนินการไปแล้ว',
            ),
          ),
          const SizedBox(height: 20),

          _LocationTile(
            attach: _attachLocation,
            locating: _locating,
            position: _position,
            onToggle: (v) => setState(() => _attachLocation = v),
            onRetry: _captureLocation,
          ),
          const SizedBox(height: 12),

          _PhotoTile(
            photoPath: _photoPath,
            onPick: _pickPhoto,
            onRemove: () => setState(() => _photoPath = null),
          ),
          const SizedBox(height: 28),

          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.report_rounded),
            label: Text(
              _submitting ? 'กำลังส่ง...' : 'ส่งแจ้งเหตุ',
              style: appFont(fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: appFont(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: AppTheme.mutedText(context),
    ),
  );
}

class _SeverityChip extends StatelessWidget {
  final _Severity severity;
  final bool selected;
  final VoidCallback onTap;

  const _SeverityChip({
    required this.severity,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? severity.color
              : severity.color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? severity.color
                : severity.color.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          severity.label,
          style: appFont(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : severity.color,
          ),
        ),
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  final bool attach;
  final bool locating;
  final Position? position;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRetry;

  const _LocationTile({
    required this.attach,
    required this.locating,
    required this.position,
    required this.onToggle,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final String status;
    if (locating) {
      status = 'กำลังระบุตำแหน่ง...';
    } else if (position != null) {
      status =
          'พิกัด: ${position!.latitude.toStringAsFixed(5)}, ${position!.longitude.toStringAsFixed(5)}';
    } else {
      status = 'ระบุตำแหน่งไม่ได้ — แตะเพื่อลองใหม่';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(context),
      child: Row(
        children: [
          const Icon(Icons.my_location_rounded, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'แนบตำแหน่งปัจจุบัน',
                  style: appFont(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface(context),
                  ),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: position == null && !locating ? onRetry : null,
                  child: Text(
                    status,
                    style: appFont(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: attach && position != null,
            onChanged: position == null ? null : onToggle,
          ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final String? photoPath;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _PhotoTile({
    required this.photoPath,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (photoPath != null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: AppTheme.cardDecoration(context),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(photoPath!),
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'แนบรูปแล้ว',
                style: appFont(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface(context),
                ),
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPick,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      icon: const Icon(Icons.add_a_photo_rounded),
      label: Text(
        'ถ่ายรูปประกอบ (ถ้ามี)',
        style: appFont(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }
}
