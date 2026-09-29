import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../config/api_endpoints.dart';
import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'app_snack.dart';
import 'travel_widgets.dart' show PrimaryCTAButton;

const _starColor = Color(0xFFFFB400);

/// คำบรรยายใต้ดาว — index 0 = 1 ดาว
const _ratingWords = [
  'ไม่ประทับใจ',
  'พอใช้',
  'ดี',
  'ดีมาก',
  'ประทับใจมาก',
];

/// Post-trip review, shown as a bottom sheet. After a successful send the sheet
/// swaps to a thank-you state instead of closing silently, so the traveller
/// knows the review actually went through.
class ReviewSubmissionDialog extends StatefulWidget {
  final int bookingId;
  final String tripTitle;

  const ReviewSubmissionDialog({
    super.key,
    required this.bookingId,
    required this.tripTitle,
  });

  @override
  State<ReviewSubmissionDialog> createState() => _ReviewSubmissionDialogState();

  static Future<bool> show(
    BuildContext context, {
    required int bookingId,
    required String tripTitle,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      builder: (_) =>
          ReviewSubmissionDialog(bookingId: bookingId, tripTitle: tripTitle),
    );
    return result ?? false;
  }
}

class _ReviewSubmissionDialogState extends State<ReviewSubmissionDialog> {
  final _commentController = TextEditingController();
  int _rating = 5;
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  // Optional per-category ratings (0 = ไม่ระบุ)
  final Map<String, int> _categoryRatings = {
    'guide': 0,
    'food': 0,
    'vehicle': 0,
  };

  static const _categoryLabels = {
    'guide': 'สตาฟ',
    'food': 'อาหาร',
    'vehicle': 'รถ',
  };

  static const _categoryIcons = {
    'guide': Icons.badge_rounded,
    'food': Icons.restaurant_rounded,
    'vehicle': Icons.directions_bus_rounded,
  };

  final List<File> _selectedImages = [];
  final List<String> _uploadedUrls = [];
  final List<bool> _uploadingFlags = [];

  // Attached videos (uploaded immediately, same as images).
  final List<File> _selectedVideos = [];
  final List<String> _uploadedVideoUrls = [];
  final List<bool> _videoUploadingFlags = [];

  static const _maxImages = 6;
  static const _maxVideos = 2;

  /// ผู้เดินทางที่รีวิวในนามได้ — เซิร์ฟเวอร์ส่งมาเฉพาะใบที่แอดมินจองให้ลูกค้า
  /// จากบัญชีตัวเอง (`review_as`) ใบของลูกค้าทั่วไปเป็นลิสต์ว่าง
  List<({int id, String name})> _reviewAs = const [];
  int? _passengerId;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppProvider>();
    for (final raw in app.bookings) {
      if (raw is! Map || '${raw['id']}' != '${widget.bookingId}') continue;
      final options = raw['review_as'];
      if (options is! List) break;
      _reviewAs = [
        for (final o in options)
          if (o is Map && int.tryParse('${o['passenger_id']}') != null)
            (id: int.parse('${o['passenger_id']}'), name: '${o['name'] ?? ''}'),
      ];
      break;
    }
    // ค่าเริ่มต้นคือผู้เดินทางคนแรก ตรงกับที่เซิร์ฟเวอร์ใช้เมื่อไม่ได้เลือก
    if (_reviewAs.isNotEmpty) _passengerId = _reviewAs.first.id;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = _maxImages - _selectedImages.length;
    if (remaining <= 0) return;
    HapticFeedback.selectionClick();

    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(
      imageQuality: 80,
      limit: remaining,
    );
    if (picked.isEmpty) return;

    final toAdd = picked.take(remaining).map((x) => File(x.path)).toList();
    setState(() {
      _selectedImages.addAll(toAdd);
      _uploadedUrls.addAll(List.filled(toAdd.length, ''));
      _uploadingFlags.addAll(List.filled(toAdd.length, false));
    });

