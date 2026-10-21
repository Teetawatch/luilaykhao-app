part of 'chat_screen.dart';

/// การ์ดเครื่องมือหน้างานที่ payload ใน broadcast ไม่มีส่วนของผู้ดู — ต้องคงค่าเดิมไว้
/// (เช็คพอยต์: ฉันขอพักไหม, เช็คอาการ/จุดลง: คำตอบ/จุดของคนที่ฉันดูแล + detail
/// ของทีมงาน, ลูกหาบ: คนที่ฉันฝากแทนได้)
const _toolKeepKeys = <String, List<String>>{
  'trail_check': ['my_help'],
  'wellness': ['mine', 'detail'],
  'dropoff': ['mine', 'detail'],
  'porter': ['mine'],
};

typedef _Card = Map<String, dynamic>;

/// ปุ่มบนการ์ดเครื่องมือหน้างานในบับเบิล — รวมไว้ก้อนเดียว บับเบิลจะได้ไม่บวม
class _BubbleTools {
  final void Function(_Card trail, List<int> ids, int? index) onTrailReach;
  final ValueChanged<_Card> onTrailHelp;
  final ValueChanged<_Card> onTrailCancelHelp;
  final ValueChanged<_Card> onOpenTrail;
  final void Function(_Card wellness, WellnessAnswer answer) onWellnessAnswer;
  final void Function(_Card wellness, String? status) onOpenWellnessAnswer;
  final ValueChanged<_Card> onOpenWellnessStaff;
  final ValueChanged<_Card> onChooseDropoff;
  final ValueChanged<_Card> onOpenDropoffStaff;
  final ValueChanged<_Card> onRegisterPorter;
  final ValueChanged<_Card> onOpenPorter;

  const _BubbleTools({
    required this.onTrailReach,
    required this.onTrailHelp,
    required this.onTrailCancelHelp,
    required this.onOpenTrail,
    required this.onWellnessAnswer,
    required this.onOpenWellnessAnswer,
    required this.onOpenWellnessStaff,
    required this.onChooseDropoff,
    required this.onOpenDropoffStaff,
    required this.onRegisterPorter,
    required this.onOpenPorter,
  });
}

/// ชีตของการ์ดที่เปิดค้างอยู่ — realtime ป้อนค่าใหม่ให้ชีตอัปเดตเอง
class _ToolSheet {
  final value = ValueNotifier<Map<String, dynamic>?>(null);
  int? messageId;

  /// กำลังดึง GET อยู่ / มีการเปลี่ยนระหว่างดึง (ดึงซ้ำอีกรอบหลังเสร็จ)
  bool fetching = false;
  bool dirty = false;
}

