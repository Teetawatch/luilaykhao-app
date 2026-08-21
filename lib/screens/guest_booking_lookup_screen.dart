import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../config/api_endpoints.dart';
import '../models/tracking_model.dart';
import '../providers/tracking_provider.dart';
import '../services/api_client.dart';
import '../utils/thai_date.dart';
import '../widgets/app_snack.dart';
import '../widgets/travel_widgets.dart';
import '../theme/app_theme.dart';
import 'tracking_screen.dart';

enum _LookupMode { byRef, byName }

class GuestBookingLookupScreen extends StatefulWidget {
  const GuestBookingLookupScreen({super.key});

  @override
  State<GuestBookingLookupScreen> createState() =>
      _GuestBookingLookupScreenState();
}

class _GuestBookingLookupScreenState extends State<GuestBookingLookupScreen> {
  // ── Mode ──────────────────────────────────────────────────────────────────
  _LookupMode _mode = _LookupMode.byRef;

  // ── By-ref fields ─────────────────────────────────────────────────────────
  final _refController = TextEditingController();
  final _refPhoneController = TextEditingController();
  final _refFocus = FocusNode();
  final _refPhoneFocus = FocusNode();
  String? _refError;
  String? _refPhoneError;

  // ── By-name fields ────────────────────────────────────────────────────────
  final _nameController = TextEditingController();
  final _namePhoneController = TextEditingController();
  final _nameFocus = FocusNode();
  final _namePhoneFocus = FocusNode();
  String? _nameError;
  String? _namePhoneError;

  bool _isLoading = false;

  // ── Results ───────────────────────────────────────────────────────────────
  // byRef → single result (Map); byName → list of results
  Map<String, dynamic>? _refResult;
  List<Map<String, dynamic>>? _nameResults;

