import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/travel_widgets.dart';
import 'payment_screen.dart';

const Color _pageBackground = Color(0xFFF8F8F8);
const Color _premiumText = Color(0xFF111827);
const Color _mutedText = Color(0xFF6B7280);
const Color _softAccent = Color(0xFF0F8F75);
const Color _cardBorder = Color(0xFFEAEAEA);
const Color _fieldBackground = Color(0xFFF7F8F7);
const List<String> _titleOptions = ['นาย', 'นาง', 'นางสาว'];
const List<String> _bloodGroupOptions = ['A', 'B', 'O', 'AB'];
const Duration _seatRefreshInterval = Duration(seconds: 5);

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

  const BookingFlowScreen({
    super.key,
    required this.trip,
    required this.schedules,
    this.initialScheduleId,
    this.initialPickupPointId,
  });

  @override
  Widget build(BuildContext context) {
    return BookingCheckoutPage(
      trip: trip,
      schedules: schedules,
      initialScheduleId: initialScheduleId,
      initialPickupPointId: initialPickupPointId,
    );
  }
}

class BookingCheckoutPage extends StatefulWidget {
  final Map<String, dynamic> trip;
  final List<dynamic> schedules;
  final int? initialScheduleId;
  final int? initialPickupPointId;

  const BookingCheckoutPage({
    super.key,
    required this.trip,
    required this.schedules,
    this.initialScheduleId,
    this.initialPickupPointId,
  });

  @override
  State<BookingCheckoutPage> createState() => _BookingCheckoutPageState();
}

