import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snack.dart';
import '../widgets/gift_voucher_card.dart';
import '../widgets/travel_widgets.dart';

enum _Step { form, payment, done }

/// ซื้อบัตรของขวัญ: กรอกมูลค่า/ผู้รับ → โอนพร้อมเพย์ + แนบสลิป → ผล
///
/// ส่ง [existing] มาเพื่อจ่ายบัตรที่สร้างไว้แล้ว (ยังไม่ได้จ่าย/สลิปไม่ผ่าน) —
/// ข้ามไปขั้นจ่ายเงินเลย ยอดและ QR มาจากหลังบ้านเสมอ ไม่คำนวณในเครื่อง
class GiftVoucherPurchaseScreen extends StatefulWidget {
  final Map<String, dynamic> config;
  final Map<String, dynamic>? existing;

  const GiftVoucherPurchaseScreen({
    super.key,
    this.config = const {},
    this.existing,
  });

  @override
  State<GiftVoucherPurchaseScreen> createState() =>
      _GiftVoucherPurchaseScreenState();
}

class _GiftVoucherPurchaseScreenState extends State<GiftVoucherPurchaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customAmount = TextEditingController();
  final _recipient = TextEditingController();
  final _from = TextEditingController();
  final _message = TextEditingController();

  _Step _step = _Step.form;
  int _presetAmount = 1000;
  bool _forSelf = false;
  String _design = 'forest';
  bool _submitting = false;

  Map<String, dynamic>? _voucher;
  Map<String, dynamic>? _payment;
  bool _paymentLoading = false;
  String? _paymentError;
  XFile? _slip;
  String? _resultMessage;

  int get _min => int.tryParse('${widget.config['min_amount']}') ?? 300;
  int get _max => int.tryParse('${widget.config['max_amount']}') ?? 50000;

  List<int> get _presets {
    final raw = widget.config['presets'];
    final list = raw is List
        ? raw.map((e) => int.tryParse('$e')).whereType<int>().toList()
        : <int>[];
    return list.isEmpty ? const [500, 1000, 2000, 3000, 5000] : list;
  }

  List<String> get _designs {
    final raw = widget.config['designs'];
    final list = raw is List
        ? raw.map((e) => '$e').where(giftVoucherPalettes.containsKey).toList()
        : <String>[];
    return list.isEmpty ? giftVoucherPalettes.keys.toList() : list;
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _voucher = existing;
      _step = _Step.payment;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPayment());
    } else {
      final user = context.read<AppProvider>().user;
      final nickname = '${user?['nickname'] ?? ''}'.trim();
      final name = '${user?['name'] ?? ''}'.trim();
      _from.text = nickname.isNotEmpty ? nickname : name;
    }
  }

  @override
  void dispose() {
    _customAmount.dispose();
    _recipient.dispose();
    _from.dispose();
    _message.dispose();
    super.dispose();
  }

  int get _voucherId => int.parse('${_voucher!['id']}');

  /// มูลค่าที่จะซื้อ — ช่องพิมพ์เองชนะปุ่มสำเร็จรูป (null = พิมพ์ไม่ใช่ตัวเลข)
  int? get _amount {
    final custom = _customAmount.text.trim();
    return custom.isEmpty ? _presetAmount : int.tryParse(custom);
  }

  Future<void> _create() async {
    if (_submitting) return;
    final formValid = _formKey.currentState?.validate() ?? false;
    final amount = _amount;
    // ตรวจยอดซ้ำตรงนี้ด้วย ไม่พึ่ง validator ของช่องอย่างเดียว
    if (!formValid || amount == null || amount < _min || amount > _max) {
      if (amount != null && (amount < _min || amount > _max)) {
        AppSnack.error(
          context,
          'มูลค่าบัตรต้องอยู่ระหว่าง ${voucherBaht(_min)} – ${voucherBaht(_max)}',
        );
      }
      return;
    }

    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);
    try {
      final result = await context.read<AppProvider>().createGiftVoucher(
        amount: amount,
        forSelf: _forSelf,
        recipientName: _recipient.text,
        fromName: _from.text,
        message: _message.text,
        design: _design,
      );
      if (!mounted) return;
      setState(() {
        _voucher = Map<String, dynamic>.from(result['voucher'] as Map);
        _payment = Map<String, dynamic>.from(result['payment'] as Map);
        _step = _Step.payment;
      });
    } on ApiException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'สร้างบัตรไม่สำเร็จ กรุณาลองใหม่');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _loadPayment() async {
    setState(() {
      _paymentLoading = true;
      _paymentError = null;
    });
    try {
      final payment = await context.read<AppProvider>().giftVoucherPayment(
        _voucherId,
      );
      if (!mounted) return;
      setState(() => _payment = payment);
    } on ApiException catch (e) {
      if (mounted) setState(() => _paymentError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _paymentError = 'โหลดข้อมูลการชำระเงินไม่สำเร็จ');
      }
    } finally {
      if (mounted) setState(() => _paymentLoading = false);
    }
  }

  Future<void> _pickSlip(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1800,
      );
      if (image != null && mounted) setState(() => _slip = image);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'เลือกรูปสลิปไม่สำเร็จ');
    }
  }

  Future<void> _chooseSlip() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.surface(context),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('เลือกจากรูปภาพ'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('ถ่ายรูปสลิป'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source != null) await _pickSlip(source);
  }

  Future<void> _submitSlip() async {
    final slip = _slip;
    if (slip == null || _submitting) return;
    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);
    try {
      final result = await context.read<AppProvider>().submitGiftVoucherSlip(
        _voucherId,
        slip.path,
      );
      if (!mounted) return;
      setState(() {
        _voucher = result.voucher;
        _resultMessage = result.message;
        _step = _Step.done;
      });
    } on ApiException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'ส่งสลิปไม่สำเร็จ กรุณาลองใหม่');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _copy(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) AppSnack.show(context, 'คัดลอก$labelแล้ว');
  }

  Future<void> _share() async {
    final v = _voucher;
    if (v == null) return;
    final from = '${v['from_name'] ?? ''}'.trim();
    final text = [
      '🎁 บัตรของขวัญลุยเลเขา มูลค่า ${voucherBaht(v['amount'])}'
          '${from.isNotEmpty ? ' จาก $from' : ''}',
      if ('${v['share_url'] ?? ''}'.isNotEmpty) 'เปิดบัตร: ${v['share_url']}',
      'รหัสบัตร: ${v['display_code']}',
      'ใช้จองทริปไหนก็ได้ในแอปลุยเลเขา',
    ].join('\n');
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: 'บัตรของขวัญลุยเลเขา'),
      );
    } catch (_) {
      await _copy('${v['display_code']}', 'รหัสบัตร');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: Text(switch (_step) {
          _Step.form => 'ซื้อบัตรของขวัญ',
          _Step.payment => 'ชำระเงิน',
          _Step.done => 'บัตรของขวัญ',
        }),
      ),
      body: SafeArea(
        top: false,
        child: switch (_step) {
          _Step.form => _buildForm(context),
          _Step.payment => _buildPayment(context),
          _Step.done => _buildDone(context),
        },
      ),
    );
  }

  // ── ขั้นที่ 1: กรอกรายละเอียด ────────────────────────────────────

  Widget _buildForm(BuildContext context) {
    // SingleChildScrollView ไม่ใช่ ListView — ListView ถอดช่องที่เลื่อนพ้นจอทิ้ง แล้ว
    // Form.validate() จะข้ามช่องมูลค่าด้านบนไปเงียบ ๆ ตอนกดปุ่มด้านล่าง
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GiftVoucherCard(
              amount: _amount ?? 0,
              design: _design,
              recipientName: _forSelf || _recipient.text.trim().isEmpty
                  ? null
                  : _recipient.text.trim(),
              fromName: _from.text.trim().isEmpty ? null : _from.text.trim(),
            ),
            const SizedBox(height: 22),
            _label(context, 'มูลค่าบัตร'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in _presets)
                  ChoiceChip(
                    label: Text(voucherBaht(preset)),
                    selected:
                        _presetAmount == preset &&
                        _customAmount.text.trim().isEmpty,
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _presetAmount = preset;
                        _customAmount.clear();
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _customAmount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'หรือระบุมูลค่าเอง (บาท)',
                hintText: '${voucherBaht(_min)} – ${voucherBaht(_max)}',
              ),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) return null;
                final n = int.tryParse(value!.trim());
                if (n == null) return 'กรุณาใส่ตัวเลข';
                if (n < _min) return 'มูลค่าขั้นต่ำ ${voucherBaht(_min)}';
                if (n > _max) return 'มูลค่าสูงสุด ${voucherBaht(_max)}';
                return null;
              },
            ),
            const SizedBox(height: 22),
            _label(context, 'ซื้อให้ใคร'),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('มอบให้คนอื่น'),
                  icon: Icon(Icons.card_giftcard_rounded),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('ใช้เอง'),
                  icon: Icon(Icons.person_rounded),
                ),
              ],
              selected: {_forSelf},
              showSelectedIcon: false,
              onSelectionChanged: (value) =>
                  setState(() => _forSelf = value.first),
            ),
            const SizedBox(height: 14),
            if (!_forSelf) ...[
              TextFormField(
                controller: _recipient,
                maxLength: 100,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'ชื่อผู้รับ (แสดงบนบัตร)',
                  counterText: '',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _from,
              maxLength: 100,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'จาก (ชื่อผู้ให้)',
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _message,
              maxLength: 300,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'ข้อความถึงผู้รับ (ไม่บังคับ)',
                hintText: 'เช่น สุขสันต์วันเกิดนะ ไปเที่ยวให้สนุก',
              ),
            ),
            const SizedBox(height: 14),
            _label(context, 'ลายบัตร'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final design in _designs)
                  _DesignSwatch(
                    design: design,
                    selected: _design == design,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _design = design);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              'บัตรใช้ได้ ${widget.config['validity_days'] ?? 365} วันนับจากวันที่ชำระเงิน '
              'ใช้จองทริปได้ทุกทริป ใช้ไม่หมดเก็บยอดที่เหลือไว้ใช้ครั้งหน้าได้ '
              'บัตรไม่สามารถแลกคืนเป็นเงินสด',
              style: appFont(
                fontSize: AppText.sizeCaption,
                height: 1.6,
                color: AppTheme.mutedText(context),
              ),
            ),
            const SizedBox(height: 16),
            PrimaryCTAButton(
              label: _amount == null
                  ? 'ไปชำระเงิน'
                  : 'ไปชำระเงิน ${voucherBaht(_amount)}',
              icon: Icons.arrow_forward_rounded,
              loading: _submitting,
              onPressed: _amount == null ? null : _create,
            ),
          ],
        ),
      ),
    );
  }

  // ── ขั้นที่ 2: โอนเงิน + แนบสลิป ────────────────────────────────

  Widget _buildPayment(BuildContext context) {
    final payment = _payment;
    if (_paymentLoading && payment == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (payment == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _paymentError ?? 'โหลดข้อมูลการชำระเงินไม่สำเร็จ',
                textAlign: TextAlign.center,
                style: appFont(
                  fontSize: AppText.sizeBody,
                  color: AppTheme.mutedText(context),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loadPayment,
                child: const Text('ลองอีกครั้ง'),
              ),
            ],
          ),
        ),
      );
    }

    final payload = '${payment['qr_payload'] ?? ''}';
    final promptPayId = '${payment['promptpay_id'] ?? ''}';
    final bankAccount = '${payment['bank_account'] ?? ''}';
    final rejectedNote = _voucher?['status'] == 'rejected'
        ? '${_voucher?['review_note'] ?? ''}'.trim()
        : '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        if (rejectedNote.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.dangerTint(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Text(
              'สลิปครั้งก่อนยังไม่ผ่าน: $rejectedNote',
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w700,
                color: AppTheme.errorColor,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        Container(
          padding: const EdgeInsets.all(18),
          decoration: AppTheme.cardDecoration(
            context,
            radius: AppTheme.radiusMd,
          ),
          child: Column(
            children: [
              Text(
                'ยอดที่ต้องโอน',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  color: AppTheme.mutedText(context),
                ),
              ),
              Text(
                voucherBaht(payment['amount']),
                style: appFont(
                  fontSize: AppText.sizeHero,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface(context),
                ),
              ),
              const SizedBox(height: 14),
              if (payload.isNotEmpty)
                // QR ต้องพื้นขาวเสมอ แม้อยู่ในโหมดมืด ไม่งั้นแอปธนาคารสแกนไม่ติด
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: QrImageView(
                    data: payload,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                'สแกนด้วยแอปธนาคาร (พร้อมเพย์) — ยอดถูกใส่ไว้ให้แล้ว',
                textAlign: TextAlign.center,
                style: appFont(
                  fontSize: AppText.sizeCaption,
                  color: AppTheme.mutedText(context),
                ),
              ),
              const Divider(height: 28),
              if (promptPayId.isNotEmpty)
                _copyRow(context, 'พร้อมเพย์', promptPayId),
              if (bankAccount.isNotEmpty)
                _copyRow(
                  context,
                  '${payment['bank_name'] ?? 'บัญชีธนาคาร'}',
                  bankAccount,
                  sub: '${payment['bank_holder'] ?? ''}',
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _label(context, 'แนบสลิปการโอน'),
        const SizedBox(height: 8),
        InkWell(
          onTap: _chooseSlip,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Container(
            height: _slip == null ? 96 : 220,
            decoration: BoxDecoration(
              color: AppTheme.subtleSurface(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.border(context)),
            ),
            clipBehavior: Clip.antiAlias,
            child: _slip == null
                ? Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_rounded,
                          color: AppTheme.mutedText(context),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'แตะเพื่อเลือกรูปสลิป',
                          style: appFont(
                            fontSize: AppText.sizeBody,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.mutedText(context),
                          ),
                        ),
                      ],
                    ),
                  )
                : Image.file(File(_slip!.path), fit: BoxFit.contain),
          ),
        ),
        if (_slip != null)
          TextButton(
            onPressed: _chooseSlip,
            child: const Text('เปลี่ยนรูปสลิป'),
          ),
        const SizedBox(height: 16),
        PrimaryCTAButton(
          label: 'ส่งสลิป',
          icon: Icons.send_rounded,
          loading: _submitting,
          onPressed: _slip == null ? null : _submitSlip,
        ),
        const SizedBox(height: 10),
        Text(
          'ระบบตรวจยอดจากสลิปอัตโนมัติ ถ้าตรงบัตรพร้อมใช้ทันที '
          'ถ้าอ่านไม่ได้ทีมงานจะตรวจให้และแจ้งเตือนเมื่อเสร็จ',
          textAlign: TextAlign.center,
          style: appFont(
            fontSize: AppText.sizeCaption,
            height: 1.6,
            color: AppTheme.mutedText(context),
          ),
        ),
      ],
    );
  }

  // ── ขั้นที่ 3: ผล ───────────────────────────────────────────────

  Widget _buildDone(BuildContext context) {
    final v = _voucher ?? const <String, dynamic>{};
    final active = v['status'] == 'active';
    final forSelf = v['for_self'] == true;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        GiftVoucherCard.fromJson(v),
        const SizedBox(height: 20),
        Icon(
          active ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
          size: 48,
          color: active ? AppTheme.primaryColor : AppTheme.warningColor,
        ),
        const SizedBox(height: 10),
        Text(
          active
              ? (forSelf ? 'บัตรอยู่ในบัญชีของคุณแล้ว' : 'บัตรพร้อมส่งต่อแล้ว')
              : 'ได้รับสลิปแล้ว',
          textAlign: TextAlign.center,
          style: appFont(
            fontSize: AppText.sizeH2,
            fontWeight: FontWeight.w800,
            color: AppTheme.onSurface(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          active
              ? (forSelf
                    ? 'ใช้ตอนจองทริปได้เลย ในขั้นตอนสรุปการจองแตะ "ใช้บัตรของขวัญ"'
                    : 'ส่งลิงก์หรือรหัสให้คนพิเศษได้เลย รหัสใช้แทนเงินสด ส่งให้เฉพาะคนที่ตั้งใจมอบให้นะครับ')
              : (_resultMessage?.isNotEmpty == true
                    ? _resultMessage!
                    : 'ทีมงานกำลังตรวจสอบยอดโอน เราจะแจ้งเตือนทันทีที่บัตรพร้อมใช้'),
          textAlign: TextAlign.center,
          style: appFont(
            fontSize: AppText.sizeBody,
            height: 1.6,
            color: AppTheme.mutedText(context),
          ),
        ),
        const SizedBox(height: 22),
        if (active && !forSelf) ...[
          PrimaryCTAButton(
            label: 'ส่งบัตรให้ผู้รับ',
            icon: Icons.ios_share_rounded,
            onPressed: _share,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _copy('${v['display_code']}', 'รหัสบัตร'),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: Text('คัดลอกรหัส ${v['display_code'] ?? ''}'),
          ),
          const SizedBox(height: 8),
        ],
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('เสร็จสิ้น'),
        ),
      ],
    );
  }

  Widget _label(BuildContext context, String text) => Text(
    text,
    style: appFont(
      fontSize: AppText.sizeBody,
      fontWeight: FontWeight.w800,
      color: AppTheme.onSurface(context),
    ),
  );

  Widget _copyRow(
    BuildContext context,
    String label,
    String value, {
    String sub = '',
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    color: AppTheme.mutedText(context),
                  ),
                ),
                Text(
                  value,
                  style: appFont(
                    fontSize: AppText.sizeSubtitle,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                ),
                if (sub.trim().isNotEmpty)
                  Text(
                    sub,
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'คัดลอก',
            onPressed: () => _copy(value.replaceAll('-', ''), label),
            icon: const Icon(Icons.copy_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _DesignSwatch extends StatelessWidget {
  final String design;
  final bool selected;
  final VoidCallback onTap;

  const _DesignSwatch({
    required this.design,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = giftVoucherPalette(design);
    return Semantics(
      button: true,
      selected: selected,
      label: 'ลาย${giftVoucherDesignLabels[design] ?? design}',
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 56,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                gradient: LinearGradient(colors: colors),
                border: Border.all(
                  color: selected
                      ? AppTheme.onSurface(context)
                      : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              giftVoucherDesignLabels[design] ?? design,
              style: appFont(
                fontSize: AppText.sizeMicro,
                color: AppTheme.mutedText(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
