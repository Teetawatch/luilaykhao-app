import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snack.dart';
import '../widgets/gift_voucher_card.dart';
import '../widgets/travel_widgets.dart';
import 'gift_voucher_purchase_screen.dart';

/// "บัตรของขวัญ" 🎁 — บัตรแบบระบุยอดเงิน ผู้รับเลือกทริปและวันเองได้
///
/// สามส่วนในจอเดียว: เพิ่มบัตรด้วยรหัส · บัตรในบัญชีของฉัน (ใช้ตอนจอง) ·
/// บัตรที่ฉันซื้อ (จ่ายเงิน/ส่งต่อ) — การใช้จ่ายจริงอยู่ที่ขั้นตอนการจอง
class GiftVoucherScreen extends StatefulWidget {
  /// เปิดจากลิงก์ `luilaykhao://voucher/CODE` — เติมรหัสและตรวจสอบให้เลย
  final String? initialCode;

  /// เปิดจากแจ้งเตือนของบัตรใบหนึ่ง — เปิดรายละเอียดใบนั้นให้หลังโหลดเสร็จ
  final int? focusVoucherId;

  const GiftVoucherScreen({super.key, this.initialCode, this.focusVoucherId});

  @override
  State<GiftVoucherScreen> createState() => _GiftVoucherScreenState();
}

class _GiftVoucherScreenState extends State<GiftVoucherScreen> {
  final _code = TextEditingController();

  bool _loading = true;
  String? _loadError;
  List<Map<String, dynamic>> _wallet = const [];
  List<Map<String, dynamic>> _purchased = const [];
  Map<String, dynamic> _config = const {};

  bool _lookupLoading = false;
  bool _claiming = false;
  String? _lookupError;
  Map<String, dynamic>? _preview;

  @override
  void initState() {
    super.initState();
    _load(focusId: widget.focusVoucherId);
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

  static List<Map<String, dynamic>> _maps(dynamic list) => list is List
      ? list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : const [];

  Future<void> _load({int? focusId}) async {
    try {
      final data = await context.read<AppProvider>().giftVouchers();
      if (!mounted) return;
      setState(() {
        _wallet = _maps(data['wallet']);
        _purchased = _maps(data['purchased']);
        _config = data['config'] is Map
            ? Map<String, dynamic>.from(data['config'] as Map)
            : const {};
        _loading = false;
        _loadError = null;
      });
      if (focusId != null) {
        final voucher = [..._wallet, ..._purchased].firstWhere(
          (v) => '${v['id']}' == '$focusId',
          orElse: () => const {},
        );
        if (voucher.isNotEmpty) _openDetail(voucher);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.message.isNotEmpty ? e.message : 'โหลดบัตรไม่สำเร็จ';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'โหลดบัตรไม่สำเร็จ กรุณาลองใหม่';
      });
    }
  }

  Future<void> _lookup() async {
    final code = _code.text.trim();
    if (code.isEmpty || _lookupLoading) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    setState(() {
      _lookupLoading = true;
      _lookupError = null;
      _preview = null;
    });
    try {
      final preview = await context.read<AppProvider>().lookupGiftVoucher(code);
      if (!mounted) return;
      setState(() => _preview = preview);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(
        () => _lookupError = e.message.isNotEmpty
            ? e.message
            : 'ไม่พบบัตรของขวัญนี้ กรุณาตรวจสอบรหัสอีกครั้ง',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _lookupError = 'ตรวจสอบรหัสไม่สำเร็จ กรุณาลองใหม่');
    } finally {
      if (mounted) setState(() => _lookupLoading = false);
    }
  }

