import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/trip_medal.dart';
import '../providers/app_provider.dart';
import '../services/medal_look_storage.dart';
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
///
/// ใช้เหรียญใบล่าสุดในตู้ที่แคชไว้ถ้ามี — หน้าที่เปิด sheet อาจถือเหรียญรุ่นก่อน
/// ที่เจ้าของจะเปลี่ยนทรงไปแล้วในการแชร์ครั้งก่อน
Future<void> showMedalShareSheet(BuildContext context, TripMedal medal) async {
  AppProvider? app;
  try {
    app = context.read<AppProvider>();
  } catch (_) {
    app = null;
  }
  medal = app?.cachedMedal(medal.id) ?? medal;

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
    // ขนาด/สเกลต้องตรงกับที่ MedalStoryCard ใช้ถอดรหัส ไม่งั้นแคชคนละตัว
    await warm(
      medalImageProvider(
        medalUrl,
        kMedalStoryDecodeWidth,
        kShareCardPixelRatio,
      ),
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
    builder: (_) => MedalShareSheet(
      medal: medal,
      tripPhoto: cover,
      onSaveShape: app == null
          ? null
          : (shape) => app!.saveMedalShape(medal.id, shape),
    ),
  );
}

/// ลายตารางหมากรุก 2×2 ช่อง (เทาอ่อน/ขาว) ขนาด 16px — พื้นหลังมาตรฐานของ
/// "ภาพนี้โปร่งใส" ในโปรแกรมแต่งรูป
final MemoryImage _checkerboard = MemoryImage(
  Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x02, //
    0x08, 0x00, 0x00, 0x00, 0x00, 0x57, 0xDD, 0x52, 0xF8, 0x00, 0x00, 0x00, //
    0x0E, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0x7F, 0x83, 0xE1, //
    0xC6, 0x7F, 0x00, 0x0B, 0x10, 0x03, 0xAF, 0x50, 0x3F, 0xB7, 0x5B, 0x00, //
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82, //
  ]),
  scale: 1 / 8,
);

/// แท็บเครื่องมือใต้พรีวิว — แยกเป็นหมวดเพื่อให้ sheet ไม่สูงจนดันพรีวิว
/// การ์ดให้เล็กจนมองไม่เห็นว่ากำลังปรับอะไร
enum _Panel {
  background('พื้นหลัง'),
  shape('ทรงเหรียญ'),
  layout('รูปแบบ'),
  info('ข้อมูล');

  const _Panel(this.label);

  final String label;
}

class MedalShareSheet extends StatefulWidget {
  final TripMedal medal;

  /// รูปปกทริปที่โหลดเข้าแคชแล้ว — null เมื่อทริปไม่มีรูปหรือโหลดไม่ได้
  final ImageProvider? tripPhoto;

  /// บันทึกทรงเหรียญลงเซิร์ฟเวอร์ตอนกดแชร์ (คืนทรงที่เก็บจริง) — ลิงก์ /m/ กับ
  /// ภาพ OG จะได้หน้าตาตรงกับการ์ด null = ไม่บันทึก (พรีวิว/เทส)
  final Future<MedalShape?> Function(MedalShape? shape)? onSaveShape;

  const MedalShareSheet({
    super.key,
    required this.medal,
    this.tripPhoto,
    this.onSaveShape,
  });

  @override
  State<MedalShareSheet> createState() => _MedalShareSheetState();
}

class _MedalShareSheetState extends State<MedalShareSheet> {
  static const Size _cardFrame = Size(kStoryCardWidth, kStoryCardHeight);

  final GlobalKey _cardKey = GlobalKey();
  MedalLook _look = MedalLook.defaults;
  _Panel _panel = _Panel.background;

  ImageProvider? _ownPhoto;
  bool _usingOwnPhoto = false;
  StoryPhotoFraming _framing = StoryPhotoFraming.none;
  double? _tripPhotoAspect;

  bool _picking = false;
  bool _sharing = false;

