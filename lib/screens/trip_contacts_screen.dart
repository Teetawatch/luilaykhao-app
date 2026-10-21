import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snack.dart';
import '../widgets/chat_rest_stop.dart'
    show RestStopSheetFrame, RestStopSheetLabel, restStopFieldDecoration;
import '../widgets/travel_widgets.dart';

// แลกคอนแทคกับเพื่อนร่วมทริป (TripContactService) — ต้องยินยอมทั้งสองฝ่าย
// คอนแทคของอีกฝ่ายมาก็ต่อเมื่อแลกกันแล้ว และอยู่ต่อหลังห้องแชทถูกลบ

/// ช่องคอนแทค — คีย์ตรงกับ TripContactService::HANDLE_KEYS
const contactHandleKinds = [
  (key: 'line', label: 'LINE ID', icon: Icons.chat_rounded, hint: 'LINE ID ของคุณ'),
  (key: 'instagram', label: 'Instagram', icon: Icons.camera_alt_rounded, hint: 'ชื่อผู้ใช้ IG (ไม่ต้องมี @)'),
  (key: 'facebook', label: 'Facebook', icon: Icons.facebook_rounded, hint: 'ชื่อ หรือลิงก์โปรไฟล์'),
  (key: 'tiktok', label: 'TikTok', icon: Icons.music_note_rounded, hint: 'ชื่อผู้ใช้ TikTok'),
];

/// ลิงก์เปิดแอปของแต่ละช่อง — null = เปิดไม่ได้ (คัดลอกได้อย่างเดียว)
Uri? contactHandleUri(String key, String value) {
  final v = value.trim();
  if (v.isEmpty) return null;
  if (v.startsWith('http://') || v.startsWith('https://')) return Uri.tryParse(v);
  return switch (key) {
    'line' => Uri.parse('https://line.me/ti/p/~${Uri.encodeComponent(v)}'),
    'instagram' => Uri.parse('https://instagram.com/${Uri.encodeComponent(v)}'),
    'tiktok' => Uri.parse('https://www.tiktok.com/@${Uri.encodeComponent(v)}'),
    // ชื่อบน Facebook ไม่ใช่ชื่อผู้ใช้เสมอไป — เปิดหน้าค้นหาแทนการเดาลิงก์
    'facebook' => Uri.parse('https://www.facebook.com/search/top?q=${Uri.encodeComponent(v)}'),
    _ => null,
  };
}

Map<String, String> _handles(dynamic raw) => raw is Map
    ? {
        for (final e in raw.entries)
          if ('${e.value}'.trim().isNotEmpty) '${e.key}': '${e.value}'.trim(),
      }
    : const {};

/// แก้คอนแทคของฉัน — คืนค่าที่บันทึกแล้ว
Future<Map<String, String>?> editMyContactHandles(BuildContext context, Map<String, String> current) async {
  final draft = await showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
    ),
    builder: (_) => _HandlesSheet(initial: current),
  );
  if (draft == null || !context.mounted) return null;
  try {
    final saved = await context.read<AppProvider>().saveSocialHandles(draft);
    if (context.mounted) AppSnack.show(context, 'บันทึกคอนแทคแล้ว');
    return _handles(saved);
  } catch (e) {
    if (context.mounted) AppSnack.error(context, e.toString());
    return null;
  }
}

class _HandlesSheet extends StatefulWidget {
  final Map<String, String> initial;

  const _HandlesSheet({required this.initial});

  @override
  State<_HandlesSheet> createState() => _HandlesSheetState();
}

