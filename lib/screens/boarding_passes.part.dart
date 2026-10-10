part of 'customer_app_screen.dart';

/// บัตรขึ้นรถรายคน — วาดจาก `check_in_passes` ที่เซิร์ฟเวอร์ส่งมากับใบจอง
///
/// ใบจองหนึ่งใบมีหลายคน และคนในใบเดียวกันไม่ได้มาพร้อมกันเสมอ (เพื่อนไม่มา คนจอง
/// ไม่มาแต่เพื่อนมา ขึ้นคนละจุด) จึงมีบัตรของแต่ละคน:
///   - คนจอง: ทั้งกลุ่ม (สตาฟสแกนแล้วติ๊กคนที่มาถึง) + บัตรของทุกคน + ส่งลิงก์ให้เพื่อน
///   - เพื่อนที่ผูกชื่อแล้ว: บัตรของตัวเองใบเดียว
///   - เพื่อนที่ยังไม่ได้เลือกชื่อ: QR ทั้งกลุ่มแบบเดิม + ให้เลือกว่าตัวเองคือใคร
///
/// ข้อมูลมาพร้อมใบจองที่แคชไว้ จึงเปิดได้ตอนไม่มีสัญญาณ (หน้ารถตอนตีห้า)
class _BoardingPasses extends StatefulWidget {
  final Map<String, dynamic> booking;

  /// ขนาด QR สูงสุด — แผ่น QR กลางแถบเมนูใหญ่กว่าการ์ดในใบจอง
  final double maxQrSize;

  /// หลังเพื่อนเลือกชื่อตัวเองสำเร็จ — ให้หน้าที่ถือข้อมูลใบจองดึงใหม่
  final VoidCallback? onChanged;

  const _BoardingPasses({
    required this.booking,
    this.maxQrSize = 240,
    this.onChanged,
  });

  /// ใบจองนี้มีบัตรรายคนจากเซิร์ฟเวอร์หรือยัง (ข้อมูลที่แคชจากแอปรุ่นก่อนไม่มี)
  static bool available(Map<String, dynamic> booking) {
    final passes = asMap(booking['check_in_passes']);
    return passes.isNotEmpty &&
        (asList(passes['passes']).isNotEmpty || passes['group'] is Map);
  }

  @override
  State<_BoardingPasses> createState() => _BoardingPassesState();
}

class _BoardingPassesState extends State<_BoardingPasses> {
  /// ตัวเลือกที่กำลังดู: 'group' หรือ id ผู้เดินทาง
  String? _selected;
  bool _sharing = false;

  Map<String, dynamic> get _data => asMap(widget.booking['check_in_passes']);

  List<Map<String, dynamic>> get _passes =>
      asList(_data['passes']).map(asMap).toList();

  Map<String, dynamic> get _group => asMap(_data['group']);

  String get _ref => textOf(widget.booking['booking_ref']);

  /// ค่าเริ่มต้น: เพื่อนที่ผูกชื่อ = บัตรของตัวเอง, อย่างอื่น = ทั้งกลุ่ม
  String _defaultSelection() {
    final mine = textOf(_data['mine_passenger_id']);
    if (mine.isNotEmpty) return mine;
    if (_group.isNotEmpty) return 'group';
    return _passes.isEmpty ? 'group' : textOf(_passes.first['passenger_id']);
  }