  /// ทรงบนการ์ด — null = แบบของทริป (ภาพออกแบบเอง/ขอบหยัก)
  ///
  /// เปิดมาเป็นทรงที่เหรียญใบนี้ถูกบันทึกไว้ ยังไม่เคยเลือก: ทริปที่มีภาพออกแบบ
  /// เองเริ่มที่ภาพนั้น (ทรงที่ชอบไม่ควรทับงานที่ออกแบบมาเฉพาะทริป) ส่วนทริป
  /// แม่แบบเริ่มที่ทรงที่เครื่องนี้จำไว้ ([MedalLook.shape])
  late MedalShape? _shape = widget.medal.shape;

  /// ทรงที่เซิร์ฟเวอร์เก็บไว้ตอนนี้ — ต่างจาก [_shape] ตอนกดแชร์ = ต้องบันทึก
  late MedalShape? _savedShape = widget.medal.shape;

  /// ผู้ใช้แตะเลือกทรงแล้ว — ค่าที่โหลดจากเครื่องมาทีหลังห้ามทับ
  bool _shapeTouched = false;

  // ค่าตั้งต้นของท่าทางหนึ่งครั้ง — คำนวณจากจุดเริ่มทุกเฟรม ไม่สะสมคลาดเคลื่อน
  double _gestureScale = 1;
  Offset _gestureOffset = Offset.zero;
  Offset _gestureFocal = Offset.zero;

  ImageProvider? get _photo => _usingOwnPhoto ? _ownPhoto : widget.tripPhoto;

  /// รูปแบบที่การ์ดวาดจริง — จำ "เส้นทาง" ไว้แต่เหรียญนี้ไม่มีเส้นทาง การ์ด
  /// จะถอยไปเป็น "กลางการ์ด" ชิปที่ไฮไลต์ต้องตรงกับที่เห็น
  MedalCardLayout get _effectiveLayout =>
      _look.layout == MedalCardLayout.route && widget.medal.route == null
      ? MedalCardLayout.centered
      : _look.layout;

  bool get _hasTripArt => widget.medal.design.isCustom;

  /// ทรงที่การ์ดวาดจริง — null = แบบของทริป
  MedalShape? get _cardShape => _shape;

  /// ทรงในรูปที่เซิร์ฟเวอร์เก็บ — ขอบหยักของทริปแม่แบบคือแบบของทริปเอง (null)
  MedalShape? _stored(MedalShape? shape) =>
      !_hasTripArt && shape == MedalShape.rosette ? null : shape;

  bool get _showsPhoto =>
      _look.backdrop == MedalBackdrop.photo && _photo != null;

  @override
  void initState() {
    super.initState();
    _loadLook();

    final trip = widget.tripPhoto;
    if (trip != null) {
      _resolveAspectRatio(trip).then((aspect) {
        if (!mounted) return;
        setState(() {
          _tripPhotoAspect = aspect;
          if (!_usingOwnPhoto) {
            _framing = StoryPhotoFraming(aspectRatio: aspect);
          }
        });
      });
    }
  }

  Future<void> _loadLook() async {
    final look = await MedalLookStorage.instance.read();
    if (!mounted) return;

    setState(() {
      // จำไว้ว่าชอบพื้นรูป แต่รอบนี้ไม่มีรูปทริป (และรูปของตัวเองไม่ถูกจำ)
      // — ถอยไปพื้นสีเหรียญ ไม่ให้การ์ดเปิดมาเป็นพื้นสีที่ไม่ได้เลือก
      _look = look.backdrop == MedalBackdrop.photo && widget.tripPhoto == null
          ? _copy(look, backdrop: MedalBackdrop.color)
          : look;

      if (!_shapeTouched && widget.medal.shape == null && !_hasTripArt) {
        _shape = look.shape;
      }
    });
  }