class _HandlesSheetState extends State<_HandlesSheet> {
  late final _controllers = {
    for (final k in contactHandleKinds) k.key: TextEditingController(text: widget.initial[k.key] ?? ''),
  };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RestStopSheetFrame(
      icon: Icons.contact_page_rounded,
      title: 'คอนแทคของฉัน',
      subtitle: 'เพื่อนเห็นได้เฉพาะคนที่คุณตกลงแลกด้วยเท่านั้น ใส่ช่องเดียวก็พอ',
      footer: PrimaryCTAButton(
        label: 'บันทึก',
        onPressed: () => Navigator.of(context).pop({
          for (final e in _controllers.entries) e.key: e.value.text.trim(),
        }),
      ),
      children: [
        for (final k in contactHandleKinds) ...[
          RestStopSheetLabel(k.label),
          TextField(
            controller: _controllers[k.key],
            maxLength: 100,
            decoration: restStopFieldDecoration(context, k.hint),
          ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}

/// ปุ่มคอนแทคหนึ่งช่อง — แตะเปิดแอป กดค้างคัดลอก
class ContactHandleChip extends StatelessWidget {
  final String kind;
  final String value;

  const ContactHandleChip({super.key, required this.kind, required this.value});

  @override
  Widget build(BuildContext context) {
    final meta = contactHandleKinds.firstWhere(
      (k) => k.key == kind,
      orElse: () => contactHandleKinds.first,
    );

    return ActionChip(
      avatar: Icon(meta.icon, size: 16, color: AppTheme.primaryColor),
      label: Text(value, style: appFont(fontWeight: FontWeight.w700)),
      tooltip: '${meta.label} · กดค้างเพื่อคัดลอก',
      onPressed: () async {
        HapticFeedback.selectionClick();
        final uri = contactHandleUri(kind, value);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          await Clipboard.setData(ClipboardData(text: value));
          if (context.mounted) AppSnack.show(context, 'คัดลอก ${meta.label} แล้ว');
        }
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  final String url;
  final String name;

  const _Avatar({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first;
    return ClipOval(
      child: SizedBox(
        width: 40,
        height: 40,
        child: url.isEmpty
            ? ColoredBox(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                child: Center(
                  child: Text(
                    initial,
                    style: appFont(fontWeight: FontWeight.w800, color: AppTheme.primaryColor),
                  ),
                ),
              )
            : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, memCacheWidth: 120),
      ),
    );
  }
}

/// แลกคอนแทคในทริปเดียว — เปิดจากห้องแชท / การแจ้งเตือน
class TripContactsScreen extends StatefulWidget {
  final int scheduleId;

  const TripContactsScreen({super.key, required this.scheduleId});

  @override
  State<TripContactsScreen> createState() => _TripContactsScreenState();
}

class _TripContactsScreenState extends State<TripContactsScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<AppProvider>().tripContacts(widget.scheduleId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Map<String, String> get _mine => _handles(_data?['my_handles']);

  Future<void> _editMine() async {
    final saved = await editMyContactHandles(context, _mine);
    if (saved != null && mounted) setState(() => _data = {...?_data, 'my_handles': saved});
  }

  Future<void> _act(int userId, Future<Map<String, dynamic>> Function() call) async {
    if (_mine.isEmpty) {
      AppSnack.show(context, 'ใส่คอนแทคของคุณก่อน เพื่อนจะได้เห็นเมื่อตกลงแลกกัน');
      await _editMine();
      if (_mine.isEmpty || !mounted) return;
    }
    setState(() => _busy.add(userId));
    try {
      final res = await call();
      if (!mounted) return;
      AppSnack.show(context, res['status'] == 'exchanged' ? 'แลกคอนแทคกันแล้ว 🤝' : 'ส่งคำขอแล้ว');
      await _load();
    } catch (e) {
      if (mounted) AppSnack.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy.remove(userId));
    }
  }

  Future<void> _decline(int userId) async {
    setState(() => _busy.add(userId));
    try {
      await context.read<AppProvider>().respondTripContact(widget.scheduleId, userId, false);
      await _load();
    } catch (e) {
      if (mounted) AppSnack.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy.remove(userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final people = (data?['people'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final open = data?['window_open'] == true;
    final app = context.read<AppProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: Text(
          'แลกคอนแทค',
          style: appFont(fontSize: AppTheme.appBarTitleSize, fontWeight: FontWeight.w800),
        ),
      ),
      body: data == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator(strokeWidth: 2.4)
                  : TextButton(onPressed: _load, child: const Text('โหลดไม่สำเร็จ · ลองอีกครั้ง')),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  _MyHandlesCard(handles: _mine, onEdit: _editMine),
                  const SizedBox(height: 12),
                  if (!open)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'ขอแลกคอนแทคได้ตั้งแต่วันเดินทางถึง 30 วันหลังจบทริป — คนที่แลกกันแล้วดูได้ตลอด',
                        style: appFont(fontSize: AppText.sizeCaption, color: AppTheme.mutedText(context)),
                      ),
                    ),
                  for (final p in people)
                    _PersonTile(
                      person: p,
                      windowOpen: open,
                      busy: _busy.contains(int.tryParse('${p['user_id']}')),
                      onRequest: () {
                        final id = int.tryParse('${p['user_id']}') ?? 0;
                        _act(id, () => app.requestTripContact(widget.scheduleId, id));
                      },
                      onAccept: () {
                        final id = int.tryParse('${p['user_id']}') ?? 0;
                        _act(id, () => app.respondTripContact(widget.scheduleId, id, true));
                      },
                      onDecline: () => _decline(int.tryParse('${p['user_id']}') ?? 0),
                    ),
                  if (people.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'ยังไม่มีเพื่อนร่วมทริปให้แลกคอนแทค',
                        textAlign: TextAlign.center,
                        style: appFont(color: AppTheme.mutedText(context)),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _MyHandlesCard extends StatelessWidget {
  final Map<String, String> handles;
  final VoidCallback onEdit;

  const _MyHandlesCard({required this.handles, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'คอนแทคของฉัน',
                  style: appFont(fontSize: AppText.sizeBody, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                onPressed: onEdit,
                child: Text(handles.isEmpty ? 'ใส่คอนแทค' : 'แก้ไข', style: appFont(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (handles.isEmpty)
            Text(
              'ยังไม่ได้ใส่ — ใส่อย่างน้อยหนึ่งช่องก่อนขอแลก เพื่อนเห็นเฉพาะคนที่ตกลงแลกกัน',
              style: appFont(fontSize: AppText.sizeCaption, color: AppTheme.mutedText(context), height: 1.4),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in handles.entries) ContactHandleChip(kind: e.key, value: e.value),
              ],
            ),
        ],
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  final Map<String, dynamic> person;
  final bool windowOpen;
  final bool busy;
  final VoidCallback onRequest;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _PersonTile({
    required this.person,
    required this.windowOpen,
    required this.busy,
    required this.onRequest,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final status = person['status']?.toString() ?? 'none';
    final name = person['name']?.toString() ?? '';
    final handles = _handles(person['handles']);
    final isStaff = person['role'] == 'staff';

    Widget action;
    if (busy) {
      action = const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2));
    } else {
      action = switch (status) {
        'exchanged' => const Icon(Icons.handshake_rounded, color: AppTheme.primaryColor),
        'requested' => Text(
          'ส่งคำขอแล้ว',
          style: appFont(fontSize: AppText.sizeCaption, fontWeight: FontWeight.w700, color: AppTheme.mutedText(context)),
        ),
        'incoming' => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(onPressed: onDecline, child: Text('ไม่ตอนนี้', style: appFont(fontWeight: FontWeight.w600))),
            FilledButton(
              onPressed: onAccept,
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              child: Text('แลกเลย', style: appFont(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        _ => windowOpen
            ? OutlinedButton(
                onPressed: onRequest,
                child: Text('ขอแลก', style: appFont(fontWeight: FontWeight.w700)),
              )
            : const SizedBox.shrink(),
      };
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Avatar(url: ApiConfig.mediaUrl(person['avatar_url']), name: name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: appFont(fontSize: AppText.sizeBody, fontWeight: FontWeight.w800)),
                      Text(
                        status == 'incoming'
                            ? 'อยากแลกคอนแทคกับคุณ'
                            : (isStaff ? 'ทีมงาน' : 'เพื่อนร่วมทริป'),
                        style: appFont(
                          fontSize: AppText.sizeCaption,
                          fontWeight: status == 'incoming' ? FontWeight.w700 : FontWeight.w500,
                          color: status == 'incoming' ? AppTheme.primaryColor : AppTheme.mutedText(context),
                        ),
                      ),
                    ],
                  ),
                ),
                action,
              ],
            ),
            if (status == 'exchanged') ...[
              const SizedBox(height: 8),
              handles.isEmpty
                  ? Text(
                      'เขายังไม่ได้ใส่คอนแทค',
                      style: appFont(fontSize: AppText.sizeCaption, color: AppTheme.mutedText(context)),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final e in handles.entries) ContactHandleChip(kind: e.key, value: e.value),
                      ],
                    ),
            ],
          ],
        ),
      ),
    );
  }
}

/// คอนแทคเพื่อนร่วมทริปทุกทริป — เปิดจากโปรไฟล์ (อยู่ต่อหลังห้องแชทถูกลบ)
class MyTripContactsScreen extends StatefulWidget {
  const MyTripContactsScreen({super.key});

  @override
  State<MyTripContactsScreen> createState() => _MyTripContactsScreenState();
}

class _MyTripContactsScreenState extends State<MyTripContactsScreen> {
  List<Map<String, dynamic>>? _items;
  Map<String, String> _mine = const {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = context.read<AppProvider>();
    try {
      final results = await Future.wait([app.myTripContacts(), app.mySocialHandles()]);
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(results[0] as List);
        _mine = _handles(results[1]);
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: Text(
          'คอนแทคเพื่อนร่วมทริป',
          style: appFont(fontSize: AppTheme.appBarTitleSize, fontWeight: FontWeight.w800),
        ),
      ),
      body: items == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator(strokeWidth: 2.4)
                  : TextButton(onPressed: _load, child: const Text('โหลดไม่สำเร็จ · ลองอีกครั้ง')),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  _MyHandlesCard(
                    handles: _mine,
                    onEdit: () async {
                      final saved = await editMyContactHandles(context, _mine);
                      if (saved != null && mounted) setState(() => _mine = saved);
                    },
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        'ยังไม่ได้แลกคอนแทคกับใคร\nหลังทริปกด "แลกคอนแทค" ในห้องแชทของทริปนั้นได้เลย',
                        textAlign: TextAlign.center,
                        style: appFont(color: AppTheme.mutedText(context), height: 1.5),
                      ),
                    ),
                  for (final c in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusMd),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _Avatar(url: ApiConfig.mediaUrl(c['avatar_url']), name: c['name']?.toString() ?? ''),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c['name']?.toString() ?? '',
                                        style: appFont(fontSize: AppText.sizeBody, fontWeight: FontWeight.w800),
                                      ),
                                      if ((c['trip_title']?.toString() ?? '').isNotEmpty)
                                        Text(
                                          'จากทริป ${c['trip_title']}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: appFont(fontSize: AppText.sizeCaption, color: AppTheme.mutedText(context)),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_handles(c['handles']).isEmpty)
                              Text(
                                'เขายังไม่ได้ใส่คอนแทค',
                                style: appFont(fontSize: AppText.sizeCaption, color: AppTheme.mutedText(context)),
                              )
                            else
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final e in _handles(c['handles']).entries)
                                    ContactHandleChip(kind: e.key, value: e.value),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