  @override
  void dispose() {
    _refController.dispose();
    _refPhoneController.dispose();
    _refFocus.dispose();
    _refPhoneFocus.dispose();
    _nameController.dispose();
    _namePhoneController.dispose();
    _nameFocus.dispose();
    _namePhoneFocus.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _validRef(String v) =>
      RegExp(r'^LLK-\d{8}-\d{4}$', caseSensitive: false).hasMatch(v.trim());

  String? _extractRef(String raw) {
    final m = RegExp(r'LLK-\d{8}-\d{4}', caseSensitive: false).firstMatch(raw);
    if (m != null) return m.group(0)!.toUpperCase();
    final compact = raw.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final cm = RegExp(r'^LLK(\d{8})(\d{4})$').firstMatch(compact);
    if (cm == null) return null;
    return 'LLK-${cm.group(1)}-${cm.group(2)}';
  }

  void _clearErrors() => setState(() {
    _refError = null;
    _refPhoneError = null;
    _nameError = null;
    _namePhoneError = null;
  });

  // ── Lookup by ref ─────────────────────────────────────────────────────────

  Future<void> _lookupByRef() async {
    _clearErrors();

    final ref =
        _extractRef(_refController.text) ??
        _refController.text.trim().toUpperCase();
    final phone = _refPhoneController.text.trim();

    bool hasError = false;
    if (!_validRef(ref)) {
      setState(() => _refError = 'รูปแบบรหัสไม่ถูกต้อง เช่น LLK-20250409-0001');
      hasError = true;
    }
    if (phone.replaceAll(RegExp(r'\D'), '').length < 4) {
      setState(() => _refPhoneError = 'กรุณากรอกเบอร์โทรอย่างน้อย 4 หลัก');
      hasError = true;
    }
    if (hasError) return;

    _refController.text = ref;
    _refPhoneFocus.unfocus();
    _refFocus.unfocus();
    HapticFeedback.selectionClick();
    setState(() => _isLoading = true);

    try {
      final client = ApiClient(token: null);
      final response =
          await client.post(
                ApiEndpoints.bookingsGuestLookup,
                body: {'booking_ref': ref, 'phone': phone},
              )
              as Map<String, dynamic>;

      final data = response['data'] as Map<String, dynamic>? ?? {};
      HapticFeedback.lightImpact();
      setState(() => _refResult = data);
    } on ApiException catch (e) {
      if (e.statusCode == 403) {
        setState(() => _refPhoneError = e.message);
      } else if (e.statusCode == 404) {
        setState(() => _refError = e.message);
      } else {
        setState(() => _refError = e.message);
      }
    } catch (_) {
      setState(() => _refError = 'เกิดข้อผิดพลาด กรุณาลองอีกครั้ง');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Lookup by name ────────────────────────────────────────────────────────

  Future<void> _lookupByName() async {
    _clearErrors();

    final name = _nameController.text.trim();
    final phone = _namePhoneController.text.replaceAll(RegExp(r'\D'), '');

    bool hasError = false;
    if (name.isEmpty) {
      setState(() => _nameError = 'กรุณากรอกชื่อ-นามสกุล');
      hasError = true;
    }
    if (phone.length < 8) {
      setState(() => _namePhoneError = 'กรุณากรอกเบอร์โทรอย่างน้อย 8 หลัก');
      hasError = true;
    }
    if (hasError) return;

    _namePhoneFocus.unfocus();
    _nameFocus.unfocus();
    HapticFeedback.selectionClick();
    setState(() => _isLoading = true);

    try {
      final client = ApiClient(token: null);
      final response =
          await client.post(
                ApiEndpoints.bookingsGuestLookupByName,
                body: {'name': name, 'phone': phone},
              )
              as Map<String, dynamic>;

      final raw = response['data'];
      final List<Map<String, dynamic>> results = raw is List
          ? raw.cast<Map<String, dynamic>>()
          : [];
      HapticFeedback.lightImpact();
      setState(() => _nameResults = results);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        setState(() => _nameError = e.message);
      } else {
        setState(() => _nameError = e.message);
      }
    } catch (_) {
      setState(() => _nameError = 'เกิดข้อผิดพลาด กรุณาลองอีกครั้ง');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Tracking ──────────────────────────────────────────────────────────────

  Future<void> _openTracking(Map<String, dynamic> result) async {
    final vehicleId = result['vehicle_id'];
    if (vehicleId == null) {
      _showSnack('ยังไม่ได้กำหนดรถสำหรับทริปนี้');
      return;
    }

    final status = (result['status'] ?? '').toString().toLowerCase();
    if (status == 'cancelled' || status == 'refunded') {
      _showSnack('การจองนี้ถูกยกเลิกแล้ว ไม่สามารถติดตามรถได้');
      return;
    }

    // เปิดให้ติดตามตั้งแต่วันที่รถออกจริง (departs_at อาจเป็นคืนก่อนวันทริป)
    // ไปจนถึงวันทริป — รอบที่รถออกคืนก่อนจึงติดตามได้ทั้งคืนนั้นและวันเดินทาง
    final departsRaw = (result['departs_at'] ?? '').toString();
    final tripRaw = (result['departure_date'] ?? '').toString();
    final departsDate = departsRaw.isEmpty ? null : DateTime.tryParse(departsRaw);
    final tripDate = tripRaw.isEmpty ? null : DateTime.tryParse(tripRaw);
    final startSource = departsDate ?? tripDate;
    final endSource = tripDate ?? departsDate;
    final now = DateTime.now();
    final t = DateTime(now.year, now.month, now.day);
    if (startSource != null) {
      final start =
          DateTime(startSource.year, startSource.month, startSource.day);
      if (t.isBefore(start)) {
        _showSnack('สามารถติดตามรถได้ในวันเดินทาง');
        return;
      }
    }
    if (endSource != null) {
      final end = DateTime(endSource.year, endSource.month, endSource.day);
      if (t.isAfter(end)) {
        _showSnack('ทริปนี้สิ้นสุดแล้ว');
        return;
      }
    }

    HapticFeedback.lightImpact();
    final bookingInfo = BookingInfo.fromJson({
      ...result,
      'schedule_id': result['schedule_id'] ?? 0,
    });

    final provider = context.read<TrackingProvider>();
    provider.stopTracking();
    await provider.startTrackingAsGuest(bookingInfo);
    if (!mounted) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, _, _) => const TrackingMapPage(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _showSnack(String msg) {
    AppSnack.show(context, msg);
  }

  void _resetResults() => setState(() {
    _refResult = null;
    _nameResults = null;
  });

  // ── Build ─────────────────────────────────────────────────────────────────

  bool get _hasResult => _refResult != null || _nameResults != null;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: AppTheme.background(context),
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: true,
              title: Text(
                'ค้นหาการจอง',
                style: AppTheme.appBarTitleStyle(context),
              ),
              leading: Navigator.canPop(context)
                  ? IconButton(
                      tooltip: 'ย้อนกลับ',
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      onPressed: () => Navigator.pop(context),
                    )
                  : null,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 120 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _GuestHeroHeader(),
                    const SizedBox(height: 20),

                    if (!_hasResult) ...[
                      // ── Mode toggle ──────────────────────────────────────
                      _ModeToggle(
                        mode: _mode,
                        onChanged: (m) => setState(() {
                          _mode = m;
                          _clearErrors();
                        }),
                      ),
                      const SizedBox(height: 20),

                      // ── Form ─────────────────────────────────────────────
                      if (_mode == _LookupMode.byRef) ...[
                        _RefField(
                          controller: _refController,
                          focusNode: _refFocus,
                          error: _refError,
                          onNext: () => _refPhoneFocus.requestFocus(),
                        ),
                        const SizedBox(height: 14),
                        _PhoneField(
                          controller: _refPhoneController,
                          focusNode: _refPhoneFocus,
                          error: _refPhoneError,
                          hint: 'เบอร์โทรผู้เดินทาง (4 หลักท้าย)',
                          hintPlaceholder: 'เช่น 0812345678 หรือ 5678',
                          onSubmitted: _lookupByRef,
                        ),
                        const SizedBox(height: 20),
                        _LookupButton(
                          isLoading: _isLoading,
                          enabled: !_isLoading,
                          onPressed: _lookupByRef,
                        ),
                      ] else ...[
                        _NameField(
                          controller: _nameController,
                          focusNode: _nameFocus,
                          error: _nameError,
                          onNext: () => _namePhoneFocus.requestFocus(),
                        ),
                        const SizedBox(height: 14),
                        _PhoneField(
                          controller: _namePhoneController,
                          focusNode: _namePhoneFocus,
                          error: _namePhoneError,
                          hint: 'เบอร์โทรศัพท์',
                          hintPlaceholder: 'เช่น 0812345678',
                          onSubmitted: _lookupByName,
                          digitsOnly: true,
                          maxLength: 10,
                        ),
                        const SizedBox(height: 20),
                        _LookupButton(
                          isLoading: _isLoading,
                          enabled: !_isLoading,
                          onPressed: _lookupByName,
                        ),
                      ],

                      const SizedBox(height: 24),
                      _GuestHelpCard(),
                    ] else ...[
                      // ── Results ──────────────────────────────────────────
                      if (_refResult != null)
                        _GuestBookingResultCard(
                          data: _refResult!,
                          showSensitiveInfo: true,
                          onTrack: () => _openTracking(_refResult!),
                          onReset: _resetResults,
                        ),

                      if (_nameResults != null) ...[
                        if (_nameResults!.isEmpty)
                          _EmptyNameResult(onReset: _resetResults)
                        else
                          ...List.generate(_nameResults!.length, (i) {
                            final item = _nameResults![i];
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: i < _nameResults!.length - 1 ? 16 : 0,
                              ),
                              child: _GuestBookingResultCard(
                                data: item,
                                showSensitiveInfo: false,
                                // เจอหลายรอบพร้อมกัน — เริ่มแบบย่อ กางทีละใบเอง
                                expandedByDefault: _nameResults!.length == 1,
                                onTrack: () => _openTracking(item),
                                onReset: i == _nameResults!.length - 1
                                    ? _resetResults
                                    : null,
                              ),
                            );
                          }),
                        if (_nameResults!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _resetResults,
                            icon: const Icon(Icons.search_rounded, size: 18),
                            label: Text(
                              'ค้นหาการจองอื่น',
                              style: appFont(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              side: BorderSide(color: AppTheme.border(context)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                              ),
                            ),
                          ),
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
}

// ─── Mode Toggle ──────────────────────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  final _LookupMode mode;
  final ValueChanged<_LookupMode> onChanged;

  const _ModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          _ToggleChip(
            label: 'รหัสการจอง + เบอร์',
            icon: Icons.confirmation_number_rounded,
            selected: mode == _LookupMode.byRef,
            onTap: () => onChanged(_LookupMode.byRef),
          ),
          _ToggleChip(
            label: 'ชื่อ + เบอร์โทร',
            icon: Icons.person_search_rounded,
            selected: mode == _LookupMode.byName,
            onTap: () => onChanged(_LookupMode.byName),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            // iOS-style white thumb that fills the segment when selected.
            color: selected ? AppTheme.surface(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected
                    ? AppTheme.primaryColor
                    : AppTheme.mutedText(context),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                    color: selected
                        ? AppTheme.primaryColor
                        : AppTheme.mutedText(context),
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

// ─── Hero Header ──────────────────────────────────────────────────────────────

class _GuestHeroHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(context, radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Same solid emerald tile as the home "มีรหัสการจอง?" banner, so the
          // entry point and this screen read as one continuous flow.
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(
              Icons.confirmation_number_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'ดู QR และติดตามรถ\nโดยไม่ต้องสมัครสมาชิก',
            style: appFont(
              fontSize: AppText.sizeH1,
              height: 1.25,
              fontWeight: FontWeight.w800,
              color: AppTheme.onSurface(context),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ค้นหาด้วยรหัสการจอง หรือชื่อ-นามสกุลพร้อมเบอร์โทรที่ให้ไว้',
            style: appFont(
              fontSize: AppText.sizeBody,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: AppTheme.mutedText(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Form Fields ──────────────────────────────────────────────────────────────

class _RefField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? error;
  final VoidCallback onNext;

  const _RefField({
    required this.controller,
    required this.focusNode,
    required this.error,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'รหัสการจอง',
          style: appFont(
            fontSize: AppText.sizeBody,
            fontWeight: FontWeight.w800,
            color: AppTheme.textMain,
          ),
        ),
        const SizedBox(height: 8),
        _InputBox(
          hasError: hasError,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [_BookingRefFormatter()],
            textInputAction: TextInputAction.next,
            style: appFont(
              fontSize: AppText.sizeSubtitle,
              fontWeight: FontWeight.w800,
              color: AppTheme.textMain,
              letterSpacing: 0.4,
            ),
            decoration: InputDecoration(
              hintText: 'LLK-20250409-0001',
              hintStyle: appFont(
                color: AppTheme.mutedText(context),
                fontWeight: FontWeight.w600,
              ),
              prefixIcon: const Icon(
                Icons.confirmation_number_outlined,
                color: AppTheme.primaryColor,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            onSubmitted: (_) => onNext(),
          ),
        ),
        if (hasError) _ErrorText(error!),
      ],
    );
  }
}

class _NameField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? error;
  final VoidCallback onNext;

  const _NameField({
    required this.controller,
    required this.focusNode,
    required this.error,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ชื่อ-นามสกุลผู้เดินทาง',
          style: appFont(
            fontSize: AppText.sizeBody,
            fontWeight: FontWeight.w800,
            color: AppTheme.textMain,
          ),
        ),
        const SizedBox(height: 8),
        _InputBox(
          hasError: hasError,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textInputAction: TextInputAction.next,
            style: appFont(
              fontSize: AppText.sizeSubtitle,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMain,
            ),
            decoration: InputDecoration(
              hintText: 'ชื่อ-นามสกุล ตามที่ให้ไว้กับเจ้าหน้าที่',
              hintStyle: appFont(
                color: AppTheme.mutedText(context),
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: const Icon(
                Icons.person_outline_rounded,
                color: AppTheme.primaryColor,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            onSubmitted: (_) => onNext(),
          ),
        ),
        if (hasError) _ErrorText(error!),
      ],
    );
  }
}

class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? error;
  final String hint;
  final String hintPlaceholder;
  final VoidCallback onSubmitted;
  final bool digitsOnly;
  final int? maxLength;

  const _PhoneField({
    required this.controller,
    required this.focusNode,
    required this.error,
    required this.hint,
    required this.hintPlaceholder,
    required this.onSubmitted,
    this.digitsOnly = false,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hint,
          style: appFont(
            fontSize: AppText.sizeBody,
            fontWeight: FontWeight.w800,
            color: AppTheme.textMain,
          ),
        ),
        const SizedBox(height: 8),
        _InputBox(
          hasError: hasError,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.go,
            inputFormatters: [
              if (digitsOnly)
                FilteringTextInputFormatter.digitsOnly
              else
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
              if (maxLength != null)
                LengthLimitingTextInputFormatter(maxLength!),
            ],
            style: appFont(
              fontSize: AppText.sizeSubtitle,
              fontWeight: FontWeight.w800,
              color: AppTheme.textMain,
              letterSpacing: 0.4,
            ),
            decoration: InputDecoration(
              hintText: hintPlaceholder,
              hintStyle: appFont(
                color: AppTheme.mutedText(context),
                fontWeight: FontWeight.w600,
              ),
              prefixIcon: const Icon(
                Icons.phone_outlined,
                color: AppTheme.primaryColor,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            onSubmitted: (_) => onSubmitted(),
          ),
        ),
        if (hasError) _ErrorText(error!),
      ],
    );
  }
}

class _InputBox extends StatelessWidget {
  final bool hasError;
  final Widget child;

  const _InputBox({required this.hasError, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 54,
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: hasError
              ? AppTheme.errorColor
              : AppTheme.border(context).withValues(alpha: 0.55),
          width: hasError ? 1.4 : 1,
        ),
      ),
      child: child,
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String text;
  const _ErrorText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: appFont(
          color: AppTheme.errorColor,
          fontSize: AppText.sizeCaption,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Lookup Button ────────────────────────────────────────────────────────────

class _LookupButton extends StatelessWidget {
  final bool enabled;
  final bool isLoading;
  final VoidCallback onPressed;

  const _LookupButton({
    required this.enabled,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isLoading ? 0.99 : 1,
      duration: const Duration(milliseconds: 140),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          color: enabled ? AppTheme.primaryColor : AppTheme.border(context),
        ),
        child: FilledButton(
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white.withValues(alpha: 0.82),
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: isLoading
                ? const SizedBox(
                    key: ValueKey('loading'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    key: const ValueKey('label'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'ค้นหาการจอง',
                        style: appFont(
                          fontSize: AppText.sizeSubtitle,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Result Card ──────────────────────────────────────────────────────────────

/// การ์ดผลการค้นหา — คนที่ค้นเจอต้องได้ข้อมูลชุดเดียวกับที่เปิดในแอปตอนล็อกอิน
/// (จุดขึ้นรถ เวลา ผู้เดินทาง ที่นั่ง ยอดเงิน กำหนดการ ทีมงาน) ไม่ใช่แค่ชื่อทริป
///
/// ผลจากการค้นด้วยชื่อ+เบอร์ ([showSensitiveInfo] = false) หลังบ้านตัดรหัสการจอง
/// QR ลิงก์แชร์ และตัวเลขเงินออกให้แล้ว การ์ดจึงวาดเท่าที่มีมาโดยไม่ต้องรู้กติกาซ้ำ
class _GuestBookingResultCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool showSensitiveInfo;
  final VoidCallback onTrack;
  final VoidCallback? onReset;

  /// ผลเดี่ยว (ค้นด้วยรหัส) กางทุกหัวข้อไว้เลย ส่วนผลหลายรายการจากการค้นด้วยชื่อ
  /// เริ่มแบบย่อ ไม่งั้นเลื่อนหาการจองที่ต้องการไม่เจอ
  final bool expandedByDefault;

  const _GuestBookingResultCard({
    required this.data,
    required this.showSensitiveInfo,
    required this.onTrack,
    this.onReset,
    this.expandedByDefault = true,
  });

  @override
  State<_GuestBookingResultCard> createState() =>
      _GuestBookingResultCardState();
}

class _GuestBookingResultCardState extends State<_GuestBookingResultCard> {
  late bool _expanded = widget.expandedByDefault;

  Map<String, dynamic> get _data => widget.data;

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openMap({String? url, dynamic lat, dynamic lng}) async {
    final target = (url != null && url.isNotEmpty)
        ? url
        : (lat != null && lng != null)
        ? 'https://www.google.com/maps/search/?api=1&query=$lat,$lng'
        : '';
    if (target.isEmpty) return;
    final uri = Uri.parse(target);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = textOf(_data['status']);
    final isConfirmed = status == 'confirmed';
    final qrCode = textOf(_data['qr_code']);
    final shareUrl = textOf(_data['share_url']);
    final hasVehicle = _data['vehicle_id'] != null;
    final passengers = asList(_data['passengers']);
    final itinerary = asList(_data['itinerary']);
    final staff = asList(_data['staff']);
    final payment = asMap(_data['payment']);
    final vehicle = asMap(_data['vehicle']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GuestTripHeader(data: _data, showRef: widget.showSensitiveInfo),

        // จุดขึ้นรถ/จุดนัดพบ — สิ่งเดียวที่คนเปิดหน้านี้ตอนเช้าวันเดินทางต้องการ
        _GuestPickupSection(
          pickup: asMap(_data['pickup']),
          schedule: asMap(_data['schedule']),
          onOpenMap: _openMap,
        ),

        // QR เช็คอิน (เฉพาะค้นด้วยรหัสการจอง + ยืนยันแล้ว)
        if (widget.showSensitiveInfo && isConfirmed && qrCode.isNotEmpty) ...[
          const SizedBox(height: 16),
          _GuestCheckInCard(
            qrCode: qrCode,
            bookingRef: textOf(_data['booking_ref'], '-'),
            checkedIn: _data['checked_in'] == true,
            checkedInAt: textOf(_data['checked_in_at']),
          ),
        ],

        if (hasVehicle && isConfirmed) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: widget.onTrack,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              icon: const Icon(Icons.near_me_rounded, size: 19),
              label: Text(
                'ติดตามรถของฉัน',
                style: appFont(
                  fontSize: AppText.sizeSubtitle,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],

        if (widget.showSensitiveInfo && shareUrl.isNotEmpty && isConfirmed) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.selectionClick();
              SharePlus.instance.share(
                ShareParams(
                  text:
                      'ติดตามตำแหน่งรถ "${textOf(_data['trip_title'], 'ทริป')}" '
                      'แบบเรียลไทม์ได้ที่นี่เลย\n$shareUrl',
                  subject: 'ติดตามรถ - ลุยเลเขา',
                ),
              );
            },
            icon: const Icon(Icons.ios_share_rounded, size: 18),
            label: Text(
              'แชร์ตำแหน่งรถให้ครอบครัว',
              style: appFont(fontWeight: FontWeight.w800),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: const BorderSide(color: AppTheme.primaryColor),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              ),
            ),
          ),
        ],

        // ── รายละเอียดที่เหลือ ──
        if (!_expanded) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _expanded = true);
            },
            icon: const Icon(Icons.expand_more_rounded, size: 18),
            label: Text(
              'ดูรายละเอียดทั้งหมด',
              style: appFont(fontWeight: FontWeight.w800),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: BorderSide(color: AppTheme.border(context)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              ),
            ),
          ),
        ] else ...[
          _GuestPaymentSection(
            payment: payment,
            status: status,
            refundStatus: textOf(payment['refund_status']),
          ),
          _GuestPassengersSection(passengers: passengers),
          _GuestVehicleSection(
            vehicle: vehicle,
            staff: staff,
            onCall: _call,
          ),
          _GuestItinerarySection(items: itinerary),
        ],

        if (widget.onReset != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: widget.onReset,
            icon: const Icon(Icons.search_rounded, size: 18),
            label: Text(
              'ค้นหาการจองอื่น',
              style: appFont(fontWeight: FontWeight.w800),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: BorderSide(color: AppTheme.border(context)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Result sections ──────────────────────────────────────────────────────────

/// หัวการ์ด: รูปทริป ชื่อ สถานะ รหัส วันเดินทาง–วันกลับ และข้อมูลรอบสั้น ๆ
class _GuestTripHeader extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool showRef;

  const _GuestTripHeader({required this.data, required this.showRef});

  @override
  Widget build(BuildContext context) {
    final trip = asMap(data['trip']);
    final schedule = asMap(data['schedule']);
    final cover = textOf(trip['thumbnail_image'], textOf(trip['cover_image']));
    final ref = textOf(data['booking_ref']);
    final departsAt = textOf(schedule['departs_at'], textOf(data['departs_at']));
    final departureDate = textOf(
      schedule['departure_date'],
      textOf(data['departure_date']),
    );
    final returnDate = textOf(schedule['return_date']);
    final checkedIn = data['checked_in'] == true;

    final travelLine = _travelLine(departureDate, returnDate, departsAt);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cover.isNotEmpty)
            SizedBox(
              height: 130,
              width: double.infinity,
              child: CachedNetworkImage(
                imageUrl: ApiConfig.mediaUrl(cover),
                fit: BoxFit.cover,
                memCacheWidth: 900,
                placeholder: (_, _) =>
                    Container(color: AppTheme.subtleSurface(context)),
                errorWidget: (_, _, _) =>
                    Container(color: AppTheme.subtleSurface(context)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        textOf(data['trip_title'], 'ทริปของคุณ'),
                        style: appFont(
                          fontSize: AppText.sizeTitle,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onSurface(context),
                          height: 1.25,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(status: textOf(data['status'])),
                  ],
                ),
                if (showRef && ref.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  SelectableText(
                    ref,
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (travelLine.isNotEmpty)
                  _GuestInfoRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'วันเดินทาง',
                    value: travelLine,
                  ),
                if (textOf(trip['location']).isNotEmpty)
                  _GuestInfoRow(
                    icon: Icons.place_rounded,
                    label: 'จุดหมาย',
                    value: textOf(trip['location']),
                  ),
                if (trip['duration_days'] != null)
                  _GuestInfoRow(
                    icon: Icons.schedule_rounded,
                    label: 'ระยะเวลา',
                    value: '${trip['duration_days']} วัน',
                  ),
                if (textOf(data['group_name']).isNotEmpty)
                  _GuestInfoRow(
                    icon: Icons.groups_rounded,
                    label: 'ชื่อกลุ่ม',
                    value: textOf(data['group_name']),
                  ),
                if (textOf(data['booked_at']).isNotEmpty)
                  _GuestInfoRow(
                    icon: Icons.receipt_long_rounded,
                    label: 'จองเมื่อ',
                    value: _dateOnly(textOf(data['booked_at'])),
                  ),
                if (checkedIn) ...[
                  const SizedBox(height: 10),
                  const _GuestNoticePill(
                    icon: Icons.how_to_reg_rounded,
                    color: AppTheme.successColor,
                    text: 'เช็คอินแล้ว',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _travelLine(String departureDate, String returnDate, String departsAt) {
    final start = DateTime.tryParse(
      departsAt.isNotEmpty ? departsAt : departureDate,
    );
    if (start == null) return '';

    final base = departsAt.isNotEmpty
        ? '${thaiDateShort(start)} ${DateFormat('HH:mm').format(start)} น.'
        : thaiDateShort(start);

    final end = DateTime.tryParse(returnDate);
    final tripDay = DateTime.tryParse(departureDate);
    if (end != null && tripDay != null && !_sameDay(end, tripDay)) {
      return '$base – ${thaiDateShort(end)}';
    }
    return base;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// จุดขึ้นรถของการจองนี้ — รวมเวลานัด หมายเหตุ และปุ่มเปิดแผนที่
class _GuestPickupSection extends StatelessWidget {
  final Map<String, dynamic> pickup;
  final Map<String, dynamic> schedule;
  final Future<void> Function({String? url, dynamic lat, dynamic lng}) onOpenMap;

  const _GuestPickupSection({
    required this.pickup,
    required this.schedule,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    // รอบที่บินไปไม่มีจุดรับ มีจุดนัดพบที่สนามบินแทน
    final isFlight = textOf(schedule['transport_type']) == 'flight';
    final meetingPoint = textOf(schedule['meeting_point']);

    if (isFlight && meetingPoint.isNotEmpty) {
      return _GuestSection(
        icon: Icons.flight_takeoff_rounded,
        title: 'จุดนัดพบ',
        children: [
          _GuestInfoRow(
            icon: Icons.place_rounded,
            label: 'สถานที่',
            value: meetingPoint,
          ),
          if (textOf(schedule['meeting_time']).isNotEmpty)
            _GuestInfoRow(
              icon: Icons.schedule_rounded,
              label: 'เวลานัดพบ',
              value: '${textOf(schedule['meeting_time'])} น.',
            ),
          if (textOf(schedule['baggage_allowance']).isNotEmpty)
            _GuestInfoRow(
              icon: Icons.luggage_rounded,
              label: 'น้ำหนักกระเป๋า',
              value: textOf(schedule['baggage_allowance']),
            ),
          if (textOf(schedule['meeting_map_url']).isNotEmpty)
            _GuestMapButton(
              onTap: () => onOpenMap(url: textOf(schedule['meeting_map_url'])),
            ),
        ],
      );
    }

    if (pickup.isEmpty) return const SizedBox.shrink();

    final kind = textOf(pickup['kind']);
    final location = textOf(
      pickup['location'],
      textOf(pickup['region_label'], textOf(pickup['region'])),
    );
    if (location.isEmpty) return const SizedBox.shrink();

    final customStatus = textOf(pickup['status']);

    return _GuestSection(
      icon: Icons.directions_bus_rounded,
      title: 'จุดขึ้นรถ',
      children: [
        _GuestInfoRow(
          icon: Icons.place_rounded,
          label: kind == 'custom' ? 'จุดที่ปักหมุดไว้' : 'สถานที่',
          value: location,
        ),
        if (textOf(pickup['pickup_time']).isNotEmpty)
          _GuestInfoRow(
            icon: Icons.schedule_rounded,
            label: 'เวลานัด',
            value: '${textOf(pickup['pickup_time'])} น.',
          ),
        if (textOf(pickup['region_label']).isNotEmpty && kind == 'point')
          _GuestInfoRow(
            icon: Icons.map_rounded,
            label: 'โซน',
            value: textOf(pickup['region_label']),
          ),
        if (textOf(pickup['notes']).isNotEmpty)
          _GuestInfoRow(
            icon: Icons.sticky_note_2_rounded,
            label: 'หมายเหตุ',
            value: textOf(pickup['notes']),
          ),
        if (kind == 'custom' && customStatus.isNotEmpty)
          _GuestNoticePill(
            icon: customStatus == 'approved'
                ? Icons.check_circle_rounded
                : customStatus == 'rejected'
                ? Icons.cancel_rounded
                : Icons.hourglass_top_rounded,
            color: customStatus == 'approved'
                ? AppTheme.successColor
                : customStatus == 'rejected'
                ? AppTheme.errorColor
                : AppTheme.warningColor,
            text: switch (customStatus) {
              'approved' => 'ทีมงานอนุมัติจุดรับนี้แล้ว',
              'rejected' =>
                'จุดรับนี้ถูกปฏิเสธ${textOf(pickup['reject_reason']).isEmpty ? '' : ' — ${textOf(pickup['reject_reason'])}'}',
              _ => 'รอทีมงานยืนยันจุดรับ',
            },
          ),
        if (textOf(pickup['map_url']).isNotEmpty ||
            (pickup['latitude'] != null && pickup['longitude'] != null))
          _GuestMapButton(
            onTap: () => onOpenMap(
              url: textOf(pickup['map_url']),
              lat: pickup['latitude'],
              lng: pickup['longitude'],
            ),
          ),
      ],
    );
  }
}

/// สรุปการชำระเงิน — ตัวเลขมาเฉพาะตอนค้นด้วยรหัสการจอง (amounts_hidden)
class _GuestPaymentSection extends StatelessWidget {
  final Map<String, dynamic> payment;
  final String status;
  final String refundStatus;

  const _GuestPaymentSection({
    required this.payment,
    required this.status,
    required this.refundStatus,
  });

  @override
  Widget build(BuildContext context) {
    if (payment.isEmpty) return const SizedBox.shrink();

    final hidden = payment['amounts_hidden'] == true;
    final fullyPaid = payment['is_fully_paid'] == true;
    final hasOutstanding = payment['has_outstanding'] == true;
    final type = textOf(payment['payment_type'], 'full');
    final typeLabel = switch (type) {
      'deposit' => 'จ่ายมัดจำ',
      'installment' => 'ผ่อนชำระ',
      _ => 'จ่ายเต็มจำนวน',
    };
    final installments = asList(payment['installments']);
    final addons = asList(payment['addons']);
    final rentals = asList(payment['rentals']);

    return _GuestSection(
      icon: Icons.payments_rounded,
      title: 'การชำระเงิน',
      children: [
        _GuestNoticePill(
          icon: fullyPaid
              ? Icons.verified_rounded
              : payment['slip_under_review'] == true
              ? Icons.hourglass_top_rounded
              : Icons.info_rounded,
          color: fullyPaid
              ? AppTheme.successColor
              : payment['slip_under_review'] == true
              ? AppTheme.infoColor
              : AppTheme.warningColor,
          text: fullyPaid
              ? 'ชำระครบแล้ว'
              : payment['slip_under_review'] == true
              ? 'ได้รับสลิปแล้ว รอทีมงานตรวจสอบ'
              : hasOutstanding
              ? 'ยังมียอดค้างชำระ'
              : 'รอการชำระเงิน',
        ),
        _GuestInfoRow(
          icon: Icons.account_balance_wallet_rounded,
          label: 'รูปแบบ',
          value: typeLabel,
        ),
        if (!hidden) ...[
          _GuestInfoRow(
            icon: Icons.summarize_rounded,
            label: 'ยอดรวม',
            value: money(payment['total_amount']),
          ),
          _GuestInfoRow(
            icon: Icons.check_circle_rounded,
            label: 'ชำระแล้ว',
            value: money(payment['paid_amount']),
          ),
          if ((num.tryParse(textOf(payment['outstanding_amount'])) ?? 0) > 0)
            _GuestInfoRow(
              icon: Icons.pending_actions_rounded,
              label: 'คงเหลือ',
              value: money(payment['outstanding_amount']),
              highlight: true,
            ),
          if ((num.tryParse(textOf(payment['discount_amount'])) ?? 0) > 0)
            _GuestInfoRow(
              icon: Icons.local_offer_rounded,
              label: 'ส่วนลด',
              value:
                  '- ${money(payment['discount_amount'])}'
                  '${textOf(payment['promotion_code']).isEmpty ? '' : ' (${textOf(payment['promotion_code'])})'}',
            ),
          if ((num.tryParse(textOf(payment['flexi_surcharge'])) ?? 0) > 0)
            _GuestInfoRow(
              icon: Icons.trending_up_rounded,
              label: 'ส่วนต่างเก็บวันเดินทาง',
              value: money(payment['flexi_surcharge']),
            ),
        ],
        if (textOf(payment['balance_due_at']).isNotEmpty &&
            payment['balance_paid_at'] == null)
          _GuestInfoRow(
            icon: Icons.event_busy_rounded,
            label: 'กำหนดชำระส่วนที่เหลือ',
            value: _dateOnly(textOf(payment['balance_due_at'])),
            highlight: true,
          ),
        if (textOf(payment['paid_at']).isNotEmpty)
          _GuestInfoRow(
            icon: Icons.task_alt_rounded,
            label: 'ชำระเมื่อ',
            value: _dateOnly(textOf(payment['paid_at'])),
          ),
        if (addons.isNotEmpty) ...[
          const SizedBox(height: 4),
          _GuestLineItems(title: 'ของแถม/บริการเสริม', items: addons),
        ],
        if (rentals.isNotEmpty) ...[
          const SizedBox(height: 4),
          _GuestLineItems(title: 'อุปกรณ์เช่า', items: rentals),
        ],
        if (installments.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...installments.map((raw) {
            final item = asMap(raw);
            final paid = textOf(item['status']) == 'paid';
            return _GuestInfoRow(
              icon: paid
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              label: 'งวดที่ ${textOf(item['installment_no'], '-')}',
              value:
                  '${money(item['amount'])} · '
                  '${paid ? 'จ่ายแล้ว' : 'ครบกำหนด ${_dateOnly(textOf(item['due_date']))}'}',
            );
          }),
        ],
        if (refundStatus.isNotEmpty)
          _GuestInfoRow(
            icon: Icons.assignment_return_rounded,
            label: 'สถานะคืนเงิน',
            value: switch (refundStatus) {
              'pending' => 'รอดำเนินการ',
              'processing' => 'กำลังโอนคืน',
              'completed' => 'คืนเงินแล้ว',
              'rejected' => 'ไม่อนุมัติ',
              _ => refundStatus,
            },
          ),
      ],
    );
  }
}

/// ผู้เดินทางในการจอง — ชื่อ ที่นั่ง เบอร์ (ปิดกลาง) จุดขึ้นรถรายคน
class _GuestPassengersSection extends StatelessWidget {
  final List<dynamic> passengers;

  const _GuestPassengersSection({required this.passengers});

  @override
  Widget build(BuildContext context) {
    if (passengers.isEmpty) return const SizedBox.shrink();

    return _GuestSection(
      icon: Icons.people_alt_rounded,
      title: 'ผู้เดินทาง (${passengers.length} คน)',
      children: [
        for (final raw in passengers) ...[
          Builder(
            builder: (context) {
              final p = asMap(raw);
              final seat = textOf(p['seat']);
              final nickname = textOf(p['nickname']);
              final details = [
                if (seat.isNotEmpty) 'ที่นั่ง $seat',
                if (textOf(p['phone']).isNotEmpty) textOf(p['phone']),
                if (textOf(p['pickup_location']).isNotEmpty)
                  'ขึ้นรถ ${textOf(p['pickup_location'])}',
              ].join(' · ');

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.selectedTint(context),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        seat.isNotEmpty
                            ? seat
                            : textOf(p['name'], '?').characters.first,
                        style: appFont(
                          fontSize: AppText.sizeCaption,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  textOf(p['name'], 'ผู้เดินทาง') +
                                      (nickname.isEmpty ? '' : ' ($nickname)'),
                                  style: appFont(
                                    fontSize: AppText.sizeBody,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.onSurface(context),
                                  ),
                                ),
                              ),
                              if (p['halal_food'] == true) ...[
                                const SizedBox(width: 6),
                                const _GuestTag(text: 'ฮาลาล'),
                              ],
                            ],
                          ),
                          if (details.isNotEmpty)
                            Text(
                              details,
                              style: appFont(
                                fontSize: AppText.sizeCaption,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.mutedText(context),
                                height: 1.4,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

/// รถ คนขับ และทีมงานที่ดูแลรอบนี้ พร้อมปุ่มโทร
class _GuestVehicleSection extends StatelessWidget {
  final Map<String, dynamic> vehicle;
  final List<dynamic> staff;
  final Future<void> Function(String phone) onCall;

  const _GuestVehicleSection({
    required this.vehicle,
    required this.staff,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    if (vehicle.isEmpty && staff.isEmpty) return const SizedBox.shrink();

    final driverPhone = textOf(vehicle['driver_phone']);

    return _GuestSection(
      icon: Icons.airport_shuttle_rounded,
      title: 'รถและทีมงาน',
      children: [
        if (textOf(vehicle['license_plate']).isNotEmpty)
          _GuestInfoRow(
            icon: Icons.confirmation_number_rounded,
            label: 'ทะเบียนรถ',
            value: [
              textOf(vehicle['license_plate']),
              if (textOf(vehicle['color']).isNotEmpty)
                'สี${textOf(vehicle['color'])}',
            ].join(' · '),
          ),
        if (textOf(vehicle['name']).isNotEmpty)
          _GuestInfoRow(
            icon: Icons.directions_bus_rounded,
            label: 'คันที่ใช้',
            value: textOf(vehicle['name']),
          ),
        if (textOf(vehicle['driver_name']).isNotEmpty)
          _GuestInfoRow(
            icon: Icons.person_rounded,
            label: 'คนขับ',
            value: textOf(vehicle['driver_name']),
          ),
        if (driverPhone.isNotEmpty)
          _GuestCallRow(
            label: 'โทรหาคนขับ',
            phone: driverPhone,
            onCall: onCall,
          ),
        for (final raw in staff) ...[
          Builder(
            builder: (context) {
              final s = asMap(raw);
              final phone = textOf(s['phone']);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GuestInfoRow(
                    icon: Icons.support_agent_rounded,
                    label: 'ทีมงาน',
                    value: textOf(s['name'], 'ทีมงาน'),
                  ),
                  if (phone.isNotEmpty)
                    _GuestCallRow(
                      label: 'โทรหา ${textOf(s['name'], 'ทีมงาน')}',
                      phone: phone,
                      onCall: onCall,
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

/// กำหนดการของรอบ จัดกลุ่มตามวัน
class _GuestItinerarySection extends StatelessWidget {
  final List<dynamic> items;

  const _GuestItinerarySection({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final raw in items) {
      final item = asMap(raw);
      grouped.putIfAbsent(textOf(item['item_date']), () => []).add(item);
    }

    return _GuestSection(
      icon: Icons.event_note_rounded,
      title: 'กำหนดการ',
      children: [
        for (final entry in grouped.entries) ...[
          if (entry.key.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                _dateOnly(entry.key),
                style: appFont(
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
          for (final item in entry.value)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      textOf(item['time'], '—'),
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          textOf(item['title']),
                          style: appFont(
                            fontSize: AppText.sizeBody,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onSurface(context),
                            height: 1.35,
                          ),
                        ),
                        if (textOf(item['detail']).isNotEmpty)
                          Text(
                            textOf(item['detail']),
                            style: appFont(
                              fontSize: AppText.sizeCaption,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.mutedText(context),
                              height: 1.45,
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

/// QR เช็คอิน — สลับเป็นสถานะ "เช็คอินแล้ว" เมื่อถูกสแกนไปแล้ว
class _GuestCheckInCard extends StatelessWidget {
  final String qrCode;
  final String bookingRef;
  final bool checkedIn;
  final String checkedInAt;

  const _GuestCheckInCard({
    required this.qrCode,
    required this.bookingRef,
    required this.checkedIn,
    required this.checkedInAt,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.primaryColor.withValues(alpha: 0.14)
            : AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              checkedIn ? Icons.check_circle_rounded : Icons.how_to_reg_rounded,
              color: AppTheme.primaryColor,
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            checkedIn ? 'เช็คอินแล้ว' : 'พร้อมสำหรับเช็คอิน',
            style: appFont(
              color: AppTheme.onSurface(context),
              fontSize: AppText.sizeSubtitle,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            checkedIn
                ? (checkedInAt.isEmpty
                      ? 'รหัสนี้ถูกสแกนเรียบร้อยแล้ว'
                      : 'เช็คอินเมื่อ ${_dateTime(checkedInAt)}')
                : 'โปรดแสดงรหัสนี้แก่เจ้าหน้าที่เมื่อถึงจุดนัดหมาย',
            textAlign: TextAlign.center,
            style: appFont(
              color: AppTheme.mutedText(context),
              fontSize: AppText.sizeCaption,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!checkedIn) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.14),
                ),
              ),
              child: QrImageView(
                data: qrCode,
                version: QrVersions.auto,
                size: 180,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SelectableText(
            bookingRef,
            style: appFont(
              color: AppTheme.primaryColor,
              fontSize: AppText.sizeSubtitle,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Small building blocks ────────────────────────────────────────────────────

class _GuestSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _GuestSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final visible = children
        .where((child) => child is! SizedBox || child.height != 0)
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: AppTheme.border(context).withValues(alpha: 0.55),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 17, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _GuestInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  const _GuestInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppTheme.mutedText(context)),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: appFont(
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w600,
                color: AppTheme.mutedText(context),
                height: 1.4,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: highlight ? FontWeight.w900 : FontWeight.w700,
                color: highlight
                    ? AppTheme.primaryColor
                    : AppTheme.onSurface(context),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestCallRow extends StatelessWidget {
  final String label;
  final String phone;
  final Future<void> Function(String phone) onCall;

  const _GuestCallRow({
    required this.label,
    required this.phone,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onCall(phone);
            },
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: AppTheme.selectedTint(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.call_rounded,
                    size: 15,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$label · $phone',
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuestMapButton extends StatelessWidget {
  final VoidCallback onTap;

  const _GuestMapButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: AppTheme.selectedTint(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.map_rounded,
                  size: 15,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'เปิดแผนที่จุดนัดหมาย',
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GuestLineItems extends StatelessWidget {
  final String title;
  final List<dynamic> items;

  const _GuestLineItems({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: appFont(
            fontSize: AppText.sizeCaption,
            fontWeight: FontWeight.w800,
            color: AppTheme.mutedText(context),
          ),
        ),
        const SizedBox(height: 6),
        for (final raw in items)
          Builder(
            builder: (context) {
              final item = asMap(raw);
              final quantity = int.tryParse(textOf(item['quantity'])) ?? 1;
              final price = num.tryParse(textOf(item['price']));
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${textOf(item['name'], 'รายการ')}'
                        '${quantity > 1 ? ' ×$quantity' : ''}',
                        style: appFont(
                          fontSize: AppText.sizeCaption,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onSurface(context),
                        ),
                      ),
                    ),
                    if (price != null)
                      Text(
                        money(price * quantity),
                        style: appFont(
                          fontSize: AppText.sizeCaption,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.mutedText(context),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _GuestNoticePill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _GuestNoticePill({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: appFont(
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestTag extends StatelessWidget {
  final String text;

  const _GuestTag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.6),
        ),
      ),
      child: Text(
        text,
        style: appFont(
          fontSize: AppText.sizeMicro,
          fontWeight: FontWeight.w800,
          color: AppTheme.mutedText(context),
        ),
      ),
    );
  }
}

/// "2026-09-05" / ISO → "5 ก.ย. 2569"
String _dateOnly(String raw) {
  final parsed = DateTime.tryParse(raw);
  return parsed == null ? raw : thaiDateShort(parsed.toLocal());
}

String _dateTime(String raw) {
  final parsed = DateTime.tryParse(raw);
  return parsed == null ? raw : thaiDateTimeShort(parsed.toLocal());
}

class _EmptyNameResult extends StatelessWidget {
  final VoidCallback onReset;
  const _EmptyNameResult({required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: AppTheme.border(context).withValues(alpha: 0.55),
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 44,
                color: AppTheme.mutedText(context),
              ),
              const SizedBox(height: 12),
              Text(
                'ไม่พบข้อมูลการจอง',
                style: appFont(
                  fontSize: AppText.sizeSubtitle,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface(context),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'ลองตรวจสอบชื่อ-นามสกุลและเบอร์โทรอีกครั้ง\nหรือติดต่อเจ้าหน้าที่',
                textAlign: TextAlign.center,
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.mutedText(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onReset,
          icon: const Icon(Icons.search_rounded, size: 18),
          label: Text(
            'ค้นหาใหม่',
            style: appFont(fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primaryColor,
            side: BorderSide(
              color: AppTheme.border(context).withValues(alpha: 0.55),
            ),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'confirmed' => ('ยืนยันแล้ว', AppTheme.primaryColor),
      'pending' => ('รอชำระ', AppTheme.warningColor),
      'cancelled' => ('ยกเลิก', AppTheme.errorColor),
      'refunded' => ('คืนเงินแล้ว', AppTheme.errorColor),
      'completed' => ('จบทริป', AppTheme.textSecondary),
      _ => (status.isEmpty ? 'ไม่ระบุ' : status, AppTheme.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Text(
        label,
        style: appFont(
          fontSize: AppText.sizeCaption,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

// ─── Help Card ────────────────────────────────────────────────────────────────

class _GuestHelpCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.help_outline_rounded,
                color: AppTheme.primaryColor,
                size: 19,
              ),
              const SizedBox(width: 8),
              Text(
                'หาข้อมูลไม่เจอ?',
                style: appFont(
                  fontWeight: FontWeight.w800,
                  fontSize: AppText.sizeSubtitle,
                  color: AppTheme.textMain,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _HelpItem(
            icon: Icons.confirmation_number_outlined,
            text:
                'รหัสการจอง: รับจากเจ้าหน้าที่ที่จองให้ เช่น LLK-20250409-0001',
          ),
          const SizedBox(height: 6),
          const _HelpItem(
            icon: Icons.phone_outlined,
            text: 'เบอร์โทร: ใช้เบอร์ที่ให้ไว้กับเจ้าหน้าที่ตอนจอง',
          ),
          const SizedBox(height: 6),
          const _HelpItem(
            icon: Icons.person_outline_rounded,
            text: 'ชื่อ: ใช้ชื่อ-นามสกุลเต็มตามที่แจ้งไว้ตอนจอง',
          ),

          // ── ติดต่อเจ้าหน้าที่ ──────────────────────────────────────────
          const SizedBox(height: 16),
          Divider(
            color: AppTheme.border(context).withValues(alpha: 0.45),
            height: 0.5,
          ),
          const SizedBox(height: 14),
          Text(
            'ต้องการความช่วยเหลือ?',
            style: appFont(
              fontWeight: FontWeight.w700,
              fontSize: AppText.sizeBody,
              color: AppTheme.textMain,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ContactButton(
                  icon: Icons.chat_rounded,
                  label: 'LINE',
                  color: const Color(0xFF06C755),
                  onTap: () => _launch('https://line.me/R/ti/p/@luilaykhao'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ContactButton(
                  icon: Icons.phone_rounded,
                  label: 'โทรหาเรา',
                  color: AppTheme.primaryColor,
                  onTap: () => _launch('tel:0626126006'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }
}

class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ContactButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: appFont(
                fontWeight: FontWeight.w800,
                fontSize: AppText.sizeLabel,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HelpItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.mutedText(context)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: appFont(
              fontSize: AppText.sizeLabel,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Formatter ────────────────────────────────────────────────────────────────

class _BookingRefFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final compact = newValue.text
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toUpperCase();
    final limited = compact.length > 15 ? compact.substring(0, 15) : compact;
    final parts = <String>[];
    if (limited.isNotEmpty) {
      parts.add(limited.substring(0, limited.length.clamp(0, 3)));
    }
    if (limited.length > 3) {
      parts.add(limited.substring(3, limited.length.clamp(3, 11)));
    }
    if (limited.length > 11) parts.add(limited.substring(11));
    final text = parts.join('-');
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