  MedalLook _copy(
    MedalLook look, {
    MedalBackdrop? backdrop,
    MedalCardLayout? layout,
    double? photoOpacity,
    double? tone,
    double? medalScale,
    MedalCardParts? parts,
    MedalShape? shape,
  }) {
    return MedalLook(
      backdrop: backdrop ?? look.backdrop,
      layout: layout ?? look.layout,
      photoOpacity: photoOpacity ?? look.photoOpacity,
      tone: tone ?? look.tone,
      medalScale: medalScale ?? look.medalScale,
      parts: parts ?? look.parts,
      shape: shape ?? look.shape,
    );
  }

  void _update(MedalLook look, {bool remember = true}) {
    setState(() => _look = look);
    if (remember) MedalLookStorage.instance.write(look);
  }

  void _resetLook() {
    HapticFeedback.selectionClick();
    setState(() {
      _framing = StoryPhotoFraming(
        aspectRatio: _usingOwnPhoto ? _framing.aspectRatio : _tripPhotoAspect,
      );
      _shape = _hasTripArt ? null : MedalShape.rosette;
      _shapeTouched = true;
    });
    _update(MedalLook.defaults);
  }

  // ── รูป ─────────────────────────────────────────────────────────────────

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
      final aspect = await _resolveAspectRatio(image);
      if (!mounted) return;

