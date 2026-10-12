import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../utils/share_card.dart';
import 'app_snack.dart';
import 'review_story_card.dart';
import 'share_sheet_controls.dart';
import 'trip_story_card.dart';

/// Bottom sheet ที่พรีวิว [ReviewStoryCard] แล้วแชร์/บันทึกเป็น PNG
///
/// เปิดด้วย [showReviewShareSheet] เสมอ — ตัวช่วยนั้นโหลดรูปเข้าแคชก่อนเปิด
/// ไม่งั้นรูปพื้นหลังจะหายไปจากภาพที่จับได้
class ReviewShareSheet extends StatefulWidget {
  final String comment;
  final int rating;
  final String tripTitle;
  final String reviewerName;
  final List<ImageProvider> photos;
  final String? tripUrl;

  const ReviewShareSheet({
    super.key,
    required this.comment,
    required this.rating,
    required this.tripTitle,
    this.reviewerName = '',
    this.photos = const [],
    this.tripUrl,
  });

  @override
  State<ReviewShareSheet> createState() => _ReviewShareSheetState();
}

class _ReviewShareSheetState extends State<ReviewShareSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;
  bool _saving = false;

  /// มีรูปก็เปิดมาเป็นรูป — รีวิวที่แนบรูปมาคือคนที่อยากอวดรูปนั้น
  late ReviewBackdrop _backdrop = widget.photos.isEmpty
      ? ReviewBackdrop.forest
      : ReviewBackdrop.photo;
  int _photoIndex = 0;
  bool _showLogo = true;
  bool _showName = true;
  StickerInk _ink = StickerInk.light;

  bool get _sticker => _backdrop == ReviewBackdrop.sticker;

  ImageProvider? get _photo =>
      widget.photos.isEmpty ? null : widget.photos[_photoIndex];

  String get _fileName =>
      _sticker ? 'luilaykhao_review_sticker.png' : 'luilaykhao_review.png';

  Future<void> _share() async {
    if (_sharing) return;
    HapticFeedback.mediumImpact();
    setState(() => _sharing = true);

    try {
      await WidgetsBinding.instance.endOfFrame;
      final shared = await shareWidgetAsPng(
        boundaryKey: _cardKey,
        fileName: _fileName,
        text: reviewShareCaption(
          comment: widget.comment,
          rating: widget.rating,
          tripTitle: widget.tripTitle,
          tripUrl: widget.tripUrl,
        ),
      );
      if (shared && mounted) Navigator.of(context).maybePop();
    } catch (_) {
      if (mounted) AppSnack.error(context, 'แชร์ไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);

    try {
      await WidgetsBinding.instance.endOfFrame;
      await saveWidgetToGallery(boundaryKey: _cardKey, fileName: _fileName);
      if (!mounted) return;
      AppSnack.success(
        context,
        _sticker
            ? 'บันทึกสติกเกอร์แล้ว — ใน IG Story กดสติกเกอร์ → รูปภาพ'
            : 'บันทึกรูปลงเครื่องแล้ว',
      );
    } on ShareCardException catch (e) {
      if (mounted) {
        AppSnack.error(
          context,
          shareCardFailureMessage(e.reason, saving: true),
        );
      }
    } catch (_) {
      if (mounted) {
        AppSnack.error(context, 'บันทึกรูปไม่สำเร็จ ลองใหม่อีกครั้ง');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _pick(ReviewBackdrop backdrop) {
    HapticFeedback.selectionClick();
    setState(() => _backdrop = backdrop);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ShareSheetHeader(title: 'แชร์รีวิวของคุณ'),
            const SizedBox(height: 6),
            Flexible(child: _preview()),
            const SizedBox(height: 12),
            _controls(),
            const SizedBox(height: 12),
            Row(
              children: [
                ShareSaveButton(busy: _saving, onPressed: _save),
                const SizedBox(width: 8),
                Expanded(
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
                      _sharing ? 'กำลังเตรียม...' : 'แชร์ลงสตอรี่',
                      style: appFont(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // การ์ดวาดที่ 360×640 เสมอ (PNG 1080×1920) — ส่วนนี้แค่ย่อตอนแสดงผล
        final scale = math.min(
          constraints.maxWidth / kStoryCardWidth,
          constraints.maxHeight / kStoryCardHeight,
        );

        return Center(
          child: SizedBox(
            width: kStoryCardWidth * scale,
            height: kStoryCardHeight * scale,
            child: FittedBox(
              // ลายหมากรุกอยู่นอก RepaintBoundary — ไม่ติดไปกับ PNG
              child: DecoratedBox(
                decoration: _sticker
                    ? BoxDecoration(
                        image: DecorationImage(
                          image: kShareCheckerboard,
                          repeat: ImageRepeat.repeat,
                          filterQuality: FilterQuality.none,
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      )
                    : const BoxDecoration(),
                child: RepaintBoundary(
                  key: _cardKey,
                  child: ReviewStoryCard(
                    comment: widget.comment,
                    rating: widget.rating,
                    tripTitle: widget.tripTitle,
                    reviewerName: widget.reviewerName,
                    backdrop: _backdrop,
                    photo: _photo,
                    showLogo: _showLogo,
                    showName: _showName,
                    ink: _ink,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _controls() {
    final hasPhotos = widget.photos.isNotEmpty;
    final hasName = widget.reviewerName.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShareChipRow(
          children: [
            for (final backdrop in ReviewBackdrop.values)
              if (backdrop != ReviewBackdrop.photo || hasPhotos)
                SharePill(
                  label: backdrop.label,
                  icon: switch (backdrop) {
                    ReviewBackdrop.photo => Icons.landscape_rounded,
                    ReviewBackdrop.sticker => Icons.layers_clear_rounded,
                    _ => null,
                  },
                  swatch: switch (backdrop) {
                    ReviewBackdrop.forest => const Color(0xFF065F46),
                    ReviewBackdrop.paper => const Color(0xFFFDFBF5),
                    _ => null,
                  },
                  active: _backdrop == backdrop,
                  onTap: () => _pick(backdrop),
                ),
          ],
        ),
        // เลือกรูปพื้นหลังเมื่อแนบมาหลายรูป
        if (_backdrop == ReviewBackdrop.photo && widget.photos.length > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final active = i == _photoIndex;
                return Semantics(
                  button: true,
                  selected: active,
                  label: 'รูปที่ ${i + 1}',
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _photoIndex = i);
                    },
                    child: Container(
                      width: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(
                          color: active
                              ? AppTheme.primaryColor
                              : AppTheme.border(context),
                          width: active ? 2.5 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image(
                        image: widget.photos[i],
                        fit: BoxFit.cover,
                        // ย่อแค่ตอนวาดชิป — รูปเต็มยังอยู่ในแคชให้การ์ดใช้
                        width: 52,
                        height: 52,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        if (_sticker) ...[
          const SizedBox(height: 10),
          ShareChipRow(
            children: [
              for (final ink in StickerInk.values)
                SharePill(
                  label: ink.label,
                  swatch: ink == StickerInk.light
                      ? Colors.white
                      : AppTheme.slate900,
                  active: _ink == ink,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _ink = ink);
                  },
                ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ShareToggle(
              label: 'โลโก้',
              on: _showLogo,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _showLogo = !_showLogo);
              },
            ),
            if (hasName)
              ShareToggle(
                label: 'ชื่อของฉัน',
                on: _showName,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _showName = !_showName);
                },
              ),
          ],
        ),
        ShareHint(
          _sticker
              ? 'กด "บันทึก" แล้วใน IG Story กดสติกเกอร์ → รูปภาพ '
                    'เพื่อแปะคำรีวิวทับรูปหรือวิดีโอของคุณ'
              : 'คำบนการ์ดเป็นคำที่คุณเขียนเอง ยาวเกินจะถูกตัดท้ายให้พอดีการ์ด',
        ),
      ],
    );
  }
}

/// เปิด sheet แชร์คำรีวิว — โหลดรูปกับโลโก้เข้าแคชก่อนเปิดเสมอ
///
/// [photos] เป็นได้ทั้งไฟล์ในเครื่อง (เพิ่งเลือกตอนเขียนรีวิว) หรือรูปบน
/// เซิร์ฟเวอร์ (เปิดจาก "รีวิวของฉัน") รูปที่โหลดไม่ขึ้นถูกตัดทิ้งเงียบ ๆ
Future<void> showReviewShareSheet(
  BuildContext context, {
  required String comment,
  required int rating,
  required String tripTitle,
  String reviewerName = '',
  List<ImageProvider> photos = const [],
  String? tripUrl,
}) async {
  final usable = <ImageProvider>[];
  for (final photo in photos.take(6)) {
    try {
      await precacheImage(photo, context);
      usable.add(photo);
    } catch (_) {
      // รูปโหลดไม่ได้ — การ์ดยังมีพื้นเขียวป่าให้ใช้
    }
    if (!context.mounted) return;
  }

  try {
    await precacheImage(const AssetImage(kStoryLogoAsset), context);
  } catch (_) {
    // โลโก้เป็นลายเซ็นมุมการ์ด — ขาดไปก็ยังแชร์ได้
  }
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppTheme.surface(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ReviewShareSheet(
      comment: comment,
      rating: rating,
      tripTitle: tripTitle,
      reviewerName: reviewerName,
      photos: usable,
      tripUrl: tripUrl,
    ),
  );
}