class _BookingCheckoutPageState extends State<BookingCheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _promo = TextEditingController();
  final _groupNotes = TextEditingController();
  final List<_PassengerControllers> _passengers = [_PassengerControllers()];

  int? _scheduleId;
  int? _pickupPointId;
  String? _pickupRegion;
  bool _submitting = false;
  bool _showPricingDetails = false;
  bool _seatLoading = false;
  bool _seatRefreshing = false;
  bool _activeSeatLocksLoading = false;
  int _currentStep = 0;
  String? _seatError;
  Map<String, dynamic>? _seatMap;
  int? _seatMapScheduleId;
  Timer? _seatRefreshTimer;
  Timer? _activeSeatLockRefreshTimer;
  int? _activeSeatLockActionScheduleId;
  List<dynamic> _activeSeatLocks = const [];
  final Set<String> _selectedSeatIds = <String>{};
  final Set<String> _lockedSeatIds = <String>{};

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

  _PricingQuote get _pricing => _PricingQuote.from(
    trip: widget.trip,
    schedule: _selectedSchedule,
    pickupPoint: _selectedPickupPoint,
    travelerCount: _passengers.length,
  );

  bool get _hasSeatMap => _seatMap?['has_seat_map'] == true;

  bool get _usesSeatStep => _seatLoading || _seatMap == null || _hasSeatMap;

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
    _syncPickup(
      initialSchedule,
      preferredPickupPointId: widget.initialPickupPointId,
    );
    _loadSeatMap();
    _loadActiveSeatLocks();
    _startActiveSeatLockRefresh();
  }

  @override
  void dispose() {
    _stopSeatRealtimeRefresh();
    _stopActiveSeatLockRefresh();
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
      _pickupRegion = point['region']?.toString();
    } else {
      _pickupPointId = null;
      _pickupRegion = null;
    }
  }

  void _addPassenger() {
    HapticFeedback.selectionClick();
    setState(() => _passengers.add(_PassengerControllers()));
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

  Future<void> _loadSeatMap({bool silent = false}) async {
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
        _selectedSeatIds.clear();
        _lockedSeatIds.clear();
        _syncPassengerCount(1);
      });
    }

    try {
      final seatMap = await context.read<AppProvider>().seats(scheduleId);
      if (!mounted || _seatMapScheduleId != scheduleId) return;
      var removedSeats = <String>[];
      setState(() {
        _seatMap = seatMap;
        if (silent) {
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
    _seatRefreshTimer = Timer.periodic(_seatRefreshInterval, (_) {
      if (!mounted) return;
      if (!_usesSeatStep || _safeCurrentStep != _seatStepIndex) return;
      _loadSeatMap(silent: true);
    });
  }

  void _stopSeatRealtimeRefresh() {
    _seatRefreshTimer?.cancel();
    _seatRefreshTimer = null;
    _seatRefreshing = false;
  }

  void _startActiveSeatLockRefresh() {
    _stopActiveSeatLockRefresh();
    _activeSeatLockRefreshTimer = Timer.periodic(_seatRefreshInterval, (_) {
      if (!mounted) return;
      _loadActiveSeatLocks(silent: true);
    });
  }

  void _stopActiveSeatLockRefresh() {
    _activeSeatLockRefreshTimer?.cancel();
    _activeSeatLockRefreshTimer = null;
  }

  Future<void> _loadActiveSeatLocks({bool silent = false}) async {
    if (_activeSeatLocksLoading) return;

    if (!silent && mounted) {
      setState(() => _activeSeatLocksLoading = true);
    } else {
      _activeSeatLocksLoading = true;
    }

    try {
      final locks = await context.read<AppProvider>().activeSeatLocks();
      if (!mounted) return;
      setState(() => _activeSeatLocks = locks);
    } catch (_) {
      if (!silent && mounted) {
        setState(() => _activeSeatLocks = const []);
      }
    } finally {
      if (mounted) {
        setState(() => _activeSeatLocksLoading = false);
      } else {
        _activeSeatLocksLoading = false;
      }
    }
  }

  Future<void> _cancelActiveSeatLock(Map<String, dynamic> lock) async {
    final scheduleId = int.tryParse(textOf(lock['schedule_id']));
    if (scheduleId == null) return;

    final seatIds = asList(lock['seat_ids'])
        .map((item) => item?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    setState(() => _activeSeatLockActionScheduleId = scheduleId);
    try {
      await context.read<AppProvider>().cancelActiveSeatLock(
        scheduleId,
        seatIds: seatIds,
      );
      if (!mounted) return;

      if (scheduleId == _scheduleId) {
        setState(() {
          _selectedSeatIds.removeAll(seatIds);
          _lockedSeatIds.removeAll(seatIds);
          if (_lockedSeatIds.isEmpty) {
            _syncPassengerCount(
              _selectedSeatIds.isEmpty ? 1 : _selectedSeatIds.length,
            );
          }
          if (_usesSeatStep && _safeCurrentStep == _passengerStepIndex) {
            _currentStep = _seatStepIndex;
          }
        });
        if (_usesSeatStep && _safeCurrentStep == _seatStepIndex) {
          _startSeatRealtimeRefresh();
        }
        await _loadSeatMap(silent: true);
      }

      await _loadActiveSeatLocks(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ยกเลิกที่นั่งที่กำลังจองแล้ว')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _activeSeatLockActionScheduleId = null);
      }
    }
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
    );
    if (result['locked'] != true) {
      throw _CheckoutValidationException(
        textOf(result['message'], 'ไม่สามารถล็อคที่นั่งได้'),
      );
    }
    _lockedSeatIds
      ..clear()
      ..addAll(seatIds);
    await _loadActiveSeatLocks(silent: true);
  }

  Future<void> _unlockLockedSeats() async {
    if (_scheduleId == null || _lockedSeatIds.isEmpty) return;
    final seatIds = _lockedSeatIds.toList();
    _lockedSeatIds.clear();
    try {
      await context.read<AppProvider>().unlockSeats(_scheduleId!, seatIds);
    } catch (_) {
      // Seat locks expire automatically; checkout should still recover gracefully.
    } finally {
      if (mounted) {
        await _loadActiveSeatLocks(silent: true);
      }
    }
  }

  bool _validatePickupStep() {
    if (_scheduleId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาเลือกรอบเดินทาง')));
      return false;
    }
    if (_pickupPoints.isNotEmpty &&
        (_pickupRegion == null || _pickupRegion!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกภูมิภาคที่จะขึ้นรถ')),
      );
      return false;
    }
    if (_pickupPoints.isNotEmpty && _pickupPointId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาเลือกจุดขึ้นรถ')));
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
      final shouldRefreshSeats = _usesSeatStep;
      setState(
        () =>
            _currentStep = _usesSeatStep ? _seatStepIndex : _passengerStepIndex,
      );
      if (shouldRefreshSeats) _startSeatRealtimeRefresh();
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
    if (_usesSeatStep && step == _seatStepIndex) return Icons.lock_rounded;
    return Icons.lock_rounded;
  }

  Widget _buildCurrentStepContent() {
    final step = _safeCurrentStep;

    if (step == 0) {
      return TravelInfoSection(
        key: const ValueKey('pickup-step'),
        scheduleId: _scheduleId,
        schedules: widget.schedules,
        pickupRegion: _pickupRegion,
        pickupPointId: _pickupPointId,
        pickupPoints: _pickupPoints,
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
            _syncPickup(nextSchedule, preferredRegion: _pickupRegion);
          });
          _loadSeatMap();
        },
        onRegionChanged: (value) {
          final point = _preferredPickupPoint(
            _pickupPoints,
            preferredRegion: value,
          );
          setState(() {
            _pickupRegion = point['region']?.toString() ?? value;
            _pickupPointId = int.tryParse(point['id'].toString());
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
            _pickupRegion = point['region']?.toString();
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
          passengers: _passengers,
          groupNotes: _groupNotes,
          isSeatSelectionMode: _hasSeatMap,
          selectedSeatIds: _hasSeatMap ? _selectedSeatList : const <String>[],
          onAddPassenger: _addPassenger,
          onRemovePassenger: _removePassenger,
          onUseProfile: _fillPassengerFromProfile,
        ),
        const SizedBox(height: 24),
        PricingSummaryCard(
          pricing: _pricing,
          promoController: _promo,
          expanded: _showPricingDetails,
          onExpandedChanged: () {
            setState(() => _showPricingDetails = !_showPricingDetails);
          },
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
      backgroundColor: _pageBackground,
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
                          ),
                          if (_activeSeatLocks.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            ActiveSeatLocksCard(
                              locks: _activeSeatLocks,
                              actionScheduleId: _activeSeatLockActionScheduleId,
                              onCancel: _cancelActiveSeatLock,
                            ),
                          ],
                          const SizedBox(height: 16),
                          const TrustSignalsSection(),
                          const SizedBox(height: 24),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: _buildCurrentStepContent(),
                          ),
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
    if (_pickupPoints.isNotEmpty &&
        (_pickupRegion == null || _pickupRegion!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกภูมิภาคที่จะขึ้นรถ')),
      );
      return;
    }
    if (_pickupPoints.isNotEmpty && _pickupPointId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาเลือกจุดขึ้นรถ')));
      return;
    }
    if (_hasSeatMap && _selectedSeatIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาเลือกที่นั่ง')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await _lockSelectedSeatsIfNeeded();
      final booking = await context.read<AppProvider>().createBooking({
        'schedule_id': _scheduleId,
        'pickup_point_id': _pickupPointId,
        'pickup_region': _pickupRegion,
        'is_group': _passengers.length > 1,
        'group_name': _passengers.length > 1
            ? 'กลุ่ม ${_passengers.length} คน'
            : null,
        'group_notes': _groupNotes.text.trim().isEmpty
            ? null
            : _groupNotes.text.trim(),
        'promotion_code': _promo.text.trim().isEmpty
            ? null
            : _promo.text.trim().toUpperCase(),
        'seat_ids': _hasSeatMap ? _selectedSeatList : <String>[],
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

class BookingProgressStepper extends StatelessWidget {
  final int currentStep;
  final List<String> steps;

  const BookingProgressStepper({
    super.key,
    required this.currentStep,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: _premiumDecoration(radius: 24),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isActive = index == currentStep;
          final isDone = index < currentStep;

          return Expanded(
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isActive || isDone ? _softAccent : _fieldBackground,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive || isDone
                          ? _softAccent
                          : const Color(0xFFE4E7E5),
                    ),
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(
                            Icons.check_rounded,
                            size: 17,
                            color: Colors.white,
                          )
                        : Text(
                            '${index + 1}',
                            style: GoogleFonts.anuphan(
                              color: isActive ? Colors.white : _mutedText,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    steps[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.anuphan(
                      color: isActive ? _premiumText : _mutedText,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (index != steps.length - 1)
                  Container(
                    width: 18,
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    color: const Color(0xFFE4E7E5),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class TripSummaryCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final Map<String, dynamic> schedule;
  final Map<String, dynamic> pickupPoint;
  final num pricePerTraveler;

  const TripSummaryCard({
    super.key,
    required this.trip,
    required this.schedule,
    required this.pickupPoint,
    required this.pricePerTraveler,
  });

  @override
  Widget build(BuildContext context) {
    final imageCacheSize = _cacheSizeFor(context, width: 104, height: 116);
    final image = ApiConfig.mediaUrl(
      trip['thumbnail_image'] ?? trip['cover_image'],
    );
    final pickupRegionLabel = _pickupRegionLabel(pickupPoint);
    final pickupLocationLabel = _pickupLocationLabel(pickupPoint);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _premiumDecoration(radius: 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RepaintBoundary(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 104,
                height: 116,
                child: image.isEmpty
                    ? const _TripImageFallback()
                    : CachedNetworkImage(
                        imageUrl: image,
                        fit: BoxFit.cover,
                        memCacheWidth: imageCacheSize.width,
                        memCacheHeight: imageCacheSize.height,
                        maxWidthDiskCache: imageCacheSize.width,
                        maxHeightDiskCache: imageCacheSize.height,
                        fadeInDuration: const Duration(milliseconds: 120),
                        fadeOutDuration: Duration.zero,
                        useOldImageOnUrlChange: true,
                        filterQuality: FilterQuality.low,
                        placeholder: (_, __) => const _TripImageFallback(),
                        errorWidget: (_, __, ___) => const _TripImageFallback(),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ทริปที่เลือก', style: _labelStyle()),
                const SizedBox(height: 4),
                Text(
                  textOf(trip['title'], '-'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.anuphan(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    color: _premiumText,
                  ),
                ),
                const SizedBox(height: 12),
                _SummaryMeta(
                  icon: Icons.calendar_month_rounded,
                  text: 'วันที่เดินทาง ${dateText(schedule['departure_date'])}',
                ),
                const SizedBox(height: 8),
                _SummaryMeta(
                  icon: Icons.location_on_rounded,
                  text: 'ภูมิภาค $pickupRegionLabel',
                ),
                const SizedBox(height: 8),
                _SummaryMeta(
                  icon: Icons.directions_bus_filled_rounded,
                  text: 'จุดขึ้นรถ $pickupLocationLabel',
                ),
                const SizedBox(height: 8),
                _SummaryMeta(
                  icon: Icons.payments_rounded,
                  text: 'ราคาต่อคน ${money(pricePerTraveler)}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ActiveSeatLocksCard extends StatelessWidget {
  final List<dynamic> locks;
  final int? actionScheduleId;
  final ValueChanged<Map<String, dynamic>> onCancel;

  const ActiveSeatLocksCard({
    super.key,
    required this.locks,
    required this.actionScheduleId,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _premiumDecoration(radius: 28).copyWith(
        color: const Color(0xFFF0FDF9),
        border: Border.all(color: _softAccent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_rounded, color: _softAccent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ที่นั่งที่กำลังจองอยู่',
                  style: GoogleFonts.anuphan(
                    color: const Color(0xFF126B5B),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...locks.map((item) {
            final lock = asMap(item);
            final scheduleId = int.tryParse(textOf(lock['schedule_id']));
            final isCancelling =
                scheduleId != null && scheduleId == actionScheduleId;
            return _ActiveSeatLockTile(
              lock: lock,
              isCancelling: isCancelling,
              onCancel: isCancelling ? null : () => onCancel(lock),
            );
          }),
        ],
      ),
    );
  }
}

class _ActiveSeatLockTile extends StatelessWidget {
  final Map<String, dynamic> lock;
  final bool isCancelling;
  final VoidCallback? onCancel;

  const _ActiveSeatLockTile({
    required this.lock,
    required this.isCancelling,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final trip = asMap(lock['trip']);
    final schedule = asMap(lock['schedule']);
    final title = textOf(lock['trip_title'], textOf(trip['title'], '-'));
    final seats = asList(lock['seat_ids'])
        .map((item) => item?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    final seatText = seats.isEmpty ? '-' : seats.join(', ');
    final remaining = _lockRemainingLabel(lock['locked_ttl_seconds']);
    final travelDate = _compactScheduleDate(schedule);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _softAccent.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.anuphan(
                color: _premiumText,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InlineStatusChip(
                  icon: Icons.calendar_month_rounded,
                  text: travelDate,
                ),
                _InlineStatusChip(
                  icon: Icons.event_seat_rounded,
                  text: 'ที่นั่ง $seatText',
                ),
                _InlineStatusChip(icon: Icons.timer_rounded, text: remaining),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onCancel,
                icon: isCancelling
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cancel_outlined, size: 18),
                label: Text(isCancelling ? 'กำลังยกเลิก...' : 'ยกเลิก'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                  textStyle: GoogleFonts.anuphan(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineStatusChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InlineStatusChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _fieldBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _softAccent),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.anuphan(
              color: _mutedText,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class TravelInfoSection extends StatelessWidget {
  final int? scheduleId;
  final List<dynamic> schedules;
  final String? pickupRegion;
  final int? pickupPointId;
  final List<dynamic> pickupPoints;
  final ValueChanged<int?> onScheduleChanged;
  final ValueChanged<String?> onRegionChanged;
  final ValueChanged<int?> onPickupChanged;

  const TravelInfoSection({
    super.key,
    required this.scheduleId,
    required this.schedules,
    required this.pickupRegion,
    required this.pickupPointId,
    required this.pickupPoints,
    required this.onScheduleChanged,
    required this.onRegionChanged,
    required this.onPickupChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheduleMaps = schedules
        .map(asMap)
        .where((item) => int.tryParse(item['id'].toString()) != null)
        .toList();
    final selectedScheduleId = _validDropdownValue(
      scheduleId,
      scheduleMaps.map((item) => int.parse(item['id'].toString())),
    );
    final selectedSchedule = selectedScheduleId == null
        ? <String, dynamic>{}
        : scheduleMaps.firstWhere(
            (item) => int.tryParse(item['id'].toString()) == selectedScheduleId,
            orElse: () => <String, dynamic>{},
          );
    final selectedVehicle = asMap(selectedSchedule['vehicle']);
    final pickupMaps = pickupPoints
        .map(asMap)
        .where((item) => int.tryParse(item['id'].toString()) != null)
        .toList();
    final regionMaps = _pickupRegionOptions(pickupMaps);
    final selectedRegion = _validStringDropdownValue(
      pickupRegion,
      regionMaps.map((item) => textOf(item['region'])),
    );
    final filteredPickupMaps = selectedRegion == null
        ? pickupMaps
        : pickupMaps
              .where((point) => textOf(point['region']) == selectedRegion)
              .toList();
    final selectedPickupPointId = _validDropdownValue(
      pickupPointId,
      filteredPickupMaps.map((item) => int.parse(item['id'].toString())),
    );

    return _SectionShell(
      title: 'ข้อมูลการเดินทาง',
      icon: Icons.route_rounded,
      child: Column(
        children: [
          _PremiumDropdown<int>(
            key: ValueKey('schedule-$selectedScheduleId'),
            label: 'รอบเดินทาง',
            icon: Icons.calendar_today_rounded,
            value: selectedScheduleId,
            items: scheduleMaps.map((schedule) {
              final id = int.parse(schedule['id'].toString());
              return DropdownMenuItem<int>(
                value: id,
                child: Text(
                  '${dateText(schedule['departure_date'])}  ·  เหลือ ${textOf(schedule['available_seats'], '0')} ที่',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: onScheduleChanged,
          ),
          const SizedBox(height: 12),
          if (pickupMaps.isEmpty)
            const _CompactNotice(
              icon: Icons.place_outlined,
              text: 'ยังไม่มีจุดรับสำหรับรอบนี้',
            )
          else
            Column(
              children: [
                _PremiumDropdown<String>(
                  key: ValueKey('region-$selectedRegion'),
                  label: 'ภูมิภาคที่จะขึ้นรถ',
                  icon: Icons.travel_explore_rounded,
                  value: selectedRegion,
                  items: regionMaps.map((region) {
                    final value = textOf(region['region']);
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        _pickupRegionLabel(region),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: onRegionChanged,
                ),
                const SizedBox(height: 12),
                if (filteredPickupMaps.isEmpty)
                  const _CompactNotice(
                    icon: Icons.directions_bus_outlined,
                    text: 'ยังไม่มีจุดขึ้นรถในภูมิภาคนี้',
                  )
                else
                  _PremiumDropdown<int>(
                    key: ValueKey(
                      'pickup-$selectedRegion-$selectedPickupPointId',
                    ),
                    label: 'จุดขึ้นรถ',
                    icon: Icons.directions_bus_filled_rounded,
                    value: selectedPickupPointId,
                    items: filteredPickupMaps.map((point) {
                      final id = int.parse(point['id'].toString());
                      final location = _pickupLocationLabel(point);
                      final price = _pickupPriceText(point['price']);
                      final notes = textOf(point['notes']).trim();
                      return DropdownMenuItem<int>(
                        value: id,
                        child: Text(
                          notes.isEmpty
                              ? '$location  ·  $price'
                              : '$location  ·  $notes  ·  $price',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: onPickupChanged,
                  ),
              ],
            ),
          if (selectedVehicle.isNotEmpty) ...[
            const SizedBox(height: 16),
            _VehiclePhotoPreview(vehicle: selectedVehicle),
          ],
        ],
      ),
    );
  }
}

class _VehiclePhotoPreview extends StatefulWidget {
  final Map<String, dynamic> vehicle;

  const _VehiclePhotoPreview({required this.vehicle});

  @override
  State<_VehiclePhotoPreview> createState() => _VehiclePhotoPreviewState();
}

class _VehiclePhotoPreviewState extends State<_VehiclePhotoPreview> {
  final PageController _photoController = PageController();
  int _photoIndex = 0;

  @override
  void didUpdateWidget(covariant _VehiclePhotoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameStringList(
      _vehicleImageUrls(oldWidget.vehicle),
      _vehicleImageUrls(widget.vehicle),
    )) {
      _photoIndex = 0;
      if (_photoController.hasClients) {
        _photoController.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _photoController.dispose();
    super.dispose();
  }

  void _showPhoto(int index) {
    _photoController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _showPreviousPhoto(int total) {
    if (total <= 1) return;
    _showPhoto((_photoIndex - 1 + total) % total);
  }

  void _showNextPhoto(int total) {
    if (total <= 1) return;
    _showPhoto((_photoIndex + 1) % total);
  }

  @override
  Widget build(BuildContext context) {
    final images = _vehicleImageUrls(widget.vehicle);
    final name = textOf(widget.vehicle['name'], 'รถประจำรอบนี้');
    final plate = textOf(widget.vehicle['license_plate']);
    final capacity = textOf(widget.vehicle['capacity']);
    final color = textOf(widget.vehicle['color']);
    final canSlide = images.length > 1;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _fieldBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RepaintBoundary(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: images.isEmpty
                  ? const _VehiclePhotoFallback()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final imageCacheSize = _cacheSizeFor(
                          context,
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                        );

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            PageView.builder(
                              controller: _photoController,
                              itemCount: images.length,
                              onPageChanged: (index) =>
                                  setState(() => _photoIndex = index),
                              itemBuilder: (context, index) {
                                return CachedNetworkImage(
                                  imageUrl: images[index],
                                  fit: BoxFit.cover,
                                  memCacheWidth: imageCacheSize.width,
                                  memCacheHeight: imageCacheSize.height,
                                  maxWidthDiskCache: imageCacheSize.width,
                                  maxHeightDiskCache: imageCacheSize.height,
                                  fadeInDuration: const Duration(
                                    milliseconds: 120,
                                  ),
                                  fadeOutDuration: Duration.zero,
                                  useOldImageOnUrlChange: true,
                                  filterQuality: FilterQuality.low,
                                  placeholder: (_, __) =>
                                      const _VehiclePhotoFallback(),
                                  errorWidget: (_, __, ___) =>
                                      const _VehiclePhotoFallback(),
                                );
                              },
                            ),
                            if (canSlide) ...[
                              Positioned(
                                left: 10,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: _VehiclePhotoNavButton(
                                    icon: Icons.chevron_left_rounded,
                                    onPressed: () =>
                                        _showPreviousPhoto(images.length),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 10,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: _VehiclePhotoNavButton(
                                    icon: Icons.chevron_right_rounded,
                                    onPressed: () =>
                                        _showNextPhoto(images.length),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 10,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(images.length, (
                                    index,
                                  ) {
                                    final selected = index == _photoIndex;
                                    return AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      width: selected ? 18 : 7,
                                      height: 7,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: selected ? 0.95 : 0.55,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.18,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _softAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.directions_bus_filled_rounded,
                    color: _softAccent,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('รถประจำรอบนี้', style: _labelStyle()),
                      const SizedBox(height: 3),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.anuphan(
                          color: _premiumText,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      if (plate.isNotEmpty || capacity.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (plate.isNotEmpty)
                              _VehicleInfoPill(
                                icon: Icons.badge_outlined,
                                text: plate,
                              ),
                            if (capacity.isNotEmpty)
                              _VehicleInfoPill(
                                icon: Icons.event_seat_outlined,
                                text: '$capacity ที่นั่ง',
                              ),
                            if (color.isNotEmpty)
                              _VehicleInfoPill(
                                icon: Icons.palette_outlined,
                                text: color,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleInfoPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _VehicleInfoPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _mutedText, size: 14),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.anuphan(
              color: _mutedText,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehiclePhotoNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _VehiclePhotoNavButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.28),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _VehiclePhotoFallback extends StatelessWidget {
  const _VehiclePhotoFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE7F3EF),
      child: const Center(
        child: Icon(
          Icons.directions_bus_filled_rounded,
          color: _softAccent,
          size: 42,
        ),
      ),
    );
  }
}

class SeatSelectionSection extends StatelessWidget {
  final Map<String, dynamic>? seatMap;
  final bool isLoading;
  final String? error;
  final Set<String> selectedSeatIds;
  final ValueChanged<Map<String, dynamic>> onSeatTap;
  final VoidCallback onRetry;

  const SeatSelectionSection({
    super.key,
    required this.seatMap,
    required this.isLoading,
    required this.error,
    required this.selectedSeatIds,
    required this.onSeatTap,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final map = seatMap ?? <String, dynamic>{};
    final hasSeatMap = map['has_seat_map'] == true;
    final statusCounts = _SeatStatusCounts.from(map);

    return _SectionShell(
      title: 'เลือกที่นั่ง',
      icon: Icons.event_seat_rounded,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: isLoading
            ? const _SeatLoadingState(key: ValueKey('seat-loading'))
            : error != null
            ? _SeatErrorState(
                key: const ValueKey('seat-error'),
                error: error!,
                onRetry: onRetry,
              )
            : !hasSeatMap
            ? _NoSeatMapState(key: const ValueKey('no-seat-map'), seatMap: map)
            : Column(
                key: const ValueKey('seat-map'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SelectedSeatSummary(selectedSeatIds: selectedSeatIds),
                  const SizedBox(height: 14),
                  _SeatRealtimeSummary(
                    counts: statusCounts,
                    refreshInterval: _seatRefreshInterval,
                  ),
                  const SizedBox(height: 14),
                  const _SeatLegend(),
                  const SizedBox(height: 16),
                  _VehicleSeatMap(
                    seatMap: map,
                    selectedSeatIds: selectedSeatIds,
                    onSeatTap: onSeatTap,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'ที่นั่งว่าง ${textOf(map['available_seats'], '0')} / ${textOf(map['total_seats'], '0')}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.anuphan(
                      color: _mutedText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SelectedSeatSummary extends StatelessWidget {
  final Set<String> selectedSeatIds;

  const _SelectedSeatSummary({required this.selectedSeatIds});

  @override
  Widget build(BuildContext context) {
    final seats = selectedSeatIds.toList()..sort();
    final hasSelection = seats.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasSelection
            ? _softAccent.withValues(alpha: 0.08)
            : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasSelection
              ? _softAccent.withValues(alpha: 0.18)
              : const Color(0xFFFDE68A),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasSelection
                ? Icons.airline_seat_recline_extra_rounded
                : Icons.touch_app_rounded,
            color: hasSelection ? _softAccent : AppTheme.warningColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasSelection
                  ? 'ที่นั่งที่เลือก ${seats.join(', ')}'
                  : 'กรุณาเลือกที่นั่งก่อนกรอกข้อมูลผู้เดินทาง',
              style: GoogleFonts.anuphan(
                color: hasSelection
                    ? const Color(0xFF126B5B)
                    : const Color(0xFF92400E),
                fontWeight: FontWeight.w800,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatRealtimeSummary extends StatelessWidget {
  final _SeatStatusCounts counts;
  final Duration refreshInterval;

  const _SeatRealtimeSummary({
    required this.counts,
    required this.refreshInterval,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _softAccent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.sync_rounded, color: _softAccent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'อัปเดตสถานะที่นั่งทุก ${refreshInterval.inSeconds} วินาที ล็อกที่นั่งชั่วคราวได้ไม่เกิน 10 นาที',
                  style: GoogleFonts.anuphan(
                    color: const Color(0xFF126B5B),
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SeatStatusPill(
                color: const Color(0xFFE5E7EB),
                label: 'ว่าง',
                value: counts.available,
              ),
              _SeatStatusPill(
                color: const Color(0xFFCBD5D1),
                label: 'กำลังจอง',
                value: counts.locked,
              ),
              _SeatStatusPill(
                color: const Color(0xFF6B7280),
                label: 'จองแล้ว',
                value: counts.booked,
              ),
            ],
          ),
          if (counts.lockedSeatLabels.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'กำลังจองอยู่: ${counts.lockedSeatLabels.take(4).join(', ')}${counts.lockedSeatLabels.length > 4 ? ' ...' : ''}',
              style: GoogleFonts.anuphan(
                color: const Color(0xFF126B5B),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SeatStatusPill extends StatelessWidget {
  final Color color;
  final String label;
  final int value;

  const _SeatStatusPill({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = color.computeLuminance() < 0.5
        ? Colors.white
        : _premiumText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Text(
        '$label $value',
        style: GoogleFonts.anuphan(
          color: textColor,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SeatLegend extends StatelessWidget {
  const _SeatLegend();

  @override
  Widget build(BuildContext context) {
    const items = [
      _SeatLegendItem(Color(0xFFE5E7EB), 'ว่าง'),
      _SeatLegendItem(_softAccent, 'กำลังเลือก'),
      _SeatLegendItem(Color(0xFFCBD5D1), 'ล็อคอยู่'),
      _SeatLegendItem(Color(0xFF6B7280), 'จองแล้ว'),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: item.color,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              item.label,
              style: GoogleFonts.anuphan(
                color: _mutedText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _VehicleSeatMap extends StatelessWidget {
  final Map<String, dynamic> seatMap;
  final Set<String> selectedSeatIds;
  final ValueChanged<Map<String, dynamic>> onSeatTap;

  const _VehicleSeatMap({
    required this.seatMap,
    required this.selectedSeatIds,
    required this.onSeatTap,
  });

  @override
  Widget build(BuildContext context) {
    final frontSeatId = textOf(seatMap['front_seat']);
    final frontSeat = frontSeatId.isEmpty
        ? null
        : _seatById(seatMap, frontSeatId);
    final rows = _seatRows(seatMap);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _fieldBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 300),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  frontSeat == null
                      ? const SizedBox(width: 58)
                      : _SeatButton(
                          seat: frontSeat,
                          selected: selectedSeatIds.contains(frontSeatId),
                          onTap: () => onSeatTap(frontSeat),
                        ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: _VehicleLabel(
                      text: textOf(seatMap['front_label'], 'หน้ารถ'),
                    ),
                  ),
                  _DriverBlock(show: seatMap['show_driver'] != false),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: SizedBox(
                  width: 292,
                  child: Divider(height: 1, color: Color(0xFFD8DEDB)),
                ),
              ),
              ...rows.map((row) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SeatRow(
                    row: row,
                    seatMap: seatMap,
                    selectedSeatIds: selectedSeatIds,
                    onSeatTap: onSeatTap,
                  ),
                );
              }),
              const SizedBox(height: 4),
              _VehicleLabel(
                text: textOf(
                  seatMap['rear_label'],
                  'ท้ายรถ (สำหรับเก็บสัมภาระ)',
                ),
                muted: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeatRow extends StatelessWidget {
  final _SeatRowData row;
  final Map<String, dynamic> seatMap;
  final Set<String> selectedSeatIds;
  final ValueChanged<Map<String, dynamic>> onSeatTap;

  const _SeatRow({
    required this.row,
    required this.seatMap,
    required this.selectedSeatIds,
    required this.onSeatTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget seats(List<String> ids) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: ids.map((id) {
          final seat = _seatById(seatMap, id);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _SeatButton(
              seat: seat,
              seatId: id,
              selected: selectedSeatIds.contains(id),
              onTap: seat == null ? null : () => onSeatTap(seat),
            ),
          );
        }).toList(),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        seats(row.left),
        if (row.center.isNotEmpty) ...[
          const SizedBox(width: 8),
          seats(row.center),
        ],
        SizedBox(
          width: 44,
          child: Center(
            child: row.hasAisle
                ? Container(
                    width: 2,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8DEDB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )
                : null,
          ),
        ),
        seats(row.right),
      ],
    );
  }
}

class _SeatButton extends StatelessWidget {
  final Map<String, dynamic>? seat;
  final String? seatId;
  final bool selected;
  final VoidCallback? onTap;

  const _SeatButton({
    required this.seat,
    this.seatId,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final id = textOf(seat?['id'] ?? seatId);
    final status = textOf(seat?['status'], 'available');
    final lockedByCurrentUser = seat != null && _seatLockedByCurrentUser(seat!);
    final disabled =
        seat == null ||
        status == 'booked' ||
        (status == 'locked' && !lockedByCurrentUser);
    final color = _seatColor(status: status, selected: selected);
    final muted = disabled && status != 'booked';
    final seatColor = muted ? color.withValues(alpha: 0.55) : color;
    final foregroundColor = selected || status == 'booked'
        ? Colors.white
        : _mutedText.withValues(alpha: muted ? 0.62 : 1);
    final labelColor = selected
        ? _softAccent
        : _mutedText.withValues(alpha: muted ? 0.62 : 1);

    return Tooltip(
      message: _seatTooltip(seat, id, selected: selected),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 52,
          height: 60,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 42,
                height: 38,
                decoration: BoxDecoration(
                  color: seatColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: _softAccent.withValues(alpha: 0.24),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.airline_seat_recline_extra_rounded,
                      color: foregroundColor,
                      size: 20,
                    ),
                    if (selected || status == 'locked')
                      Positioned(
                        top: 3,
                        right: 3,
                        child: Icon(
                          selected ? Icons.check_circle : Icons.timer_rounded,
                          color: selected
                              ? Colors.white
                              : _premiumText.withValues(alpha: 0.72),
                          size: 11,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                textOf(seat?['label'], id),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.anuphan(
                  color: labelColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverBlock extends StatelessWidget {
  final bool show;

  const _DriverBlock({required this.show});

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox(width: 58);

    return SizedBox(
      width: 58,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.drive_eta_rounded,
              color: _mutedText,
              size: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'คนขับ',
            style: GoogleFonts.anuphan(
              color: _mutedText,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleLabel extends StatelessWidget {
  final String text;
  final bool muted;

  const _VehicleLabel({required this.text, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: muted ? Colors.white : _softAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: muted ? _cardBorder : Colors.transparent),
      ),
      child: Text(
        text,
        style: GoogleFonts.anuphan(
          color: muted ? _mutedText : _softAccent,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SeatLoadingState extends StatelessWidget {
  const _SeatLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 148,
      decoration: BoxDecoration(
        color: _fieldBackground,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Center(child: CircularProgressIndicator(color: _softAccent)),
    );
  }
}

class _SeatErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _SeatErrorState({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CompactNotice(icon: Icons.error_outline_rounded, text: error),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(
            'โหลดผังที่นั่งอีกครั้ง',
            style: GoogleFonts.anuphan(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _NoSeatMapState extends StatelessWidget {
  final Map<String, dynamic> seatMap;

  const _NoSeatMapState({super.key, required this.seatMap});

  @override
  Widget build(BuildContext context) {
    return _CompactNotice(
      icon: Icons.event_seat_outlined,
      text:
          'ทริปนี้ไม่มีผังที่นั่ง เลือกจำนวนผู้เดินทางได้ตามปกติ · ว่าง ${textOf(seatMap['available_seats'], '0')} / ${textOf(seatMap['total_seats'], '0')} ที่นั่ง',
    );
  }
}

class _SeatLegendItem {
  final Color color;
  final String label;

  const _SeatLegendItem(this.color, this.label);
}

class _SeatStatusCounts {
  final int available;
  final int locked;
  final int booked;
  final List<String> lockedSeatLabels;

  const _SeatStatusCounts({
    required this.available,
    required this.locked,
    required this.booked,
    required this.lockedSeatLabels,
  });

  factory _SeatStatusCounts.from(Map<String, dynamic> seatMap) {
    var available = 0;
    var locked = 0;
    var booked = 0;
    final lockedSeatLabels = <String>[];

    for (final item in asList(seatMap['seats'])) {
      final seat = asMap(item);
      final status = textOf(seat['status'], 'available');
      if (status == 'booked') {
        booked++;
      } else if (status == 'locked') {
        locked++;
        final seatLabel = textOf(seat['label'], textOf(seat['id']));
        final remaining = _seatLockRemainingText(seat);
        lockedSeatLabels.add(
          remaining.isEmpty ? seatLabel : '$seatLabel $remaining',
        );
      } else {
        available++;
      }
    }

    return _SeatStatusCounts(
      available: available,
      locked: locked,
      booked: booked,
      lockedSeatLabels: lockedSeatLabels,
    );
  }
}

class _SeatRowData {
  final List<String> left;
  final List<String> right;
  final List<String> center;
  final bool hasAisle;

  const _SeatRowData({
    required this.left,
    required this.right,
    required this.center,
    required this.hasAisle,
  });
}

class TravelerCounter extends StatelessWidget {
  final int count;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const TravelerCounter({
    super.key,
    required this.count,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _fieldBackground,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5E7E5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CounterButton(
            icon: Icons.remove_rounded,
            onPressed: count == 1 ? null : onRemove,
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: SizedBox(
              key: ValueKey(count),
              width: 42,
              child: Center(
                child: Text(
                  '$count',
                  style: GoogleFonts.anuphan(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: _premiumText,
                  ),
                ),
              ),
            ),
          ),
          _CounterButton(
            icon: Icons.add_rounded,
            onPressed: onAdd,
            isPrimary: true,
          ),
        ],
      ),
    );
  }
}

class TravelerFormSection extends StatelessWidget {
  final List<_PassengerControllers> passengers;
  final TextEditingController groupNotes;
  final bool isSeatSelectionMode;
  final List<String> selectedSeatIds;
  final VoidCallback onAddPassenger;
  final VoidCallback onRemovePassenger;
  final ValueChanged<int> onUseProfile;

  const TravelerFormSection({
    super.key,
    required this.passengers,
    required this.groupNotes,
    required this.isSeatSelectionMode,
    required this.selectedSeatIds,
    required this.onAddPassenger,
    required this.onRemovePassenger,
    required this.onUseProfile,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'ข้อมูลผู้เดินทาง',
      icon: Icons.people_alt_rounded,
      trailing: isSeatSelectionMode
          ? _SeatDrivenTravelerCount(count: selectedSeatIds.length)
          : TravelerCounter(
              count: passengers.length,
              onAdd: onAddPassenger,
              onRemove: onRemovePassenger,
            ),
      child: Column(
        children: [
          ...List.generate(passengers.length, (index) {
            return _TravelerCard(
              index: index,
              controllers: passengers[index],
              isLast: index == passengers.length - 1,
              seatId: index < selectedSeatIds.length
                  ? selectedSeatIds[index]
                  : null,
              onUseProfile: () => onUseProfile(index),
            );
          }),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: passengers.length > 1
                ? Padding(
                    key: const ValueKey('group-notes'),
                    padding: const EdgeInsets.only(top: 4),
                    child: _PremiumTextField(
                      controller: groupNotes,
                      label: 'หมายเหตุกลุ่ม',
                      hint: 'เช่น ขอที่นั่งใกล้กัน',
                      icon: Icons.notes_rounded,
                      maxLines: 2,
                      textInputAction: TextInputAction.newline,
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('empty-notes')),
          ),
        ],
      ),
    );
  }
}

class PricingSummaryCard extends StatelessWidget {
  final _PricingQuote pricing;
  final TextEditingController promoController;
  final bool expanded;
  final VoidCallback onExpandedChanged;

  const PricingSummaryCard({
    super.key,
    required this.pricing,
    required this.promoController,
    required this.expanded,
    required this.onExpandedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'สรุปราคา',
      icon: Icons.receipt_long_rounded,
      child: Column(
        children: [
          _PremiumTextField(
            controller: promoController,
            label: 'โค้ดส่วนลด',
            hint: 'เช่น NEWLUILAY',
            icon: Icons.local_offer_rounded,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 16),
          _PriceRow(
            label: 'ราคาต่อท่าน',
            value: money(pricing.pricePerTraveler),
          ),
          const SizedBox(height: 10),
          _PriceRow(
            label: 'จำนวนผู้เดินทาง',
            value: '${pricing.travelerCount} คน',
          ),
          const SizedBox(height: 10),
          _PriceRow(label: 'ราคาทริป', value: money(pricing.tripSubtotal)),
          const SizedBox(height: 10),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                _PriceRow(label: 'ค่าบริการ', value: money(pricing.serviceFee)),
                const SizedBox(height: 10),
                _PriceRow(
                  label: 'ส่วนลด',
                  value: '-${money(pricing.discount)}',
                  valueColor: _softAccent,
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onExpandedChanged,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Text(
                    expanded ? 'ซ่อนรายละเอียดราคา' : 'ดูรายละเอียดราคา',
                    style: GoogleFonts.anuphan(
                      color: _softAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: _softAccent,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 24, color: _cardBorder),
          _PriceRow(
            label: 'รวมทั้งหมด',
            value: money(pricing.total),
            isTotal: true,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'โค้ดส่วนลดจะถูกตรวจสอบเมื่อส่งข้อมูลการจอง',
              style: GoogleFonts.anuphan(
                color: _mutedText,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TrustSignalsSection extends StatelessWidget {
  const TrustSignalsSection({super.key});

  @override
  Widget build(BuildContext context) {
    const signals = [
      _TrustSignal(Icons.lock_rounded, 'ชำระเงินปลอดภัย'),
      _TrustSignal(Icons.task_alt_rounded, 'ยืนยันการจองทันที'),
      _TrustSignal(Icons.support_agent_rounded, 'ติดต่อทีมงาน 24 ชม.'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: signals.map((signal) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F8F6),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _softAccent.withValues(alpha: 0.10)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(signal.icon, size: 15, color: _softAccent),
              const SizedBox(width: 6),
              Text(
                signal.label,
                style: GoogleFonts.anuphan(
                  color: const Color(0xFF126B5B),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class StickyCheckoutBar extends StatelessWidget {
  final num total;
  final bool isSubmitting;
  final bool canGoBack;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback onBack;
  final VoidCallback? onPressed;

  const StickyCheckoutBar({
    super.key,
    required this.total,
    required this.isSubmitting,
    required this.canGoBack,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onBack,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: _cardBorder)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'รวมทั้งหมด',
                    style: GoogleFonts.anuphan(
                      color: _mutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    money(total),
                    style: GoogleFonts.anuphan(
                      color: _premiumText,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (canGoBack) ...[
              SizedBox(
                width: 52,
                height: 52,
                child: IconButton(
                  onPressed: isSubmitting ? null : onBack,
                  style: IconButton.styleFrom(
                    backgroundColor: _fieldBackground,
                    foregroundColor: _premiumText,
                    disabledForegroundColor: _mutedText.withValues(alpha: 0.4),
                    shape: const CircleBorder(),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              flex: 2,
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: FilledButton(
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: _softAccent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFC8D5D1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: isSubmitting
                        ? const SizedBox(
                            key: ValueKey('loading'),
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            key: ValueKey(primaryLabel),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(primaryIcon, size: 18),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  primaryLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.anuphan(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _SectionShell({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _premiumDecoration(radius: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _softAccent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: _softAccent, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.anuphan(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _premiumText,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SeatDrivenTravelerCount extends StatelessWidget {
  final int count;

  const _SeatDrivenTravelerCount({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _softAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_seat_rounded, color: _softAccent, size: 16),
          const SizedBox(width: 6),
          Text(
            count > 0 ? '$count คน' : 'เลือกที่นั่ง',
            style: GoogleFonts.anuphan(
              color: _softAccent,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TravelerCard extends StatelessWidget {
  final int index;
  final _PassengerControllers controllers;
  final bool isLast;
  final String? seatId;
  final VoidCallback onUseProfile;

  const _TravelerCard({
    required this.index,
    required this.controllers,
    required this.isLast,
    this.seatId,
    required this.onUseProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: _premiumText,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.anuphan(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ผู้เดินทาง',
                  style: GoogleFonts.anuphan(
                    fontWeight: FontWeight.w800,
                    color: _premiumText,
                    fontSize: 15,
                  ),
                ),
              ),
              if (seatId != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _fieldBackground,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: Text(
                    'ที่นั่ง $seatId',
                    style: GoogleFonts.anuphan(
                      color: _mutedText,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onUseProfile,
                icon: const Icon(Icons.account_circle_outlined, size: 17),
                label: Text(
                  'ดึงข้อมูลโปรไฟล์',
                  style: GoogleFonts.anuphan(fontWeight: FontWeight.w800),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: _softAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 360;
              final titleDropdown = _PremiumDropdown<String>(
                key: ValueKey('title-$index-${controllers.title.text}'),
                label: 'คำนำหน้า',
                icon: Icons.badge_outlined,
                value: _titleValue(controllers.title.text),
                items: _titleOptions.map((title) {
                  return DropdownMenuItem<String>(
                    value: title,
                    child: Text(title, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                validator: _requiredValidator('กรุณาเลือกคำนำหน้า'),
                onChanged: (value) {
                  controllers.title.text = value ?? '';
                },
              );
              final nameField = _PremiumTextField(
                controller: controllers.name,
                label: 'ชื่อ-นามสกุล',
                hint: 'สมชาย ลุยเลยเขา',
                icon: Icons.person_rounded,
                validator: _requiredValidator('กรุณากรอกชื่อ-นามสกุล'),
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
              );

              if (isCompact) {
                return Column(
                  children: [
                    titleDropdown,
                    const SizedBox(height: 12),
                    nameField,
                  ],
                );
              }

              return Row(
                children: [
                  SizedBox(width: 124, child: titleDropdown),
                  const SizedBox(width: 12),
                  Expanded(child: nameField),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 390;
              final nicknameField = _PremiumTextField(
                controller: controllers.nickname,
                label: 'ชื่อเล่น',
                hint: 'ชื่อเล่น',
                icon: Icons.face_rounded,
                textInputAction: TextInputAction.next,
              );
              final phoneField = _PremiumTextField(
                controller: controllers.phone,
                label: 'เบอร์โทรศัพท์',
                hint: '081-234-5678',
                icon: Icons.phone_android_rounded,
                keyboardType: TextInputType.phone,
                validator: _requiredValidator('กรุณากรอกเบอร์โทรศัพท์'),
                autofillHints: const [AutofillHints.telephoneNumber],
                textInputAction: TextInputAction.next,
              );

              if (isCompact) {
                return Column(
                  children: [
                    nicknameField,
                    const SizedBox(height: 12),
                    phoneField,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: nicknameField),
                  const SizedBox(width: 12),
                  Expanded(child: phoneField),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 390;
              final idCardField = _PremiumTextField(
                controller: controllers.idCard,
                label: 'เลขบัตรประชาชน (สำหรับประกัน)',
                hint: 'เลข 13 หลัก',
                icon: Icons.credit_card_rounded,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(13),
                ],
                textInputAction: TextInputAction.next,
              );
              final bloodDropdown = _PremiumDropdown<String>(
                key: ValueKey('blood-$index-${controllers.bloodGroup.text}'),
                label: 'กรุ๊ปเลือด',
                icon: Icons.bloodtype_rounded,
                value: _bloodGroupValue(controllers.bloodGroup.text),
                items: _bloodGroupOptions.map((group) {
                  return DropdownMenuItem<String>(
                    value: group,
                    child: Text(group, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (value) {
                  controllers.bloodGroup.text = value ?? '';
                },
              );

              if (isCompact) {
                return Column(
                  children: [
                    idCardField,
                    const SizedBox(height: 12),
                    bloodDropdown,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: idCardField),
                  const SizedBox(width: 12),
                  SizedBox(width: 132, child: bloodDropdown),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          _HalalFoodSelector(
            selected: controllers.halalFood,
            onChanged: (value) => controllers.halalFood.value = value,
          ),
          const SizedBox(height: 12),
          _PremiumTextField(
            controller: controllers.allergies,
            label: 'การแพ้อาหาร / อื่นๆ',
            hint: 'เช่น แพ้อาหารทะเล, ไม่ทานเนื้อ, แพ้ถั่ว',
            icon: Icons.restaurant_menu_rounded,
            maxLines: 2,
            textInputAction: TextInputAction.newline,
          ),
          const SizedBox(height: 16),
          Text(
            'ผู้ติดต่อฉุกเฉิน',
            style: GoogleFonts.anuphan(
              color: _premiumText,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 390;
              final contactField = _PremiumTextField(
                controller: controllers.emergencyContact,
                label: 'ชื่อผู้ติดต่อ',
                hint: 'ชื่อผู้ติดต่อ',
                icon: Icons.contact_emergency_rounded,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
              );
              final phoneField = _PremiumTextField(
                controller: controllers.emergencyPhone,
                label: 'เบอร์ติดต่อฉุกเฉิน',
                hint: '089-xxx-xxxx',
                icon: Icons.phone_enabled_rounded,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                textInputAction: TextInputAction.next,
              );

              if (isCompact) {
                return Column(
                  children: [
                    contactField,
                    const SizedBox(height: 12),
                    phoneField,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: contactField),
                  const SizedBox(width: 12),
                  Expanded(child: phoneField),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          _PremiumTextField(
            controller: controllers.healthNotes,
            label: 'โรคประจำตัว / หมายเหตุสุขภาพ',
            hint: 'ไม่มี',
            icon: Icons.health_and_safety_rounded,
            maxLines: 2,
            textInputAction: TextInputAction.newline,
          ),
          if (!isLast)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Divider(height: 1, color: _cardBorder),
            ),
        ],
      ),
    );
  }
}

class _HalalFoodSelector extends StatelessWidget {
  final ValueNotifier<bool> selected;
  final ValueChanged<bool> onChanged;

  const _HalalFoodSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: selected,
      builder: (context, wantsHalal, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ต้องการอาหารฮาลาล', style: _labelStyle()),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _HalalChoiceButton(
                    label: 'ต้องการ',
                    icon: Icons.check_circle_outline_rounded,
                    selected: wantsHalal,
                    onTap: () => onChanged(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _HalalChoiceButton(
                    label: 'ไม่ต้องการ',
                    icon: Icons.cancel_outlined,
                    selected: !wantsHalal,
                    onTap: () => onChanged(false),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _HalalChoiceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _HalalChoiceButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected
              ? _softAccent.withValues(alpha: 0.10)
              : _fieldBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? _softAccent : _cardBorder,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? _softAccent : _mutedText, size: 18),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.anuphan(
                  color: selected ? _softAccent : _mutedText,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumDropdown<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;

  const _PremiumDropdown({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle()),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          decoration: _fieldDecoration(icon: icon, hint: label),
          style: GoogleFonts.anuphan(
            color: _premiumText,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(18),
          items: items,
          onChanged: items.isEmpty ? null : onChanged,
          validator: validator,
        ),
      ],
    );
  }
}

class _PremiumTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final TextCapitalization textCapitalization;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;

  const _PremiumTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.keyboardType,
    this.validator,
    this.autofillHints,
    this.textInputAction,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle()),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          minLines: maxLines > 1 ? maxLines : 1,
          textCapitalization: textCapitalization,
          keyboardType: keyboardType,
          validator: validator,
          autofillHints: autofillHints,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          decoration: _fieldDecoration(icon: icon, hint: hint),
          style: GoogleFonts.anuphan(
            color: _premiumText,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isPrimary;

  const _CounterButton({
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: isPrimary ? _softAccent : Colors.white,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.62),
          foregroundColor: isPrimary ? Colors.white : _premiumText,
          disabledForegroundColor: _mutedText.withValues(alpha: 0.35),
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
        ),
        icon: Icon(icon, size: 20),
      ),
    );
  }
}

class _SummaryMeta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SummaryMeta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _mutedText, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.anuphan(
              color: _mutedText,
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isTotal;

  const _PriceRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.anuphan(
              color: isTotal ? _premiumText : _mutedText,
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.anuphan(
            color: valueColor ?? _premiumText,
            fontSize: isTotal ? 20 : 14,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _CompactNotice extends StatelessWidget {
  final IconData icon;
  final String text;

  const _CompactNotice({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _fieldBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: _mutedText, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.anuphan(
                color: _mutedText,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripImageFallback extends StatelessWidget {
  const _TripImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE7F3EF),
      child: const Center(
        child: Icon(Icons.landscape_rounded, color: _softAccent, size: 34),
      ),
    );
  }
}

class _TrustSignal {
  final IconData icon;
  final String label;

  const _TrustSignal(this.icon, this.label);
}

class _CheckoutValidationException implements Exception {
  final String message;

  const _CheckoutValidationException(this.message);

  @override
  String toString() => message;
}

class _PricingQuote {
  final num pricePerTraveler;
  final int travelerCount;
  final num serviceFee;
  final num discount;

  const _PricingQuote({
    required this.pricePerTraveler,
    required this.travelerCount,
    required this.serviceFee,
    required this.discount,
  });

  num get tripSubtotal => pricePerTraveler * travelerCount;

  num get total {
    final value = tripSubtotal + serviceFee - discount;
    return value < 0 ? 0 : value;
  }

  factory _PricingQuote.from({
    required Map<String, dynamic> trip,
    required Map<String, dynamic> schedule,
    required Map<String, dynamic> pickupPoint,
    required int travelerCount,
  }) {
    final basePrice = _asNum(
      schedule['effective_price'] ??
          schedule['price'] ??
          trip['price_per_person'] ??
          trip['price'] ??
          trip['start_price'],
    );
    final pickupPrice = _asNum(pickupPoint['price']);

    return _PricingQuote(
      pricePerTraveler: pickupPrice > 0 ? pickupPrice : basePrice,
      travelerCount: travelerCount,
      serviceFee: 0,
      discount: 0,
    );
  }
}

class _PassengerControllers {
  final title = TextEditingController();
  final name = TextEditingController();
  final nickname = TextEditingController();
  final phone = TextEditingController();
  final idCard = TextEditingController();
  final bloodGroup = TextEditingController();
  final emergencyContact = TextEditingController();
  final emergencyPhone = TextEditingController();
  final allergies = TextEditingController();
  final healthNotes = TextEditingController();
  final halalFood = ValueNotifier<bool>(false);

  void applyProfile(Map<String, dynamic> user) {
    title.text = _profileTitle(user['title']);
    name.text = textOf(user['name']);
    nickname.text = textOf(user['nickname']);
    phone.text = textOf(user['phone']);
    idCard.text = textOf(user['id_card']);
    bloodGroup.text = _profileBloodGroup(user['blood_group']);
    emergencyContact.text = textOf(user['emergency_contact']);
    emergencyPhone.text = textOf(user['emergency_phone']);
    allergies.text = textOf(user['allergies']);
    healthNotes.text = textOf(user['health_notes']);
    halalFood.value = _asBool(
      user['halal_food'] ??
          user['needs_halal_food'] ??
          user['requires_halal_food'],
    );
  }

  Map<String, dynamic> payload() => {
    'title': title.text.trim(),
    'name': name.text.trim(),
    'nickname': nickname.text.trim().isEmpty ? null : nickname.text.trim(),
    'phone': phone.text.trim(),
    'id_card': idCard.text.trim().isEmpty ? null : idCard.text.trim(),
    'blood_group': bloodGroup.text.trim().isEmpty
        ? null
        : bloodGroup.text.trim(),
    'emergency_contact': emergencyContact.text.trim().isEmpty
        ? null
        : emergencyContact.text.trim(),
    'emergency_phone': emergencyPhone.text.trim().isEmpty
        ? null
        : emergencyPhone.text.trim(),
    'allergies': allergies.text.trim().isEmpty ? null : allergies.text.trim(),
    'halal_food': halalFood.value,
    'health_notes': healthNotes.text.trim().isEmpty
        ? null
        : healthNotes.text.trim(),
  };

  void dispose() {
    title.dispose();
    name.dispose();
    nickname.dispose();
    phone.dispose();
    idCard.dispose();
    bloodGroup.dispose();
    emergencyContact.dispose();
    emergencyPhone.dispose();
    allergies.dispose();
    healthNotes.dispose();
    halalFood.dispose();
  }
}

BoxDecoration _premiumDecoration({double radius = 24}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: _cardBorder),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.035),
        blurRadius: 22,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

InputDecoration _fieldDecoration({
  required IconData icon,
  required String hint,
}) {
  return InputDecoration(
    hintText: hint,
    isDense: true,
    filled: true,
    fillColor: _fieldBackground,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
    prefixIcon: Icon(icon, size: 19, color: _mutedText),
    prefixIconConstraints: const BoxConstraints(minWidth: 44),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: _cardBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: _cardBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: _softAccent, width: 1.4),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppTheme.errorColor),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppTheme.errorColor, width: 1.4),
    ),
    hintStyle: GoogleFonts.anuphan(
      color: _mutedText.withValues(alpha: 0.62),
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
  );
}

TextStyle _labelStyle() {
  return GoogleFonts.anuphan(
    color: _mutedText,
    fontSize: 12,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );
}

String? Function(String?) _requiredValidator(String message) {
  return (value) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  };
}

String? _titleValue(String value) {
  final title = _profileTitle(value);
  return _titleOptions.contains(title) ? title : null;
}

String _profileTitle(dynamic value) {
  final title = textOf(value).trim();
  if (title == 'น.ส.' || title == 'นส') return 'นางสาว';
  return _titleOptions.contains(title) ? title : '';
}

String? _bloodGroupValue(String value) {
  final group = _profileBloodGroup(value);
  return _bloodGroupOptions.contains(group) ? group : null;
}

String _profileBloodGroup(dynamic value) {
  final group = textOf(value).trim().toUpperCase();
  return _bloodGroupOptions.contains(group) ? group : '';
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase();
  return normalized == 'true' ||
      normalized == '1' ||
      normalized == 'yes' ||
      normalized == 'y';
}

int? _validDropdownValue(int? selected, Iterable<int> values) {
  final ids = values.toList();
  if (ids.isEmpty) return null;
  if (selected != null && ids.contains(selected)) return selected;
  return ids.first;
}

String? _validStringDropdownValue(String? selected, Iterable<String> values) {
  final ids = values.where((value) => value.isNotEmpty).toList();
  if (ids.isEmpty) return null;
  if (selected != null && ids.contains(selected)) return selected;
  return ids.first;
}

num _asNum(dynamic value) {
  return num.tryParse(value?.toString() ?? '') ?? 0;
}

Map<String, dynamic> _preferredPickupPoint(
  List<dynamic> points, {
  int? preferredPickupPointId,
  String? preferredRegion,
}) {
  if (points.isEmpty) return <String, dynamic>{};

  if (preferredPickupPointId != null) {
    final match = points
        .map(asMap)
        .where(
          (point) =>
              int.tryParse(point['id'].toString()) == preferredPickupPointId,
        );
    if (match.isNotEmpty) return match.first;
  }

  if (preferredRegion != null && preferredRegion.isNotEmpty) {
    final match = points
        .map(asMap)
        .where((point) => textOf(point['region']) == preferredRegion);
    if (match.isNotEmpty) return match.first;
  }

  return asMap(points.first);
}

List<Map<String, dynamic>> _pickupRegionOptions(
  List<Map<String, dynamic>> points,
) {
  final options = <String, Map<String, dynamic>>{};
  for (final point in points) {
    final region = textOf(point['region']);
    if (region.isEmpty || options.containsKey(region)) continue;
    options[region] = point;
  }
  return options.values.toList();
}

String _pickupRegionLabel(Map<String, dynamic> point) {
  return textOf(point['region_label'] ?? point['region'], 'ยังไม่ระบุภูมิภาค');
}

String _pickupLocationLabel(Map<String, dynamic> point) {
  return textOf(
    point['pickup_location'] ?? point['region_label'] ?? point['region'],
    'ยังไม่ระบุจุดขึ้นรถ',
  );
}

String _pickupPriceText(dynamic value) {
  final price = _asNum(value);
  if (price <= 0) return 'ไม่มีค่าใช้จ่ายเพิ่ม';
  return money(price);
}

List<String> _vehicleImageUrls(Map<String, dynamic> vehicle) {
  final urls = <String>[];

  void addUrl(dynamic value) {
    final url = ApiConfig.mediaUrl(value);
    if (url.isNotEmpty && !urls.contains(url)) urls.add(url);
  }

  for (final item in asList(vehicle['images'])) {
    final value = item is Map
        ? asMap(item)['url'] ?? asMap(item)['image'] ?? asMap(item)['path']
        : item;
    addUrl(value);
  }

  addUrl(vehicle['image']);
  addUrl(vehicle['photo']);
  addUrl(vehicle['thumbnail_image']);
  addUrl(vehicle['cover_image']);

  return urls;
}

bool _sameStringList(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

_ImageCacheSize _cacheSizeFor(
  BuildContext context, {
  required double width,
  required double height,
}) {
  final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);
  return _ImageCacheSize(
    width: (width * dpr).round().clamp(1, 1200),
    height: (height * dpr).round().clamp(1, 900),
  );
}

bool _isSeatAvailable(Map<String, dynamic> seat) {
  final status = textOf(seat['status'], 'available');
  return status != 'booked' && status != 'locked';
}

bool _seatLockedByCurrentUser(Map<String, dynamic> seat) {
  return _asBool(seat['locked_by_current_user']);
}

String _seatTooltip(
  Map<String, dynamic>? seat,
  String id, {
  required bool selected,
}) {
  if (seat == null) return '$id ไม่พร้อมใช้งาน';
  if (selected) return '$id กำลังเลือก';

  final status = textOf(seat['status'], 'available');
  if (status == 'booked') return '$id จองแล้ว';
  if (status == 'locked') {
    final remaining = _seatLockRemainingText(seat);
    if (_seatLockedByCurrentUser(seat)) {
      return remaining.isEmpty
          ? '$id คุณกำลังจองอยู่'
          : '$id คุณกำลังจองอยู่ เหลือ $remaining';
    }
    return remaining.isEmpty
        ? '$id มีผู้ใช้อื่นกำลังจองอยู่'
        : '$id มีผู้ใช้อื่นกำลังจองอยู่ เหลือ $remaining';
  }

  return '$id ว่าง';
}

String _seatLockRemainingText(Map<String, dynamic> seat) {
  final seconds = int.tryParse(textOf(seat['locked_ttl_seconds'])) ?? 0;
  if (seconds <= 0) return '';
  final minutes = seconds ~/ 60;
  final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
  return '$minutes:$remainingSeconds นาที';
}

String _lockRemainingLabel(dynamic value) {
  final seconds = int.tryParse(textOf(value)) ?? 0;
  if (seconds <= 0) return 'หมดเวลาแล้ว';
  if (seconds < 60) return 'เหลือไม่ถึง 1 นาที';
  final minutes = (seconds / 60).ceil();
  return 'เหลือ $minutes นาที';
}

String _compactScheduleDate(Map<String, dynamic> schedule) {
  final departure = textOf(schedule['departure_date']);
  final returning = textOf(schedule['return_date']);
  if (departure.isEmpty) return '-';
  if (returning.isEmpty || returning == departure) return dateText(departure);
  return '${dateText(departure)} - ${dateText(returning)}';
}

Color _seatColor({required String status, required bool selected}) {
  if (selected) return _softAccent;
  if (status == 'booked') return const Color(0xFF6B7280);
  if (status == 'locked') return const Color(0xFFCBD5D1);
  return const Color(0xFFE5E7EB);
}

Map<String, dynamic>? _seatById(Map<String, dynamic> seatMap, String id) {
  for (final item in asList(seatMap['seats'])) {
    final seat = asMap(item);
    if (textOf(seat['id']) == id) return seat;
  }
  return null;
}

List<_SeatRowData> _seatRows(Map<String, dynamic> seatMap) {
  final rows = int.tryParse(textOf(seatMap['rows'])) ?? 0;
  final columns = asList(
    seatMap['columns'],
  ).map((item) => item?.toString() ?? '').toList();
  final frontSeatId = textOf(seatMap['front_seat']);
  final centerSeatIds = asList(
    seatMap['last_row_center'],
  ).map((item) => item?.toString() ?? '').toSet();
  final result = <_SeatRowData>[];

  for (var rowIndex = 1; rowIndex <= rows; rowIndex++) {
    final left = <String>[];
    final right = <String>[];
    final center = <String>[];
    var hasAisle = false;
    var inRight = false;

    for (final column in columns) {
      if (column.isEmpty) {
        hasAisle = true;
        inRight = true;
        continue;
      }

      final seatId = '$column$rowIndex';
      if (seatId == frontSeatId) continue;
      if (_seatById(seatMap, seatId) == null) continue;

      if (centerSeatIds.contains(seatId)) {
        center.add(seatId);
      } else if (inRight) {
        right.add(seatId);
      } else {
        left.add(seatId);
      }
    }

    if (left.isEmpty && right.isEmpty && center.isEmpty) continue;

    result.add(
      _SeatRowData(
        left: left,
        right: right,
        center: center,
        hasAisle: hasAisle && right.isNotEmpty,
      ),
    );
  }

  return result;
}
