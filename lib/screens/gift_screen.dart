import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/thai_date.dart';
import '../widgets/travel_widgets.dart';

/// "ของขวัญ" 🎁 — สองหน้าที่ในจอเดียว:
/// 1) รับของขวัญ: กรอกโค้ดที่ได้จากผู้ให้ → ดูการ์ดของขวัญ → กดรับ
///    แล้วการจองย้ายมาเป็นของเรา (ข้อมูลผู้เดินทางถูกเติมจากโปรไฟล์)
/// 2) ของขวัญที่ฉันส่ง: ดูโค้ด/สถานะการรับของขวัญแต่ละชิ้นที่เคยซื้อ
class GiftScreen extends StatefulWidget {
  /// เปิดจาก deep link `luilaykhao://gift/CODE` — เติมโค้ดและตรวจสอบให้อัตโนมัติ
  final String? initialCode;

  const GiftScreen({super.key, this.initialCode});

  @override
  State<GiftScreen> createState() => _GiftScreenState();
}

class _GiftScreenState extends State<GiftScreen> {
  final _code = TextEditingController();
  bool _previewLoading = false;
  bool _claiming = false;
  String? _error;
  Map<String, dynamic>? _preview;

  bool _sentLoading = true;
  List<Map<String, dynamic>> _sent = const [];

