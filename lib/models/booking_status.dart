import 'package:flutter/material.dart';

/// Canonical booking statuses returned by the backend.
///
/// Status strings live in many code paths (filter chips, card colors, lookup
/// screens). Centralising them as an enum + extension prevents typos and
/// keeps display logic in one place.
enum BookingStatus {
  pending,
  confirmed,
  cancelled,
  refunded,
  completed,
  failed,
  unknown;

  static BookingStatus parse(dynamic value) {
    final raw = value?.toString().toLowerCase().trim() ?? '';
    return switch (raw) {
      'pending' => pending,
      'confirmed' => confirmed,
      'cancelled' || 'canceled' => cancelled,
      'refunded' => refunded,
      'completed' => completed,
      'failed' => failed,
      _ => unknown,
    };
  }

  /// Server-side identifier — feed this back to API calls if needed.
  String get key => switch (this) {
    pending => 'pending',
    confirmed => 'confirmed',
    cancelled => 'cancelled',
    refunded => 'refunded',
    completed => 'completed',
    failed => 'failed',
    unknown => '',
  };

  /// Thai display label.
  String get label => switch (this) {
    pending => 'รอชำระเงิน',
    confirmed => 'ยืนยันแล้ว',
    cancelled => 'ยกเลิก',
    refunded => 'คืนเงินแล้ว',
    completed => 'เสร็จสิ้น',
    failed => 'ชำระไม่สำเร็จ',
    unknown => '-',
  };

  /// Display tint used by chips/badges.
  Color get color => switch (this) {
    pending => const Color(0xFFD97706),
    confirmed => const Color(0xFF059669),
    cancelled => const Color(0xFF687272),
    refunded => const Color(0xFF315A9D),
    completed => const Color(0xFF315A9D),
    failed => const Color(0xFFE11D48),
    unknown => const Color(0xFF9CA3AF),
  };

  bool get isTerminal =>
      this == cancelled ||
      this == refunded ||
      this == completed ||
      this == failed;

  bool get isPaid => this == confirmed || this == completed;
}

extension BookingStatusJson on Map<String, dynamic> {
  BookingStatus get bookingStatus => BookingStatus.parse(this['status']);
}