  Future<void> _sharePass(Map<String, dynamic> pass) async {
    if (_sharing) return;
    final id = int.tryParse(textOf(pass['passenger_id']));
    if (id == null) return;
    setState(() => _sharing = true);
    HapticFeedback.selectionClick();
    try {
      final result = await context.read<AppProvider>().passengerPassLink(
        _ref,
        id,
      );
      final url = textOf(result['url']);
      if (url.isEmpty) throw Exception('no url');
      await SharePlus.instance.share(
        ShareParams(text: textOf(result['share_text'], url)),
      );
    } on ApiException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) {
        AppSnack.error(context, 'สร้างลิงก์ไม่สำเร็จ ลองใหม่อีกครั้ง');
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _pickSelf() async {
    final pickable = asList(_data['pickable_passengers']).map(asMap).toList();
    if (pickable.isEmpty) return;

    final chosen = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'คุณคือใครในรายชื่อนี้?',
                style: appFont(
                  fontSize: AppText.sizeTitle,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface(ctx),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'เลือกแล้วจะได้บัตรขึ้นรถของตัวเอง เช็คอินได้แม้คนจองยังไม่มา '
                'เลือกได้ครั้งเดียว',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  color: AppTheme.mutedText(ctx),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              for (final person in pickable)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryColor.withValues(
                      alpha: 0.10,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  title: Text(
                    textOf(person['name'], '-'),
                    style: appFont(fontWeight: FontWeight.w800),
                  ),
                  subtitle: textOf(person['full_name']).isEmpty ||
                          textOf(person['full_name']) == textOf(person['name'])
                      ? null
                      : Text(textOf(person['full_name'])),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pop(ctx, person),
                ),
            ],
          ),
        ),
      ),
    );

    if (chosen == null || !mounted) return;
    final id = int.tryParse(textOf(chosen['passenger_id']));
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'คุณคือ ${textOf(chosen['name'])}?',
          style: appFont(
            fontSize: AppText.sizeSubtitle,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'บัตรขึ้นรถและการแจ้งเตือนวันเดินทางจะผูกกับชื่อนี้ — ถ้าเลือกผิด '
          'ต้องให้คนจองนำคุณออกแล้วเชิญใหม่',
          style: appFont(fontSize: AppText.sizeBody, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ใช่ ฉันเอง'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<AppProvider>().claimBookingPassenger(_ref, id);
      if (!mounted) return;
      setState(() => _selected = '$id');
      widget.onChanged?.call();
      AppSnack.success(context, 'บัตรขึ้นรถของคุณพร้อมแล้ว');
    } on ApiException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'บันทึกไม่สำเร็จ ลองใหม่อีกครั้ง');
    }
  }

  @override
  Widget build(BuildContext context) {
    final passes = _passes;
    final group = _group;
    final isOwner = textOf(_data['viewer_role']) == 'owner';
    final options = <String>[
      if (group.isNotEmpty) 'group',
      for (final pass in passes) textOf(pass['passenger_id']),
    ];
    var selected = _selected ?? _defaultSelection();
    if (!options.contains(selected) && options.isNotEmpty) {
      selected = options.first;
    }

    final pickable = asList(_data['pickable_passengers']);
    // นับจากรายชื่อผู้เดินทางของใบจอง (ทุกคนในใบเห็นเหมือนกัน) — เพื่อนที่ยังไม่ได้
    // ผูกชื่อไม่มีบัตรรายคนให้นับ แต่ยังต้องรู้ว่าทั้งกลุ่มขึ้นรถครบหรือยัง
    final travellers = asList(widget.booking['passengers']).map(asMap).toList();
    final total = travellers.isNotEmpty
        ? travellers.length
        : (int.tryParse(textOf(group['passenger_count'])) ?? passes.length);
    final aboard = travellers.isNotEmpty
        ? travellers.where((p) => textOf(p['checked_in_at']).isNotEmpty).length
        : passes.where((p) => p['checked_in'] == true).length;
    final allAboard = total > 0
        ? aboard >= total
        : widget.booking['checked_in'] == true;

    Map<String, dynamic>? pass;
    for (final p in passes) {
      if (textOf(p['passenger_id']) == selected) pass = p;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (options.length > 1) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final option in options)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _PassChip(
                      label: option == 'group'
                          ? 'ทั้งกลุ่ม · ${group['passenger_count'] ?? total} คน'
                          : textOf(
                              passes.firstWhere(
                                (p) => textOf(p['passenger_id']) == option,
                              )['name'],
                              '-',
                            ),
                      done: option != 'group' &&
                          passes.firstWhere(
                                (p) => textOf(p['passenger_id']) == option,
                              )['checked_in'] ==
                              true,
                      selected: option == selected,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selected = option);
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: KeyedSubtree(
            key: ValueKey('pass-$selected'),
            child: selected == 'group' || pass == null
                ? _GroupPass(
                    code: textOf(group['code']),
                    bookingRef: _ref,
                    aboard: aboard,
                    total: total,
                    allAboard: allAboard,
                    checkedInAt: widget.booking['checked_in_at'],
                    maxQrSize: widget.maxQrSize,
                  )
                : _PersonPass(
                    pass: pass,
                    maxQrSize: widget.maxQrSize,
                    sharing: _sharing,
                    onShare: isOwner ? () => _sharePass(pass!) : null,
                  ),
          ),
        ),
        // เพื่อนที่ยังไม่ได้บอกว่าตัวเองคือใคร — เลือกชื่อแล้วได้บัตรของตัวเอง
        if (!isOwner && pickable.isNotEmpty) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickSelf,
            icon: const Icon(Icons.badge_outlined, size: 18),
            label: const Text('เลือกชื่อของฉัน เพื่อรับบัตรขึ้นรถของตัวเอง'),
          ),
        ],
      ],
    );
  }
}

