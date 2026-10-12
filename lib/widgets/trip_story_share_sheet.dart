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
import 'share_sheet_controls.dart';
import 'trip_story_card.dart';

/// Bottom sheet ที่พรีวิว [TripStoryCard] แล้วส่งออกเป็น PNG 1080×1920
///
/// เปิดด้วย [showTripStoryShareSheet] (ก่อนไป) หรือ [showTripRecapShareSheet]
/// (กลับมาแล้ว) เสมอ อย่าเรียก showModalBottomSheet เอง เพราะตัวช่วยนั้นโหลด
/// รูปปกให้เสร็จก่อนเปิด ซึ่งเป็นเงื่อนไขที่ทำให้ภาพที่จับได้มีรูปจริงไม่ใช่ช่องว่าง
///
/// ใต้พรีวิวมีเครื่องมือสี่แท็บ — รูป, สไตล์, ข้อมูล (เปิด/ปิดโลโก้ ตัวนับ จุดหมาย
/// วันที่ รูปแบบวันที่ ลิงก์ในคำบรรยาย), ข้อความ (แก้ชื่อทริป/จุดหมาย และเพิ่ม
/// บรรทัดของตัวเอง) — สิ่งที่เป็นรสนิยมถูกจำไว้ผ่าน [StoryLookStorage] เพราะ
/// รสนิยมของคนไม่ได้เปลี่ยนทุกทริป ส่วนรูปกับคำที่พิมพ์ไม่จำ เพราะเป็นของทริปนั้น ๆ
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
  bool _saving = false;
  bool _picking = false;
  String? _shareUrl;
  StoryLook _look = StoryLook.defaults;
  _Panel _panel = _Panel.photo;

  /// รูปของเจ้าของการ์ด — เก็บไว้แม้สลับกลับไปใช้รูปทริป จะได้สลับกลับมา
  /// ได้โดยไม่ต้องเลือกใหม่
  ImageProvider? _ownImage;
  bool _usingOwnPhoto = false;
  StoryPhotoFraming _framing = StoryPhotoFraming.none;
  double? _tripPhotoAspect;

  /// คำบนการ์ดที่เจ้าของแก้เอง — ใช้เฉพาะการ์ดใบนี้ ไม่จำข้ามทริป
  late String _title = widget.tripTitle;
  late String _location = widget.location;
  String _note = '';

  /// ค่าตั้งต้นของท่าทางหนึ่งครั้ง — เก็บไว้ตอนนิ้วแตะ แล้วคำนวณจากจุดนั้น
  /// ทุกเฟรม การลากจึงไม่สะสมความคลาดเคลื่อนทีละนิดจนรูปไหลไปเอง
  double _gestureScale = 1;
  Offset _gestureOffset = Offset.zero;
  Offset _gestureFocal = Offset.zero;

  static const Size _cardFrame = Size(kStoryCardWidth, kStoryCardHeight);

  ImageProvider? get _photo => _usingOwnPhoto ? _ownImage : widget.coverImage;

  /// สไตล์สติกเกอร์ไม่มีรูปพื้นหลัง — ปิดการลากรูป และพรีวิวบนลายหมากรุก
  bool get _isSticker => _look.style == StoryStyle.sticker;

  @override
  void initState() {
    super.initState();
    _loadLook();
    _loadShareUrl();

    final trip = widget.coverImage;
    if (trip != null) {
      _resolveAspectRatio(trip).then((aspect) {
        if (!mounted) return;
        setState(() {
          _tripPhotoAspect = aspect;
          if (!_usingOwnPhoto) _framing = StoryPhotoFraming(aspectRatio: aspect);
        });
      });
    }
  }

  Future<void> _loadLook() async {
    final look = await StoryLookStorage.instance.read();
    if (!mounted) return;

    setState(() => _look = look);
  }

  /// [remember] เป็น false ระหว่างลากแถบเลื่อน — จำครั้งเดียวตอนปล่อยนิ้ว
  void _update(StoryLook look, {bool remember = true}) {
    setState(() => _look = look);
    if (remember) StoryLookStorage.instance.write(look);
  }

  void _resetAll() {
    HapticFeedback.selectionClick();
    setState(() {
      _usingOwnPhoto = false;
      _framing = StoryPhotoFraming(aspectRatio: _tripPhotoAspect);
      _title = widget.tripTitle;
      _location = widget.location;
      _note = '';
    });
    _update(StoryLook.defaults);
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
        _ownImage = image;
        _usingOwnPhoto = true;
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
    HapticFeedback.selectionClick();
    setState(() {
      _usingOwnPhoto = false;
      _framing = StoryPhotoFraming(aspectRatio: _tripPhotoAspect);
    });
  }

  Future<void> _useOwnPhoto() async {
    final own = _ownImage;
    if (own == null) return _pickPhoto();

    HapticFeedback.selectionClick();
    final aspect = await _resolveAspectRatio(own);
    if (!mounted) return;

    setState(() {
      _usingOwnPhoto = true;
      _framing = StoryPhotoFraming(aspectRatio: aspect);
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
    if (_photo == null || _isSticker || displayScale <= 0) return;

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

  // ── แก้คำบนการ์ด ────────────────────────────────────────────────────────

  /// เปิดช่องพิมพ์ แล้วคืนคำที่พิมพ์ (ตัดช่องว่างหัวท้ายแล้ว) — null เมื่อกดยกเลิก
  Future<String?> _askText({
    required String title,
    required String initial,
    required int maxLength,
    required String hint,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => _WordsDialog(
        title: title,
        initial: initial,
        maxLength: maxLength,
        hint: hint,
      ),
    );
  }

  Future<void> _editTitle() async {
    final value = await _askText(
      title: 'ชื่อทริปบนการ์ด',
      initial: _title,
      maxLength: kStoryTitleMaxLength,
      hint: widget.tripTitle,
    );
    if (value == null || !mounted) return;

    // การ์ดต้องบอกว่าไปไหนเสมอ — ลบจนว่างคือขอกลับไปใช้ชื่อเดิม
    setState(() => _title = value.isEmpty ? widget.tripTitle : value);
  }

  Future<void> _editLocation() async {
    final value = await _askText(
      title: 'จุดหมายบนการ์ด',
      initial: _location,
      maxLength: kStoryLocationMaxLength,
      hint: widget.location.isEmpty ? 'เช่น เชียงใหม่' : widget.location,
    );
    if (value == null || !mounted) return;

    setState(() => _location = value.isEmpty ? widget.location : value);
  }

  Future<void> _editNote() async {
    final value = await _askText(
      title: 'ข้อความของคุณ',
      initial: _note,
      maxLength: kStoryNoteMaxLength,
      hint: 'เช่น ทริปวันเกิดปีนี้ ไปกับแก๊งเดิม',
    );
    if (value == null || !mounted) return;

    setState(() => _note = value);
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

      final shared = await shareWidgetAsPng(
        boundaryKey: _cardKey,
        fileName: _fileName(),
        text: _shareText(),
      );

      // แชร์ไปแล้วจริง = งานของ sheet นี้จบ กลับมาจาก IG ก็ไม่ต้องหาทางปิดเอง
      // ส่วนคนที่กดปิด share sheet ของระบบ ยังอยู่ที่นี่ต่อเพื่อแก้การ์ดได้
      if (shared && mounted) Navigator.of(context).maybePop();
    } on ShareCardException {
      if (mounted) AppSnack.error(context, 'แชร์ไม่สำเร็จ ลองใหม่อีกครั้ง');
    } catch (_) {
      if (mounted) AppSnack.error(context, 'แชร์ไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// บันทึกลงคลังรูป — sheet ไม่ปิดเอง เผื่อคนอยากได้ทั้งการ์ดและสติกเกอร์
  Future<void> _save() async {
    if (_saving) return;
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);

    try {
      await WidgetsBinding.instance.endOfFrame;
      await saveWidgetToGallery(boundaryKey: _cardKey, fileName: _fileName());
      if (!mounted) return;
      AppSnack.success(
        context,
        _isSticker
            ? 'บันทึกสติกเกอร์แล้ว — ใน IG Story กดสติกเกอร์ → รูปภาพ'
            : 'บันทึกรูปลงเครื่องแล้ว',
      );
    } on ShareCardException catch (e) {
      if (mounted) {
        AppSnack.error(context, shareCardFailureMessage(e.reason, saving: true));
      }
    } catch (_) {
      if (mounted) AppSnack.error(context, 'บันทึกรูปไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _fileName() {
    final kind = widget.isRecap ? 'recap' : 'countdown';

    return _isSticker
        ? 'luilaykhao_${kind}_sticker.png'
        : 'luilaykhao_$kind.png';
  }

  /// คำบรรยายที่ติดไปกับรูป — บางแอป (IG Story) ทิ้งไป บางแอป (LINE, FB) ใช้
  /// จึงต้องอ่านรู้เรื่องด้วยตัวเองโดยไม่ต้องเห็นรูป
  ///
  /// เป็นคำของเจ้าของทริป ไม่ใช่คำขายของบริษัท — มีแค่ลิงก์การ์ดต่อท้ายไว้ให้
  /// คนกดดูต่อได้ ไม่มีคำชวนจองพ่วง และเคารพสิ่งที่เจ้าของซ่อนไว้บนการ์ด:
  /// ปิดตัวนับก็ไม่บอกจำนวนวันในคำบรรยาย ปิดลิงก์ก็ไม่แนบ
  String _shareText() => storyShareCaption(
    tripTitle: _title,
    daysLeft: widget.daysLeft,
    isRecap: widget.isRecap,
    showCountdown: _look.parts.countdown,
    url: _look.includeLink ? _shareUrl : null,
  );

  // ── หน้าตา ──────────────────────────────────────────────────────────────

  Widget _card() {
    if (widget.isRecap) {
      return TripStoryCard.recap(
        tripTitle: _title,
        location: _location,
        highlight: widget.highlight!,
        dateLabel: widget.dateLabel ?? '',
        stats: widget.stats,
        coverImage: _photo,
        framing: _framing,
        style: _look.style,
        photoOpacity: _look.photoOpacity,
        parts: _look.parts,
        note: _note,
        ink: _look.stickerInk,
      );
    }

    return TripStoryCard(
      tripTitle: _title,
      location: _location,
      departureDate: widget.departureDate,
      daysLeft: widget.daysLeft,
      coverImage: _photo,
      framing: _framing,
      style: _look.style,
      photoOpacity: _look.photoOpacity,
      parts: _look.parts,
      dateFormat: _look.dateFormat,
      note: _note,
      ink: _look.stickerInk,
    );
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
            ShareSheetHeader(
              title: widget.isRecap ? 'การ์ดสรุปทริป' : 'การ์ดนับถอยหลัง',
            ),
            const SizedBox(height: 6),
            Flexible(child: _preview()),
            const SizedBox(height: 12),
            ShareSheetTabs(
              labels: [for (final panel in _Panel.values) panel.label],
              selected: _panel.index,
              onSelected: (index) {
                HapticFeedback.selectionClick();
                setState(() => _panel = _Panel.values[index]);
              },
            ),
            const SizedBox(height: 10),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: switch (_panel) {
                _Panel.photo => _photoPanel(),
                _Panel.style => _stylePanel(),
                _Panel.info => _infoPanel(),
                _Panel.words => _wordsPanel(),
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: _resetAll,
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
                const SizedBox(width: 4),
                ShareSaveButton(
                  busy: _saving,
                  onPressed: _save,
                  compact:
                      MediaQuery.sizeOf(context).width <
                      ShareSaveButton.compactBelow,
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
              onScaleStart: _isSticker ? null : _onScaleStart,
              onScaleUpdate: _isSticker
                  ? null
                  : (details) => _onScaleUpdate(details, displayScale),
              child: FittedBox(
                // ลายหมากรุกอยู่ *นอก* RepaintBoundary — ให้เห็นว่าพื้นโปร่ง
                // แต่ไม่ติดไปกับ PNG ที่แชร์/บันทึกออกไป
                child: DecoratedBox(
                  decoration: _isSticker
                      ? BoxDecoration(
                          image: DecorationImage(
                            image: kShareCheckerboard,
                            repeat: ImageRepeat.repeat,
                            filterQuality: FilterQuality.none,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                        )
                      : const BoxDecoration(),
                  child: RepaintBoundary(key: _cardKey, child: _card()),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _photoPanel() {
    final hasTripPhoto = widget.coverImage != null;

    if (_isSticker) {
      return const ShareHint(
        'สติกเกอร์ไม่มีรูปพื้นหลัง — บันทึกลงเครื่อง แล้วใน IG Story '
        'กดสติกเกอร์ → รูปภาพ เพื่อแปะทับรูปหรือวิดีโอของคุณเอง',
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShareChipRow(
          children: [
            if (hasTripPhoto)
              SharePill(
                label: 'รูปทริป',
                icon: Icons.landscape_rounded,
                active: !_usingOwnPhoto,
                onTap: _useTripPhoto,
              ),
            SharePill(
              label: _ownImage == null ? 'ใช้รูปของคุณ' : 'รูปของคุณ',
              icon: Icons.photo_library_rounded,
              busy: _picking,
              active: _usingOwnPhoto,
              onTap: _useOwnPhoto,
            ),
          ],
        ),
        const SizedBox(height: 6),
        ShareSliderRow(
          label: 'ความชัดของรูป',
          value: _look.photoOpacity,
          onChanged: (v) =>
              _update(_look.copyWith(photoOpacity: v), remember: false),
          onSettled: () => _update(_look),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                _photo == null
                    ? 'ทริปนี้ยังไม่มีรูป — เลือก "ใช้รูปของคุณ" เพื่อใส่รูปพื้นหลัง'
                    : 'ลากที่การ์ดเพื่อเลื่อนรูป · จีบนิ้วเพื่อซูม',
                style: appFont(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mutedText(context),
                ),
              ),
            ),
            if (_usingOwnPhoto)
              ShareTextAction(label: 'เปลี่ยนรูป', onTap: _pickPhoto),
            if (!_framing.isDefault)
              ShareTextAction(
                label: 'จัดรูปใหม่',
                onTap: () => setState(
                  () => _framing = StoryPhotoFraming(
                    aspectRatio: _framing.aspectRatio,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _stylePanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShareChipRow(
          children: [
            for (final style in StoryStyle.values)
              SharePill(
                label: style.label,
                active: _look.style == style,
                onTap: () {
                  HapticFeedback.selectionClick();
                  _update(_look.copyWith(style: style));
                },
              ),
          ],
        ),
        if (_isSticker) ...[
          const SizedBox(height: 8),
          ShareChipRow(
            children: [
              for (final ink in StickerInk.values)
                SharePill(
                  label: ink.label,
                  swatch: ink == StickerInk.light
                      ? Colors.white
                      : AppTheme.slate900,
                  active: _look.stickerInk == ink,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _update(_look.copyWith(stickerInk: ink));
                  },
                ),
            ],
          ),
          const ShareHint(
            'ตัวขาวเหมาะกับรูปวิว/กลางคืน ตัวเข้มเหมาะกับท้องฟ้าสว่าง — '
            'กด "บันทึก" แล้วแปะใน IG Story ผ่านสติกเกอร์ → รูปภาพ',
          ),
        ] else
          const ShareHint('สไตล์ที่เลือกจะถูกจำไว้ใช้กับการ์ดใบต่อไปด้วย'),
      ],
    );
  }

  Widget _infoPanel() {
    final parts = _look.parts;
    final date = widget.departureDate;
    final hasDate = widget.isRecap
        ? (widget.dateLabel ?? '').isNotEmpty
        : date != null;

    void toggle(StoryCardParts next) {
      HapticFeedback.selectionClick();
      _update(_look.copyWith(parts: next));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ShareToggle(
              label: 'โลโก้',
              on: parts.logo,
              onTap: () => toggle(parts.copyWith(logo: !parts.logo)),
            ),
            ShareToggle(
              label: widget.isRecap ? 'ตัวเลขเด่น' : 'นับถอยหลัง',
              on: parts.countdown,
              onTap: () => toggle(parts.copyWith(countdown: !parts.countdown)),
            ),
            if (_location.trim().isNotEmpty)
              ShareToggle(
                label: 'จุดหมาย',
                on: parts.location,
                onTap: () => toggle(parts.copyWith(location: !parts.location)),
              ),
            if (hasDate)
              ShareToggle(
                label: 'วันที่',
                on: parts.date,
                onTap: () => toggle(parts.copyWith(date: !parts.date)),
              ),
            if (widget.stats.isNotEmpty)
              ShareToggle(
                label: 'ตัวเลขสรุป',
                on: parts.stats,
                onTap: () => toggle(parts.copyWith(stats: !parts.stats)),
              ),
            if (widget.bookingRef?.isNotEmpty == true)
              ShareToggle(
                label: 'แนบลิงก์ในคำบรรยาย',
                on: _look.includeLink,
                onTap: () {
                  HapticFeedback.selectionClick();
                  _update(_look.copyWith(includeLink: !_look.includeLink));
                },
              ),
          ],
        ),
        // รูปแบบวันที่ — โชว์ตัวอย่างวันจริงบนชิป คนเลือกจากหน้าตา ไม่ใช่จากชื่อ
        if (!widget.isRecap && date != null && parts.date) ...[
          const SizedBox(height: 10),
          ShareChipRow(
            children: [
              for (final format in StoryDateFormat.values)
                SharePill(
                  label: format.format(date),
                  active: _look.dateFormat == format,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _update(_look.copyWith(dateFormat: format));
                  },
                ),
            ],
          ),
        ],
        ShareHint(
          !parts.date || _look.dateFormat == StoryDateFormat.month
              ? 'ไม่บอกวันเดินทางชัด ๆ ก็ไม่มีใครรู้ว่าบ้านว่างวันไหน'
              : 'ชื่อทริปอยู่บนการ์ดเสมอ — แก้คำได้ที่แท็บ "ข้อความ"',
        ),
      ],
    );
  }

  Widget _wordsPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WordsRow(
          label: 'ชื่อทริป',
          value: _title,
          edited: _title != widget.tripTitle,
          onTap: _editTitle,
          onReset: () => setState(() => _title = widget.tripTitle),
        ),
        const SizedBox(height: 8),
        _WordsRow(
          label: 'จุดหมาย',
          value: _location,
          placeholder: 'ยังไม่ได้ระบุ',
          edited: _location != widget.location,
          onTap: _editLocation,
          onReset: () => setState(() => _location = widget.location),
        ),
        const SizedBox(height: 8),
        _WordsRow(
          label: 'ข้อความของคุณ',
          value: _note,
          placeholder: 'เพิ่มบรรทัดของคุณเอง',
          edited: _note.isNotEmpty,
          resetLabel: 'ลบ',
          onTap: _editNote,
          onReset: () => setState(() => _note = ''),
        ),
        const ShareHint('คำที่แก้ใช้เฉพาะการ์ดใบนี้ ข้อมูลการจองไม่เปลี่ยน'),
      ],
    );
  }
}

/// แท็บเครื่องมือใต้พรีวิว
enum _Panel {
  photo('รูป'),
  style('สไตล์'),
  info('ข้อมูล'),
  words('ข้อความ');

  const _Panel(this.label);

  final String label;
}

/// ช่องพิมพ์คำบนการ์ด — ถือ controller เองใน State เพราะถ้าผู้เรียก dispose
/// ทันทีที่ dialog ปิด แอนิเมชันตอนปิดยังวาด TextField ด้วย controller ที่ตายแล้ว
class _WordsDialog extends StatefulWidget {
  final String title;
  final String initial;
  final int maxLength;
  final String hint;

  const _WordsDialog({
    required this.title,
    required this.initial,
    required this.maxLength,
    required this.hint,
  });

  @override
  State<_WordsDialog> createState() => _WordsDialogState();
}

class _WordsDialogState extends State<_WordsDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.title,
        style: appFont(
          fontSize: AppText.sizeSubtitle,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: widget.maxLength,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _done(),
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('ยกเลิก', style: appFont(fontWeight: FontWeight.w700)),
        ),
        TextButton(
          onPressed: _done,
          child: Text(
            'ใช้คำนี้',
            style: appFont(
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// แถวคำบนการ์ดหนึ่งช่อง — แตะเพื่อแก้ มีปุ่มคืนค่าเมื่อแก้ไปแล้ว
class _WordsRow extends StatelessWidget {
  final String label;
  final String value;
  final String placeholder;
  final bool edited;
  final String resetLabel;
  final VoidCallback onTap;
  final VoidCallback onReset;

  const _WordsRow({
    required this.label,
    required this.value,
    required this.edited,
    required this.onTap,
    required this.onReset,
    this.placeholder = '',
    this.resetLabel = 'ใช้คำเดิม',
  });

  @override
  Widget build(BuildContext context) {
    final empty = value.trim().isEmpty;

    return Semantics(
      button: true,
      label: 'แก้$label',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppTheme.subtleSurface(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 96,
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
                child: Text(
                  empty ? placeholder : value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: 13.5,
                    fontWeight: empty ? FontWeight.w600 : FontWeight.w700,
                    color: empty
                        ? AppTheme.mutedText(context)
                        : AppTheme.onSurface(context),
                  ),
                ),
              ),
              if (edited)
                ShareTextAction(label: resetLabel, onTap: onReset)
              else
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.edit_rounded,
                    size: 16,
                    color: AppTheme.mutedText(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// คำบรรยายที่ติดไปกับรูปตอนแชร์ — แยกออกมาให้เทสได้โดยไม่ต้องเปิด sheet
///
/// [showCountdown] false = เจ้าของซ่อนตัวนับบนการ์ด คำบรรยายก็ต้องไม่บอกจำนวน
/// วันแทน ไม่งั้นการซ่อนบนการ์ดก็ไม่มีความหมาย
String storyShareCaption({
  required String tripTitle,
  required int? daysLeft,
  required bool isRecap,
  bool showCountdown = true,
  String? url,
}) {
  final lead = isRecap
      ? 'เพิ่งกลับจาก "$tripTitle"'
      : !showCountdown
      ? 'ทริปต่อไปของฉัน "$tripTitle"'
      : switch (daysLeft) {
          null => 'ทริปต่อไปของฉัน "$tripTitle"',
          < 0 => 'กำลังลุย "$tripTitle"',
          0 => 'วันนี้ออกเดินทางไป "$tripTitle" แล้ว',
          1 => 'พรุ่งนี้ไป "$tripTitle" แล้ว',
          _ => 'อีก $daysLeft วันจะได้ไป "$tripTitle"',
        };

  return '$lead 🏔️${url == null || url.isEmpty ? '' : '\n$url'}\n#ลุยเลเขา';
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
    // ไม่ให้ sheet ลอดใต้รอยบาก — เหลือแถบมืดด้านบนให้เห็นว่าแตะปิดได้
    useSafeArea: true,
    backgroundColor: AppTheme.surface(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => builder(cover),
  );
}
