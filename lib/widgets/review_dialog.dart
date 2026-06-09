import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../config/api_endpoints.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

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
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ReviewSubmissionDialog(
        bookingId: bookingId,
        tripTitle: tripTitle,
      ),
    );
    return result ?? false;
  }
}

class _ReviewSubmissionDialogState extends State<ReviewSubmissionDialog> {
  final _commentController = TextEditingController();
  int _rating = 5;
  bool _submitting = false;
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

  static const _maxImages = 6;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = _maxImages - _selectedImages.length;
    if (remaining <= 0) return;

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('อัปโหลดรูปภาพล้มเหลว',
                style: GoogleFonts.anuphan()),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );
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

  bool get _anyUploading => _uploadingFlags.any((f) => f);

  Future<void> _submit() async {
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
            ratingGuide:
                _categoryRatings['guide']! > 0 ? _categoryRatings['guide'] : null,
            ratingVehicle: _categoryRatings['vehicle']! > 0
                ? _categoryRatings['vehicle']
                : null,
            ratingFood:
                _categoryRatings['food']! > 0 ? _categoryRatings['food'] : null,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _submitting = false;
      });
    }
  }

  Widget _buildCategoryRow(String key) {
    final value = _categoryRatings[key]!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(_categoryIcons[key],
              size: 16, color: AppTheme.mutedText(context)),
          const SizedBox(width: 8),
          SizedBox(
            width: 78,
            child: Text(
              _categoryLabels[key]!,
              style: GoogleFonts.anuphan(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface(context),
              ),
            ),
          ),
          const Spacer(),
          ...List.generate(5, (i) {
            final star = i + 1;
            final filled = star <= value;
            return GestureDetector(
              onTap: _submitting
                  ? null
                  : () => setState(() {
                        // Tapping the current value clears it (back to optional).
                        _categoryRatings[key] = value == star ? 0 : star;
                      }),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 22,
                  color: filled
                      ? const Color(0xFFFFB400)
                      : AppTheme.mutedText(context).withValues(alpha: 0.5),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppTheme.surface(context),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header (fixed) ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
              child: Column(
                children: [
                  Text(
                    'รีวิวทริปนี้',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.anuphan(
                      color: AppTheme.onSurface(context),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.tripTitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.anuphan(
                      color: AppTheme.mutedText(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable body ────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Star rating (overall) ──────────────────────────
                    Text(
                'ภาพรวม',
                textAlign: TextAlign.center,
                style: GoogleFonts.anuphan(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.mutedText(context),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final value = i + 1;
                  final filled = value <= _rating;
                  return IconButton(
                    onPressed: _submitting
                        ? null
                        : () => setState(() => _rating = value),
                    icon: Icon(
                      filled
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: filled
                          ? const Color(0xFFFFB400)
                          : AppTheme.mutedText(context),
                      size: 36,
                    ),
                  );
                }),
              ),

              // ── Category breakdown (optional) ────────────────────────
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                decoration: BoxDecoration(
                  color: AppTheme.fieldSurface(context),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'ให้คะแนนแยกหมวด (ไม่บังคับ)',
                        style: GoogleFonts.anuphan(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.mutedText(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    ..._categoryLabels.keys.map(_buildCategoryRow),
                  ],
                ),
              ),

              // ── Comment ──────────────────────────────────────────────
              const SizedBox(height: 12),
              TextField(
                controller: _commentController,
                enabled: !_submitting,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'เล่าประสบการณ์ของคุณ…',
                  filled: true,
                  fillColor: AppTheme.fieldSurface(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: AppTheme.border(context)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryColor,
                      width: 1.4,
                    ),
                  ),
                ),
              ),

              // ── Photo picker ─────────────────────────────────────────
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'รูปภาพ (${_selectedImages.length}/$_maxImages)',
                    style: GoogleFonts.anuphan(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                  const Spacer(),
                  if (_selectedImages.length < _maxImages)
                    TextButton.icon(
                      onPressed: _submitting ? null : _pickImages,
                      icon: const Icon(Icons.add_photo_alternate_outlined,
                          size: 17),
                      label: Text('เพิ่มรูป',
                          style: GoogleFonts.anuphan(
                              fontWeight: FontWeight.w800)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),

              if (_selectedImages.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 86,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    separatorBuilder: (context, i) => const SizedBox(width: 8),
                    itemBuilder: (_, index) {
                      final uploading = _uploadingFlags[index];
                      final uploaded =
                          _uploadedUrls[index].isNotEmpty;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _selectedImages[index],
                              width: 82,
                              height: 82,
                              fit: BoxFit.cover,
                            ),
                          ),
                          // Upload state overlay
                          if (uploading || !uploaded)
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  color: Colors.black.withValues(
                                      alpha: uploading ? 0.45 : 0.25),
                                  child: uploading
                                      ? const Center(
                                          child: SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: Colors.white,
                                            ),
                                          ),
                                        )
                                      : const Center(
                                          child: Icon(
                                            Icons.error_outline_rounded,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          // Success badge
                          if (uploaded && !uploading)
                            Positioned(
                              bottom: 4,
                              right: 4,
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
                          // Remove button
                          Positioned(
                            top: -6,
                            right: -6,
                            child: GestureDetector(
                              onTap: _submitting
                                  ? null
                                  : () => _removeImage(index),
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: AppTheme.errorColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppTheme.surface(context),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(Icons.close_rounded,
                                    color: Colors.white, size: 12),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],

                    // ── Error ──────────────────────────────────────────
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: GoogleFonts.anuphan(
                          color: AppTheme.errorColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Actions (fixed footer) ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: Text(
                      'ยกเลิก',
                      style: GoogleFonts.anuphan(
                        color: AppTheme.mutedText(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: (_submitting || _anyUploading) ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      disabledBackgroundColor: AppTheme.primaryColor.withValues(
                        alpha: 0.40,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'ส่งรีวิว',
                            style: GoogleFonts.anuphan(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
