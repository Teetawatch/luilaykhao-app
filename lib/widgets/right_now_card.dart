import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:provider/provider.dart';

import '../models/tracking_model.dart';
import '../providers/app_provider.dart';
import '../services/tracking_service.dart';
import '../theme/app_theme.dart';

/// "ตอนนี้ต้องทำอะไร" — one line answering the only question a customer
/// standing at the roadside actually has.
///
/// Everything else on the trip-day screen is a tile you have to decide to open.
/// This decides for them: how far away the van is, where to stand, and the one
/// action worth taking right now (open the pickup point in maps, or call the
/// driver once it is close).
///
/// Hides itself when there is nothing useful to say, rather than showing an
/// empty shell.
class RightNowCard extends StatefulWidget {
  final String bookingRef;

  const RightNowCard({super.key, required this.bookingRef});

  @override
  State<RightNowCard> createState() => _RightNowCardState();
}

class _RightNowCardState extends State<RightNowCard> {
  /// The van moves; a minute is often enough to change the answer.
  static const Duration _refreshEvery = Duration(seconds: 60);

  final _tracking = TrackingService();

  BookingInfo? _booking;
  VehicleTracking? _vehicle;
  Timer? _timer;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _tracking.authToken = context.read<AppProvider>().api.token;
    _load();
    _timer = Timer.periodic(_refreshEvery, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final booking = await _tracking.fetchBookingInfo(widget.bookingRef);
    if (!mounted) return;

    VehicleTracking? vehicle;
    final vehicleId = booking?.vehicleId ?? 0;
    if (vehicleId > 0) {
      vehicle = await _tracking.fetchVehicleLocation(vehicleId);
    }
    if (!mounted) return;

    setState(() {
      _booking = booking ?? _booking;
      _vehicle = vehicle ?? _vehicle;
      _loaded = true;
    });
  }

  ETAResult? get _eta {
    final vehicle = _vehicle;
    final pickup = _booking?.pickupPoint;
    if (vehicle == null || pickup == null) return null;

    return ETAResult.compute(
      from: vehicle.driverLocation,
      to: pickup,
      speedKmh: vehicle.speed,
    );
  }

  Future<void> _openPickupInMaps() async {
    final pickup = _booking?.pickupPoint;
    if (pickup == null) return;
    HapticFeedback.selectionClick();

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1'
      '&query=${pickup.latitude},${pickup.longitude}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// คนขับอาจมาจากข้อมูลรถหรือจากการจอง แล้วแต่ว่าอันไหนมาก่อน
  String get _driverPhone =>
      (_vehicle?.driverPhone ?? _booking?.driverPhone ?? '').trim();

  Future<void> _callDriver() async {
    final phone = _driverPhone;
    if (phone.isEmpty) return;
    HapticFeedback.selectionClick();

    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    final eta = _eta;
    final pickupName = (_booking?.departurePoint ?? '').trim().isEmpty
        ? 'จุดรับของคุณ'
        : _booking!.departurePoint.trim();

    // No fix on the van yet — say what is known instead of pretending.
    if (eta == null) {
      if (_booking == null) return const SizedBox.shrink();

      return _shell(
        tone: AppTheme.mutedText(context),
        headline: 'ยังไม่มีสัญญาณรถ',
        detail: 'จุดขึ้นรถของคุณคือ $pickupName',
        actionLabel: 'เปิดแผนที่จุดรับ',
        onAction: _openPickupInMaps,
      );
    }

    final minutes = eta.eta.inMinutes;
    final km = eta.distanceKm;

    final (String headline, String detail, Color tone) = switch (eta.phase) {
      TrackingPhase.arrived => (
        'รถถึงจุดรับแล้ว',
        'ขึ้นรถได้เลยที่ $pickupName',
        AppTheme.primaryColor,
      ),
      TrackingPhase.imminent => (
        'อีกประมาณ $minutes นาที',
        'ไปรอที่ $pickupName ได้เลย',
        AppTheme.errorColor,
      ),
      TrackingPhase.nearSoon => (
        'อีกประมาณ $minutes นาที',
        'ห่าง ${km.toStringAsFixed(1)} กม. · เตรียมตัวไปที่ $pickupName',
        AppTheme.warningColor,
      ),
      TrackingPhase.far => (
        'อีกประมาณ $minutes นาที',
        'ห่าง ${km.toStringAsFixed(1)} กม. จาก $pickupName',
        AppTheme.mutedText(context),
      ),
    };

    // Once the van is close, calling the driver beats opening a map.
    final callable =
        _driverPhone.isNotEmpty &&
        (eta.phase == TrackingPhase.imminent ||
            eta.phase == TrackingPhase.arrived);

    return _shell(
      tone: tone,
      headline: headline,
      detail: detail,
      actionLabel: callable ? 'โทรหาคนขับ' : 'เปิดแผนที่จุดรับ',
      onAction: callable ? _callDriver : _openPickupInMaps,
    );
  }

  Widget _shell({
    required Color tone,
    required String headline,
    required String detail,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_bus_rounded, size: 20, color: tone),
              const SizedBox(width: 8),
              Expanded(
                // Announced by screen readers when the ETA changes, which is
                // the whole point of this card.
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    headline,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: tone,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}
