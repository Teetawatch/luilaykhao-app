import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

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

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final comment = _commentController.text.trim();
    if (comment.length < 4) {
      setState(() => _error = 'กรุณาเขียนรีวิวอย่างน้อย 4 ตัวอักษร');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<AppProvider>().submitReview(
        bookingId: widget.bookingId,
        rating: _rating,
        comment: comment,
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppTheme.surface(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 18),
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
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: filled
                          ? const Color(0xFFFFB400)
                          : AppTheme.mutedText(context),
                      size: 36,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
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
                    borderSide: BorderSide(color: AppTheme.border(context)),
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
              const SizedBox(height: 12),
              Row(
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
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
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
            ],
          ),
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