class _PassChip extends StatelessWidget {
  final String label;
  final bool done;
  final bool selected;
  final VoidCallback onTap;

  const _PassChip({
    required this.label,
    required this.done,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppTheme.onSurface(context);
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40, maxWidth: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryColor
                : AppTheme.subtleSurface(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
              color: selected
                  ? AppTheme.primaryColor
                  : AppTheme.border(context),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (done) ...[
                Icon(
                  Icons.check_circle_rounded,
                  size: 15,
                  color: selected ? Colors.white : AppTheme.primaryColor,
                ),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// QR ของทั้งกลุ่ม — สตาฟสแกนแล้วติ๊กเฉพาะคนที่มาถึง
class _GroupPass extends StatelessWidget {
  final String code;
  final String bookingRef;
  final int aboard;
  final int total;
  final bool allAboard;
  final dynamic checkedInAt;
  final double maxQrSize;

  const _GroupPass({
    required this.code,
    required this.bookingRef,
    required this.aboard,
    required this.total,
    required this.allAboard,
    required this.checkedInAt,
    required this.maxQrSize,
  });

  @override
  Widget build(BuildContext context) {
    if (allAboard) {
      return _CheckedInCard(bookingRef: bookingRef, checkedInAt: checkedInAt);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = (constraints.maxWidth - 30).clamp(120.0, maxQrSize);
        return Column(
          children: [
            if (code.isNotEmpty)
              Semantics(
                label: 'QR เช็คอินทั้งกลุ่ม ใบจอง $bookingRef',
                image: true,
                child: _CheckInQrBox(code: code, size: size, padding: 14),
              ),
            const SizedBox(height: 10),
            Text(
              aboard > 0
                  ? 'ขึ้นรถแล้ว $aboard/$total คน — สแกนอีกครั้งสำหรับคนที่เหลือ'
                  : 'QR ของทั้งกลุ่ม · ทีมงานจะติ๊กเฉพาะคนที่มาถึง',
              textAlign: TextAlign.center,
              style: appFont(
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w600,
                color: AppTheme.mutedText(context),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            _BookingReferencePanel(bookingRef: bookingRef),
          ],
        );
      },
    );
  }
}

/// บัตรขึ้นรถของคนเดียว
class _PersonPass extends StatelessWidget {
  final Map<String, dynamic> pass;
  final double maxQrSize;
  final bool sharing;

  /// คนจองส่งลิงก์ของเพื่อนคนนี้ (บัตร + กรอกข้อมูล + เข้าแอป) — null สำหรับเพื่อน
  final VoidCallback? onShare;

  const _PersonPass({
    required this.pass,
    required this.maxQrSize,
    required this.sharing,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final name = textOf(pass['name'], '-');
    final code = textOf(pass['code']);
    final checkedIn = pass['checked_in'] == true;
    final notGoing = pass['not_going'] == true;
    final at = DateTime.tryParse(textOf(pass['checked_in_at']))?.toLocal();

    final share = onShare == null
        ? null
        : TextButton.icon(
            onPressed: sharing ? null : onShare,
            icon: sharing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded, size: 18),
            label: Text('ส่งบัตรให้$name'),
          );

    if (checkedIn) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.20),
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.primaryColor,
                  size: 40,
                ),
                const SizedBox(height: 10),
                Text(
                  '$name ขึ้นรถแล้ว',
                  textAlign: TextAlign.center,
                  style: appFont(
                    fontSize: AppText.sizeTitle,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                ),
                if (at != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'เช็คอินเมื่อ ${thaiDateTimeShort(at)}',
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = (constraints.maxWidth - 30).clamp(120.0, maxQrSize);
        return Column(
          children: [
            Text(
              'บัตรขึ้นรถของ $name',
              textAlign: TextAlign.center,
              style: appFont(
                fontSize: AppText.sizeSubtitle,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface(context),
              ),
            ),
            if (notGoing) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Text(
                  'แจ้งไว้ว่าไม่ไป — ถ้ามาจริง ทีมงานสแกนได้ตามปกติ',
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.warningColor,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (code.isNotEmpty)
              Semantics(
                label: 'QR บัตรขึ้นรถของ $name',
                image: true,
                child: _CheckInQrBox(code: code, size: size, padding: 14),
              ),
            const SizedBox(height: 8),
            Text(
              'สแกนแล้วเช็คอินเฉพาะ$name',
              style: appFont(
                fontSize: AppText.sizeCaption,
                color: AppTheme.mutedText(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            ?share,
          ],
        );
      },
    );
  }
}