    // Upload each image immediately
    for (var i = _selectedImages.length - toAdd.length;
        i < _selectedImages.length;
        i++) {
      _uploadImage(i);
    }
  }

  Future<void> _uploadImage(int index) async {
    setState(() => _uploadingFlags[index] = true);
    try {
      final app = context.read<AppProvider>();
      final response = await app.api.postMultipart(
        ApiEndpoints.reviewsUploadImage,
        fields: {},
        files: {'image': _selectedImages[index].path},
      ) as Map<String, dynamic>;
      final url = (response['data']?['url'] ?? response['url'] ?? '')
          .toString();
      if (mounted) setState(() => _uploadedUrls[index] = url);
    } catch (_) {
      if (mounted) {
        setState(() => _uploadingFlags[index] = false);
        AppSnack.error(context, 'อัปโหลดรูปภาพล้มเหลว');
      }
      return;
    }
    if (mounted) setState(() => _uploadingFlags[index] = false);
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      _uploadedUrls.removeAt(index);
      _uploadingFlags.removeAt(index);
    });
  }

  Future<void> _pickVideo() async {
    if (_selectedVideos.length >= _maxVideos) return;
    HapticFeedback.selectionClick();

    final picker = ImagePicker();
    final picked = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 60),
    );
    if (picked == null) return;

    final file = File(picked.path);
    setState(() {
      _selectedVideos.add(file);
      _uploadedVideoUrls.add('');
      _videoUploadingFlags.add(false);
    });
    _uploadVideo(_selectedVideos.length - 1);
  }

  Future<void> _uploadVideo(int index) async {
    setState(() => _videoUploadingFlags[index] = true);
    try {
      final app = context.read<AppProvider>();
      final response = await app.api.postMultipart(
        ApiEndpoints.reviewsUploadVideo,
        fields: {},
        files: {'video': _selectedVideos[index].path},
      ) as Map<String, dynamic>;
      final url = (response['data']?['url'] ?? response['url'] ?? '')
          .toString();
      if (mounted) setState(() => _uploadedVideoUrls[index] = url);
    } catch (_) {
      if (mounted) {
        setState(() => _videoUploadingFlags[index] = false);
        AppSnack.error(context, 'อัปโหลดวิดีโอล้มเหลว (ไฟล์อาจใหญ่เกิน 50MB)');
      }
      return;
    }
    if (mounted) setState(() => _videoUploadingFlags[index] = false);
  }

  void _removeVideo(int index) {
    setState(() {
      _selectedVideos.removeAt(index);
      _uploadedVideoUrls.removeAt(index);
      _videoUploadingFlags.removeAt(index);
    });
  }

  bool get _anyUploading =>
      _uploadingFlags.any((f) => f) || _videoUploadingFlags.any((f) => f);

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final comment = _commentController.text.trim();
    if (comment.length < 4) {
      setState(() => _error = 'กรุณาเขียนรีวิวอย่างน้อย 4 ตัวอักษร');
      return;
    }
    if (_anyUploading) {
      setState(() => _error = 'กรุณารอให้รูปภาพอัปโหลดเสร็จก่อน');
      return;
    }
    final images =
        _uploadedUrls.where((url) => url.isNotEmpty).toList();
    final videos =
        _uploadedVideoUrls.where((url) => url.isNotEmpty).toList();

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<AppProvider>().submitReview(
            bookingId: widget.bookingId,
            rating: _rating,
            comment: comment,
            images: images,
            videos: videos,
            ratingGuide:
                _categoryRatings['guide']! > 0 ? _categoryRatings['guide'] : null,
            ratingVehicle: _categoryRatings['vehicle']! > 0
                ? _categoryRatings['vehicle']
                : null,
            ratingFood:
                _categoryRatings['food']! > 0 ? _categoryRatings['food'] : null,
            passengerId: _passengerId,
          );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _submitting = false;
        _submitted = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    return PopScope(
      // กันปัดทิ้งกลางคันตอนกำลังส่ง ไม่งั้นไม่รู้ว่าส่งถึงหรือเปล่า
      canPop: !_submitting,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: _submitted
                  ? _ReviewSuccessView(
                      key: const ValueKey('success'),
                      tripTitle: widget.tripTitle,
                      rating: _rating,
                      onDone: () => Navigator.of(context).pop(true),
                    )
                  : _buildForm(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Column(
      key: const ValueKey('form'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ทริปนี้เป็นยังไงบ้าง?',
                      style: appFont(
                        fontSize: AppText.sizeTitle,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.tripTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'ปิด',
                onPressed: _submitting
                    ? null
                    : () => Navigator.of(context).pop(false),
                icon: Icon(
                  Icons.close_rounded,
                  color: AppTheme.mutedText(context),
                ),
              ),
            ],
          ),
        ),

        // ── Scrollable body ────────────────────────────────────────────
        Flexible(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_reviewAs.isNotEmpty) ...[
                  _buildReviewAs(),
                  const SizedBox(height: 16),
                ],
                _buildOverallRating(),
                const SizedBox(height: 20),
                const _SectionLabel('ให้คะแนนแยกหมวด', optional: true),
                const SizedBox(height: 8),
                _buildCategories(),
                const SizedBox(height: 20),
                const _SectionLabel('เล่าประสบการณ์ของคุณ'),
                const SizedBox(height: 8),
                _buildComment(),
                const SizedBox(height: 12),
                const _SectionLabel('รูปและวิดีโอ', optional: true),
                const SizedBox(height: 8),
                _buildMediaStrip(),
              ],
            ),
          ),
        ),

        // ── Footer ─────────────────────────────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            12 + (keyboardOpen ? 0 : MediaQuery.paddingOf(context).bottom),
          ),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: AppTheme.border(context).withValues(alpha: 0.6),
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                _ErrorBanner(message: _error!),
                const SizedBox(height: 10),
              ],
              PrimaryCTAButton(
                label: _submitting
                    ? 'กำลังส่งรีวิว...'
                    : _anyUploading
                    ? 'รออัปโหลดให้เสร็จก่อน...'
                    : 'ส่งรีวิว',
                icon: Icons.send_rounded,
                loading: _submitting,
                onPressed: _anyUploading ? null : _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// แอดมินจองให้ลูกค้า — เลือกว่ารีวิวนี้ขึ้นเป็นชื่อผู้เดินทางคนไหน
  Widget _buildReviewAs() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.fieldSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'รีวิวในนามของ',
            style: appFont(
              fontSize: AppText.sizeLabel,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'รีวิวจะแสดงเป็นชื่อลูกค้า ไม่ใช่ชื่อบัญชีที่จองให้',
            style: appFont(
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w600,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in _reviewAs)
                ChoiceChip(
                  selected: _passengerId == p.id,
                  onSelected: _submitting
                      ? null
                      : (_) => setState(() => _passengerId = p.id),
                  showCheckmark: false,
                  label: Text(p.name),
                  selectedColor: AppTheme.primaryColor,
                  backgroundColor: AppTheme.surface(context),
                  side: BorderSide(
                    color: _passengerId == p.id
                        ? AppTheme.primaryColor
                        : AppTheme.border(context),
                  ),
                  labelStyle: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w700,
                    color: _passengerId == p.id
                        ? Colors.white
                        : AppTheme.onSurface(context),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverallRating() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: AppTheme.tintOf(context, _starColor),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final value = i + 1;
              final filled = value <= _rating;
              return Semantics(
                button: true,
                selected: value == _rating,
                label: 'ให้ $value ดาว',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _submitting
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          setState(() => _rating = value);
                        },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: AnimatedScale(
                      scale: filled ? 1 : 0.86,
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutBack,
                      child: Icon(
                        filled ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 44,
                        color: filled
                            ? _starColor
                            : AppTheme.mutedText(context).withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Text(
              _ratingWords[_rating - 1],
              key: ValueKey(_rating),
              style: appFont(
                fontSize: AppText.sizeBody,
                fontWeight: FontWeight.w700,
                color: AppTheme.onTintOf(context, AppTheme.warningColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    final keys = _categoryLabels.keys.toList();
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < keys.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 14,
                endIndent: 14,
                color: AppTheme.border(context).withValues(alpha: 0.5),
              ),
            _buildCategoryRow(keys[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryRow(String key) {
    final value = _categoryRatings[key]!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.tintOf(context, AppTheme.primaryColor),
              borderRadius: BorderRadius.circular(AppTheme.radiusXs),
            ),
            child: Icon(
              _categoryIcons[key],
              size: 17,
              color: AppTheme.onTintOf(context, AppTheme.primaryColor),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _categoryLabels[key]!,
              style: appFont(
                fontSize: AppText.sizeBody,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurface(context),
              ),
            ),
          ),
          ...List.generate(5, (i) {
            final star = i + 1;
            final filled = star <= value;
            return Semantics(
              button: true,
              label: '${_categoryLabels[key]} $star ดาว',
              child: GestureDetector(
                onTap: _submitting
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          // Tapping the current value clears it (back to optional).
                          _categoryRatings[key] = value == star ? 0 : star;
                        });
                      },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 24,
                    color: filled
                        ? _starColor
                        : AppTheme.mutedText(context).withValues(alpha: 0.4),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildComment() {
    final radius = BorderRadius.circular(AppTheme.radiusMd);
    return TextField(
      controller: _commentController,
      enabled: !_submitting,
      minLines: 3,
      maxLines: 5,
      maxLength: 500,
      textCapitalization: TextCapitalization.sentences,
      onChanged: (_) {
        if (_error != null) setState(() => _error = null);
      },
      style: appFont(
        fontSize: AppText.sizeBody,
        color: AppTheme.onSurface(context),
        height: 1.5,
      ),
      decoration: InputDecoration(
        hintText: 'ประทับใจตรงไหน วิว อาหาร หรือทีมงาน '
            'เล่าให้เพื่อนนักเดินทางคนต่อไปฟังได้เลย',
        hintMaxLines: 3,
        hintStyle: appFont(
          fontSize: AppText.sizeBody,
          color: AppTheme.mutedText(context).withValues(alpha: 0.8),
          height: 1.5,
        ),
        filled: true,
        fillColor: AppTheme.fieldSurface(context),
        contentPadding: const EdgeInsets.all(14),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(
            color: AppTheme.primaryColor,
            width: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildMediaStrip() {
    final tiles = <Widget>[
      if (_selectedImages.length < _maxImages)
        _AddMediaTile(
          icon: Icons.add_photo_alternate_outlined,
          label: 'เพิ่มรูป',
          count: '${_selectedImages.length}/$_maxImages',
          onTap: _submitting ? null : _pickImages,
        ),
      if (_selectedVideos.length < _maxVideos)
        _AddMediaTile(
          icon: Icons.video_call_outlined,
          label: 'เพิ่มวิดีโอ',
          count: '${_selectedVideos.length}/$_maxVideos',
          onTap: _submitting ? null : _pickVideo,
        ),
      for (var i = 0; i < _selectedImages.length; i++)
        _MediaThumb(
          uploading: _uploadingFlags[i],
          uploaded: _uploadedUrls[i].isNotEmpty,
          removeLabel: 'ลบรูปนี้',
          onRemove: _submitting ? null : () => _removeImage(i),
          child: Image.file(
            _selectedImages[i],
            fit: BoxFit.cover,
            cacheWidth: 240,
          ),
        ),
      for (var i = 0; i < _selectedVideos.length; i++)
        _MediaThumb(
          uploading: _videoUploadingFlags[i],
          uploaded: _uploadedVideoUrls[i].isNotEmpty,
          removeLabel: 'ลบวิดีโอนี้',
          onRemove: _submitting ? null : () => _removeVideo(i),
          child: const ColoredBox(
            color: AppTheme.slate900,
            child: Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
    ];

    return SizedBox(
      height: _MediaThumb.size + 8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // เผื่อที่ให้ปุ่มลบที่ยื่นออกมุมขวาบน
        padding: const EdgeInsets.only(top: 8, right: 8),
        clipBehavior: Clip.none,
        itemCount: tiles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) => tiles[i],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool optional;

  const _SectionLabel(this.text, {this.optional = false});

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedText(context);
    return Text.rich(
      TextSpan(
        text: text,
        children: [
          if (optional)
            TextSpan(
              text: '  ·  ไม่บังคับ',
              style: appFont(
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w500,
                color: muted.withValues(alpha: 0.75),
              ),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: appFont(
        fontSize: AppText.sizeLabel,
        fontWeight: FontWeight.w700,
        color: muted,
      ),
    );
  }
}

class _AddMediaTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String count;
  final VoidCallback? onTap;

  const _AddMediaTile({
    required this.icon,
    required this.label,
    required this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radiusSm);
    return Material(
      color: AppTheme.fieldSurface(context),
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          width: _MediaThumb.size,
          height: _MediaThumb.size,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: AppTheme.border(context).withValues(alpha: 0.8),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: AppTheme.primaryColor),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: appFont(
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface(context),
                ),
              ),
              Text(
                count,
                style: appFont(
                  fontSize: AppText.sizeMicro,
                  fontWeight: FontWeight.w600,
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

class _MediaThumb extends StatelessWidget {
  static const double size = 80;

  final Widget child;
  final bool uploading;
  final bool uploaded;
  final String removeLabel;
  final VoidCallback? onRemove;

  const _MediaThumb({
    required this.child,
    required this.uploading,
    required this.uploaded,
    required this.removeLabel,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radiusSm);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(borderRadius: radius, child: child),
          ),
          // Upload state overlay
          if (uploading || !uploaded)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  color: Colors.black.withValues(alpha: uploading ? 0.45 : 0.3),
                ),
                child: Center(
                  child: uploading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.error_outline_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                ),
              ),
            ),
          // Success badge
          if (uploaded && !uploading)
            Positioned(
              bottom: 5,
              left: 5,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
          // Remove button — a bare glyph with no text; without a label a
          // screen reader announces nothing at all.
          Positioned(
            top: -7,
            right: -7,
            child: Semantics(
              button: true,
              label: removeLabel,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppTheme.slate900,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.surface(context),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 12,
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

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final fg = AppTheme.onTintOf(context, AppTheme.dangerColor);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppTheme.dangerTint(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w600,
                color: fg,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown in place of the form once the review is saved. Reviews go live on
/// the trip page immediately (`reviews.is_approved` defaults to true), so the
/// copy can say so plainly.
class _ReviewSuccessView extends StatelessWidget {
  final String tripTitle;
  final int rating;
  final VoidCallback onDone;

  const _ReviewSuccessView({
    super.key,
    required this.tripTitle,
    required this.rating,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.4, end: 1),
            duration: const Duration(milliseconds: 520),
            curve: Curves.elasticOut,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppTheme.tintOf(context, AppTheme.primaryColor),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'ส่งรีวิวเรียบร้อยแล้ว',
            textAlign: TextAlign.center,
            style: appFont(
              fontSize: AppText.sizeH2,
              fontWeight: FontWeight.w800,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                Icon(
                  i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 22,
                  color: i <= rating
                      ? _starColor
                      : AppTheme.mutedText(context).withValues(alpha: 0.4),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'ขอบคุณที่มาเล่าให้ฟังนะครับ รีวิวของคุณขึ้นบนหน้าทริป '
            '"$tripTitle" แล้ว และจะช่วยให้เพื่อนนักเดินทางคนต่อไป'
            'ตัดสินใจได้ง่ายขึ้น',
            textAlign: TextAlign.center,
            style: appFont(
              fontSize: AppText.sizeBody,
              fontWeight: FontWeight.w500,
              color: AppTheme.mutedText(context),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          PrimaryCTAButton(
            label: 'เสร็จสิ้น',
            icon: Icons.check_circle_outline_rounded,
            onPressed: onDone,
          ),
        ],
      ),
    );
  }
}

/// Helper: returns true if a past booking has not been reviewed yet.
bool bookingNeedsReview(
  Map<String, dynamic> booking,
  List<dynamic> myReviews,
) {
  final bookingId = booking['id'];
  if (bookingId == null) return false;
  final hasReview = myReviews.any((review) {
    if (review is! Map) return false;
    return review['booking_id']?.toString() == bookingId.toString();
  });
  return !hasReview;
}
