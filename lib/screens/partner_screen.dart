import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/thai_date.dart';
import '../widgets/app_snack.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/skeleton.dart';
import '../widgets/travel_widgets.dart';

/// "พาร์ทเนอร์ช่วยขาย" — โค้ด/ลิงก์ของพาร์ทเนอร์ ยอดคอม บัญชีรับเงิน และคอมรายใบจอง
///
/// ตัวเลขทุกตัวมาจาก GET /partner (App\Services\PartnerService) แอปแค่วาด
/// พาร์ทเนอร์ไม่เห็นข้อมูลลูกค้า — แถวคอมมีแค่ทริป วันเดินทาง และจำนวนที่นั่ง
class PartnerScreen extends StatefulWidget {
  const PartnerScreen({super.key});

  @override
  State<PartnerScreen> createState() => _PartnerScreenState();
}

class _PartnerScreenState extends State<PartnerScreen> {
  static const _filters = <(String?, String)>[
    (null, 'ทั้งหมด'),
    ('pending', 'รอเดินทาง'),
    ('approved', 'รอโอน'),
    ('paid', 'โอนแล้ว'),
    ('void', 'ไม่ได้คอม'),
  ];

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _partner;
  bool _isPartner = false;

  String? _filter;
  final List<Map<String, dynamic>> _rows = [];
  int _page = 1;
  bool _hasMore = false;
  bool _rowsLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  ApiClient get _api => context.read<AppProvider>().api;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.get('partner');
      final data = _api.data(res);
      if (!mounted) return;
      setState(() {
        _isPartner = data is Map;
        _partner = data is Map ? Map<String, dynamic>.from(data) : null;
        _loading = false;
      });
      if (_isPartner) await _loadRows(1);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'โหลดข้อมูลไม่สำเร็จ ลองอีกครั้ง';
      });
    }
  }

  Future<void> _loadRows(int page) async {
    setState(() => _rowsLoading = true);
    try {
      final res = await _api.get(
        'partner/commissions',
        query: {'page': page, if (_filter != null) 'status': _filter},
      );
      final list = (_api.data(res) as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final meta = _api.meta(res) ?? const {};
      if (!mounted) return;
      setState(() {
        if (page == 1) _rows.clear();
        _rows.addAll(list);
        _page = int.tryParse('${meta['current_page'] ?? page}') ?? page;
        _hasMore = _page < (int.tryParse('${meta['last_page'] ?? 1}') ?? 1);
      });
    } catch (_) {
      if (mounted) AppSnack.error(context, 'โหลดรายการไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _rowsLoading = false);
    }
  }

  void _setFilter(String? value) {
    if (_filter == value) return;
    HapticFeedback.selectionClick();
    setState(() => _filter = value);
    _loadRows(1);
  }

  Future<void> _copy(String text, String done) async {
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    if (mounted) AppSnack.success(context, done);
  }

  Future<void> _share() async {
    final url = textOf(_partner?['share_url']);
    if (url.isEmpty) return;
    HapticFeedback.selectionClick();
    try {
      await SharePlus.instance.share(
        ShareParams(text: url, subject: 'ทริปเที่ยวกับลุยเลเขา'),
      );
    } catch (_) {
      await _copy(url, 'คัดลอกลิงก์แล้ว');
    }
  }

  Future<void> _editAccount() async {
    final saved = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      builder: (_) => const _PayoutAccountSheet(),
    );
    if (saved != null && mounted) {
      setState(() => _partner?['payout_account'] = saved);
      AppSnack.success(context, 'บันทึกบัญชีรับเงินแล้ว');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.background(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.onSurface(context)),
        title: Text(
          'พาร์ทเนอร์ช่วยขาย',
          style: appFont(
            color: AppTheme.onSurface(context),
            fontSize: AppText.sizeTitle,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _loading
          ? const SkeletonList(padding: EdgeInsets.all(20))
          : RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: _load,
              child: _error != null
                  ? ScrollableEmptyState(
                      icon: Icons.wifi_off_rounded,
                      title: _error!,
                      actionLabel: 'ลองอีกครั้ง',
                      onAction: _load,
                    )
                  : !_isPartner
                  ? const ScrollableEmptyState(
                      icon: Icons.handshake_outlined,
                      title: 'บัญชีนี้ยังไม่ได้เป็นพาร์ทเนอร์',
                      body: 'อยากช่วยขายทริปและรับค่าคอม ทักทีมงานได้เลยครับ',
                    )
                  : _buildContent(context),
            ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final p = _partner!;
    final summary = asMap(p['summary']);
    final account = p['payout_account'] is Map
        ? asMap(p['payout_account'])
        : null;
    final rules = (p['rules'] as List? ?? const []).map((e) => '$e').toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      children: [
        if (textOf(p['status']) != 'active') ...[
          const _Notice(
            text:
                'บัญชีพาร์ทเนอร์หยุดชั่วคราว — ใบจองใหม่จะไม่นับคอม ใบเดิมได้คอมตามปกติ',
          ),
          const SizedBox(height: 12),
        ],
        _CodeCard(
          code: textOf(p['code']),
          rateLabel: textOf(p['rate_label']),
          hasLiff: textOf(p['liff_url']).isNotEmpty,
          onCopyCode: () => _copy(textOf(p['code']), 'คัดลอกโค้ดแล้ว'),
          onShare: _share,
          onCopyLiff: () =>
              _copy(textOf(p['liff_url']), 'คัดลอกลิงก์ LINE แล้ว'),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _SummaryTile(
              label: 'รอเดินทาง',
              value: _money(summary['pending']),
              color: AppTheme.warningColor,
            ),
            const SizedBox(width: 10),
            _SummaryTile(
              label: 'รอโอน',
              value: _money(summary['approved']),
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 10),
            _SummaryTile(
              label: 'โอนแล้ว',
              value: _money(summary['paid']),
              color: AppTheme.onSurface(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'ขายได้ ${summary['bookings'] ?? 0} ใบจอง · ${summary['seats'] ?? 0} ที่นั่ง',
            style: appFont(
              fontSize: AppText.sizeCaption,
              color: AppTheme.mutedText(context),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _AccountCard(account: account, onEdit: _editAccount),
        const SizedBox(height: 24),
        const _SectionLabel('ค่าคอมรายใบจอง'),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (value, label) in _filters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: _filter == value,
                    onSelected: (_) => _setFilter(value),
                    showCheckmark: false,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (_rows.isEmpty && !_rowsLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'ยังไม่มีรายการ',
                style: appFont(
                  fontSize: AppText.sizeBody,
                  color: AppTheme.mutedText(context),
                ),
              ),
            ),
          ),
        for (final row in _rows) _CommissionRow(row: row),
        if (_hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
              onPressed: _rowsLoading ? null : () => _loadRows(_page + 1),
              child: Text(_rowsLoading ? 'กำลังโหลด...' : 'ดูเพิ่ม'),
            ),
          ),
        if (rules.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SectionLabel('กติกาค่าคอม'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardDecoration(
              context,
              radius: AppTheme.radiusMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final rule in rules)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '•  ',
                          style: appFont(
                            fontSize: AppText.sizeLabel,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            rule,
                            style: appFont(
                              fontSize: AppText.sizeLabel,
                              height: 1.5,
                              color: AppTheme.mutedText(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

String _money(dynamic value) {
  final n = double.tryParse('${value ?? 0}') ?? 0;
  final whole = n == n.roundToDouble();
  final fixed = n.abs().toStringAsFixed(whole ? 0 : 2);
  final parts = fixed.split('.');
  final withCommas = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final body = parts.length > 1 ? '$withCommas.${parts[1]}' : withCommas;
  return '${n < 0 ? '-' : ''}฿$body';
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: appFont(
        fontSize: AppText.sizeLabel,
        fontWeight: FontWeight.w700,
        color: AppTheme.mutedText(context),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;

  const _Notice({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Text(
        text,
        style: appFont(
          fontSize: AppText.sizeLabel,
          fontWeight: FontWeight.w600,
          color: AppTheme.warningColor,
        ),
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  final String code;
  final String rateLabel;
  final bool hasLiff;
  final VoidCallback onCopyCode;
  final VoidCallback onShare;
  final VoidCallback onCopyLiff;

  const _CodeCard({
    required this.code,
    required this.rateLabel,
    required this.hasLiff,
    required this.onCopyCode,
    required this.onShare,
    required this.onCopyLiff,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusLg),
      child: Column(
        children: [
          Text(
            'โค้ดพาร์ทเนอร์ของคุณ · คอม $rateLabel',
            style: appFont(
              color: AppTheme.mutedText(context),
              fontSize: AppText.sizeLabel,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: onCopyCode,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      code.isEmpty ? '—' : code,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceMono(
                        color: AppTheme.primaryColor,
                        fontSize: AppText.sizeH1,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: AppTheme.primaryColor.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          PrimaryCTAButton(
            label: 'แชร์ลิงก์',
            icon: Icons.ios_share_rounded,
            onPressed: onShare,
          ),
          if (hasLiff) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCopyLiff,
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: const Text('คัดลอกลิงก์เปิดใน LINE'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusMd),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: appFont(
                  fontSize: AppText.sizeSubtitle,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: appFont(
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w600,
                color: AppTheme.mutedText(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final Map<String, dynamic>? account;
  final VoidCallback onEdit;

  const _AccountCard({required this.account, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final has = account != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusMd),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'บัญชีรับค่าคอม',
                  style: appFont(
                    fontSize: AppText.sizeBody,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  has
                      ? '${textOf(account!['bank'])} ${textOf(account!['number_masked'])} · ${textOf(account!['name'])}'
                      : 'ยังไม่ได้ใส่ — ใส่ไว้เพื่อให้ทีมงานโอนได้',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: has ? FontWeight.w500 : FontWeight.w700,
                    color: has
                        ? AppTheme.mutedText(context)
                        : AppTheme.errorColor,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onEdit,
            child: Text(has ? 'แก้ไข' : 'ใส่บัญชี'),
          ),
        ],
      ),
    );
  }
}

class _CommissionRow extends StatelessWidget {
  final Map<String, dynamic> row;

  const _CommissionRow({required this.row});

  static String statusLabel(Map<String, dynamic> row) {
    if (textOf(row['type']) == 'clawback') return 'หักคืน';
    return switch (textOf(row['status'])) {
      'pending' => 'รอเดินทาง',
      'approved' => 'รอโอน',
      'paid' => 'โอนแล้ว',
      'void' => 'ไม่ได้คอม',
      final other => other,
    };
  }

  @override
  Widget build(BuildContext context) {
    final status = textOf(row['status']);
    final color = switch (status) {
      'pending' => AppTheme.warningColor,
      'approved' => AppTheme.primaryColor,
      'paid' => AppTheme.onSurface(context),
      _ => AppTheme.mutedText(context),
    };
    final amount = double.tryParse('${row['amount'] ?? 0}') ?? 0;
    final date = DateTime.tryParse(textOf(row['departure_date']));
    final details = [
      if (date != null) thaiDateShort(date),
      '${row['seats'] ?? 0} ที่นั่ง',
      textOf(row['booking_ref']),
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.border(context).withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  textOf(row['trip_title'], 'ทริป'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: AppText.sizeBody,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  details,
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    color: AppTheme.mutedText(context),
                  ),
                ),
                if (textOf(row['void_reason']).isNotEmpty)
                  Text(
                    textOf(row['void_reason']),
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _money(amount),
                style: appFont(
                  fontSize: AppText.sizeBody,
                  fontWeight: FontWeight.w800,
                  color: amount < 0
                      ? AppTheme.errorColor
                      : AppTheme.onSurface(context),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Text(
                  statusLabel(row),
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PayoutAccountSheet extends StatefulWidget {
  const _PayoutAccountSheet();

  @override
  State<_PayoutAccountSheet> createState() => _PayoutAccountSheetState();
}

class _PayoutAccountSheetState extends State<_PayoutAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _bank = TextEditingController();
  final _number = TextEditingController();
  final _name = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _bank.dispose();
    _number.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    final api = context.read<AppProvider>().api;
    try {
      final res = await api.put(
        'partner/payout-account',
        body: {
          'bank': _bank.text.trim(),
          'number': _number.text.trim(),
          'name': _name.text.trim(),
        },
      );
      final account = asMap(asMap(api.data(res))['payout_account']);
      if (mounted) Navigator.of(context).pop(account);
    } on ApiException catch (e) {
      if (mounted) {
        AppSnack.error(
          context,
          e.message.isNotEmpty ? e.message : 'บันทึกไม่สำเร็จ',
        );
      }
    } catch (_) {
      if (mounted) AppSnack.error(context, 'บันทึกไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String? required(String? v) =>
        (v ?? '').trim().isEmpty ? 'กรุณากรอกช่องนี้' : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'บัญชีรับค่าคอม',
              style: appFont(
                fontSize: AppText.sizeTitle,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface(context),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bank,
              maxLength: 60,
              validator: required,
              decoration: const InputDecoration(
                labelText: 'ธนาคาร',
                hintText: 'เช่น กสิกรไทย',
                counterText: '',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _number,
              maxLength: 30,
              keyboardType: TextInputType.number,
              validator: required,
              decoration: const InputDecoration(
                labelText: 'เลขบัญชี หรือพร้อมเพย์',
                counterText: '',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _name,
              maxLength: 100,
              validator: required,
              decoration: const InputDecoration(
                labelText: 'ชื่อบัญชี',
                counterText: '',
              ),
            ),
            const SizedBox(height: 20),
            PrimaryCTAButton(
              label: 'บันทึก',
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
