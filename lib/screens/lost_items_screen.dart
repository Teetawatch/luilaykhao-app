import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snack.dart';
import '../widgets/chat_lost_item.dart';
import '../widgets/chat_rest_stop.dart'
    show RestStopSheetFrame, RestStopSheetLabel, restStopFieldDecoration;
import '../widgets/empty_state_view.dart';
import '../widgets/skeleton.dart';
import '../widgets/travel_widgets.dart';

/// ของที่ลืมไว้ในทริป
///
/// - [scheduleId] = รอบเดียว (เปิดจากห้องแชท/แจ้งเตือน) ทีมงานโพสต์ของที่เจอได้
/// - ไม่ส่ง = ของในทุกทริปที่ฉันไปย้อนหลัง 90 วัน (เปิดจากโปรไฟล์)
///
/// อยู่ได้หลังห้องแชทถูกลบ เพราะของหายมักเพิ่งเจอตอนทริปจบไปแล้ว
class LostItemsScreen extends StatefulWidget {
  final int? scheduleId;

  /// เปิดมาแล้วเปิดชีตโพสต์ของที่เจอเลย (ทีมงานกดมาจากเมนูในแชท)
  final bool startPosting;

  const LostItemsScreen({
    super.key,
    this.scheduleId,
    this.startPosting = false,
  });

  @override
  State<LostItemsScreen> createState() => _LostItemsScreenState();
}

int _int(dynamic v) => int.tryParse('$v') ?? 0;

class _LostItemsScreenState extends State<LostItemsScreen> {
  List<Map<String, dynamic>>? _items;
  bool _canManage = false;
  String? _error;
  bool _busy = false;
  int? _myUserId;

  AppProvider get _app => context.read<AppProvider>();

  @override
  void initState() {
    super.initState();
    _myUserId = int.tryParse('${context.read<AppProvider>().user?['id']}');
    _load().then((_) {
      if (mounted && widget.startPosting && _canManage) _post();
    });
  }

