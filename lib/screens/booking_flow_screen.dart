import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../services/realtime_service.dart';
import '../theme/app_theme.dart';
import '../widgets/travel_widgets.dart';
import 'custom_pickup_picker_screen.dart';
import 'document_wallet_screen.dart';
import 'payment_screen.dart';

part 'booking_flow_summary.part.dart';
part 'booking_flow_seats.part.dart';
part 'booking_flow_travelers.part.dart';
part 'booking_flow_forms.part.dart';
part 'booking_flow_helpers.part.dart';

// _softAccent is the booking-flow brand tint (slightly deeper than AppTheme.primaryColor for contrast on light bg)
const Color _softAccent = Color(0xFF059669); // matches AppTheme.primaryColor
const List<String> _titleOptions = ['นาย', 'นาง', 'นางสาว'];
const List<String> _bloodGroupOptions = ['A', 'B', 'O', 'AB'];
const Duration _seatRefreshInterval = Duration(seconds: 5);

Color _premiumText(BuildContext context) => AppTheme.onSurface(context);
Color _mutedTextColor(BuildContext context) => AppTheme.mutedText(context);
Color _cardBorder(BuildContext context) =>
    AppTheme.border(context).withValues(alpha: 0.70);
Color _fieldBackground(BuildContext context) => AppTheme.fieldSurface(context);

class _ImageCacheSize {
  final int width;
  final int height;

  const _ImageCacheSize({required this.width, required this.height});
}

class BookingFlowScreen extends StatelessWidget {
  final Map<String, dynamic> trip;
  final List<dynamic> schedules;
  final int? initialScheduleId;
  final int? initialPickupPointId;
  final bool initialJoinTrip;
  final List<String> initialSeatIds;
  final bool resumeLockedSeats;
  final bool startAtSeatSelection;

  const BookingFlowScreen({
    super.key,
    required this.trip,
    required this.schedules,
    this.initialScheduleId,
    this.initialPickupPointId,
    this.initialJoinTrip = false,
    this.initialSeatIds = const [],
    this.resumeLockedSeats = false,
    this.startAtSeatSelection = false,
  });

  @override
  Widget build(BuildContext context) {
    return BookingCheckoutPage(
      trip: trip,
      schedules: schedules,
      initialScheduleId: initialScheduleId,
      initialPickupPointId: initialPickupPointId,
      initialJoinTrip: initialJoinTrip,
      initialSeatIds: initialSeatIds,
      resumeLockedSeats: resumeLockedSeats,
      startAtSeatSelection: startAtSeatSelection,
    );
  }
}

class BookingCheckoutPage extends StatefulWidget {
  final Map<String, dynamic> trip;
  final List<dynamic> schedules;
  final int? initialScheduleId;
  final int? initialPickupPointId;
  final bool initialJoinTrip;
  final List<String> initialSeatIds;
  final bool resumeLockedSeats;
  final bool startAtSeatSelection;

  const BookingCheckoutPage({
    super.key,
    required this.trip,
    required this.schedules,
    this.initialScheduleId,
    this.initialPickupPointId,
    this.initialJoinTrip = false,
    this.initialSeatIds = const [],
    this.resumeLockedSeats = false,
    this.startAtSeatSelection = false,
  });

  @override
  State<BookingCheckoutPage> createState() => _BookingCheckoutPageState();
}

