import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Compact orange "⚡ FLASH SALE · จบใน HH:MM:SS" pill. Ticks every second while
/// [endsAt] is in the future; pass null for an open-ended sale (no countdown).
/// Shared across the trip-detail booking bar and any other flash-sale surface.
class FlashCountdownPill extends StatefulWidget {
  final DateTime? endsAt;

  const FlashCountdownPill({super.key, this.endsAt});

  @override
  State<FlashCountdownPill> createState() => _FlashCountdownPillState();
}

class _FlashCountdownPillState extends State<FlashCountdownPill> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.endsAt != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    if (d.inDays > 0) {
      return '${d.inDays} วัน ${two(d.inHours % 24)}:${two(d.inMinutes % 60)}';
    }
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    String label = 'FLASH SALE';
    if (widget.endsAt != null) {
      final remaining = widget.endsAt!.difference(DateTime.now());
      label = remaining.isNegative
          ? 'FLASH SALE · หมดเวลา'
          : 'FLASH SALE · จบใน ${_format(remaining)}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.flashSaleColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: appFont(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