  Future<void> _load() async {
    try {
      final data = await _app.loadLostItems(scheduleId: widget.scheduleId);
      if (!mounted) return;
      setState(() {
        _items = (data['items'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _canManage = data['can_manage'] == true;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is ApiException ? e.message : e.toString());
    }
  }

  void _replace(Map<String, dynamic> item) {
    final id = _int(item['id']);
    setState(() {
      _items = [
        for (final i in _items ?? const <Map<String, dynamic>>[])
          _int(i['id']) == id ? item : i,
      ];
    });
  }

  Future<void> _run(Future<void> Function() call, {String? done}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await call();
      if (mounted && done != null) AppSnack.show(context, done);
    } catch (e) {
      if (mounted) {
        AppSnack.show(context, e is ApiException ? e.message : e.toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<T?> _sheet<T>(Widget child) => showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTheme.radiusLg),
      ),
    ),
    builder: (_) => child,
  );

  Future<void> _post() async {
    final scheduleId = widget.scheduleId;
    if (scheduleId == null) return;
    final draft = await _sheet<_PostDraft>(const _PostLostItemSheet());
    if (draft == null || !mounted) return;
    await _run(() async {
      final item = await _app.postLostItem(
        scheduleId,
        description: draft.description,
        photoPath: draft.photoPath,
      );
      if (!mounted) return;
      setState(() => _items = [item, ...?_items]);
      HapticFeedback.mediumImpact();
    }, done: 'แจ้งทุกคนในทริปแล้ว');
  }

  Future<void> _claim(Map<String, dynamic> item) async {
    final note = await _sheet<String>(
      _ClaimSheet(item: item, initialNote: item['claim_note']?.toString()),
    );
    if (note == null) return;
    await _run(() async {
      final updated = await _app.claimLostItem(
        _int(item['id']),
        note: note.isEmpty ? null : note,
      );
      if (mounted) _replace(updated);
      HapticFeedback.mediumImpact();
    }, done: 'แจ้งทีมงานแล้ว เดี๋ยวติดต่อกลับเรื่องรับคืนครับ');
  }

  Future<void> _unclaim(Map<String, dynamic> item) async {
    final ok = await _confirm(
      item['can_manage'] == true && item['is_mine'] != true
          ? 'ยกเลิกผู้แจ้งรายนี้?'
          : 'ไม่ใช่ของคุณใช่ไหม?',
      'ของจะกลับไปเป็น "ยังไม่มีเจ้าของ" ให้คนอื่นแจ้งได้',
      'ยกเลิกการแจ้ง',
    );
    if (!ok) return;
    await _run(() async {
      final updated = await _app.unclaimLostItem(_int(item['id']));
      if (mounted) _replace(updated);
    });
  }

  Future<void> _markReturned(Map<String, dynamic> item, bool returned) async {
    String? note;
    if (returned) {
      note = await _sheet<String>(const _ReturnSheet());
      if (note == null) return;
    } else if (!await _confirm('ยกเลิกสถานะคืนแล้ว?', '', 'ยกเลิก')) {
      return;
    }
    await _run(() async {
      final updated = await _app.setLostItemReturned(
        _int(item['id']),
        returned: returned,
        note: (note ?? '').isEmpty ? null : note,
      );
      if (mounted) _replace(updated);
    }, done: returned ? 'บันทึกแล้ว แจ้งเจ้าของให้แล้ว' : null);
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    if (!await _confirm('ลบโพสต์นี้?', 'การ์ดในแชทจะถูกลบไปด้วย', 'ลบ')) return;
    await _run(() async {
      await _app.deleteLostItem(_int(item['id']));
      if (!mounted) return;
      setState(() {
        _items = [
          for (final i in _items ?? const <Map<String, dynamic>>[])
            if (_int(i['id']) != _int(item['id'])) i,
        ];
      });
    }, done: 'ลบแล้ว');
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          title,
          style: appFont(
            fontSize: AppText.sizeSubtitle,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: body.isEmpty
            ? null
            : Text(body, style: appFont(fontSize: AppText.sizeBody)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('ไม่', style: appFont(fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              action,
              style: appFont(
                fontWeight: FontWeight.w800,
                color: AppTheme.errorColor,
              ),
            ),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          widget.scheduleId == null ? 'ของที่ลืมไว้ในทริป' : 'ของหาย / ลืมของ',
          style: appFont(
            fontSize: AppText.sizeTitle,
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      floatingActionButton: _canManage && widget.scheduleId != null
          ? FloatingActionButton.extended(
              elevation: 0,
              onPressed: _busy ? null : _post,
              icon: const Icon(Icons.add_a_photo_rounded),
              label: Text(
                'โพสต์ของที่เจอ',
                style: appFont(fontWeight: FontWeight.w800),
              ),
            )
          : null,
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final items = _items;
    if (items == null && _error == null) {
      return const SkeletonList(count: 3, padding: EdgeInsets.only(top: 8));
    }
    if (items == null) {
      return ScrollableEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'โหลดไม่สำเร็จ',
        body: _error,
        actionLabel: 'ลองใหม่',
        onAction: _load,
      );
    }
    if (items.isEmpty) {
      return ScrollableEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'ยังไม่มีของที่ลืมไว้',
        body: _canManage
            ? 'เจอของที่ลูกทริปลืมไว้ กด "โพสต์ของที่เจอ" แล้วทุกคนในทริปจะได้แจ้งเตือน'
            : 'ถ้าทีมงานเจอของที่ลืมไว้ในทริปของคุณ จะแจ้งให้ทราบที่นี่ครับ',
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _ItemCard(
        item: items[i],
        myUserId: _myUserId,
        showTrip: widget.scheduleId == null,
        onClaim: () => _claim(items[i]),
        onUnclaim: () => _unclaim(items[i]),
        onReturned: (v) => _markReturned(items[i], v),
        onDelete: () => _delete(items[i]),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int? myUserId;
  final bool showTrip;
  final VoidCallback onClaim;
  final VoidCallback onUnclaim;
  final ValueChanged<bool> onReturned;
  final VoidCallback onDelete;

  const _ItemCard({
    required this.item,
    required this.myUserId,
    required this.showTrip,
    required this.onClaim,
    required this.onUnclaim,
    required this.onReturned,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final status = item['status']?.toString();
    final manage = item['can_manage'] == true;
    final mine = item['is_mine'] == true;
    final badge = lostItemBadge(context, item, myUserId);
    final muted = AppTheme.mutedText(context);
    final claimNote = item['claim_note']?.toString() ?? '';
    final returnedNote = item['returned_note']?.toString() ?? '';
    final phone = item['claimant_phone']?.toString() ?? '';

    TextStyle small([Color? c]) =>
        appFont(fontSize: AppText.sizeCaption, color: c ?? muted, height: 1.4);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LostItemPhoto(url: item['photo_url']?.toString(), size: 84),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showTrip && item['trip_title'] != null)
                      Text(
                        '${item['trip_title']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appFont(
                          fontSize: AppText.sizeCaption,
                          fontWeight: FontWeight.w700,
                          color: muted,
                        ),
                      ),
                    Text(
                      item['description']?.toString() ?? '',
                      style: appFont(
                        fontSize: AppText.sizeBody,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface(context),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(badge.icon, size: 14, color: badge.color),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            badge.label,
                            style: appFont(
                              fontSize: AppText.sizeCaption,
                              fontWeight: FontWeight.w800,
                              color: badge.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if ((item['posted_by_name']?.toString() ?? '').isNotEmpty)
                      Text(
                        'โพสต์โดย ${item['posted_by_name']}',
                        style: small(),
                      ),
                  ],
                ),
              ),
            ],
          ),
          // รายละเอียดที่เห็นเฉพาะเจ้าของกับทีมงาน
          if (manage && status != 'open') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'เจ้าของ: ${item['claimant_name'] ?? '-'}'
                    '${phone.isNotEmpty ? ' · $phone' : ''}',
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (phone.isNotEmpty)
                  IconButton(
                    tooltip: 'โทรหา',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)),
                    icon: const Icon(
                      Icons.call_rounded,
                      color: AppTheme.primaryColor,
                    ),
                  ),
              ],
            ),
          ],
          if ((manage || mine) && claimNote.isNotEmpty)
            Text(
              'รับคืน: $claimNote',
              style: small(AppTheme.onSurface(context)),
            ),
          if ((manage || mine) && returnedNote.isNotEmpty)
            Text(
              'ส่งคืน: $returnedNote',
              style: small(AppTheme.onSurface(context)),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (status == 'open' && !manage)
                FilledButton.icon(
                  onPressed: onClaim,
                  icon: const Icon(Icons.back_hand_rounded, size: 17),
                  label: Text(
                    'ของฉัน',
                    style: appFont(fontWeight: FontWeight.w800),
                  ),
                ),
              if (status == 'claimed' && mine) ...[
                OutlinedButton(
                  onPressed: onClaim,
                  child: Text(
                    'แก้วิธีรับคืน',
                    style: appFont(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: onUnclaim,
                  child: Text(
                    'ไม่ใช่ของฉัน',
                    style: appFont(fontWeight: FontWeight.w700, color: muted),
                  ),
                ),
              ],
              if (status == 'claimed' && !mine && !manage)
                Text('ถ้าเป็นของคุณจริง ทักทีมงานในแชทได้เลย', style: small()),
              if (manage && status == 'claimed') ...[
                FilledButton.icon(
                  onPressed: () => onReturned(true),
                  icon: const Icon(Icons.local_shipping_rounded, size: 17),
                  label: Text(
                    'ส่งคืนแล้ว',
                    style: appFont(fontWeight: FontWeight.w800),
                  ),
                ),
                if (!mine)
                  TextButton(
                    onPressed: onUnclaim,
                    child: Text(
                      'ยกเลิกผู้แจ้ง',
                      style: appFont(fontWeight: FontWeight.w700, color: muted),
                    ),
                  ),
              ],
              if (manage && status == 'returned')
                TextButton(
                  onPressed: () => onReturned(false),
                  child: Text(
                    'ยกเลิกสถานะคืนแล้ว',
                    style: appFont(fontWeight: FontWeight.w700, color: muted),
                  ),
                ),
              if (manage)
                TextButton(
                  onPressed: onDelete,
                  child: Text(
                    'ลบ',
                    style: appFont(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.errorColor,
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

// ── ชีต ───────────────────────────────────────────────────────────────────

class _PostDraft {
  final String description;
  final String? photoPath;

  const _PostDraft(this.description, this.photoPath);
}

class _PostLostItemSheet extends StatefulWidget {
  const _PostLostItemSheet();

  @override
  State<_PostLostItemSheet> createState() => _PostLostItemSheetState();
}

class _PostLostItemSheetState extends State<_PostLostItemSheet> {
  final _desc = TextEditingController();
  final _picker = ImagePicker();
  String? _photoPath;

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (picked != null && mounted) setState(() => _photoPath = picked.path);
    } catch (_) {
      if (mounted) {
        AppSnack.show(context, 'เปิดกล้อง/คลังรูปไม่ได้ ลองอีกครั้ง');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RestStopSheetFrame(
      icon: Icons.inventory_2_rounded,
      title: 'โพสต์ของที่เจอ',
      subtitle:
          'ทุกคนที่ไปทริปนี้ได้แจ้งเตือน เจ้าของกด "ของฉัน" แล้วบอกวิธีรับคืน',
      footer: PrimaryCTAButton(
        label: 'แจ้งทุกคนในทริป',
        icon: Icons.campaign_rounded,
        onPressed: _desc.text.trim().isEmpty
            ? null
            : () => Navigator.pop(
                context,
                _PostDraft(_desc.text.trim(), _photoPath),
              ),
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_rounded),
                label: Text(
                  'ถ่ายรูป',
                  style: appFont(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_rounded),
                label: Text(
                  'เลือกรูป',
                  style: appFont(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
        if (_photoPath != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.primaryColor,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'แนบรูปแล้ว',
                    style: appFont(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _photoPath = null),
                  child: Text(
                    'เอาออก',
                    style: appFont(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        const RestStopSheetLabel('เป็นของอะไร เจอที่ไหน'),
        TextField(
          controller: _desc,
          maxLength: 300,
          maxLines: 3,
          minLines: 2,
          onChanged: (_) => setState(() {}),
          decoration: restStopFieldDecoration(
            context,
            'เช่น หมวกสีดำ เจอที่เบาะหลังรถตู้',
          ),
        ),
      ],
    );
  }
}

/// เจ้าของบอกวิธีรับคืน — คืนข้อความ ('' = ไม่ระบุ)
class _ClaimSheet extends StatefulWidget {
  final Map<String, dynamic> item;
  final String? initialNote;

  const _ClaimSheet({required this.item, this.initialNote});

  @override
  State<_ClaimSheet> createState() => _ClaimSheetState();
}

class _ClaimSheetState extends State<_ClaimSheet> {
  late final _note = TextEditingController(text: widget.initialNote ?? '');

  static const _quick = [
    'มารับเองที่ออฟฟิศ',
    'ฝากทริปหน้า',
    'ส่งไปรษณีย์ (ใส่ที่อยู่ด้านล่าง)',
  ];

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RestStopSheetFrame(
      icon: Icons.back_hand_rounded,
      title: 'นี่ของฉัน',
      subtitle: widget.item['description']?.toString(),
      footer: PrimaryCTAButton(
        label: 'แจ้งทีมงาน',
        icon: Icons.send_rounded,
        onPressed: () => Navigator.pop(context, _note.text.trim()),
      ),
      children: [
        const RestStopSheetLabel('อยากรับคืนยังไง (ทีมงานเท่านั้นที่เห็น)'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final q in _quick)
              ActionChip(
                label: Text(q, style: appFont(fontSize: AppText.sizeCaption)),
                onPressed: () => setState(() => _note.text = q),
              ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _note,
          maxLength: 300,
          maxLines: 3,
          minLines: 2,
          decoration: restStopFieldDecoration(
            context,
            'เช่น ส่งไปรษณีย์ 99/1 ถ.สุขุมวิท ... 10110',
          ),
        ),
      ],
    );
  }
}

/// ทีมงานบันทึกว่าส่งคืนแล้ว — คืนหมายเหตุ ('' = ไม่ระบุ)
class _ReturnSheet extends StatefulWidget {
  const _ReturnSheet();

  @override
  State<_ReturnSheet> createState() => _ReturnSheetState();
}

class _ReturnSheetState extends State<_ReturnSheet> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RestStopSheetFrame(
      icon: Icons.local_shipping_rounded,
      title: 'ส่งคืนแล้ว',
      subtitle: 'เจ้าของจะได้แจ้งเตือนพร้อมหมายเหตุนี้',
      footer: PrimaryCTAButton(
        label: 'บันทึก',
        icon: Icons.check_rounded,
        onPressed: () => Navigator.pop(context, _note.text.trim()),
      ),
      children: [
        TextField(
          controller: _note,
          maxLength: 300,
          decoration: restStopFieldDecoration(
            context,
            'เช่น เลขพัสดุ EMS TH123456789 / ให้คืนที่ออฟฟิศแล้ว',
          ),
        ),
      ],
    );
  }
}