class _BookingCheckoutPageState extends State<BookingCheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _travelerFormKey = GlobalKey();
  final _promo = TextEditingController();
  final _groupNotes = TextEditingController();
  final List<_PassengerControllers> _passengers = [_PassengerControllers()];

  // Applied discount code — validated inline so the customer sees the final
  // discount + net total here, before the payment step. {code, type, value}.
  Map<String, dynamic>? _appliedPromo;
  bool _promoLoading = false;
  String? _promoError;

  int? _scheduleId;
  int? _pickupPointId;
  String? _pickupRegion;
  // จุดรับที่ลูกค้าปักหมุดเอง { label, lat, lng, note } — ใช้เมื่อไม่ได้เลือกจุดที่กำหนด
  Map<String, dynamic>? _customPickup;
  bool _submitting = false;
  bool _showPricingDetails = false;
  bool _seatLoading = false;
  bool _seatRefreshing = false;
  int? _realtimeScheduleId;
  final List<VoidCallback> _realtimeDisposers = [];
  int _currentStep = 0;
  String? _seatError;
  Map<String, dynamic>? _seatMap;
  int? _seatMapScheduleId;
  bool _isJoinTrip = false;
  Timer? _seatRefreshTimer;
  final Set<String> _selectedSeatIds = <String>{};
  final Set<String> _lockedSeatIds = <String>{};
  final Set<int> _selectedAddonIndexes = <int>{};

  Map<String, dynamic> get _selectedSchedule {
    if (widget.schedules.isEmpty) return <String, dynamic>{};

    return asMap(
      widget.schedules.firstWhere(
        (item) => asMap(item)['id'].toString() == _scheduleId.toString(),
        orElse: () => widget.schedules.first,
      ),
    );
  }

  List<dynamic> get _pickupPoints => asList(_selectedSchedule['pickup_points']);

  Map<String, dynamic> get _selectedPickupPoint {
    if (_pickupPoints.isEmpty) return <String, dynamic>{};

    return asMap(
      _pickupPoints.firstWhere(
        (item) => asMap(item)['id'].toString() == _pickupPointId.toString(),
        orElse: () => _pickupPoints.first,
      ),
    );
  }

  _PricingQuote get _pricing => _PricingQuote.fromPassengers(
    passengers: _passengers,
    schedule: _selectedSchedule,
    isJoinTrip: _isJoinTrip,
    pickupPoints: _pickupPoints,
    selectedAddons: _selectedAddonOptions,
    appliedPromo: _appliedPromo,
  );

  /// Validate the entered code and, on success, apply it inline so the discount
  /// and net total update immediately. Mirrors the backend's validate rules;
  /// the final amount is re-verified server-side at booking submit.
  Future<void> _applyPromo() async {
    final code = _promo.text.trim().toUpperCase();
    if (code.isEmpty || _promoLoading) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _promoLoading = true;
      _promoError = null;
    });

    final app = context.read<AppProvider>();
    try {
      final res = await app.api.post(
        'promotions/validate',
        body: {'code': code, 'trip_id': widget.trip['id']},
      );
      final promotion = asMap(asMap(res)['promotion']);
      if (!mounted) return;
      setState(() {
        _promo.text = code;
        _appliedPromo = {
          'code': code,
          'type': textOf(promotion['type']),
          'value': _asNum(promotion['value']),
        };
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _appliedPromo = null;
        _promoError = e.message.isNotEmpty
            ? e.message
            : 'โค้ดส่วนลดไม่ถูกต้องหรือใช้งานไม่ได้';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _appliedPromo = null;
        _promoError = 'ตรวจสอบโค้ดไม่สำเร็จ กรุณาลองใหม่';
      });
    } finally {
      if (mounted) setState(() => _promoLoading = false);
    }
  }

  void _removePromo() {
    setState(() {
      _appliedPromo = null;
      _promoError = null;
      _promo.clear();
    });
  }

  List<_AddonOption> get _addonOptions => _addonOptionsFrom(widget.trip);

  List<_AddonOption> get _selectedAddonOptions => _addonOptions
      .where((option) => _selectedAddonIndexes.contains(option.index))
      .toList(growable: false);

  bool get _selectedScheduleAllowsJoinTrip =>
      _asBool(_selectedSchedule['join_trip_enabled']);

  bool get _hasSeatMap => !_isJoinTrip && _seatMap?['has_seat_map'] == true;

  bool get _usesSeatStep =>
      !_isJoinTrip && (_seatLoading || _seatMap == null || _hasSeatMap);

  List<String> get _stepLabels => _usesSeatStep
      ? const ['จุดขึ้นรถ', 'เลือกที่นั่ง', 'ข้อมูลผู้โดยสาร']
      : const ['จุดขึ้นรถ', 'ข้อมูลผู้โดยสาร'];

  int get _seatStepIndex => 1;

  int get _passengerStepIndex => _usesSeatStep ? 2 : 1;

  int get _safeCurrentStep {
    final lastIndex = _stepLabels.length - 1;
    if (_currentStep > lastIndex) return lastIndex;
    return _currentStep;
  }

  List<String> get _selectedSeatList => _selectedSeatIds.toList()..sort();

  @override
  void initState() {
    super.initState();
    final initialSchedule = _initialSchedule();
    _scheduleId = int.tryParse(initialSchedule['id'].toString());
    _isJoinTrip =
        widget.initialJoinTrip && _asBool(initialSchedule['join_trip_enabled']);
    _syncPickup(
      initialSchedule,
      preferredPickupPointId: widget.initialPickupPointId,
    );
    final initialSeatIds = widget.initialSeatIds
        .where((seatId) => seatId.isNotEmpty)
        .toSet();
    if (initialSeatIds.isNotEmpty) {
      _selectedSeatIds.addAll(initialSeatIds);
      _lockedSeatIds.addAll(initialSeatIds);
      _syncPassengerCount(initialSeatIds.length);
      if (widget.resumeLockedSeats) {
        _currentStep = _passengerStepIndex;
      }
    }
    if (widget.startAtSeatSelection) {
      _currentStep = _seatStepIndex;
    }
    if (!_isJoinTrip) {
      _loadSeatMap(preserveSelection: initialSeatIds.isNotEmpty);
    }
  }

  @override
  void dispose() {
    _stopSeatRealtimeRefresh();
    _promo.dispose();
    _groupNotes.dispose();
    for (final passenger in _passengers) {
      passenger.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _initialSchedule() {
    if (widget.schedules.isEmpty) return <String, dynamic>{};

    return asMap(
      widget.schedules.firstWhere(
        (item) =>
            asMap(item)['id'].toString() == widget.initialScheduleId.toString(),
        orElse: () => widget.schedules.first,
      ),
    );
  }

  void _syncPickup(
    Map<String, dynamic> schedule, {
    int? preferredPickupPointId,
    String? preferredRegion,
  }) {
    final points = asList(schedule['pickup_points']);
    if (points.isNotEmpty) {
      final point = _preferredPickupPoint(
        points,
        preferredPickupPointId: preferredPickupPointId,
        preferredRegion: preferredRegion,
      );
      _pickupPointId = int.tryParse(point['id'].toString());
      _pickupRegion = _pickupRegionKey(point);
      // Pre-fill passengers that don't have their own pickup selected
      for (final p in _passengers) {
        if (p.pickupPointId.value == null) p.pickupPointId.value = _pickupPointId;
      }
    } else {
      _pickupPointId = null;
      _pickupRegion = null;
    }
  }

  void _addPassenger() {
    HapticFeedback.selectionClick();
    setState(() {
      final p = _PassengerControllers();
      p.pickupPointId.value = _pickupPointId;
      _passengers.add(p);
    });
  }

  void _removePassenger() {
    if (_passengers.length == 1) return;
    HapticFeedback.selectionClick();
    setState(() => _passengers.removeLast().dispose());
  }

  void _fillPassengerFromProfile(int index) {
    final user = context.read<AppProvider>().user;
    if (user == null || user.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อนดึงข้อมูลโปรไฟล์')),
      );
      return;
    }
    if (index < 0 || index >= _passengers.length) return;

    HapticFeedback.selectionClick();
    setState(() => _passengers[index].applyProfile(user));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ดึงข้อมูลโปรไฟล์ให้ผู้เดินทางคนที่ ${index + 1} แล้ว'),
      ),
    );
  }

  Future<void> _fillPassengerFromWallet(int index) async {
    if (index < 0 || index >= _passengers.length) return;
    final wallet = await DocumentWallet.load();
    if ((wallet['name'] as String).isEmpty &&
        (wallet['phone'] as String).isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('ยังไม่มีข้อมูลใน Wallet กรุณาบันทึกก่อนใช้งาน'),
          action: SnackBarAction(
            label: 'เปิด Wallet',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const DocumentWalletScreen()),
            ),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    HapticFeedback.selectionClick();
    setState(() => _passengers[index].applyWallet(wallet));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('กรอกข้อมูล Wallet ให้ผู้เดินทางคนที่ ${index + 1} แล้ว'),
      ),
    );
  }

  Future<void> _loadSeatMap({
    bool silent = false,
    bool preserveSelection = false,
  }) async {
    if (silent && _seatRefreshing) return;

    final scheduleId = _scheduleId;
    if (scheduleId == null) {
      _stopSeatRealtimeRefresh();
      setState(() {
        _seatMap = null;
        _seatMapScheduleId = null;
        _seatError = null;
        _selectedSeatIds.clear();
        _lockedSeatIds.clear();
      });
      return;
    }

    if (silent) {
      _seatRefreshing = true;
    } else {
      setState(() {
        _seatLoading = true;
        _seatError = null;
        _seatMapScheduleId = scheduleId;
        _seatMap = null;
        if (!preserveSelection) {
          _selectedSeatIds.clear();
          _lockedSeatIds.clear();
          _syncPassengerCount(1);
        }
      });
    }

    try {
      final seatMap = await context.read<AppProvider>().seats(scheduleId);
      if (!mounted || _seatMapScheduleId != scheduleId) return;
      var removedSeats = <String>[];
      setState(() {
        _seatMap = seatMap;
        if (silent || preserveSelection) {
          removedSeats = _reconcileSelectedSeats(seatMap);
        }
      });
      if (silent && removedSeats.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ที่นั่ง ${removedSeats.join(', ')} มีผู้ใช้อื่นกำลังจองอยู่แล้ว',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted || _seatMapScheduleId != scheduleId) return;
      if (!silent) setState(() => _seatError = e.toString());
    } finally {
      if (silent) {
        _seatRefreshing = false;
      } else if (mounted && _seatMapScheduleId == scheduleId) {
        setState(() => _seatLoading = false);
      }
    }
  }

  void _startSeatRealtimeRefresh() {
    _stopSeatRealtimeRefresh();
    if (_scheduleId == null) return;
    final pollInterval = ApiConfig.hasRealtimeConfig
        ? const Duration(seconds: 20)
        : _seatRefreshInterval;
    _seatRefreshTimer = Timer.periodic(pollInterval, (_) {
      if (!mounted) return;
      if (!_usesSeatStep || _safeCurrentStep != _seatStepIndex) return;
      _loadSeatMap(silent: true);
    });
    _bindRealtimeChannel();
  }

  void _stopSeatRealtimeRefresh() {
    _seatRefreshTimer?.cancel();
    _seatRefreshTimer = null;
    _seatRefreshing = false;
    _unbindRealtimeChannel();
  }

  Future<void> _bindRealtimeChannel() async {
    if (!ApiConfig.hasRealtimeConfig) return;
    final scheduleId = _scheduleId;
    if (scheduleId == null) return;
    if (_realtimeScheduleId == scheduleId && _realtimeDisposers.isNotEmpty) {
      return;
    }
    _unbindRealtimeChannel();
    _realtimeScheduleId = scheduleId;

    void onSeatEvent(Map<String, dynamic> _) {
      if (!mounted) return;
      if (_scheduleId != scheduleId) return;
      _loadSeatMap(silent: true);
    }

    final channel = 'private-schedule.$scheduleId';
    for (final event in const ['SeatLocked', 'SeatBooked', 'SeatReleased']) {
      final disposer = await RealtimeService.instance.subscribe(
        channel: channel,
        event: event,
        handler: onSeatEvent,
      );
      _realtimeDisposers.add(disposer);
    }
  }

  void _unbindRealtimeChannel() {
    for (final dispose in _realtimeDisposers) {
      dispose();
    }
    _realtimeDisposers.clear();
    _realtimeScheduleId = null;
  }

  List<String> _reconcileSelectedSeats(Map<String, dynamic> seatMap) {
    if (_selectedSeatIds.isEmpty) return const <String>[];

    final availableSeatIds = <String>{};
    for (final item in asList(seatMap['seats'])) {
      final seat = asMap(item);
      final id = textOf(seat['id']);
      if (id.isEmpty) continue;
      if (_isSeatAvailable(seat) || _seatLockedByCurrentUser(seat)) {
        availableSeatIds.add(id);
      }
    }

    final removedSeats =
        _selectedSeatIds
            .where((seatId) => !availableSeatIds.contains(seatId))
            .toList()
          ..sort();
    if (removedSeats.isEmpty) return const <String>[];

    _selectedSeatIds.removeAll(removedSeats);
    _lockedSeatIds.removeAll(removedSeats);
    _syncPassengerCount(_selectedSeatIds.isEmpty ? 1 : _selectedSeatIds.length);
    return removedSeats;
  }

  void _toggleSeat(Map<String, dynamic> seat) {
    final id = textOf(seat['id']);
    if (id.isEmpty || !_isSeatAvailable(seat)) return;

    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedSeatIds.contains(id)) {
        _selectedSeatIds.remove(id);
      } else {
        _selectedSeatIds.add(id);
      }
      _lockedSeatIds.clear();
      _syncPassengerCount(
        _selectedSeatIds.isEmpty ? 1 : _selectedSeatIds.length,
      );
    });
  }

  void _syncPassengerCount(int count) {
    final target = count < 1 ? 1 : count;
    while (_passengers.length < target) {
      _passengers.add(_PassengerControllers());
    }
    while (_passengers.length > target) {
      _passengers.removeLast().dispose();
    }
  }

  Future<void> _lockSelectedSeatsIfNeeded() async {
    if (_isJoinTrip) return;
    if (!_hasSeatMap) return;
    if (_scheduleId == null) return;
    if (_selectedSeatIds.isEmpty) {
      throw const _CheckoutValidationException('กรุณาเลือกที่นั่ง');
    }
    if (_lockedSeatIds.length == _selectedSeatIds.length &&
        _lockedSeatIds.containsAll(_selectedSeatIds)) {
      return;
    }

    final seatIds = _selectedSeatList;
    final result = await context.read<AppProvider>().lockSeats(
      _scheduleId!,
      seatIds,
      pickupPointId: _pickupPointId,
      pickupRegion: _pickupRegion,
    );
    if (result['locked'] != true) {
      throw _CheckoutValidationException(
        textOf(result['message'], 'ไม่สามารถล็อคที่นั่งได้'),
      );
    }
    _lockedSeatIds
      ..clear()
      ..addAll(seatIds);
  }

  Future<void> _unlockLockedSeats() async {
    if (_scheduleId == null || _lockedSeatIds.isEmpty) return;
    final seatIds = _lockedSeatIds.toList();
    _lockedSeatIds.clear();
    try {
      await context.read<AppProvider>().unlockSeats(_scheduleId!, seatIds);
    } catch (_) {
      // Seat locks expire automatically; checkout should still recover gracefully.
    }
  }

  /// จุดเริ่มต้นแผนที่ = พิกัดจุดรับแรกของรอบ (ถ้ามี) มิฉะนั้น center กรุงเทพฯ
  LatLng _pickupMapCenter() {
    for (final raw in _pickupPoints) {
      final p = asMap(raw);
      final lat = double.tryParse('${p['latitude']}');
      final lng = double.tryParse('${p['longitude']}');
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    return const LatLng(13.7563, 100.5018);
  }

  Future<void> _openCustomPickup() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomPickupPickerScreen(
          center: _pickupMapCenter(),
          initial: _customPickup,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _customPickup = result;
      // จุด custom กับจุดที่กำหนด เลือกได้อย่างใดอย่างหนึ่ง
      _pickupPointId = null;
      _pickupRegion = null;
      for (final p in _passengers) {
        p.pickupPointId.value = null;
      }
    });
  }

  void _clearCustomPickup() {
    setState(() => _customPickup = null);
  }

  bool _validatePickupStep() {
    if (_scheduleId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาเลือกรอบเดินทาง')));
      return false;
    }
    if (_isJoinTrip) {
      if (!_selectedScheduleAllowsJoinTrip) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('รอบนี้ยังไม่เปิดจองแบบ Join Trip')),
        );
        return false;
      }
      return true;
    }
    // ปักหมุดจุดรับเองแล้ว ถือว่าเลือกจุดรับครบ ข้ามการบังคับเลือกจุดที่กำหนด
    if (_customPickup != null) return true;
    // รอบที่ไม่มีจุดขึ้นรถตายตัว → บังคับให้ปักหมุดจุดรับเอง (กันการจองที่ไม่มีจุดรับ)
    if (_pickupPoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาปักหมุดจุดรับของคุณบนแผนที่')),
      );
      return false;
    }
    if (_pickupRegion == null || _pickupRegion!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกภูมิภาคที่จะขึ้นรถ หรือปักหมุดจุดรับเอง')),
      );
      return false;
    }
    if (_pickupPointId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาเลือกจุดขึ้นรถ หรือปักหมุดจุดรับเอง')));
      return false;
    }
    return true;
  }

  bool _validateSeatStep() {
    if (!_hasSeatMap) return true;
    if (_selectedSeatIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาเลือกที่นั่ง')));
      return false;
    }
    return true;
  }

  Future<void> _goNext() async {
    FocusScope.of(context).unfocus();
    final step = _safeCurrentStep;

    if (step == 0) {
      if (!_validatePickupStep()) return;
      setState(
        () =>
            _currentStep = _usesSeatStep ? _seatStepIndex : _passengerStepIndex,
      );
      if (_usesSeatStep) _startSeatRealtimeRefresh();
      return;
    }

    if (_usesSeatStep && step == _seatStepIndex) {
      if (_seatLoading) return;
      if (!_validateSeatStep()) return;
      setState(() => _submitting = true);
      try {
        await _lockSelectedSeatsIfNeeded();
        _stopSeatRealtimeRefresh();
        if (mounted) setState(() => _currentStep = _passengerStepIndex);
      } catch (e) {
        await _unlockLockedSeats();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
      return;
    }

    await _submit();
  }

  void _goBack() {
    FocusScope.of(context).unfocus();
    final step = _safeCurrentStep;
    if (step == 0) {
      Navigator.pop(context);
      return;
    }
    if (step == _passengerStepIndex) {
      _unlockLockedSeats();
    }
    if (step == _seatStepIndex) {
      _stopSeatRealtimeRefresh();
    }
    setState(() => _currentStep = step - 1);
    if (step == _passengerStepIndex && _usesSeatStep) {
      _startSeatRealtimeRefresh();
    }
  }

  String get _primaryActionLabel {
    final step = _safeCurrentStep;
    if (step == 0) {
      return _usesSeatStep ? 'ไปเลือกที่นั่ง' : 'ไปกรอกข้อมูลผู้โดยสาร';
    }
    if (_usesSeatStep && step == _seatStepIndex) {
      if (_submitting) return 'กำลังล็อคที่นั่ง...';
      return 'ไปกรอกข้อมูลผู้โดยสาร';
    }
    return _submitting ? 'กำลังส่งข้อมูล...' : 'ดำเนินการชำระเงิน';
  }

  IconData get _primaryActionIcon {
    final step = _safeCurrentStep;
    if (step == 0) return Icons.arrow_forward_rounded;
    if (_usesSeatStep && step == _seatStepIndex) return Icons.event_seat_rounded;
    return Icons.payment_rounded;
  }

  Widget _buildCurrentStepContent() {
    final step = _safeCurrentStep;

    if (step == 0) {
      return TravelInfoSection(
        key: const ValueKey('pickup-step'),
        scheduleId: _scheduleId,
        schedules: widget.schedules,
        isJoinTrip: _isJoinTrip,
        pickupRegion: _pickupRegion,
        pickupPointId: _pickupPointId,
        pickupPoints: _pickupPoints,
        customPickup: _customPickup,
        onCustomPickupTap: _openCustomPickup,
        onCustomPickupClear: _clearCustomPickup,
        onScheduleChanged: (value) {
          final nextSchedule = asMap(
            widget.schedules.firstWhere(
              (item) => asMap(item)['id'].toString() == value.toString(),
              orElse: () => widget.schedules.first,
            ),
          );
          _unlockLockedSeats();
          _stopSeatRealtimeRefresh();
          setState(() {
            _scheduleId = value;
            if (_isJoinTrip && !_asBool(nextSchedule['join_trip_enabled'])) {
              _isJoinTrip = false;
            }
            _syncPickup(nextSchedule, preferredRegion: _pickupRegion);
          });
          _loadSeatMap();
        },
        onJoinTripChanged: (value) {
          _unlockLockedSeats();
          _stopSeatRealtimeRefresh();
          setState(() {
            _isJoinTrip = value && _selectedScheduleAllowsJoinTrip;
            if (_isJoinTrip) {
              _selectedSeatIds.clear();
              _lockedSeatIds.clear();
              _seatError = null;
            }
          });
          if (!_isJoinTrip) _loadSeatMap();
        },
        onRegionChanged: (value) {
          final point = _preferredPickupPoint(
            _pickupPoints,
            preferredRegion: value,
          );
          final newPickupId = int.tryParse(point['id'].toString());
          setState(() {
            _pickupRegion = _pickupRegionKey(point).isNotEmpty
                ? _pickupRegionKey(point)
                : value;
            _pickupPointId = newPickupId;
            _customPickup = null; // เลือกจุดที่กำหนด → ยกเลิกจุดที่ปักเอง
            for (final p in _passengers) {
              p.pickupPointId.value = newPickupId;
            }
          });
        },
        onPickupChanged: (value) {
          final point = asMap(
            _pickupPoints.firstWhere(
              (item) => asMap(item)['id'].toString() == value.toString(),
              orElse: () => _pickupPoints.first,
            ),
          );
          setState(() {
            _pickupPointId = value;
            _pickupRegion = _pickupRegionKey(point);
            _customPickup = null; // เลือกจุดที่กำหนด → ยกเลิกจุดที่ปักเอง
            // Update all passengers to use the new global pickup
            for (final p in _passengers) {
              p.pickupPointId.value = value;
            }
          });
        },
      );
    }

    if (_usesSeatStep && step == _seatStepIndex) {
      return SeatSelectionSection(
        key: const ValueKey('seat-step'),
        seatMap: _seatMap,
        isLoading: _seatLoading,
        error: _seatError,
        selectedSeatIds: _selectedSeatIds,
        onSeatTap: _toggleSeat,
        onRetry: _loadSeatMap,
      );
    }

    return Column(
      key: const ValueKey('passenger-step'),
      children: [
        TravelerFormSection(
          key: _travelerFormKey,
          passengers: _passengers,
          groupNotes: _groupNotes,
          isSeatSelectionMode: _hasSeatMap,
          selectedSeatIds: _hasSeatMap ? _selectedSeatList : const <String>[],
          pickupPoints: _isJoinTrip ? const [] : _pickupPoints,
          onAddPassenger: _addPassenger,
          onRemovePassenger: _removePassenger,
          onUseProfile: _fillPassengerFromProfile,
          onUseWallet: _fillPassengerFromWallet,
        ),
        const SizedBox(height: 24),
        if (_addonOptions.isNotEmpty) ...[
          AddonSelectionSection(
            addons: _addonOptions,
            selectedIndexes: _selectedAddonIndexes,
            travelerCount: _passengers.length,
            onChanged: (index, selected) {
              setState(() {
                if (selected) {
                  _selectedAddonIndexes.add(index);
                } else {
                  _selectedAddonIndexes.remove(index);
                }
              });
            },
          ),
          const SizedBox(height: 24),
        ],
        PricingSummaryCard(
          pricing: _pricing,
          promoController: _promo,
          expanded: _showPricingDetails,
          onExpandedChanged: () {
            setState(() => _showPricingDetails = !_showPricingDetails);
          },
          appliedPromo: _appliedPromo,
          promoLoading: _promoLoading,
          promoError: _promoError,
          onApplyPromo: _applyPromo,
          onRemovePromo: _removePromo,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isKeyboardOpen = bottomInset > 0;
    final pricing = _pricing;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Form(
          key: _formKey,
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const BouncingScrollPhysics(),
            slivers: [
              const TravelSliverAppBar(
                title: 'จองทริปเดินทาง',
                showBackButton: true,
              ),
              SliverToBoxAdapter(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final horizontalPadding = constraints.maxWidth < 390
                        ? 16.0
                        : 20.0;

                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        16,
                        horizontalPadding,
                        isKeyboardOpen ? 32 : 132,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          BookingProgressStepper(
                            currentStep: _safeCurrentStep,
                            steps: _stepLabels,
                          ),
                          const SizedBox(height: 16),
                          TripSummaryCard(
                            trip: widget.trip,
                            schedule: _selectedSchedule,
                            pickupPoint: _selectedPickupPoint,
                            pricePerTraveler: pricing.pricePerTraveler,
                            isJoinTrip: _isJoinTrip,
                          ),
                          const SizedBox(height: 24),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: _buildCurrentStepContent(),
                          ),
                          // Quiet reassurance footer — sits just above the
                          // sticky checkout bar, near the commit action.
                          const SizedBox(height: 24),
                          const TrustSignalsSection(),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: isKeyboardOpen
          ? null
          : StickyCheckoutBar(
              total: pricing.total,
              isSubmitting: _submitting,
              canGoBack: _safeCurrentStep > 0,
              primaryLabel: _primaryActionLabel,
              primaryIcon: _primaryActionIcon,
              onBack: _goBack,
              onPressed: _submitting ? null : _goNext,
            ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_scheduleId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาเลือกรอบเดินทาง')));
      return;
    }
    if (_isJoinTrip) {
      if (!_selectedScheduleAllowsJoinTrip) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('รอบนี้ยังไม่เปิดจองแบบ Join Trip')),
        );
        return;
      }
    } else if (_customPickup == null) {
      // ปักหมุดจุดรับเองแล้ว ถือว่าเลือกจุดรับครบ — ข้ามการบังคับเลือกจุดที่กำหนด
      // รอบที่ไม่มีจุดขึ้นรถตายตัว → บังคับให้ปักหมุดจุดรับเอง
      if (_pickupPoints.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาปักหมุดจุดรับของคุณบนแผนที่')),
        );
        return;
      }
      if (_pickupRegion == null || _pickupRegion!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาเลือกภูมิภาคที่จะขึ้นรถ หรือปักหมุดจุดรับเอง')),
        );
        return;
      }
      if (_pickupPointId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาเลือกจุดขึ้นรถ หรือปักหมุดจุดรับเอง')),
        );
        return;
      }
    }
    if (_hasSeatMap && _selectedSeatIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาเลือกที่นั่ง')));
      return;
    }
    // Validate per-passenger pickup points (ข้ามเมื่อปักหมุดจุดรับเอง)
    if (!_isJoinTrip && _customPickup == null && _pickupPoints.isNotEmpty) {
      for (var i = 0; i < _passengers.length; i++) {
        if (_passengers[i].pickupPointId.value == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('กรุณาเลือกจุดขึ้นรถสำหรับผู้เดินทางคนที่ ${i + 1}')),
          );
          return;
        }
      }
    }
    if (!_formKey.currentState!.validate()) {
      final ctx = _travelerFormKey.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          alignment: 0.0,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบถ้วนก่อนดำเนินการ')),
        );
      }
      return;
    }

    setState(() => _submitting = true);
    final app = context.read<AppProvider>();
    try {
      await _lockSelectedSeatsIfNeeded();
      final booking = await app.createBooking({
        'schedule_id': _scheduleId,
        // ปักหมุดเอง = ไม่ส่ง region/จุดตายตัว ไม่งั้น backend จับคู่จุดตายตัวแล้วมองข้ามหมุด
        'pickup_point_id': (_isJoinTrip || _customPickup != null) ? null : _pickupPointId,
        'pickup_region': (_isJoinTrip || _customPickup != null) ? null : _pickupRegion,
        // จุดรับที่ปักหมุดเอง — ส่งเมื่อไม่ได้เลือกจุดที่กำหนด รอแอดมินยืนยันราคา
        if (!_isJoinTrip && _pickupPointId == null && _customPickup != null) ...{
          'custom_pickup_label': _customPickup!['label'],
          'custom_pickup_lat': _customPickup!['lat'],
          'custom_pickup_lng': _customPickup!['lng'],
          'custom_pickup_note': _customPickup!['note'],
        },
        'is_group': _passengers.length > 1,
        'group_name': _passengers.length > 1
            ? 'กลุ่ม ${_passengers.length} คน'
            : null,
        'group_notes': _groupNotes.text.trim().isEmpty
            ? null
            : _groupNotes.text.trim(),
        // Only the inline-validated code is sent, so the charge matches the
        // discount previewed here (backend re-verifies authoritatively).
        'promotion_code': _appliedPromo != null
            ? textOf(_appliedPromo!['code'])
            : null,
        'seat_ids': _hasSeatMap ? _selectedSeatList : <String>[],
        'is_join_trip': _isJoinTrip,
        if (_selectedAddonIndexes.isNotEmpty)
          'selected_addons': (_selectedAddonIndexes.toList()..sort()),
        'passengers': _passengers.map((p) => p.payload()).toList(),
      });
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PaymentScreen(bookingRef: textOf(booking['booking_ref'])),
        ),
      );
    } catch (e) {
      await _unlockLockedSeats();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