      setState(() {
        _ownPhoto = image;
        _usingOwnPhoto = true;
        // รูปใหม่เริ่มเฟรมใหม่เสมอ ค่าที่จัดไว้กับรูปเก่าไม่มีความหมายกับรูปนี้
        _framing = StoryPhotoFraming(aspectRatio: aspect);
      });
      _update(_copy(_look, backdrop: MedalBackdrop.photo));
    } catch (_) {
      if (mounted) AppSnack.error(context, 'เปิดรูปไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _useTripPhoto() {
    setState(() {
      _usingOwnPhoto = false;
      _framing = StoryPhotoFraming(aspectRatio: _tripPhotoAspect);
    });
    _update(_copy(_look, backdrop: MedalBackdrop.photo));
  }

  /// อ่านสัดส่วนรูปจริงและอุ่นแคชไปในตัว — ต้องรู้สัดส่วนก่อนถึงจะบอกได้ว่า
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

  void _onScaleStart(ScaleStartDetails details) {
    _gestureScale = _framing.scale;
    _gestureOffset = _framing.offset;
    _gestureFocal = details.localFocalPoint;
  }

  /// [displayScale] คืออัตราที่พรีวิวถูกย่อให้พอดีจอ — นิ้วขยับบนจอ 10 พิกเซล
  /// ไม่เท่ากับรูปขยับ 10 หน่วยบนการ์ด ต้องหารกลับก่อนเสมอ
  void _onScaleUpdate(ScaleUpdateDetails details, double displayScale) {
    if (!_showsPhoto || displayScale <= 0) return;

    final candidate = _framing.copyWith(
      scale: (_gestureScale * details.scale).clamp(1.0, 4.0),
      offset:
          _gestureOffset +
          (details.localFocalPoint - _gestureFocal) / displayScale,
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

    // บันทึกทรงก่อนแชร์ — คนที่กดลิงก์ในโพสต์ต้องเห็นเหรียญทรงเดียวกับการ์ด
    final shapeSaved = await _saveShape();

    try {
      // เพิ่งปรับอะไรไปก่อนกดแชร์ — รอเฟรมล่าสุดวาดจบก่อนจับภาพ
      await WidgetsBinding.instance.endOfFrame;

      await shareWidgetAsPng(
        boundaryKey: _cardKey,
        fileName: _look.backdrop == MedalBackdrop.transparent
            ? 'luilaykhao_medal_sticker.png'
            : 'luilaykhao_medal.png',
        text: _shareText(),
      );
      if (!shapeSaved && mounted) {
        AppSnack.error(
          context,
          'บันทึกทรงเหรียญไม่สำเร็จ ลิงก์เหรียญยังเป็นทรงเดิม ลองแชร์อีกครั้ง',
        );
      }
    } catch (_) {
      if (mounted) AppSnack.error(context, 'แชร์ไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// true เมื่อเซิร์ฟเวอร์มีทรงตรงกับการ์ดแล้ว (หรือไม่มีอะไรต้องบันทึก)
  ///
  /// บันทึกไม่ได้ (ออฟไลน์/เซิร์ฟเวอร์ช้า) ก็ยังแชร์ต่อ — รูปการ์ดเป็นของเจ้าของ
  /// อยู่แล้ว เสียแค่ลิงก์ที่ยังเป็นทรงเดิม ซึ่งบอกให้รู้หลังแชร์
  Future<bool> _saveShape() async {
    final save = widget.onSaveShape;
    final wanted = _stored(_shape);

    if (save == null || wanted == _savedShape) return true;

    try {
      final saved = await save(wanted).timeout(const Duration(seconds: 8));
      _savedShape = saved;
      return saved == wanted;
    } catch (_) {
      return false;
    }
  }

  /// คำบรรยายของคนที่พิชิต ไม่ใช่คำขายของ — ลิงก์ท้ายเปิดหน้าเหรียญที่มีภาพ OG
  String _shareText() {
    final medal = widget.medal;
    final url = medal.shareUrl;

    return 'พิชิต "${medal.design.name}" แล้ว! 🏅 ${medal.finisherLabel}'
        '${url.isEmpty ? '' : '\n$url'}\n#ลุยเลเขา';
  }

  // ── หน้าตา ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppTheme.mutedText(context).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
            ),
            Flexible(child: _preview()),
            const SizedBox(height: 12),
            _PanelTabs(
              selected: _panel,
              onSelected: (panel) {
                HapticFeedback.selectionClick();
                setState(() => _panel = panel);
              },
            ),
            const SizedBox(height: 10),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: switch (_panel) {
                _Panel.background => _backgroundPanel(),
                _Panel.shape => _shapePanel(),
                _Panel.layout => _layoutPanel(),
                _Panel.info => _infoPanel(),
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: _resetLook,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.mutedText(context),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: Text(
                    'ค่าเริ่มต้น',
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                ),
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
          ],
        ),
      ),
    );
  }

  Widget _preview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // การ์ดวาดที่ 360×640 เสมอ (PNG 1080×1920 ทุกเครื่อง) ส่วนนี้แค่ย่อตอน
        // แสดงผล — RepaintBoundary จับตามขนาดจริง ไม่ใช่ขนาดที่ย่อ
        final scale = math.min(
          constraints.maxWidth / kStoryCardWidth,
          constraints.maxHeight / kStoryCardHeight,
        );

        return Center(
          child: SizedBox(
            width: kStoryCardWidth * scale,
            height: kStoryCardHeight * scale,
            child: GestureDetector(
              onScaleStart: _showsPhoto ? _onScaleStart : null,
              onScaleUpdate: _showsPhoto
                  ? (details) => _onScaleUpdate(details, scale)
                  : null,
              child: FittedBox(
                // ลายตารางหมากรุกอยู่ *นอก* RepaintBoundary — ให้เห็นว่าพื้นโปร่ง
                // แต่ไม่ติดไปกับ PNG ที่แชร์ออกไป
                child: DecoratedBox(
                  decoration: _look.backdrop == MedalBackdrop.transparent
                      ? BoxDecoration(
                          image: DecorationImage(
                            image: _checkerboard,
                            repeat: ImageRepeat.repeat,
                            // ไม่ให้ภาพ 2×2 ถูกเบลอเป็นสีเทาเรียบตอนขยาย
                            filterQuality: FilterQuality.none,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusXl,
                          ),
                        )
                      : const BoxDecoration(),
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: MedalStoryCard(
                      medal: widget.medal,
                      backdrop: _look.backdrop,
                      layout: _look.layout,
                      photo: _photo,
                      framing: _framing,
                      photoOpacity: _look.photoOpacity,
                      tone: _look.tone,
                      medalScale: _look.medalScale,
                      parts: _look.parts,
                      shape: _cardShape,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _backgroundPanel() {
    final backdrop = _look.backdrop;
    final hasTripPhoto = widget.tripPhoto != null;

    void pick(MedalBackdrop value) {
      HapticFeedback.selectionClick();
      _update(_copy(_look, backdrop: value));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ChipRow(
          children: [
            _Pill(
              label: MedalBackdrop.color.label,
              swatch: medalBackdropColor(widget.medal.design.color, _look.tone),
              active: backdrop == MedalBackdrop.color,
              onTap: () => pick(MedalBackdrop.color),
            ),
            _Pill(
              label: MedalBackdrop.dark.label,
              swatch: const Color(0xFF0E1412),
              active: backdrop == MedalBackdrop.dark,
              onTap: () => pick(MedalBackdrop.dark),
            ),
            _Pill(
              label: MedalBackdrop.paper.label,
              swatch: const Color(0xFFFDFBF5),
              active: backdrop == MedalBackdrop.paper,
              onTap: () => pick(MedalBackdrop.paper),
            ),
            if (hasTripPhoto)
              _Pill(
                label: 'รูปทริป',
                icon: Icons.landscape_rounded,
                active: backdrop == MedalBackdrop.photo && !_usingOwnPhoto,
                onTap: _useTripPhoto,
              ),
            _Pill(
              label: MedalBackdrop.transparent.label,
              icon: Icons.layers_clear_rounded,
              active: backdrop == MedalBackdrop.transparent,
              onTap: () => pick(MedalBackdrop.transparent),
            ),
            _Pill(
              label: _ownPhoto == null ? 'ใช้รูปของคุณ' : 'รูปของคุณ',
              icon: Icons.photo_library_rounded,
              busy: _picking,
              active: backdrop == MedalBackdrop.photo && _usingOwnPhoto,
              onTap: () {
                if (_ownPhoto == null) {
                  _pickPhoto();
                  return;
                }
                HapticFeedback.selectionClick();
                setState(() => _usingOwnPhoto = true);
                _update(_copy(_look, backdrop: MedalBackdrop.photo));
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_showsPhoto) ...[
          _SliderRow(
            label: 'ความชัดของรูป',
            value: _look.photoOpacity,
            onChanged: (v) =>
                _update(_copy(_look, photoOpacity: v), remember: false),
            onSettled: () => _update(_look),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'ลากที่การ์ดเพื่อเลื่อนรูป · จีบนิ้วเพื่อซูม',
                  style: appFont(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.mutedText(context),
                  ),
                ),
              ),
              if (_usingOwnPhoto)
                _TextAction(label: 'เปลี่ยนรูป', onTap: _pickPhoto),
              if (!_framing.isDefault)
                _TextAction(
                  label: 'จัดรูปใหม่',
                  onTap: () => setState(
                    () => _framing = StoryPhotoFraming(
                      aspectRatio: _framing.aspectRatio,
                    ),
                  ),
                ),
            ],
          ),
        ] else if (backdrop == MedalBackdrop.transparent)
          const _Hint(
            'บันทึกรูปลงเครื่อง แล้วใน IG Story กดสติกเกอร์ → รูปภาพ '
            'เพื่อวางเหรียญทับรูปของคุณ',
          )
        else if (backdrop == MedalBackdrop.color)
          _SliderRow(
            label: 'ความเข้มของสี',
            value: _look.tone,
            onChanged: (v) => _update(_copy(_look, tone: v), remember: false),
            onSettled: () => _update(_look),
          )
        else
          _Hint(
            backdrop == MedalBackdrop.photo
                ? 'ทริปนี้ยังไม่มีรูป — เลือก "ใช้รูปของคุณ" เพื่อใส่รูปพื้นหลัง'
                : 'เลือกพื้นสีเหรียญหรือรูปถ่าย เพื่อปรับความเข้ม/ความชัด',
          ),
      ],
    );
  }

  Widget _shapePanel() {
    final medal = widget.medal;
    final design = medal.design;
    final year = medal.buddhistYear;
    final current = _cardShape;

    void pick(MedalShape? shape) {
      HapticFeedback.selectionClick();
      setState(() {
        _shape = shape;
        _shapeTouched = true;
      });
      // จำเป็นรสนิยมของเครื่อง เฉพาะทรงแม่แบบ — "แบบของทริป" เป็นของทริปนั้น
      if (shape != null) _update(_copy(_look, shape: shape));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _ShapeTile.height,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              if (_hasTripArt)
                _ShapeTile(
                  label: 'แบบของทริป',
                  active: current == null,
                  onTap: () => pick(null),
                  child: MedalArt(
                    design: design,
                    size: _ShapeTile.medalSize,
                    year: year,
                  ),
                ),
              for (final shape in MedalShape.values)
                _ShapeTile(
                  label: shape.label,
                  // ทริปแม่แบบ: "แบบของทริป" กับขอบหยักคืออันเดียวกัน
                  active:
                      current == shape ||
                      (current == null &&
                          !_hasTripArt &&
                          shape == MedalShape.rosette),
                  onTap: () => pick(shape),
                  child: MedalArt(
                    design: design,
                    size: _ShapeTile.medalSize,
                    year: year,
                    shape: shape,
                    finish: medal.finish,
                  ),
                ),
            ],
          ),
        ),
        _FinishNote(medal: medal),
        const _Hint(
          'กดแชร์แล้ว ทรงนี้จะใช้กับเหรียญใบนี้ทุกที่ '
          'ทั้งตู้เหรียญและลิงก์ที่เพื่อนกดเข้ามาดู',
        ),
      ],
    );
  }

  Widget _layoutPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ChipRow(
          children: [
            for (final layout in MedalCardLayout.values)
              if (layout != MedalCardLayout.route || widget.medal.route != null)
                _Pill(
                  label: layout.label,
                  icon: layout == MedalCardLayout.route
                      ? Icons.route_rounded
                      : null,
                  active: _effectiveLayout == layout,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _update(_copy(_look, layout: layout));
                  },
                ),
          ],
        ),
        const SizedBox(height: 6),
        _SliderRow(
          label: 'ขนาดเหรียญ',
          value:
              (_look.medalScale - kMedalScaleMin) /
              (kMedalScaleMax - kMedalScaleMin),
          onChanged: (v) => _update(
            _copy(
              _look,
              medalScale:
                  kMedalScaleMin + v * (kMedalScaleMax - kMedalScaleMin),
            ),
            remember: false,
          ),
          onSettled: () => _update(_look),
        ),
      ],
    );
  }

  Widget _infoPanel() {
    final parts = _look.parts;

    void toggle(MedalCardParts next) {
      HapticFeedback.selectionClick();
      _update(_copy(_look, parts: next));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Toggle(
              label: 'ชื่อผู้พิชิต',
              on: parts.holder,
              onTap: () => toggle(parts.copyWith(holder: !parts.holder)),
            ),
            _Toggle(
              label: 'สถานที่ · วันที่',
              on: parts.meta,
              onTap: () => toggle(parts.copyWith(meta: !parts.meta)),
            ),
            _Toggle(
              label: widget.medal.personal != null
                  ? 'ตัวเลขจาก GPS'
                  : 'ระยะทาง/ความสูง',
              on: parts.stats,
              onTap: () => toggle(parts.copyWith(stats: !parts.stats)),
            ),
            if (widget.medal.attempt > 1)
              _Toggle(
                label: 'ครั้งที่ ${widget.medal.attempt}',
                on: parts.attempt,
                onTap: () => toggle(parts.copyWith(attempt: !parts.attempt)),
              ),
            if (widget.medal.records.isNotEmpty)
              _Toggle(
                label: 'สถิติส่วนตัว',
                on: parts.records,
                onTap: () => toggle(parts.copyWith(records: !parts.records)),
              ),
            _Toggle(
              label: 'โลโก้',
              on: parts.logo,
              onTap: () => toggle(parts.copyWith(logo: !parts.logo)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const _Hint('เหรียญ ชื่อทริป และเลข Finisher อยู่บนการ์ดเสมอ'),
      ],
    );
  }
}