  Future<void> _claim() async {
    final code = '${_preview?['code'] ?? _code.text}'.trim();
    if (code.isEmpty || _claiming) return;
    HapticFeedback.mediumImpact();
    setState(() => _claiming = true);
    try {
      await context.read<AppProvider>().claimGiftVoucher(code);
      if (!mounted) return;
      AppSnack.success(context, 'เพิ่มบัตรเข้าบัญชีแล้ว ใช้ตอนจองทริปได้เลย');
      setState(() {
        _preview = null;
        _code.clear();
      });
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(
        () => _lookupError = e.message.isNotEmpty
            ? e.message
            : 'เพิ่มบัตรไม่สำเร็จ',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _lookupError = 'เพิ่มบัตรไม่สำเร็จ กรุณาลองใหม่');
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  Future<void> _buy() async {
    HapticFeedback.selectionClick();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GiftVoucherPurchaseScreen(config: _config),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _pay(Map<String, dynamic> voucher) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            GiftVoucherPurchaseScreen(config: _config, existing: voucher),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _cancel(Map<String, dynamic> voucher) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยกเลิกบัตรนี้?'),
        content: Text(
          'บัตร ${voucherBaht(voucher['amount'])} ยังไม่ได้ชำระเงิน ยกเลิกแล้วสร้างใหม่ได้เสมอ',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ไม่ใช่ตอนนี้'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('ยกเลิกบัตร'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AppProvider>().cancelGiftVoucher(
        int.parse('${voucher['id']}'),
      );
      if (!mounted) return;
      AppSnack.show(context, 'ยกเลิกบัตรแล้ว');
      await _load();
    } on ApiException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'ยกเลิกไม่สำเร็จ กรุณาลองใหม่');
    }
  }

  void _openDetail(Map<String, dynamic> voucher) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      builder: (ctx) => _VoucherDetailSheet(
        voucher: voucher,
        onPay: () {
          Navigator.pop(ctx);
          _pay(voucher);
        },
        onCancel: () {
          Navigator.pop(ctx);
          _cancel(voucher);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primaryColor,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const TravelSliverAppBar(title: 'บัตรของขวัญ'),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _BuyBanner(onBuy: _buy),
                    const SizedBox(height: 16),
                    _redeemSection(context),
                    const SizedBox(height: 28),
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    else if (_loadError != null) ...[
                      EmptyState(
                        icon: Icons.wifi_off_rounded,
                        title: 'โหลดบัตรไม่สำเร็จ',
                        body: _loadError!,
                      ),
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() => _loading = true);
                            _load();
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('ลองอีกครั้ง'),
                        ),
                      ),
                    ]
                    else ...[
                      const _SectionTitle('บัตรของฉัน'),
                      const SizedBox(height: 4),
                      Text(
                        'ใช้ได้ตอนจองทริป — เลือกบัตรในขั้นตอนสรุปการจอง',
                        style: appFont(
                          fontSize: AppText.sizeCaption,
                          color: AppTheme.mutedText(context),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_wallet.isEmpty)
                        const EmptyState(
                          icon: Icons.card_giftcard_rounded,
                          title: 'ยังไม่มีบัตรในบัญชี',
                          body:
                              'ได้รหัสบัตรมาจากเพื่อน? กรอกรหัสด้านบนเพื่อเพิ่มบัตรเข้าบัญชี',
                        )
                      else
                        for (final v in _wallet) ...[
                          GiftVoucherCard.fromJson(
                            v,
                            onTap: () => _openDetail(v),
                          ),
                          const SizedBox(height: 12),
                        ],
                      if (_purchased.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        const _SectionTitle('บัตรที่ฉันซื้อ'),
                        const SizedBox(height: 12),
                        for (final v in _purchased) ...[
                          GiftVoucherCard.fromJson(
                            v,
                            showBalance: false,
                            onTap: () => _openDetail(v),
                          ),
                          if (v['status'] == 'pending' ||
                              v['status'] == 'rejected')
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                v['status'] == 'rejected'
                                    ? 'สลิปยังไม่ผ่าน แตะเพื่อดูเหตุผลและส่งใหม่'
                                    : 'ยังไม่ได้ชำระเงิน แตะเพื่อชำระ',
                                style: appFont(
                                  fontSize: AppText.sizeCaption,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.warningColor,
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _redeemSection(BuildContext context) {
    final preview = _preview;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'เพิ่มบัตรด้วยรหัส',
            style: appFont(
              fontSize: AppText.sizeSubtitle,
              fontWeight: FontWeight.w800,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'รหัสขึ้นต้นด้วย GV ที่ได้จากผู้ให้ เพิ่มแล้วบัตรเป็นของบัญชีนี้',
            style: appFont(
              fontSize: AppText.sizeLabel,
              height: 1.5,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _lookup(),
                  style: appFont(
                    fontSize: AppText.sizeSubtitle,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: 'GV-XXXXX-XXXXX',
                    filled: true,
                    fillColor: AppTheme.fieldSurface(context),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: BorderSide(color: AppTheme.border(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: BorderSide(color: AppTheme.border(context)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _lookupLoading ? null : _lookup,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                child: _lookupLoading
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
          if (_lookupError != null) ...[
            const SizedBox(height: 10),
            Text(
              _lookupError!,
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w600,
                color: AppTheme.errorColor,
              ),
            ),
          ],
          if (preview != null) ...[
            const SizedBox(height: 16),
            GiftVoucherCard.fromJson(preview),
            if ('${preview['message'] ?? ''}'.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '"${preview['message']}"',
                style: appFont(
                  fontSize: AppText.sizeBody,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                  color: AppTheme.onSurface(context),
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (preview['owned_by_me'] == true)
              const _Note(
                icon: Icons.check_circle_rounded,
                color: AppTheme.primaryColor,
                text: 'บัตรนี้อยู่ในบัญชีของคุณแล้ว',
              )
            else if (preview['owned_by_other'] == true)
              const _Note(
                icon: Icons.lock_rounded,
                color: AppTheme.errorColor,
                text: 'บัตรนี้ถูกเพิ่มเข้าบัญชีอื่นไปแล้ว',
              )
            else if (preview['usable'] != true)
              _Note(
                icon: Icons.info_rounded,
                color: AppTheme.warningColor,
                text: giftVoucherStatusLabel('${preview['status']}'),
              )
            else
              PrimaryCTAButton(
                label: 'เพิ่มบัตรเข้าบัญชี',
                icon: Icons.add_card_rounded,
                loading: _claiming,
                onPressed: _claim,
              ),
          ],
        ],
      ),
    );
  }
}

class _BuyBanner extends StatelessWidget {
  final VoidCallback onBuy;

  const _BuyBanner({required this.onBuy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.selectedTint(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'มอบการเดินทางเป็นของขวัญ 🎁',
            style: appFont(
              fontSize: AppText.sizeSubtitle,
              fontWeight: FontWeight.w800,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'เลือกมูลค่าที่ต้องการ ผู้รับเลือกทริปและวันที่อยากไปเองได้ '
            'ใช้ไม่หมดก็เก็บยอดที่เหลือไว้จองครั้งหน้า',
            style: appFont(
              fontSize: AppText.sizeLabel,
              height: 1.5,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 14),
          PrimaryCTAButton(
            label: 'ซื้อบัตรของขวัญ',
            icon: Icons.card_giftcard_rounded,
            height: 48,
            onPressed: onBuy,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: appFont(
        fontSize: AppText.sizeSubtitle,
        fontWeight: FontWeight.w800,
        color: AppTheme.onSurface(context),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _Note({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: appFont(
              fontSize: AppText.sizeLabel,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// รายละเอียดบัตรหนึ่งใบ — แชร์/คัดลอกรหัส หรือชำระเงิน/ยกเลิกบัตรที่ยังไม่ได้จ่าย
class _VoucherDetailSheet extends StatelessWidget {
  final Map<String, dynamic> voucher;
  final VoidCallback onPay;
  final VoidCallback onCancel;

  const _VoucherDetailSheet({
    required this.voucher,
    required this.onPay,
    required this.onCancel,
  });

  String get _status => '${voucher['status'] ?? ''}';

  Future<void> _copyCode(BuildContext context) async {
    final code = '${voucher['display_code'] ?? ''}';
    if (code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) AppSnack.show(context, 'คัดลอกรหัสแล้ว');
  }

  Future<void> _share(BuildContext context) async {
    final url = '${voucher['share_url'] ?? ''}';
    final code = '${voucher['display_code'] ?? ''}';
    final from = '${voucher['from_name'] ?? ''}'.trim();
    final text = [
      '🎁 บัตรของขวัญลุยเลเขา มูลค่า ${voucherBaht(voucher['amount'])}'
          '${from.isNotEmpty ? ' จาก $from' : ''}',
      if (url.isNotEmpty) 'เปิดบัตร: $url',
      'รหัสบัตร: $code',
      'ใช้จองทริปไหนก็ได้ในแอปลุยเลเขา',
    ].join('\n');
    HapticFeedback.selectionClick();
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: 'บัตรของขวัญลุยเลเขา'),
      );
    } catch (_) {
      if (context.mounted) await _copyCode(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = '${voucher['message'] ?? ''}'.trim();
    final reviewNote = '${voucher['review_note'] ?? ''}'.trim();
    final isPurchaser = voucher['is_purchaser'] == true;
    final isOwner = voucher['is_owner'] == true;
    final active = _status == 'active';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GiftVoucherCard.fromJson(voucher, showBalance: isOwner),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '"$message"',
                style: appFont(
                  fontSize: AppText.sizeBody,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                  color: AppTheme.onSurface(context),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_status == 'pending' || _status == 'rejected') ...[
              if (_status == 'rejected' && reviewNote.isNotEmpty) ...[
                _Note(
                  icon: Icons.error_rounded,
                  color: AppTheme.errorColor,
                  text: 'สลิปยังไม่ผ่าน: $reviewNote',
                ),
                const SizedBox(height: 12),
              ],
              PrimaryCTAButton(
                label: _status == 'rejected' ? 'ส่งสลิปใหม่' : 'ชำระเงิน',
                icon: Icons.qr_code_2_rounded,
                onPressed: onPay,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                ),
                child: const Text('ยกเลิกบัตรนี้'),
              ),
            ] else if (_status == 'under_review')
              const _Note(
                icon: Icons.hourglass_top_rounded,
                color: AppTheme.warningColor,
                text:
                    'ทีมงานกำลังตรวจสอบยอดโอน บัตรจะพร้อมใช้ทันทีที่ตรวจเสร็จ เราจะแจ้งเตือนให้ครับ',
              )
            else if (active) ...[
              if (isPurchaser && !isOwner) ...[
                if (voucher['claimed'] == true)
                  const _Note(
                    icon: Icons.check_circle_rounded,
                    color: AppTheme.primaryColor,
                    text: 'ผู้รับเพิ่มบัตรเข้าบัญชีแล้ว',
                  )
                else
                  Text(
                    'ส่งลิงก์หรือรหัสนี้ให้ผู้รับ — รหัสใช้แทนเงินสด ส่งให้เฉพาะคนที่ตั้งใจมอบให้นะครับ',
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      height: 1.5,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                const SizedBox(height: 12),
                PrimaryCTAButton(
                  label: 'ส่งบัตรให้ผู้รับ',
                  icon: Icons.ios_share_rounded,
                  onPressed: () => _share(context),
                ),
                const SizedBox(height: 8),
              ] else
                Text(
                  'ใช้บัตรนี้ได้ตอนจองทริป ในขั้นตอนสรุปการจองแตะ "ใช้บัตรของขวัญ"',
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    height: 1.5,
                    color: AppTheme.mutedText(context),
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _copyCode(context),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('คัดลอกรหัสบัตร'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
