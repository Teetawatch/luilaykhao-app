part of 'payment_screen.dart';

class _PaymentCompletedCard extends StatefulWidget {
  final Map<String, dynamic> booking;

  const _PaymentCompletedCard({required this.booking});

  @override
  State<_PaymentCompletedCard> createState() => _PaymentCompletedCardState();
}

class _PaymentCompletedCardState extends State<_PaymentCompletedCard>
    with SingleTickerProviderStateMixin {
  final GlobalKey _qrKey = GlobalKey();
  bool _downloadingQr = false;
  late AnimationController _anim;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = CurvedAnimation(parent: _anim, curve: Curves.elasticOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _downloadQr() async {
    if (_downloadingQr) return;
    setState(() => _downloadingQr = true);
    try {
      final ro = _qrKey.currentContext?.findRenderObject();
      if (ro is! RenderRepaintBoundary) {
        throw Exception('ไม่พบ QR CODE สำหรับดาวน์โหลด');
      }
      final image = await ro.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) throw Exception('ไม่สามารถสร้างรูป QR CODE ได้');

      final safeRef = textOf(widget.booking['booking_ref'], 'checkin')
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final fileName = 'luilaykhao-checkin-$safeRef-qr.png';
      final bytes = byteData.buffer.asUint8List();

      final directories = <Directory>[];
      if (Platform.isAndroid) {
        directories.add(Directory('/storage/emulated/0/Download'));
      }
      try {
        final dl = await getDownloadsDirectory();
        if (dl != null) directories.add(dl);
      } catch (_) {}
      directories.add(await getApplicationDocumentsDirectory());
      directories.add(Directory.systemTemp);

      File? saved;
      for (final dir in directories) {
        try {
          if (!await dir.exists()) await dir.create(recursive: true);
          saved = await File(
            '${dir.path}${Platform.pathSeparator}$fileName',
          ).writeAsBytes(bytes, flush: true);
          break;
        } catch (_) {}
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved != null
                ? 'ดาวน์โหลด QR CODE แล้ว: ${saved.path}'
                : 'ไม่สามารถบันทึกไฟล์ได้',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ไม่สามารถดาวน์โหลด QR CODE ได้: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingQr = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingRef = textOf(widget.booking['booking_ref'], '-');
    final checkInCode = textOf(widget.booking['qr_code']).trim();
    final isDark = AppTheme.isDark(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  _accent.withValues(alpha: 0.22),
                  const Color(0xFF059669).withValues(alpha: 0.08),
                ]
              : [
                  _accent.withValues(alpha: 0.09),
                  _accent.withValues(alpha: 0.04),
                ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _accent.withValues(alpha: 0.22)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          ScaleTransition(
            scale: _scale,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _accent.withValues(alpha: 0.28),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: _accent,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'พร้อมสำหรับเช็คอิน',
            style: GoogleFonts.anuphan(
              color: AppTheme.onSurface(context),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'โปรดแสดงรหัสนี้แก่เจ้าหน้าที่เมื่อถึงจุดนัดหมาย',
            textAlign: TextAlign.center,
            style: GoogleFonts.anuphan(
              color: AppTheme.mutedText(context),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          if (checkInCode.isNotEmpty) ...[
            const SizedBox(height: 20),
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _accent.withValues(alpha: 0.18)),
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withValues(alpha: 0.14),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: checkInCode,
                  version: QrVersions.auto,
                  size: 180,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 220,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _downloadingQr ? null : _downloadQr,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: BorderSide(color: _accent.withValues(alpha: 0.30)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                icon: _downloadingQr
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _accent,
                        ),
                      )
                    : const Icon(Icons.download_rounded, size: 20),
                label: Text(
                  _downloadingQr ? 'กำลังดาวน์โหลด' : 'ดาวน์โหลด QR CODE',
                  style: GoogleFonts.anuphan(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _accent.withValues(alpha: 0.18)),
            ),
            child: Column(
              children: [
                Text(
                  'รหัสการจอง',
                  style: GoogleFonts.anuphan(
                    color: AppTheme.mutedText(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  bookingRef,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.anuphan(
                    color: _accent,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Submit / home buttons
// ─────────────────────────────────────────────────────────────────────────────

class _SubmitButton extends StatelessWidget {
  final bool paying;
  final num amount;
  final VoidCallback onPressed;

  const _SubmitButton({
    required this.paying,
    required this.amount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: FilledButton.icon(
        onPressed: paying ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _accent.withValues(alpha: 0.40),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.70),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: paying ? 0 : 2,
          shadowColor: _accent.withValues(alpha: 0.40),
        ),
        icon: paying
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.verified_user_rounded, size: 22),
        label: Text(
          paying ? 'กำลังบันทึก...' : 'ยืนยันการชำระ ${money(amount)}',
          style: GoogleFonts.anuphan(
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _HomeButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _accent,
          side: BorderSide(color: _accent.withValues(alpha: 0.32)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        icon: const Icon(Icons.home_rounded),
        label: Text(
          'กลับหน้าหลัก',
          style: GoogleFonts.anuphan(fontWeight: FontWeight.w900, fontSize: 15),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Success dialog
// ─────────────────────────────────────────────────────────────────────────────

class _SuccessDialog extends StatelessWidget {
  final num amount;

  const _SuccessDialog({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: AppTheme.surface(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: _accent,
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'แจ้งชำระเงินสำเร็จ',
              style: GoogleFonts.anuphan(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppTheme.onSurface(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ระบบบันทึกข้อมูลการชำระเงิน ${money(amount)} แล้ว\nทีมงานจะตรวจสอบและยืนยันการจองให้เร็วๆ นี้',
              textAlign: TextAlign.center,
              style: GoogleFonts.anuphan(
                color: AppTheme.mutedText(context),
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  'ตกลง',
                  style: GoogleFonts.anuphan(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
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

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────