  @override
  void initState() {
    super.initState();
    _loadSent();
    final code = widget.initialCode?.trim();
    if (code != null && code.isNotEmpty) {
      _code.text = code.toUpperCase();
      WidgetsBinding.instance.addPostFrameCallback((_) => _lookup());
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _loadSent() async {
    try {
      final sent = await context.read<AppProvider>().sentGifts();
      if (!mounted) return;
      setState(() {
        _sent = sent;
        _sentLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sentLoading = false);
    }
  }

  Future<void> _lookup() async {
    final code = _code.text.trim().toUpperCase();
    if (code.isEmpty || _previewLoading) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    setState(() {
      _previewLoading = true;
      _error = null;
      _preview = null;
    });
    try {
      final preview = await context.read<AppProvider>().giftPreview(code);
      if (!mounted) return;
      setState(() => _preview = preview);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e.message.isNotEmpty
            ? e.message
            : 'ไม่พบโค้ดของขวัญนี้ กรุณาตรวจสอบอีกครั้ง',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'ตรวจสอบโค้ดไม่สำเร็จ กรุณาลองใหม่');
    } finally {
      if (mounted) setState(() => _previewLoading = false);
    }
  }

  Future<void> _claim() async {
    if (_claiming) return;
    HapticFeedback.mediumImpact();
    setState(() => _claiming = true);
    try {
      final booking = await context.read<AppProvider>().claimGift(_code.text);
      if (!mounted) return;
      final ref = '${booking['booking_ref'] ?? ''}';
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'รับของขวัญสำเร็จ 🎉',
            style: appFont(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          content: Text(
            'ทริปนี้เป็นของคุณแล้ว ดูรายละเอียดได้ที่ "การจองของฉัน" '
            '(เลขการจอง $ref)\n\nอย่าลืมกรอกข้อมูลส่วนตัวในโปรไฟล์ให้ครบ '
            'เพื่อให้ทีมงานดูแลคุณได้เต็มที่',
            style: appFont(
              fontSize: 14,
              height: 1.6,
              color: AppTheme.mutedText(ctx),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('เยี่ยมเลย'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e.message.isNotEmpty ? e.message : 'รับของขวัญไม่สำเร็จ',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'รับของขวัญไม่สำเร็จ กรุณาลองใหม่');
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const BouncingScrollPhysics(),
        slivers: [
          const TravelSliverAppBar(title: 'ของขวัญ'),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _redeemSection(context),
                  const SizedBox(height: 28),
                  Text(
                    'ของขวัญที่ฉันส่ง',
                    style: appFont(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_sentLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  else if (_sent.isEmpty)
                    const EmptyState(
                      icon: Icons.card_giftcard_rounded,
                      title: 'ยังไม่เคยส่งของขวัญ',
                      body:
                          'เลือกทริปที่ชอบ แล้วเปิดโหมด "ซื้อเป็นของขวัญ" ในขั้นตอนการจอง เพื่อส่งทริปให้คนพิเศษ',
                    )
                  else
                    ..._sent.map((gift) => _SentGiftCard(gift: gift)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _redeemSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration(context, radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎁', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'รับของขวัญ',
                  style: appFont(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'มีคนส่งทริปมาให้? กรอกโค้ดของขวัญที่ได้รับเพื่อรับทริปไปเป็นของคุณ',
            style: appFont(
              fontSize: 13,
              height: 1.6,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _lookup(),
                  style: appFont(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                  decoration: InputDecoration(
                    hintText: 'เช่น K7XPQ2MB',
                    hintStyle: appFont(
                      fontSize: 15,
                      letterSpacing: 1,
                      color: AppTheme.mutedText(context),
                    ),
                    filled: true,
                    fillColor: AppTheme.fieldSurface(context),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppTheme.border(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppTheme.border(context)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _previewLoading ? null : _lookup,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                ),
                child: _previewLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('ตรวจสอบ'),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: appFont(
                fontSize: 13,
                color: AppTheme.errorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (_preview != null) ...[
            const SizedBox(height: 16),
            _GiftPreviewCard(
              preview: _preview!,
              claiming: _claiming,
              onClaim: _claim,
            ),
          ],
        ],
      ),
    );
  }
}

/// การ์ดพรีวิวของขวัญหลังตรวจสอบโค้ด — โชว์ทริป วันเดินทาง ผู้ให้ และคำอวยพร
/// (ไม่โชว์ราคา) พร้อมปุ่มกดรับเมื่อยังรับได้
class _GiftPreviewCard extends StatelessWidget {
  final Map<String, dynamic> preview;
  final bool claiming;
  final VoidCallback onClaim;

  const _GiftPreviewCard({
    required this.preview,
    required this.claiming,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final trip = Map<String, dynamic>.from((preview['trip'] as Map?) ?? {});
    final cover = '${trip['cover_image'] ?? ''}';
    final claimable = preview['claimable'] == true;
    final claimed = preview['claimed'] == true;
    final blockedReason = '${preview['claim_blocked_reason'] ?? ''}';
    final message = '${preview['message'] ?? ''}';
    final fromName = '${preview['from_name'] ?? ''}';
    final departure = _departureLabel(preview);
    final travelers = int.tryParse('${preview['traveler_count']}') ?? 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: cover.isEmpty
                    ? Container(
                        width: 64,
                        height: 64,
                        color: AppTheme.primaryColor.withValues(alpha: 0.10),
                        child: const Icon(Icons.landscape_rounded),
                      )
                    : CachedNetworkImage(
                        imageUrl: cover,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${trip['title'] ?? 'ทริปเดินทาง'}',
                      style: appFont(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (departure.isNotEmpty) 'เดินทาง $departure',
                        '$travelers ที่นั่ง',
                      ].join(' · '),
                      style: appFont(
                        fontSize: 12.5,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                    if (fromName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'ของขวัญจาก $fromName 🎁',
                        style: appFont(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '"$message"',
              style: appFont(
                fontSize: 13.5,
                height: 1.6,
                fontStyle: FontStyle.italic,
                color: AppTheme.onSurface(context),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (claimable)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: claiming ? null : onClaim,
                icon: claiming
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.redeem_rounded, size: 18),
                label: Text(claiming ? 'กำลังรับของขวัญ...' : 'รับของขวัญนี้'),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                claimed
                    ? 'ของขวัญนี้ถูกรับไปแล้ว'
                    : (blockedReason.isNotEmpty
                          ? blockedReason
                          : 'ของขวัญนี้ยังรับไม่ได้'),
                style: appFont(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.errorColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// รายการของขวัญที่ฉันเป็นผู้ให้ — โค้ด สถานะรับ และปุ่มคัดลอกโค้ด
class _SentGiftCard extends StatelessWidget {
  final Map<String, dynamic> gift;

  const _SentGiftCard({required this.gift});

  @override
  Widget build(BuildContext context) {
    final claimed = gift['claimed'] == true;
    final fullyPaid = gift['is_fully_paid'] == true;
    final cancelled = '${gift['status']}' == 'cancelled';
    final code = '${gift['gift_code'] ?? ''}';
    final claimedBy = '${gift['claimed_by_name'] ?? ''}';
    final departure = _departureLabel(gift);

    final (statusLabel, statusColor) = () {
      if (cancelled) return ('ยกเลิกแล้ว', AppTheme.errorColor);
      if (claimed) return ('รับแล้ว', AppTheme.primaryColor);
      if (!fullyPaid) {
        return ('รอชำระเงิน', AppTheme.mutedText(context));
      }
      return ('รอผู้รับกดรับ', const Color(0xFFB45309));
    }();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.cardDecoration(context, radius: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${gift['trip_title'] ?? 'ทริปเดินทาง'}',
                    style: appFont(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: appFont(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                if (departure.isNotEmpty) 'เดินทาง $departure',
                if (claimed && claimedBy.isNotEmpty) 'ผู้รับ: $claimedBy',
              ].join(' · '),
              style: appFont(
                fontSize: 12.5,
                color: AppTheme.mutedText(context),
              ),
            ),
            if (!claimed && !cancelled && code.isNotEmpty) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () async {
                  HapticFeedback.selectionClick();
                  await Clipboard.setData(ClipboardData(text: code));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('คัดลอกโค้ดของขวัญแล้ว')),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.fieldSurface(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border(context)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        code,
                        style: appFont(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.5,
                          color: AppTheme.onSurface(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.copy_rounded,
                        size: 15,
                        color: AppTheme.mutedText(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// วันเดินทางแบบไทยจาก payload ของ gift API — ใช้ label จาก backend ก่อน
/// ถ้าไม่มีค่อย parse departure_date เอง
String _departureLabel(Map<String, dynamic> data) {
  final label = '${data['departure_label'] ?? ''}';
  if (label.isNotEmpty && label != 'null') return label;
  final raw = '${data['departure_date'] ?? ''}';
  final parsed = DateTime.tryParse(raw);
  return parsed == null ? '' : thaiDateShort(parsed);
}
