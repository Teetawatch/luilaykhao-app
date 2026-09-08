import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/travel_widgets.dart';

/// หน้าจอ "ผูกการจองที่ทีมงานจองให้"
///
/// เคสที่เกิดขึ้นจริง: ลูกค้าทักไลน์มาจอง ทีมงานเปิดใบจองให้ ลูกค้าจ่ายเงินแล้ว
/// แต่ตอนนั้นยังไม่มีบัญชีในแอป พอโหลดแอปมาสมัครเอง กลับเห็นหน้าการจองว่างเปล่า
/// เพราะใบจองนั้นผูกอยู่กับบัญชีที่ทีมงานสร้างไว้แทน
///
/// หลักฐานที่ใช้คือชุดเดียวกับหน้า "ค้นหาการจอง" ของคนที่ยังไม่ล็อกอิน —
/// เลขที่จอง + เบอร์ 4 ตัวท้าย — ไม่ใช่แค่เบอร์อย่างเดียว เพราะในใบจองมีเลขบัตร
/// ประชาชนและข้อมูลสุขภาพของผู้เดินทางทุกคน การเดาเบอร์ถูกจึงไม่ควรพอ
class ClaimBookingScreen extends StatefulWidget {
  const ClaimBookingScreen({super.key});

  @override
  State<ClaimBookingScreen> createState() => _ClaimBookingScreenState();
}

class _ClaimBookingScreenState extends State<ClaimBookingScreen> {
  final _refController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // เบอร์ในโปรไฟล์คือเบอร์ที่ลูกค้าให้ทีมงานไว้เกือบทุกครั้ง — เติมให้เลย
    // เหลือให้พิมพ์แค่เลขที่จองช่องเดียว
    final phone = context.read<AppProvider>().user?['phone']?.toString() ?? '';
    if (phone.trim().isNotEmpty) _phoneController.text = phone.trim();
  }

  @override
  void dispose() {
    _refController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pasteReference() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      if (mounted) setState(() => _error = 'ยังไม่มีอะไรอยู่ในคลิปบอร์ด');
      return;
    }
    _refController.text = text;
  }

  Future<void> _submit() async {
    final ref = _refController.text.trim();
    final phone = _phoneController.text.trim();

    if (ref.isEmpty) {
      setState(() => _error = 'กรุณากรอกเลขที่การจอง');
      return;
    }
    if (phone.replaceAll(RegExp(r'\D'), '').length < 4) {
      setState(() => _error = 'กรอกเบอร์โทรอย่างน้อย 4 ตัวท้าย');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final data = await context.read<AppProvider>().claimBooking(
        bookingRef: ref,
        phone: phone,
      );
      if (!mounted) return;
      final title =
          (data['schedule'] as Map?)?['trip']?['title']?.toString() ?? 'ทริป';
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เพิ่ม "$title" เข้าบัญชีของคุณแล้ว')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString().replaceFirst('Exception: ', '').trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final waiting = context.watch<AppProvider>().claimableBookingCount;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: const Text('ผูกการจองที่ทีมงานจองให้'),
        backgroundColor: AppTheme.background(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.selectedTint(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.surface(context),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: const Icon(
                      Icons.playlist_add_check_rounded,
                      color: AppTheme.primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    waiting > 0
                        ? 'เราพบการจอง $waiting รายการที่อาจเป็นของคุณ'
                        : 'จองผ่านทีมงานไว้ใช่ไหม?',
                    style: appFont(
                      fontSize: AppText.sizeH2,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ถ้าทีมงานเปิดการจองให้คุณทางไลน์หรือโทรศัพท์ก่อนที่คุณจะ '
                    'สมัครในแอป การจองนั้นจะยังไม่ขึ้นในบัญชีนี้ '
                    'กรอกเลขที่การจองกับเบอร์ที่ใช้จอง แล้วเราจะย้ายมาให้ทันที',
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      color: AppTheme.mutedText(context),
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const _FieldLabel('เลขที่การจอง'),
            const SizedBox(height: 8),
            TextField(
              controller: _refController,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: 'เช่น LLK-20260915-A1B2',
                filled: true,
                fillColor: AppTheme.fieldSurface(context),
                prefixIcon: const Icon(Icons.confirmation_number_rounded),
                suffixIcon: IconButton(
                  tooltip: 'วางจากคลิปบอร์ด',
                  icon: const Icon(Icons.content_paste_rounded),
                  onPressed: _pasteReference,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _FieldLabel('เบอร์โทรที่ใช้จอง'),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'กรอกเบอร์เต็ม หรือ 4 ตัวท้ายก็ได้',
                filled: true,
                fillColor: AppTheme.fieldSurface(context),
                prefixIcon: const Icon(Icons.phone_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              _ClaimBanner(
                color: AppTheme.dangerColor,
                icon: Icons.error_outline_rounded,
                text: _error!,
              ),
            ],
            const SizedBox(height: 20),
            PrimaryCTAButton(
              label: _submitting ? 'กำลังตรวจสอบ...' : 'ผูกเข้าบัญชีของฉัน',
              icon: Icons.link_rounded,
              onPressed: _submitting ? null : _submit,
            ),
            const SizedBox(height: 26),
            const _FieldLabel('หาเลขที่การจองไม่เจอ?'),
            const SizedBox(height: 8),
            const _ClaimHintCard(),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: appFont(
        fontSize: AppText.sizeLabel,
        fontWeight: FontWeight.w700,
        color: AppTheme.mutedText(context),
        letterSpacing: 0.2,
      ),
    );
  }
}

class _ClaimHintCard extends StatelessWidget {
  const _ClaimHintCard();

  static const _lines = <String>[
    'ดูใน SMS หรืออีเมลยืนยันการจองที่ทีมงานส่งให้ — ขึ้นต้นด้วย LLK-',
    'ถ้าทีมงานส่งลิงก์ "เปิดใช้บัญชี" มาให้ กดลิงก์นั้นได้เลย ไม่ต้องกรอกอะไร',
    'หรือทักทีมงานในไลน์ ขอเลขที่การจองของคุณอีกครั้งได้ตลอด',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _lines.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _lines[i],
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      color: AppTheme.mutedText(context),
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ClaimBanner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;

  const _ClaimBanner({
    required this.color,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: appFont(
                fontSize: AppText.sizeLabel,
                color: AppTheme.onSurface(context),
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
