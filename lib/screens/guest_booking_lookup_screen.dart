import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_endpoints.dart';
import '../models/tracking_model.dart';
import '../providers/tracking_provider.dart';
import '../services/api_client.dart';
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
    final compact =
        raw.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
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
        _extractRef(_refController.text) ?? _refController.text.trim().toUpperCase();
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
      final response = await client.post(
        ApiEndpoints.bookingsGuestLookup,
        body: {'booking_ref': ref, 'phone': phone},
      ) as Map<String, dynamic>;

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
      final response = await client.post(
        ApiEndpoints.bookingsGuestLookupByName,
        body: {'name': name, 'phone': phone},
      ) as Map<String, dynamic>;

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

    // เปิดให้ติดตามรถตามวันออกรถจริง (departs_at) — รอบที่รถออกคืนก่อน
    // วันทริปจะติดตามได้ตั้งแต่คืนนั้น
    final departureDate = (result['departs_at'] ?? result['departure_date'])
            ?.toString() ??
        '';
    final date = DateTime.tryParse(departureDate);
    if (date != null) {
      final today = DateTime.now();
      final d = DateTime(date.year, date.month, date.day);
      final t = DateTime(today.year, today.month, today.day);
      if (d.isAfter(t)) {
        _showSnack('สามารถติดตามรถได้ในวันเดินทาง');
        return;
      }
      if (d.isBefore(t)) {
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content:
            Text(msg, style: GoogleFonts.anuphan(fontWeight: FontWeight.w600)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ));
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
              backgroundColor:
                  AppTheme.background(context).withValues(alpha: 0.92),
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: true,
              title: Text(
                'ค้นหาการจอง',
                style: GoogleFonts.anuphan(
                  color: AppTheme.onSurface(context),
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.2,
                ),
              ),
              leading: Navigator.canPop(context)
                  ? IconButton(
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
                                  bottom: i < _nameResults!.length - 1 ? 16 : 0),
                              child: _GuestBookingResultCard(
                                data: item,
                                showSensitiveInfo: false,
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
                              style: GoogleFonts.anuphan(
                                  fontWeight: FontWeight.w800),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              side: BorderSide(
                                  color: AppTheme.border(context)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
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
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        children: [
          _ToggleChip(
            label: 'รหัสการจอง + เบอร์',
            icon: Icons.confirmation_number_outlined,
            selected: mode == _LookupMode.byRef,
            onTap: () => onChanged(_LookupMode.byRef),
          ),
          _ToggleChip(
            label: 'ชื่อ + เบอร์โทร',
            icon: Icons.person_search_outlined,
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
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected
                    ? Colors.white
                    : AppTheme.mutedText(context),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.anuphan(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                    color: selected
                        ? Colors.white
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
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.55),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.confirmation_number_outlined,
              color: AppTheme.primaryColor,
              size: 26,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'ดู QR และติดตามรถ\nโดยไม่ต้องสมัครสมาชิก',
            style: GoogleFonts.anuphan(
              fontSize: 22,
              height: 1.25,
              fontWeight: FontWeight.w800,
              color: AppTheme.onSurface(context),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ค้นหาด้วยรหัสการจอง หรือชื่อ-นามสกุลพร้อมเบอร์โทรที่ให้ไว้',
            style: GoogleFonts.anuphan(
              fontSize: 14,
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
          style: GoogleFonts.anuphan(
            fontSize: 14,
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
            style: GoogleFonts.anuphan(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.textMain,
              letterSpacing: 0.4,
            ),
            decoration: InputDecoration(
              hintText: 'LLK-20250409-0001',
              hintStyle: GoogleFonts.anuphan(
                color: const Color(0xFF98A2B3),
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
          style: GoogleFonts.anuphan(
            fontSize: 14,
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
            style: GoogleFonts.anuphan(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMain,
            ),
            decoration: InputDecoration(
              hintText: 'ชื่อ-นามสกุล ตามที่ให้ไว้กับเจ้าหน้าที่',
              hintStyle: GoogleFonts.anuphan(
                color: const Color(0xFF98A2B3),
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
          style: GoogleFonts.anuphan(
            fontSize: 14,
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
            style: GoogleFonts.anuphan(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.textMain,
              letterSpacing: 0.4,
            ),
            decoration: InputDecoration(
              hintText: hintPlaceholder,
              hintStyle: GoogleFonts.anuphan(
                color: const Color(0xFF98A2B3),
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
        borderRadius: BorderRadius.circular(14),
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
        style: GoogleFonts.anuphan(
          color: AppTheme.errorColor,
          fontSize: 12,
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
          borderRadius: BorderRadius.circular(16),
          color: enabled ? AppTheme.primaryColor : const Color(0xFFD0D5DD),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
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
              borderRadius: BorderRadius.circular(16),
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
                        style: GoogleFonts.anuphan(
                          fontSize: 16,
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

class _GuestBookingResultCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool showSensitiveInfo;
  final VoidCallback onTrack;
  final VoidCallback? onReset;

  const _GuestBookingResultCard({
    required this.data,
    required this.showSensitiveInfo,
    required this.onTrack,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final ref = data['booking_ref']?.toString() ?? '-';
    final status = data['status']?.toString() ?? '';
    final qrCode = data['qr_code']?.toString() ?? '';
    final tripTitle = data['trip_title']?.toString() ?? 'ทริปของคุณ';
    final departsAtRaw = data['departs_at']?.toString() ?? '';
    final departureDate = departsAtRaw.isNotEmpty
        ? departsAtRaw
        : data['departure_date']?.toString() ?? '';
    final driverName = data['driver_name']?.toString();
    final licensePlate = data['license_plate']?.toString();
    final shareUrl = data['share_url']?.toString();
    final hasVehicle = data['vehicle_id'] != null;
    final isConfirmed = status == 'confirmed';
    final isDark = AppTheme.isDark(context);

    String formattedDate = departureDate;
    final parsed = DateTime.tryParse(departureDate);
    if (parsed != null) {
      final months = [
        '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
        'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
      ];
      formattedDate =
          '${parsed.day} ${months[parsed.month]} ${parsed.year + 543}';
      // แสดงเวลาออกรถด้วยเมื่อรอบนั้นกำหนดเวลาออกรถจริงไว้
      if (departsAtRaw.isNotEmpty) {
        final hh = parsed.hour.toString().padLeft(2, '0');
        final mm = parsed.minute.toString().padLeft(2, '0');
        formattedDate = '$formattedDate $hh:$mm น.';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Trip info card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.border(context).withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tripTitle,
                      style: GoogleFonts.anuphan(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor,
                        height: 1.25,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(status: status),
                ],
              ),
              if (showSensitiveInfo) ...[
                const SizedBox(height: 6),
                Text(
                  ref,
                  style: GoogleFonts.anuphan(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.mutedText(context),
                  ),
                ),
              ],
              if (formattedDate.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 15, color: AppTheme.mutedText(context)),
                    const SizedBox(width: 6),
                    Text(
                      'เดินทาง $formattedDate',
                      style: GoogleFonts.anuphan(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                  ],
                ),
              ],
              if (driverName != null || licensePlate != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.directions_bus_outlined,
                        size: 15, color: AppTheme.mutedText(context)),
                    const SizedBox(width: 6),
                    Text(
                      [
                        if (driverName != null && driverName.isNotEmpty)
                          driverName,
                        if (licensePlate != null && licensePlate.isNotEmpty)
                          licensePlate,
                      ].join(' • '),
                      style: GoogleFonts.anuphan(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // QR check-in card (only for ref lookup + confirmed)
        if (showSensitiveInfo && isConfirmed && qrCode.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.primaryColor.withValues(alpha: 0.14)
                  : AppTheme.primaryColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.16)),
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
                  child: const Icon(Icons.how_to_reg_rounded,
                      color: AppTheme.primaryColor, size: 26),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.verified_rounded,
                        size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 6),
                    Text(
                      'พร้อมสำหรับเช็คอิน',
                      style: GoogleFonts.anuphan(
                        color: AppTheme.onSurface(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'โปรดแสดงรหัสนี้แก่เจ้าหน้าที่เมื่อถึงจุดนัดหมาย',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.anuphan(
                    color: AppTheme.mutedText(context),
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color:
                            AppTheme.primaryColor.withValues(alpha: 0.14)),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: qrCode,
                    version: QrVersions.auto,
                    size: 180,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                ),
                const SizedBox(height: 16),
                SelectableText(
                  ref,
                  style: GoogleFonts.anuphan(
                    color: AppTheme.primaryColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Track button
        if (hasVehicle && isConfirmed) ...[
          const SizedBox(height: 16),
          Container(
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppTheme.primaryColor,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: FilledButton.icon(
              onPressed: onTrack,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.near_me_rounded, size: 19),
              label: Text(
                'ติดตามรถของฉัน',
                style: GoogleFonts.anuphan(
                    fontSize: 16, fontWeight: FontWeight.w800,
                    letterSpacing: -0.2),
              ),
            ),
          ),
        ],

        // Share link (ref lookup only)
        if (showSensitiveInfo &&
            shareUrl != null &&
            shareUrl.isNotEmpty &&
            isConfirmed) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.selectionClick();
              SharePlus.instance.share(
                ShareParams(
                  text:
                      'ติดตามตำแหน่งรถ "$tripTitle" แบบเรียลไทม์ได้ที่นี่เลย\n$shareUrl',
                  subject: 'ติดตามรถ - ลุยเลเขา',
                ),
              );
            },
            icon: const Icon(Icons.ios_share_rounded, size: 18),
            label: Text(
              'แชร์ตำแหน่งรถให้ครอบครัว',
              style: GoogleFonts.anuphan(fontWeight: FontWeight.w800),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: const BorderSide(color: AppTheme.primaryColor),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
        ],

        if (onReset != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.search_rounded, size: 18),
            label: Text(
              'ค้นหาการจองอื่น',
              style: GoogleFonts.anuphan(fontWeight: FontWeight.w800),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: BorderSide(color: AppTheme.border(context)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
        ],
      ],
    );
  }
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
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.border(context).withValues(alpha: 0.55),
            ),
          ),
          child: Column(
            children: [
              Icon(Icons.search_off_rounded,
                  size: 44, color: AppTheme.mutedText(context)),
              const SizedBox(height: 12),
              Text(
                'ไม่พบข้อมูลการจอง',
                style: GoogleFonts.anuphan(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface(context),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'ลองตรวจสอบชื่อ-นามสกุลและเบอร์โทรอีกครั้ง\nหรือติดต่อเจ้าหน้าที่',
                textAlign: TextAlign.center,
                style: GoogleFonts.anuphan(
                  fontSize: 13,
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
          label: Text('ค้นหาใหม่',
              style: GoogleFonts.anuphan(fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primaryColor,
            side: BorderSide(
              color: AppTheme.border(context).withValues(alpha: 0.55),
            ),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      'pending'   => ('รอชำระ', AppTheme.warningColor),
      'cancelled' => ('ยกเลิก', AppTheme.errorColor),
      'refunded'  => ('คืนเงินแล้ว', AppTheme.errorColor),
      'completed' => ('จบทริป', AppTheme.textSecondary),
      _           => (status.isEmpty ? 'ไม่ระบุ' : status, AppTheme.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.anuphan(
            fontSize: 11, fontWeight: FontWeight.w700, color: color,
            letterSpacing: -0.1),
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline_rounded,
                  color: AppTheme.primaryColor, size: 19),
              const SizedBox(width: 8),
              Text(
                'หาข้อมูลไม่เจอ?',
                style: GoogleFonts.anuphan(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppTheme.textMain,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _HelpItem(
            icon: Icons.confirmation_number_outlined,
            text: 'รหัสการจอง: รับจากเจ้าหน้าที่ที่จองให้ เช่น LLK-20250409-0001',
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
            style: GoogleFonts.anuphan(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
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
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.anuphan(
                fontWeight: FontWeight.w800,
                fontSize: 13,
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
            style: GoogleFonts.anuphan(
              fontSize: 13,
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
    final limited =
        compact.length > 15 ? compact.substring(0, 15) : compact;
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
