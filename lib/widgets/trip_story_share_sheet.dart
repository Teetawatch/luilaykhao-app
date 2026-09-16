import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/story_look_storage.dart';
import '../theme/app_theme.dart';
import '../utils/share_card.dart';
import 'app_snack.dart';
import 'trip_story_card.dart';

/// Bottom sheet ที่พรีวิว [TripStoryCard] แล้วส่งออกเป็น PNG 1080×1920
///
/// เปิดด้วย [showTripStoryShareSheet] (ก่อนไป) หรือ [showTripRecapShareSheet]
/// (กลับมาแล้ว) เสมอ อย่าเรียก showModalBottomSheet เอง เพราะตัวช่วยนั้นโหลด
/// รูปปกให้เสร็จก่อนเปิด ซึ่งเป็นเงื่อนไขที่ทำให้ภาพที่จับได้มีรูปจริงไม่ใช่ช่องว่าง
///
/// ใต้พรีวิวมีของให้เล่นสามอย่าง — รูป, สไตล์การ์ด, ความโปร่งใสของรูป — สไตล์
/// กับความโปร่งใสถูกจำไว้ผ่าน [StoryLookStorage] เพราะรสนิยมของคนไม่ได้เปลี่ยน
/// ทุกทริป ส่วนรูปไม่จำ เพราะเป็นของทริปนั้น ๆ
class TripStoryShareSheet extends StatefulWidget {
  final String tripTitle;
  final String location;
  final DateTime? departureDate;
  final int? daysLeft;
  final ImageProvider? coverImage;

  /// เลขที่จอง ใช้ *เฉพาะ* ขอลิงก์การ์ดสาธารณะจาก API — ไม่เคยถูกวาดลงการ์ด
  final String? bookingRef;

  /// โหมดการ์ดจบทริป: ตัวเด่นที่ผู้เรียกกำหนดเอง + ตัวเลขสรุป + ป้ายวันที่
  final StoryCountdown? highlight;
  final List<StoryStat> stats;
  final String? dateLabel;

  const TripStoryShareSheet({
    super.key,
    required this.tripTitle,
    required this.location,
    required this.departureDate,
    required this.daysLeft,
    this.coverImage,
    this.bookingRef,
    this.highlight,
    this.stats = const [],
    this.dateLabel,
  });

  bool get isRecap => highlight != null;

  @override
  State<TripStoryShareSheet> createState() => _TripStoryShareSheetState();
}