// ── ชิ้นส่วนของ sheet ───────────────────────────────────────────────────────

class _PanelTabs extends StatelessWidget {
  final _Panel selected;
  final ValueChanged<_Panel> onSelected;

  const _PanelTabs({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        children: [
          for (final panel in _Panel.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelected(panel),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: panel == selected
                        ? AppTheme.primaryColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Text(
                    panel.label,
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w800,
                      color: panel == selected
                          ? Colors.white
                          : AppTheme.onSurface(context),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ผิวเหรียญใบนี้ + ต้องมาอีกกี่ครั้งถึงผิวถัดไป — ผิวเลือกเองไม่ได้ ต้องเดินไปให้ได้
class _FinishNote extends StatelessWidget {
  final TripMedal medal;

  const _FinishNote({required this.medal});

  @override
  Widget build(BuildContext context) {
    final finish = medal.finish;
    final next = finish.next;
    final left = next == null ? 0 : next.fromAttempt - medal.attempt;

    final text = [
      'ผิว${finish.label}',
      if (medal.attempt > 1) 'มาพิชิตครั้งที่ ${medal.attempt}',
      if (next != null && left > 0) 'มาอีก $left ครั้งได้ผิว${next.label}',
    ].join('  ·  ');

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: finish.swatch,
              shape: BoxShape.circle,
              border: Border.all(color: finish.palette.frame, width: 2),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: appFont(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ตัวเลือกทรงเหรียญ — โชว์เหรียญจริงย่อส่วนในสีของทริป ไม่ใช่ไอคอนแทน
/// เพราะคนเลือกจากหน้าตา ไม่ใช่จากชื่อทรง
class _ShapeTile extends StatelessWidget {
  static const double medalSize = 46;
  static const double height = 92;

  final String label;
  final bool active;
  final VoidCallback onTap;
  final Widget child;

  const _ShapeTile({
    required this.label,
    required this.active,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: 'ทรง$label',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 76,
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? AppTheme.tintOf(context, AppTheme.primaryColor)
                : AppTheme.subtleSurface(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: active ? AppTheme.primaryColor : AppTheme.border(context),
              width: active ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ExcludeSemantics(child: child),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: appFont(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: active
                      ? AppTheme.onSurface(context)
                      : AppTheme.mutedText(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  final List<Widget> children;

  const _ChipRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? swatch;
  final bool busy;

  const _Pill({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
    this.swatch,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? Colors.white : AppTheme.onSurface(context);

    return GestureDetector(
      onTap: busy ? null : onTap,
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
            else if (swatch != null)
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: swatch,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.border(context)),
                ),
              )
            else if (icon != null)
              Icon(icon, size: 16, color: fg),
            if (busy || swatch != null || icon != null)
              const SizedBox(width: 6),
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
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;

  const _Toggle({required this.label, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = on ? AppTheme.primaryColor : AppTheme.mutedText(context);

    return Semantics(
      toggled: on,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: on
                ? AppTheme.tintOf(context, AppTheme.primaryColor)
                : AppTheme.subtleSurface(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
              color: on ? AppTheme.primaryColor : AppTheme.border(context),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                on ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 16,
                color: fg,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: appFont(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: on
                      ? AppTheme.onSurface(context)
                      : AppTheme.mutedText(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// แถบเลื่อน 0–1 — [onChanged] ทุกเฟรมที่ลาก [onSettled] ตอนปล่อยนิ้ว (ค่อยจำ)
class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final VoidCallback onSettled;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onSettled,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 104,
          child: Text(
            label,
            style: appFont(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.mutedText(context),
            ),
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
              value: value.clamp(0.0, 1.0),
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

class _TextAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TextAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Text(
          label,
          style: appFont(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;

  const _Hint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: appFont(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.mutedText(context),
        ),
      ),
    );
  }
}