/// เครื่องมือหน้างานในห้องแชท — ปลุกรวม (การ์ดจุดพักชนิด wakeup), เช็คพอยต์เส้นทาง,
/// เช็คอาการ "ยังไหวไหม", จุดลงขากลับ และฝากของลูกหาบ
mixin _TripToolsMixin on State<ChatScreen> {
  // ── สิ่งที่ห้องแชทมีอยู่แล้ว ─────────────────────────────────────────────
  List<Map<String, dynamic>> get _messages;
  bool get _canModerate;
  int? get _myUserId;
  void _snack(String message);
  Future<T?> _showSheet<T>(Widget sheet);
  void _scrollToBottom();
  void _markRead();
  void _scrollToMessage(int messageId);
  void _refreshTodos();

  final Map<String, _ToolSheet> _toolSheets = {
    for (final key in _toolKeepKeys.keys) key: _ToolSheet(),
  };

  /// การ์ดที่ดึง "ส่วนของฉัน" มาแล้ว — กันดึงซ้ำทุกครั้งที่ข้อความถูกวาด
  final Set<String> _hydratedTools = {};

  AppProvider get _app => context.read<AppProvider>();

  int get _sid => widget.scheduleId;

  void disposeTripTools() {
    for (final s in _toolSheets.values) {
      s.value.dispose();
    }
  }

  // ── รวมค่าจาก realtime / ตอบกลับ ───────────────────────────────────────

  Map<String, dynamic> _keepViewerParts(
    String key,
    Map<String, dynamic>? old,
    Map<String, dynamic> next,
  ) {
    if (old == null) return next;
    final merged = {...next};
    for (final k in _toolKeepKeys[key] ?? const <String>[]) {
      if (!merged.containsKey(k) && old.containsKey(k)) merged[k] = old[k];
    }
    return merged;
  }

  void _applyToolCard(String key, int messageId, dynamic card) {
    if (card is! Map || !mounted) return;
    final incoming = Map<String, dynamic>.from(card);

    final sheet = _toolSheets[key];
    if (sheet != null && sheet.messageId == messageId) {
      sheet.value.value = _keepViewerParts(key, sheet.value.value, incoming);
    }

    final idx = _messages.indexWhere(
      (m) => int.tryParse('${m['id']}') == messageId,
    );
    if (idx < 0) return;
    final old = _messages[idx][key] is Map
        ? Map<String, dynamic>.from(_messages[idx][key] as Map)
        : null;
    setState(
      () => _messages[idx] = {
        ..._messages[idx],
        key: _keepViewerParts(key, old, incoming),
      },
    );
    _refreshTodos();
  }

  /// realtime ของการ์ด — ถ้าทีมงานเปิดชีตของใบนี้อยู่ ดึงรายละเอียดใหม่ด้วย
  /// (broadcast ไม่มีรายชื่อคนขอพัก/คำตอบ/จุดลงของแต่ละคน)
  void _onToolSignal(String key, Map<String, dynamic> data) {
    final messageId = int.tryParse('${data['message_id']}');
    if (messageId == null || data[key] is! Map) return;
    _applyToolCard(key, messageId, data[key]);

    final sheet = _toolSheets[key];
    if (_canModerate && sheet != null && sheet.messageId == messageId) {
      final id = int.tryParse('${(data[key] as Map)['id']}') ?? 0;
      _refreshToolSheet(key, messageId, id);
    }
  }

  Future<Map<String, dynamic>> _fetchTool(String key, int id) => switch (key) {
    'trail_check' => _app.getChatTrailCheck(_sid, id),
    'wellness' => _app.getChatWellness(_sid, id),
    'dropoff' => _app.getChatDropoff(_sid, id),
    _ => _app.getChatPorter(_sid, id),
  };

  /// ดึง GET ของการ์ดในชีตที่เปิดอยู่ — คำขอซ้อนกันรวมเป็นรอบเดียว
  Future<void> _refreshToolSheet(String key, int messageId, int id) async {
    final sheet = _toolSheets[key]!;
    if (id == 0) return;
    if (sheet.fetching) {
      sheet.dirty = true;
      return;
    }
    sheet.fetching = true;
    try {
      do {
        sheet.dirty = false;
        final result = await _fetchTool(key, id);
        if (!mounted) return;
        _applyToolCard(key, messageId, result[key]);
      } while (sheet.dirty && mounted);
    } catch (_) {
      // ไม่เป็นไร — realtime ครั้งถัดไปหรือการเปิดชีตใหม่จะดึงให้
    } finally {
      sheet.fetching = false;
    }
  }

  /// ข้อความที่เพิ่งมาทาง realtime (ของคนอื่นที่เปิดการ์ด) ไม่มี "ส่วนของฉัน" —
  /// ดึงครั้งเดียวต่อการ์ด และตั้งปลุกในเครื่องให้การ์ดปลุกรวม
  void _hydrateTools(Iterable<Map<String, dynamic>> messages) {
    for (final m in messages) {
      final messageId = int.tryParse('${m['id']}');
      if (messageId == null) continue;

      final stop = m['rest_stop'];
      if (stop is Map && stop['kind'] == 'wakeup') {
        unawaited(
          WakeAlarmService.instance.sync(
            Map<String, dynamic>.from(stop),
            _myUserId,
          ),
        );
      }

      for (final key in const ['wellness', 'dropoff', 'porter']) {
        final card = m[key];
        if (card is! Map || card.containsKey('mine')) continue;
        final id = int.tryParse('${card['id']}') ?? 0;
        if (id == 0 || !_hydratedTools.add('$key:$id')) continue;
        _fetchTool(key, id)
            .then((result) {
              if (mounted) _applyToolCard(key, messageId, result[key]);
            })
            .catchError((_) {});
      }
    }
  }

  void _appendToolMessage(Map<String, dynamic> message) {
    if (!mounted) return;
    setState(() => _messages.add(message));
    _scrollToBottom();
    _markRead();
    _hydrateTools([message]);
    HapticFeedback.mediumImpact();
  }

  Future<void> _runTool(
    String key,
    int messageId,
    Future<Map<String, dynamic>> Function() call, {
    String? success,
  }) async {
    try {
      final result = await call();
      if (!mounted) return;
      _applyToolCard(key, messageId, result[key]);
      if (success != null) _snack(success);
    } catch (e) {
      _snack(e.toString());
    }
  }

  /// เปิดชีตของการ์ด [key] ใบนี้ค้างไว้ — ดึงค่าล่าสุดจาก GET ทันที (ทีมงานได้รายละเอียด)
  Future<void> _showToolSheet(
    String key,
    int messageId,
    Map<String, dynamic> card,
    Widget sheet,
  ) async {
    final s = _toolSheets[key]!;
    s.messageId = messageId;
    s.value.value = card;
    unawaited(
      _refreshToolSheet(key, messageId, int.tryParse('${card['id']}') ?? 0),
    );
    await _showSheet<void>(sheet);
    s.messageId = null;
  }

  // ── ปลุกรวม ──────────────────────────────────────────────────────────────

  Future<void> _openWakeup() async {
    final draft = await _showSheet<MeetupDraft>(
      const OpenMeetupSheet(wakeup: true),
    );
    if (draft == null || !mounted) return;
    try {
      final message = await _app.openChatRestStop(
        _sid,
        kind: 'wakeup',
        meetAt: draft.meetAt,
        place: draft.place,
      );
      _appendToolMessage(message);
    } catch (e) {
      _snack(e.toString());
    }
  }

  // ── เช็คพอยต์ ────────────────────────────────────────────────────────────

  Future<void> _openTrailCheck() async {
    final draft = await _showSheet<TrailDraft>(const OpenTrailCheckSheet());
    if (draft == null || !mounted) return;
    try {
      final message = await _app.openChatTrailCheck(
        _sid,
        title: draft.title,
        checkpoints: draft.checkpoints,
      );
      _appendToolMessage(message);
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _reachTrail(
    int messageId,
    Map<String, dynamic> trail,
    List<int> passengerIds,
    int? index,
  ) async {
    final id = int.tryParse('${trail['id']}') ?? 0;
    if (id == 0 || passengerIds.isEmpty) return;
    await _runTool(
      'trail_check',
      messageId,
      () => _app.reachChatTrailCheck(
        _sid,
        id,
        passengerIds: passengerIds,
        index: index,
      ),
    );
  }

  Future<void> _askTrailHelp(int messageId, Map<String, dynamic> trail) async {
    final id = int.tryParse('${trail['id']}') ?? 0;
    final mine = myTrailPassengers(trail, _myUserId);
    if (id == 0 || mine.isEmpty) return;
    final draft = await _showSheet<TrailHelpDraft>(TrailHelpSheet(mine: mine));
    if (draft == null || !mounted) return;
    await _runTool(
      'trail_check',
      messageId,
      () => _app.requestChatTrailHelp(
        _sid,
        id,
        passengerIds: draft.passengerIds,
        note: draft.note,
      ),
      success: 'แจ้งทีมงานแล้ว พักก่อนได้เลยนะครับ',
    );
  }

  Future<void> _cancelTrailHelp(
    int messageId,
    Map<String, dynamic> trail,
  ) async {
    final id = int.tryParse('${trail['id']}') ?? 0;
    if (id == 0) return;
    await _runTool(
      'trail_check',
      messageId,
      () => _app.cancelChatTrailHelp(_sid, id),
    );
  }

  Future<void> _openTrailBoard(
    int messageId,
    Map<String, dynamic> trail,
  ) async {
    final id = int.tryParse('${trail['id']}') ?? 0;
    if (id == 0) return;
    await _showToolSheet(
      'trail_check',
      messageId,
      trail,
      TrailBoardSheet(
        trail: _toolSheets['trail_check']!.value,
        canManage: _canModerate,
        myUserId: _myUserId,
        onReach: (ids, index) => _reachTrail(messageId, trail, ids, index),
        onAckHelp: (ids) => _runTool(
          'trail_check',
          messageId,
          () => _app.ackChatTrailHelp(_sid, id, ids),
        ),
        onClose: () => _runTool(
          'trail_check',
          messageId,
          () => _app.closeChatTrailCheck(_sid, id),
        ),
      ),
    );
  }

  // ── เช็คอาการ ────────────────────────────────────────────────────────────

  Future<void> _openWellnessCheck() async {
    final label = await _showSheet<String>(const OpenWellnessSheet());
    if (label == null || !mounted) return;
    try {
      final message = await _app.openChatWellness(
        _sid,
        label: label.isEmpty ? null : label,
      );
      _appendToolMessage(message);
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _answerWellness(
    int messageId,
    Map<String, dynamic> wellness,
    List<WellnessAnswer> answers,
  ) async {
    final id = int.tryParse('${wellness['id']}') ?? 0;
    if (id == 0 || answers.isEmpty) return;
    for (final a in answers) {
      await _runTool(
        'wellness',
        messageId,
        () => _app.answerChatWellness(
          _sid,
          id,
          passengerIds: a.passengerIds,
          status: a.status,
          note: a.note,
        ),
      );
    }
    if (!mounted) return;
    final worst = answers.any((a) => a.status == 'unwell')
        ? 'ส่งถึงทีมงานแล้ว เดี๋ยวมีคนมาดูนะครับ'
        : 'ขอบคุณที่บอกครับ';
    _snack(worst);
  }

  Future<void> _openWellnessAnswer(
    int messageId,
    Map<String, dynamic> wellness,
    String? status,
  ) async {
    final id = int.tryParse('${wellness['id']}') ?? 0;
    if (id == 0) return;
    var mine = wellness['mine'];
    if (mine is! List) {
      try {
        final result = await _app.getChatWellness(_sid, id);
        if (!mounted) return;
        _applyToolCard('wellness', messageId, result['wellness']);
        mine = (result['wellness'] as Map?)?['mine'];
      } catch (e) {
        _snack(e.toString());
        return;
      }
    }
    final people = (mine as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (people.isEmpty) {
      _snack('คุณไม่มีชื่อในรายการเช็คอาการรอบนี้');
      return;
    }
    final answers = await _showSheet<List<WellnessAnswer>>(
      WellnessAnswerSheet(mine: people, initialStatus: status),
    );
    if (answers == null || !mounted) return;
    await _answerWellness(messageId, wellness, answers);
  }

  Future<void> _openWellnessStaff(
    int messageId,
    Map<String, dynamic> wellness,
  ) async {
    final id = int.tryParse('${wellness['id']}') ?? 0;
    if (id == 0) return;
    await _showToolSheet(
      'wellness',
      messageId,
      wellness,
      WellnessStaffSheet(
        wellness: _toolSheets['wellness']!.value,
        onHandled: (pid) => _runTool(
          'wellness',
          messageId,
          () => _app.handleChatWellness(_sid, id, pid),
        ),
        onClose: () => _runTool(
          'wellness',
          messageId,
          () => _app.closeChatWellness(_sid, id),
        ),
      ),
    );
  }

  // ── จุดลงขากลับ ──────────────────────────────────────────────────────────

  Future<void> _openDropoffCard() async {
    final ok = await showConfirmDialog(
      context,
      title: 'ถามจุดลงขากลับ?',
      message:
          'ทุกคนได้แจ้งเตือนให้เลือกจุดลง (ไม่เลือก = จุดรับเดิม) รถใกล้ถึงจุดไหน '
          'คนที่ลงจุดนั้นได้เตือนให้เตรียมของ และคุณได้รายการจุดเรียงตามทาง',
      icon: Icons.airport_shuttle_outlined,
      confirmLabel: 'ถามเลย',
    );
    if (!ok || !mounted) return;
    try {
      final message = await _app.openChatDropoff(_sid);
      _appendToolMessage(message);
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _chooseDropoff(
    int messageId,
    Map<String, dynamic> dropoff,
  ) async {
    final id = int.tryParse('${dropoff['id']}') ?? 0;
    if (id == 0) return;

    Map<String, dynamic> result;
    try {
      result = await _app.getChatDropoff(_sid, id);
    } catch (e) {
      _snack(e.toString());
      return;
    }
    if (!mounted) return;
    _applyToolCard('dropoff', messageId, result['dropoff']);

    List<Map<String, dynamic>> maps(dynamic raw) => (raw as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final mine = maps((result['dropoff'] as Map?)?['mine']);
    final options = maps(result['options']);
    if (mine.isEmpty) {
      _snack('คุณไม่มีชื่อในรถขากลับรอบนี้');
      return;
    }

    final draft = await _showSheet<DropoffDraft>(
      DropoffChooseSheet(
        mine: mine,
        options: options,
        onPickOnMap: (initial) {
          final anchor = options.firstWhere(
            (o) => o['lat'] != null && o['lng'] != null,
            orElse: () => const {},
          );
          final center = LatLng(
            double.tryParse('${anchor['lat'] ?? ''}') ?? 13.7563,
            double.tryParse('${anchor['lng'] ?? ''}') ?? 100.5018,
          );
          return Navigator.of(context).push<Map<String, dynamic>>(
            MaterialPageRoute(
              builder: (_) => CustomPickupPickerScreen(
                center: center,
                initial: initial,
                title: 'ปักหมุดจุดลง',
                hint:
                    'เลื่อนแผนที่ให้หมุดตรงจุดที่จะลง (ต้องอยู่ทางผ่านของรถ) '
                    'จุดนี้เห็นแค่ทีมงาน',
                labelText: 'ชื่อจุดลง / จุดสังเกต *',
                labelHint: 'เช่น ปั๊ม ปตท. ก่อนเข้าเมือง',
                noteHint: 'เช่น จอดฝั่งตรงข้ามเซเว่น',
                labelMaxLength: 120,
                noteMaxLength: 200,
              ),
            ),
          );
        },
      ),
    );
    if (draft == null || !mounted) return;
    await _runTool(
      'dropoff',
      messageId,
      () => _app.chooseChatDropoff(
        _sid,
        id,
        passengerIds: draft.passengerIds,
        pickupPointId: draft.pickupPointId,
        label: draft.reset ? null : draft.label,
        lat: draft.lat,
        lng: draft.lng,
        note: draft.note,
      ),
      success: 'บันทึกจุดลงแล้ว ใกล้ถึงจะเตือนให้นะครับ',
    );
  }

  Future<void> _openDropoffStaff(
    int messageId,
    Map<String, dynamic> dropoff,
  ) async {
    final id = int.tryParse('${dropoff['id']}') ?? 0;
    if (id == 0) return;
    await _showToolSheet(
      'dropoff',
      messageId,
      dropoff,
      DropoffStaffSheet(
        dropoff: _toolSheets['dropoff']!.value,
        onDrop: (ids, dropped) => _runTool(
          'dropoff',
          messageId,
          () => _app.dropChatDropoff(
            _sid,
            id,
            passengerIds: ids,
            dropped: dropped,
          ),
        ),
        onClose: () => _runTool(
          'dropoff',
          messageId,
          () => _app.closeChatDropoff(_sid, id),
        ),
      ),
    );
  }

  // ── ฝากของลูกหาบ ────────────────────────────────────────────────────────

  Future<void> _openPorterRound() async {
    final draft = await _showSheet<PorterDraft>(const OpenPorterSheet());
    if (draft == null || !mounted) return;
    try {
      final message = await _app.openChatPorter(
        _sid,
        title: draft.title,
        ratePerKg: draft.ratePerKg,
        minCharge: draft.minCharge,
        roundUp: draft.roundUp,
        promptPayId: draft.promptPayId,
        payeeName: draft.payeeName,
      );
      _appendToolMessage(message);
    } catch (e) {
      _snack(e.toString());
    }
  }

  Map<int, int> _bagCounts(Map<String, dynamic> porter) {
    final counts = <int, int>{};
    for (final b in (porter['bags'] as List? ?? const []).whereType<Map>()) {
      final pid = int.tryParse('${b['passenger_id']}') ?? 0;
      counts[pid] = (counts[pid] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _registerPorter(
    int messageId,
    Map<String, dynamic> porter,
  ) async {
    final id = int.tryParse('${porter['id']}') ?? 0;
    if (id == 0) return;
    var data = porter;
    if (data['mine'] is! List) {
      try {
        final result = await _app.getChatPorter(_sid, id);
        if (!mounted) return;
        _applyToolCard('porter', messageId, result['porter']);
        data = Map<String, dynamic>.from(result['porter'] as Map);
      } catch (e) {
        _snack(e.toString());
        return;
      }
    }
    final people = (data['mine'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (people.isEmpty) {
      _snack('คุณไม่มีชื่อในรายชื่อผู้เดินทางรอบนี้');
      return;
    }
    final draft = await _showSheet<PorterRegisterDraft>(
      PorterRegisterSheet(people: people, existingBags: _bagCounts(data)),
    );
    if (draft == null || !mounted) return;
    await _runTool(
      'porter',
      messageId,
      () => _app.addChatPorterBags(
        _sid,
        id,
        passengerId: draft.passengerId,
        count: draft.count,
        note: draft.note,
      ),
      success: 'ลงชื่อฝากแล้ว ทีมงานชั่งแล้วเลขป้ายจะขึ้นในการ์ด',
    );
  }

  Future<void> _openPorterManage(
    int messageId,
    Map<String, dynamic> porter,
  ) async {
    final id = int.tryParse('${porter['id']}') ?? 0;
    if (id == 0) return;
    final sheet = _toolSheets['porter']!;

    Future<void> run(Future<Map<String, dynamic>> Function() call) =>
        _runTool('porter', messageId, call);

    await _showToolSheet(
      'porter',
      messageId,
      porter,
      PorterManageSheet(
        porter: sheet.value,
        canManage: _canModerate,
        myUserId: _myUserId,
        onWeigh: (bagId, kg) =>
            run(() => _app.weighChatPorterBag(_sid, id, bagId, kg)),
        onRemove: (bagId) =>
            run(() => _app.removeChatPorterBag(_sid, id, bagId)),
        onReturned: (ids, returned) => run(
          () => _app.setChatPorterReturned(
            _sid,
            id,
            bagIds: ids,
            returned: returned,
          ),
        ),
        onAddForSomeone: () async {
          List<Map<String, dynamic>> roster;
          try {
            roster = await _app.loadChatRoster(_sid);
          } catch (e) {
            _snack(e.toString());
            return;
          }
          if (!mounted) return;
          final draft = await _showSheet<PorterRegisterDraft>(
            PorterRegisterSheet(
              people: [
                for (final p in roster)
                  {'id': p['passenger_id'], 'name': p['name']},
              ],
              existingBags: _bagCounts(sheet.value.value ?? porter),
              withWeight: true,
            ),
          );
          if (draft == null) return;
          await run(
            () => _app.addChatPorterBags(
              _sid,
              id,
              passengerId: draft.passengerId,
              note: draft.note,
              weightKg: draft.weightKg,
            ),
          );
        },
        onBill: () => run(() => _app.billChatPorter(_sid, id)),
        onSetClosed: (closed) =>
            run(() => _app.setChatPorterClosed(_sid, id, closed: closed)),
        onOpenCollection: () {
          final target = int.tryParse(
            '${(sheet.value.value ?? porter)['collection_message_id']}',
          );
          Navigator.of(context).pop();
          if (target != null) _scrollToMessage(target);
        },
      ),
    );
  }
}