class _TripStoryShareSheetState extends State<TripStoryShareSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;
  bool _picking = false;
  String? _shareUrl;
  StoryStyle _style = StoryLook.defaults.style;
  double _photoOpacity = StoryLook.defaults.photoOpacity;

  /// รูปบนการ์ด — เริ่มที่รูปปกทริป จนกว่าเจ้าของจะเลือกรูปของตัวเองมาแทน
  ImageProvider? _photo;
  bool _ownPhoto = false;
  StoryPhotoFraming _framing = StoryPhotoFraming.none;

  /// ค่าตั้งต้นของท่าทางหนึ่งครั้ง — เก็บไว้ตอนนิ้วแตะ แล้วคำนวณจากจุดนั้น
  /// ทุกเฟรม การลากจึงไม่สะสมความคลาดเคลื่อนทีละนิดจนรูปไหลไปเอง
  double _gestureScale = 1;
  Offset _gestureOffset = Offset.zero;
  Offset _gestureFocal = Offset.zero;

  static const Size _cardFrame = Size(kStoryCardWidth, kStoryCardHeight);

  @override
  void initState() {
    super.initState();
    _photo = widget.coverImage;
    _loadLook();
    _loadShareUrl();
  }

  Future<void> _loadLook() async {
    final look = await StoryLookStorage.instance.read();
    if (!mounted) return;

    setState(() {
      _style = look.style;
      _photoOpacity = look.photoOpacity;
    });
  }

  void _rememberLook() {
    StoryLookStorage.instance.write(
      StoryLook(style: _style, photoOpacity: _photoOpacity),
    );
  }

  /// ลิงก์ที่ติดไปกับคำบรรยาย ไม่ใช่เงื่อนไขของการแชร์ — โหลดไม่ได้ก็แค่ไม่มี
  /// ลิงก์ ผู้ใช้ยังแชร์การ์ดได้ตามปกติ
  ///
  /// เป็นลิงก์การ์ดสาธารณะ (/s/{token}) เพราะปลายทางมีภาพ OG เป็นการ์ดใบ
  /// เดียวกัน พอโพสต์ลงฟีดแล้วพรีวิวจึงขึ้นเป็นรูป ไม่ใช่กล่องเปล่า
  Future<void> _loadShareUrl() async {
    final ref = widget.bookingRef;
    if (ref == null || ref.isEmpty) return;

    try {
      final url = await context.read<AppProvider>().fetchBookingStoryLink(ref);
      if (!mounted || url == null || url.isEmpty) return;

      setState(() => _shareUrl = url);
    } catch (_) {
      // เงียบไว้ตั้งใจ — ดูหัวข้อคอมเมนต์ด้านบน
    }
  }

  // ── รูปของเจ้าของการ์ด ──────────────────────────────────────────────────

  /// เลือกรูปจากคลังในเครื่อง
  ///
  /// รูปไม่เคยถูกอัปโหลดไปไหน — ถูกวาดลงการ์ดในเครื่องแล้วกลายเป็น PNG ที่ผู้ใช้
  /// เป็นคนตัดสินใจเองว่าจะส่งต่อให้ใคร เราจึงไม่ต้องเก็บ ไม่ต้องตรวจ ไม่ต้องลบ
  ///
  /// ย่อตั้งแต่ตอนเลือก เพราะการ์ดถูกจับภาพที่ 3 เท่า รูปดิบ 12 ล้านพิกเซล
  /// จะกินหน่วยความจำจนแอปโดนระบบฆ่าทิ้งกลางทาง
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
      final aspect = await _resolveAspectRatio(image);
      if (!mounted) return;

      setState(() {
        _photo = image;
        _ownPhoto = true;
        // รูปใหม่เริ่มเฟรมใหม่เสมอ ค่าที่จัดไว้กับรูปเก่าไม่มีความหมายกับรูปนี้
        _framing = StoryPhotoFraming(aspectRatio: aspect);
      });
    } catch (_) {
      if (mounted) AppSnack.error(context, 'เปิดรูปไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _useTripPhoto() {
    setState(() {
      _photo = widget.coverImage;
      _ownPhoto = false;
      _framing = StoryPhotoFraming.none;
    });
  }

  /// อ่านสัดส่วนรูปจริง แล้วอุ่นแคชไปในตัว — ต้องรู้สัดส่วนก่อนถึงจะบอกได้ว่า
  /// ลากรูปไปได้ไกลแค่ไหนโดยขอบไม่โผล่
  Future<double?> _resolveAspectRatio(ImageProvider provider) {
    final completer = Completer<double?>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;

    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        final ui.Image image = info.image;
        if (!completer.isCompleted) {
          completer.complete(
            image.height == 0 ? null : image.width / image.height,
          );
        }
        stream.removeListener(listener);
      },
      onError: (_, _) {
        if (!completer.isCompleted) completer.complete(null);
        stream.removeListener(listener);
      },
    );

    stream.addListener(listener);

    return completer.future;
  }

  // ── ท่าทางจัดเฟรมรูป ────────────────────────────────────────────────────

  void _onScaleStart(ScaleStartDetails details) {
    _gestureScale = _framing.scale;
    _gestureOffset = _framing.offset;
    _gestureFocal = details.localFocalPoint;
  }

  /// [displayScale] คืออัตราส่วนที่พรีวิวถูกย่อลงมาให้พอดีจอ — นิ้วขยับบนจอ
  /// 10 พิกเซลจึงไม่เท่ากับรูปขยับ 10 หน่วยบนการ์ด ต้องหารกลับก่อนเสมอ
  void _onScaleUpdate(ScaleUpdateDetails details, double displayScale) {
    if (_photo == null || displayScale <= 0) return;

    final scale = (_gestureScale * details.scale).clamp(1.0, 4.0);
    final moved = (details.localFocalPoint - _gestureFocal) / displayScale;
    final candidate = _framing.copyWith(
      scale: scale,
      offset: _gestureOffset + moved,
    );

    setState(() {
      _framing = candidate.copyWith(offset: candidate.clampOffset(_cardFrame));
    });
  }

  // ── แชร์ ────────────────────────────────────────────────────────────────

  Future<void> _share() async {
    if (_sharing) return;
    HapticFeedback.mediumImpact();
    setState(() => _sharing = true);

    try {
      // การ์ดเพิ่งเปลี่ยนรูปร่างถ้าผู้ใช้สลับสไตล์ก่อนกดแชร์ — รอให้เฟรมล่าสุด
      // วาดจบก่อนจับภาพ ไม่งั้นได้ภาพของเลย์เอาต์เก่า
      await WidgetsBinding.instance.endOfFrame;

      await shareWidgetAsPng(
        boundaryKey: _cardKey,
        fileName: widget.isRecap
            ? 'luilaykhao_recap.png'
            : 'luilaykhao_countdown.png',
        text: _shareText(),
      );
    } on ShareCardException {
      if (mounted) AppSnack.error(context, 'แชร์ไม่สำเร็จ ลองใหม่อีกครั้ง');
    } catch (_) {
      if (mounted) AppSnack.error(context, 'แชร์ไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// คำบรรยายที่ติดไปกับรูป — บางแอป (IG Story) ทิ้งไป บางแอป (LINE, FB) ใช้
  /// จึงต้องอ่านรู้เรื่องด้วยตัวเองโดยไม่ต้องเห็นรูป
  ///
  /// เป็นคำของเจ้าของทริป ไม่ใช่คำขายของบริษัท — มีแค่ลิงก์การ์ดต่อท้ายไว้ให้
  /// คนกดดูต่อได้ ไม่มีคำชวนจองพ่วง
  String _shareText() {
    final days = widget.daysLeft;
    final lead = widget.isRecap
        ? 'เพิ่งกลับจาก "${widget.tripTitle}"'
        : switch (days) {
            null => 'ทริปต่อไปของฉัน',
            < 0 => 'กำลังลุย "${widget.tripTitle}"',
            0 => 'วันนี้ออกเดินทางไป "${widget.tripTitle}" แล้ว',
            1 => 'พรุ่งนี้ไป "${widget.tripTitle}" แล้ว',
            _ => 'อีก $days วันจะได้ไป "${widget.tripTitle}"',
          };

    final url = _shareUrl;

    return '$lead 🏔️${url == null ? '' : '\n$url'}\n#ลุยเลเขา';
  }

  // ── หน้าตา ──────────────────────────────────────────────────────────────

  Widget _card() {
    if (widget.isRecap) {
      return TripStoryCard.recap(
        tripTitle: widget.tripTitle,
        location: widget.location,
        highlight: widget.highlight!,
        dateLabel: widget.dateLabel ?? '',
        stats: widget.stats,
        coverImage: _photo,
        framing: _framing,
        style: _style,
        photoOpacity: _photoOpacity,
      );
    }

    return TripStoryCard(
      tripTitle: widget.tripTitle,
      location: widget.location,
      departureDate: widget.departureDate,
      daysLeft: widget.daysLeft,
      coverImage: _photo,
      framing: _framing,
      style: _style,
      photoOpacity: _photoOpacity,
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  // การ์ดวาดที่ 360×640 เสมอเพื่อให้ PNG ออกมา 1080×1920 เท่ากัน
                  // ทุกเครื่อง ส่วน FittedBox แค่ย่อ *ตอนแสดงผล* ให้พอดีจอ —
                  // RepaintBoundary จับภาพตามขนาด layout ของตัวเอง ไม่ใช่ขนาดที่ย่อ
                  //
                  // คำนวณอัตราย่อเองแทนที่จะปล่อย FittedBox คิด เพราะท่าทางลากรูป
                  // ต้องใช้ตัวเลขเดียวกันนี้แปลงนิ้วบนจอเป็นระยะบนการ์ด
                  final displayScale = math.min(
                    constraints.maxWidth / kStoryCardWidth,
                    constraints.maxHeight / kStoryCardHeight,
                  );

                  return Center(
                    child: SizedBox(
                      width: kStoryCardWidth * displayScale,
                      height: kStoryCardHeight * displayScale,
                      child: GestureDetector(
                        onScaleStart: _onScaleStart,
                        onScaleUpdate: (details) =>
                            _onScaleUpdate(details, displayScale),
                        child: FittedBox(
                          child: RepaintBoundary(key: _cardKey, child: _card()),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            _PhotoBar(
              busy: _picking,
              hasOwnPhoto: _ownPhoto,
              canUseTripPhoto: widget.coverImage != null,
              onPick: _pickPhoto,
              onUseTripPhoto: _useTripPhoto,
            ),
            const SizedBox(height: 10),
            _StylePicker(
              selected: _style,
              onSelected: (style) {
                HapticFeedback.selectionClick();
                setState(() => _style = style);
                _rememberLook();
              },
            ),
            const SizedBox(height: 10),
            _OpacitySlider(
              value: _photoOpacity,
              onChanged: (value) => setState(() => _photoOpacity = value),
              onSettled: _rememberLook,
            ),
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
      ),
    );
  }
}

/// แถวจัดการรูปบนการ์ด
class _PhotoBar extends StatelessWidget {
  final bool busy;
  final bool hasOwnPhoto;
  final bool canUseTripPhoto;
  final VoidCallback onPick;
  final VoidCallback onUseTripPhoto;

  const _PhotoBar({
    required this.busy,
    required this.hasOwnPhoto,
    required this.canUseTripPhoto,
    required this.onPick,
    required this.onUseTripPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PhotoAction(
          icon: Icons.photo_library_rounded,
          label: hasOwnPhoto ? 'เปลี่ยนรูป' : 'ใช้รูปของคุณ',
          busy: busy,
          onTap: busy ? null : onPick,
        ),
        if (hasOwnPhoto && canUseTripPhoto) ...[
          const SizedBox(width: 8),
          _PhotoAction(
            icon: Icons.landscape_rounded,
            label: 'รูปทริป',
            busy: false,
            onTap: busy ? null : onUseTripPhoto,
          ),
        ],
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'ลากเพื่อเลื่อน จีบนิ้วเพื่อซูม',
            textAlign: TextAlign.end,
            maxLines: 2,
            style: appFont(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.mutedText(context),
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback? onTap;

  const _PhotoAction({
    required this.icon,
    required this.label,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppTheme.subtleSurface(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(color: AppTheme.border(context)),
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
            else
              Icon(icon, size: 16, color: AppTheme.onSurface(context)),
            const SizedBox(width: 7),
            Text(
              label,
              style: appFont(
                fontSize: 13,
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

/// แถวชิปเลือกสไตล์การ์ด
class _StylePicker extends StatelessWidget {
  final StoryStyle selected;
  final ValueChanged<StoryStyle> onSelected;

  const _StylePicker({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: StoryStyle.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final style = StoryStyle.values[index];
          final active = style == selected;

          return GestureDetector(
            onTap: () => onSelected(style),
            behavior: HitTestBehavior.opaque,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.primaryColor
                    : AppTheme.subtleSurface(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                border: Border.all(
                  color: active
                      ? AppTheme.primaryColor
                      : AppTheme.border(context),
                ),
              ),
              child: Text(
                style.label,
                style: appFont(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : AppTheme.onSurface(context),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// แถบปรับความโปร่งใสของรูป
///
/// ซ้ายคือเงาเข้ม (ตัวหนังสือเด่น) ขวาคือรูปชัด — ไม่ปล่อยให้สุดขอบขวาแปลว่า
/// ไม่มีเงาเลย เพราะการ์ดจะอ่านไม่ออกบนรูปสว่าง ดู [TripStoryCard.photoOpacity]
class _OpacitySlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final VoidCallback onSettled;

  const _OpacitySlider({
    required this.value,
    required this.onChanged,
    required this.onSettled,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'ความโปร่งใสของรูป',
          style: appFont(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.mutedText(context),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: AppTheme.primaryColor,
              inactiveTrackColor: AppTheme.border(context),
              thumbColor: AppTheme.primaryColor,
              // แบนตามธีมของแอป — thumb มาตรฐานมีเงาติดมาด้วย
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 9,
                elevation: 0,
                pressedElevation: 0,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              overlayColor: AppTheme.primaryColor.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: value,
              onChanged: onChanged,
              onChangeEnd: (_) {
                HapticFeedback.selectionClick();
                onSettled();
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// เปิด sheet แชร์การ์ดนับถอยหลัง (ก่อนออกเดินทาง)
///
/// โหลดรูปปกกับโลโก้ให้เข้าแคชก่อนเปิด sheet เพราะ `RenderRepaintBoundary.toImage`
/// จับเฉพาะสิ่งที่วาดแล้วจริง ๆ — รูปที่ยังโหลดไม่เสร็จจะกลายเป็นช่องว่างใน PNG
/// โดยไม่มีข้อผิดพลาดใด ๆ ให้จับได้
Future<void> showTripStoryShareSheet(
  BuildContext context, {
  required String tripTitle,
  required String location,
  required DateTime? departureDate,
  required int? daysLeft,
  String? coverImageUrl,
  String? bookingRef,
}) {
  return _openSheet(
    context,
    coverImageUrl: coverImageUrl,
    builder: (cover) => TripStoryShareSheet(
      tripTitle: tripTitle,
      location: location,
      departureDate: departureDate,
      daysLeft: daysLeft,
      coverImage: cover,
      bookingRef: bookingRef,
    ),
  );
}

/// เปิด sheet แชร์การ์ดสรุปทริป (หลังกลับมาแล้ว)
///
/// ใช้การ์ด สไตล์ และเครื่องมือจัดรูปชุดเดียวกับการ์ดนับถอยหลังทุกอย่าง
Future<void> showTripRecapShareSheet(
  BuildContext context, {
  required String tripTitle,
  required String location,
  required StoryCountdown highlight,
  required String dateLabel,
  List<StoryStat> stats = const [],
  String? coverImageUrl,
  String? bookingRef,
}) {
  return _openSheet(
    context,
    coverImageUrl: coverImageUrl,
    builder: (cover) => TripStoryShareSheet(
      tripTitle: tripTitle,
      location: location,
      departureDate: null,
      daysLeft: null,
      highlight: highlight,
      dateLabel: dateLabel,
      stats: stats,
      coverImage: cover,
      bookingRef: bookingRef,
    ),
  );
}

Future<void> _openSheet(
  BuildContext context, {
  required String? coverImageUrl,
  required Widget Function(ImageProvider? cover) builder,
}) async {
  ImageProvider? cover;

  if (coverImageUrl != null && coverImageUrl.isNotEmpty) {
    cover = NetworkImage(coverImageUrl);
    try {
      await precacheImage(cover, context);
    } catch (_) {
      // รูปโหลดไม่ได้ (ออฟไลน์ / ไฟล์หาย) — การ์ดมีพื้นหลังไล่เฉดรองรับอยู่แล้ว
      cover = null;
    }
  }

  if (!context.mounted) return;

  try {
    await precacheImage(const AssetImage(kStoryLogoAsset), context);
  } catch (_) {
    // โลโก้เป็นลายเซ็นมุมการ์ด ไม่ใช่เนื้อหา — ขาดไปก็ยังแชร์ได้
  }

  if (!context.mounted) return;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => builder(cover),
  );
}
