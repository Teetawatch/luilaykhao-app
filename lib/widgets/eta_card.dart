import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/tracking_model.dart';
import '../theme/app_theme.dart';
import '../widgets/travel_widgets.dart';

class ETACard extends StatelessWidget {
  final ETAResult? eta;
  final String tripTitle;
  final String pickupLabel;
  final String? driverPhone;
  final TrackingPhase phase;
  final VoidCallback? onCallDriver;

  const ETACard({
    super.key,
    required this.eta,
    required this.tripTitle,
    required this.pickupLabel,
    this.driverPhone,
    required this.phase,
    this.onCallDriver,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppTheme.isDark(context) ? 0.22 : 0.08,
            ),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              _StatusHeader(
                tripTitle: tripTitle,
                pickupLabel: pickupLabel,
                phase: phase,
              ),
              const SizedBox(height: 24),
              _TrackingStats(eta: eta, phase: phase),
              const SizedBox(height: 24),
              if (driverPhone != null && driverPhone!.isNotEmpty)
                PrimaryCTAButton(
                  label: 'โทรหาคนขับ ($driverPhone)',
                  icon: Icons.phone_rounded,
                  onPressed: onCallDriver,
                  color: AppTheme.accentColor,
                  height: 52,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  final String tripTitle;
  final String pickupLabel;
  final TrackingPhase phase;

  const _StatusHeader({
    required this.tripTitle,
    required this.pickupLabel,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.airport_shuttle_rounded,
            color: AppTheme.primaryColor,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tripTitle,
                style: GoogleFonts.anuphan(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppTheme.onSurface(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 14,
                    color: AppTheme.mutedText(context).withValues(alpha: 0.65),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      pickupLabel,
                      style: GoogleFonts.anuphan(
                        fontSize: 13,
                        color: AppTheme.mutedText(context),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _PhaseBadge(phase: phase),
      ],
    );
  }
}

class _PhaseBadge extends StatelessWidget {
  final TrackingPhase phase;

  const _PhaseBadge({required this.phase});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (phase) {
      TrackingPhase.imminent => ('ใกล้ถึงแล้ว!', AppTheme.errorColor),
      TrackingPhase.nearSoon => ('กำลังมา', Colors.orange),
      TrackingPhase.arrived => ('ถึงแล้ว!', AppTheme.accentColor),
      TrackingPhase.far => ('อยู่ห่าง', AppTheme.primaryColor),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: GoogleFonts.anuphan(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TrackingStats extends StatelessWidget {
  final ETAResult? eta;
  final TrackingPhase phase;

  const _TrackingStats({required this.eta, required this.phase});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatTile(
            label: 'เวลาถึงโดยประมาณ',
            value: eta?.formattedETA ?? '--:--',
            isHighlighted: true,
          ),
          Container(width: 1, height: 40, color: AppTheme.border(context)),
          _StatTile(
            label: 'ระยะทาง',
            value: eta?.formattedDistance ?? '-- กม.',
          ),
          Container(width: 1, height: 40, color: AppTheme.border(context)),
          _StatTile(label: 'อัปเดตทุกๆ', value: _getUpdateInterval()),
        ],
      ),
    );
  }

  String _getUpdateInterval() {
    return switch (phase) {
      TrackingPhase.far => '30 นาที',
      TrackingPhase.nearSoon => '30 วินาที',
      TrackingPhase.imminent => '4 วินาที',
      TrackingPhase.arrived => '-',
    };
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlighted;

  const _StatTile({
    required this.label,
    required this.value,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.anuphan(
            fontSize: 10,
            color: AppTheme.mutedText(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.anuphan(
            fontSize: isHighlighted ? 18 : 14,
            fontWeight: FontWeight.w800,
            color: isHighlighted
                ? AppTheme.primaryColor
                : AppTheme.onSurface(context),
          ),
        ),
      ],
    );
  }
}
