import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/trip_medal.dart';
import '../theme/app_theme.dart';
import '../utils/share_card.dart';
import 'app_snack.dart';
import 'medal_art.dart';
import 'medal_story_card.dart';
import 'trip_story_card.dart';

/// เปิด sheet แชร์เหรียญลงสตอรี่
///
/// โหลดทุกรูปที่จะอยู่บนการ์ดให้เข้าแคชก่อนเปิดเสมอ (โลโก้ ภาพเหรียญออกแบบเอง
/// รูปปกทริป) เพราะ `toImage` จับเฉพาะสิ่งที่วาดเสร็จแล้ว — รูปที่ยังโหลดไม่เสร็จ
/// จะหายไปจาก PNG เงียบ ๆ (บทเรียนเดียวกับการ์ดนับถอยหลัง)
Future<void> showMedalShareSheet(BuildContext context, TripMedal medal) async {
  Future<ImageProvider?> warm(ImageProvider provider) async {
    try {
      await precacheImage(provider, context);
      return provider;
    } catch (_) {
      return null;
    }
  }

  await warm(const AssetImage(kStoryLogoAsset));

  final medalUrl = medal.design.imageUrl;
  if (medalUrl != null && context.mounted) {
    // ขนาด/สเกลต้องตรงกับที่ MedalStoryCard วาด ไม่งั้นแคชคนละตัว
    await warm(
      medalImageProvider(medalUrl, kMedalStoryMedalSize, kShareCardPixelRatio),
    );
  }

  ImageProvider? cover;
  final coverUrl = medal.coverImage;
  if (coverUrl != null && coverUrl.isNotEmpty && context.mounted) {
    cover = await warm(
      ResizeImage(NetworkImage(coverUrl), width: 1080, allowUpscaling: false),
    );
  }

  if (!context.mounted) return;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => MedalShareSheet(medal: medal, tripPhoto: cover),
  );
}

class MedalShareSheet extends StatefulWidget {
  final TripMedal medal;

  /// รูปปกทริปที่โหลดเข้าแคชแล้ว — null เมื่อทริปไม่มีรูปหรือโหลดไม่ได้
  final ImageProvider? tripPhoto;

  const MedalShareSheet({super.key, required this.medal, this.tripPhoto});

  @override
  State<MedalShareSheet> createState() => _MedalShareSheetState();
}

class _MedalShareSheetState extends State<MedalShareSheet> {
  final GlobalKey _cardKey = GlobalKey();
  MedalBackdrop _backdrop = MedalBackdrop.color;
  ImageProvider? _ownPhoto;
  bool _usingOwnPhoto = false;
  bool _picking = false;
  bool _sharing = false;

  ImageProvider? get _photo => _usingOwnPhoto ? _ownPhoto : widget.tripPhoto;

  /// รูปของเจ้าของการ์ด — ไม่เคยถูกอัปโหลดไปไหน ถูกวาดลงการ์ดในเครื่องแล้วกลาย
  /// เป็น PNG ที่เจ้าตัวเลือกเองว่าจะส่งต่อให้ใคร ย่อตั้งแต่ตอนเลือกเพราะการ์ด
  /// ถูกจับภาพ 3 เท่า รูปดิบจากกล้องจะกินหน่วยความจำจนแอปถูกปิด
  Future<void> _pickPhoto() async {
    if (_picking) return;
    setState(() => _picking = true);

    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1440,
        maxHeight: 2560,
        imageQuality: 92,
      );

      if (picked == null || !mounted) return;

      final image = FileImage(File(picked.path));
      await precacheImage(image, context);
      if (!mounted) return;

