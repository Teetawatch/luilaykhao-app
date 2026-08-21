import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';
import 'app_snack.dart';

/// ช่องแนบไฟล์เอกสารตามที่ทริปขอ
///
/// รายการเอกสารและข้อความ "ใช้สำหรับ..." มาจากที่แอดมินตั้งไว้บนทริป —
/// หน้าจอนี้แค่วาด ไม่ตัดสินใจเองว่าอะไรจำเป็น
///
/// ใช้ทั้งตอนจอง (เก็บ path ไว้ก่อน อัปโหลดหลังได้ booking_ref) และตอนตามมา
/// แนบทีหลังจากหน้ารายละเอียดการจอง (อัปโหลดทันที) — ต่างกันแค่ callback
class DocumentAttachField extends StatelessWidget {
  /// { key, label, note, required } ตามที่ backend ส่งมา
  final Map<String, dynamic> requirement;

  /// ชื่อไฟล์ที่แนบไว้แล้ว (ยังไม่ส่ง หรือส่งแล้วก็ได้)
  final List<String> fileNames;

  /// กำลังอัปโหลดอยู่ — ปิดปุ่มไว้ก่อน
  final bool busy;

  /// แตะ "แนบไฟล์" แล้วเลือกไฟล์ได้ path หนึ่งอัน
  final ValueChanged<String> onPicked;

  /// เอาไฟล์ลำดับนี้ออก; null = ห้ามลบ (เช่น กำลังส่งอยู่)
  final void Function(int index)? onRemove;

  static const int maxFiles = 5;
  static const int maxSizeMb = 10;

  const DocumentAttachField({
    super.key,
    required this.requirement,
    required this.fileNames,
    required this.onPicked,
    this.onRemove,
    this.busy = false,
  });

  String get _label => (requirement['label'] ?? '').toString();

  String get _note => (requirement['note'] ?? '').toString();

  bool get _isRequired => requirement['required'] == true;

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedText(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _label,
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface(context),
                ),
              ),
            ),
            Text(
              _isRequired ? 'ต้องแนบ' : 'ไม่บังคับ',
              style: appFont(
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w700,
                color: _isRequired ? AppTheme.dangerColor : muted,
              ),
            ),
          ],
        ),
        if (_note.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            _note,
            style: appFont(fontSize: AppText.sizeCaption, color: muted),
          ),
        ],
        for (var i = 0; i < fileNames.length; i++) ...[
          const SizedBox(height: 8),
          _AttachedFileRow(
            name: fileNames[i],
            onRemove: onRemove == null ? null : () => onRemove!(i),
          ),
        ],
        const SizedBox(height: 8),
        if (fileNames.length < maxFiles)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: busy ? null : () => _pick(context),
              icon: Icon(
                busy ? Icons.hourglass_top_rounded : Icons.attach_file_rounded,
                size: 18,
              ),
              label: Text(
                busy
                    ? 'กำลังอัปโหลด...'
                    : (fileNames.isEmpty ? 'แนบไฟล์' : 'แนบไฟล์เพิ่ม'),
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final source = await showModalBottomSheet<_DocSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  _label,
                  style: appFont(
                    fontSize: AppText.sizeSubtitle,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(ctx),
                  ),
                ),
              ),
              _SourceTile(
                icon: Icons.photo_camera_rounded,
                label: 'ถ่ายรูปเอกสาร',
                onTap: () => Navigator.pop(ctx, _DocSource.camera),
              ),
              const SizedBox(height: 8),
              _SourceTile(
                icon: Icons.photo_library_rounded,
                label: 'เลือกรูปจากเครื่อง',
                onTap: () => Navigator.pop(ctx, _DocSource.gallery),
              ),
              const SizedBox(height: 8),
              _SourceTile(
                icon: Icons.picture_as_pdf_rounded,
                label: 'เลือกไฟล์ PDF',
                onTap: () => Navigator.pop(ctx, _DocSource.file),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null || !context.mounted) return;

    try {
      final path = await _resolvePath(source);
      if (path == null || !context.mounted) return;

      // ขนาดไฟล์ตรวจที่นี่ด้วย ไม่รอให้เซิร์ฟเวอร์ปฏิเสธ — คนที่เน็ตช้าจะได้
      // ไม่เสียเวลาอัปโหลดไฟล์ 30 MB จนจบแล้วค่อยรู้ว่าใหญ่เกิน
      final bytes = await File(path).length();
      if (bytes > maxSizeMb * 1024 * 1024) {
        if (context.mounted) {
          AppSnack.error(context, 'ไฟล์ใหญ่เกิน $maxSizeMb MB');
        }
        return;
      }

      onPicked(path);
    } catch (e) {
      if (context.mounted) AppSnack.error(context, 'เลือกไฟล์ไม่สำเร็จ');
    }
  }

  Future<String?> _resolvePath(_DocSource source) async {
    if (source == _DocSource.file) {
      final result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'heic', 'webp'],
      );
      return result?.path;
    }

    final image = await ImagePicker().pickImage(
      source: source == _DocSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      // เอกสารต้องอ่านตัวหนังสือออก บีบแรงกว่านี้แล้วเลขพาสปอร์ตจะเบลอ
      imageQuality: 90,
      maxWidth: 2400,
    );
    return image?.path;
  }
}

enum _DocSource { camera, gallery, file }

class _AttachedFileRow extends StatelessWidget {
  final String name;
  final VoidCallback? onRemove;

  const _AttachedFileRow({required this.name, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final isPdf = name.toLowerCase().endsWith('.pdf');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusMd),
      child: Row(
        children: [
          Icon(
            isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
            size: 18,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface(context),
              ),
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: AppTheme.mutedText(context),
              ),
              tooltip: 'เอาไฟล์นี้ออก',
            ),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusMd),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            Text(
              label,
              style: appFont(
                fontSize: AppText.sizeBody,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