      setState(() {
        _ownPhoto = image;
        _usingOwnPhoto = true;
        _backdrop = MedalBackdrop.photo;
      });
    } catch (_) {
      if (mounted) AppSnack.error(context, 'เปิดรูปไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _share() async {
    if (_sharing) return;
    HapticFeedback.mediumImpact();
    setState(() => _sharing = true);

    try {
      // เพิ่งสลับพื้นหลังก่อนกดแชร์ — รอให้เฟรมล่าสุดวาดจบก่อนจับภาพ
      await WidgetsBinding.instance.endOfFrame;

      await shareWidgetAsPng(
        boundaryKey: _cardKey,
        fileName: 'luilaykhao_medal.png',
        text: _shareText(),
      );
    } catch (_) {
      if (mounted) AppSnack.error(context, 'แชร์ไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// คำบรรยายของคนที่พิชิต ไม่ใช่คำขายของ — ลิงก์ท้ายเปิดหน้าเหรียญที่มีภาพ OG
  /// พอโพสต์ลงฟีด/LINE แล้วพรีวิวจึงขึ้นเป็นเหรียญ ไม่ใช่กล่องเปล่า
  String _shareText() {
    final medal = widget.medal;
    final url = medal.shareUrl;

    return 'พิชิต "${medal.design.name}" แล้ว! 🏅 ${medal.finisherLabel}'
        '${url.isEmpty ? '' : '\n$url'}\n#ลุยเลเขา';
  }

  void _selectBackdrop(MedalBackdrop backdrop, {bool own = false}) {
    HapticFeedback.selectionClick();
    setState(() {
      _backdrop = backdrop;
      if (backdrop == MedalBackdrop.photo) _usingOwnPhoto = own;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasTripPhoto = widget.tripPhoto != null;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.mutedText(context).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
            ),
            Flexible(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // การ์ดวาดที่ 360×640 เสมอ (PNG 1080×1920 ทุกเครื่อง) ส่วนนี้
                  // แค่ย่อตอนแสดงผลให้พอดีจอ — RepaintBoundary จับตามขนาดจริง
                  final scale = math.min(
                    constraints.maxWidth / kStoryCardWidth,
                    constraints.maxHeight / kStoryCardHeight,
                  );

                  return Center(
                    child: SizedBox(
                      width: kStoryCardWidth * scale,
                      height: kStoryCardHeight * scale,
                      child: FittedBox(
                        child: RepaintBoundary(
                          key: _cardKey,
                          child: MedalStoryCard(
                            medal: widget.medal,
                            backdrop: _backdrop,
                            photo: _photo,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _BackdropChip(
                    label: MedalBackdrop.color.label,
                    active: _backdrop == MedalBackdrop.color,
                    onTap: () => _selectBackdrop(MedalBackdrop.color),
                  ),
                  _BackdropChip(
                    label: MedalBackdrop.paper.label,
                    active: _backdrop == MedalBackdrop.paper,
                    onTap: () => _selectBackdrop(MedalBackdrop.paper),
                  ),
                  if (hasTripPhoto)
                    _BackdropChip(
                      label: 'รูปทริป',
                      active:
                          _backdrop == MedalBackdrop.photo && !_usingOwnPhoto,
                      onTap: () => _selectBackdrop(MedalBackdrop.photo),
                    ),
                  _BackdropChip(
                    label: _ownPhoto == null ? 'ใช้รูปของคุณ' : 'รูปของคุณ',
                    icon: Icons.photo_library_rounded,
                    busy: _picking,
                    active: _backdrop == MedalBackdrop.photo && _usingOwnPhoto,
                    onTap: _ownPhoto == null
                        ? _pickPhoto
                        : () => _selectBackdrop(MedalBackdrop.photo, own: true),
                    onLongPress: _pickPhoto,
                  ),
                ],
              ),
            ),
            if (_ownPhoto != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: Text(
                    'เปลี่ยนรูป',
                    style: appFont(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sharing ? null : _share,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
                icon: _sharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.ios_share_rounded, size: 18),
                label: Text(
                  _sharing ? 'กำลังเตรียม...' : 'แชร์เหรียญ',
                  style: appFont(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackdropChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final IconData? icon;
  final bool busy;

  const _BackdropChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.onLongPress,
    this.icon,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? Colors.white : AppTheme.onSurface(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: busy ? null : onTap,
        onLongPress: busy ? null : onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: active
                ? AppTheme.primaryColor
                : AppTheme.subtleSurface(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
              color: active ? AppTheme.primaryColor : AppTheme.border(context),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (icon != null)
                Icon(icon, size: 16, color: fg),
              if (busy || icon != null) const SizedBox(width: 6),
              Text(
                label,
                style: appFont(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
