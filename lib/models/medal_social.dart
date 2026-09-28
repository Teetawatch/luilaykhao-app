import 'package:flutter/foundation.dart';

import 'trip_medal.dart';

String _text(Object? v) => v == null ? '' : '$v'.trim();
int _int(Object? v, [int fallback = 0]) => int.tryParse(_text(v)) ?? fallback;
double _double(Object? v) => double.tryParse(_text(v)) ?? 0;
List<Map<String, dynamic>> _maps(Object? v) => [
  for (final item in v is List ? v : const [])
    if (item is Map) Map<String, dynamic>.from(item),
];

// ── ปรบมือ ─────────────────────────────────────────────────────────────────

/// หนึ่งคนบนกระดาน "ใครพิชิตรอบนี้" (GET /me/medals/{id}/round)
@immutable
class MedalRoundEntry {
  final int medalId;
  final String holderName;
  final String? avatarUrl;
  final int finisherNo;
  final String finisherLabel;
  final bool isMe;
  final int kudosCount;
  final bool kudoedByMe;

  const MedalRoundEntry({
    required this.medalId,
    required this.holderName,
    required this.avatarUrl,
    required this.finisherNo,
    required this.finisherLabel,
    required this.isMe,
    required this.kudosCount,
    required this.kudoedByMe,
  });

  MedalRoundEntry withKudos({required bool kudoed, required int count}) =>
      MedalRoundEntry(
        medalId: medalId,
        holderName: holderName,
        avatarUrl: avatarUrl,
        finisherNo: finisherNo,
        finisherLabel: finisherLabel,
        isMe: isMe,
        kudosCount: count,
        kudoedByMe: kudoed,
      );

  factory MedalRoundEntry.fromJson(Map<String, dynamic> json) {
    final avatar = _text(json['avatar_url']);
    final no = _int(json['finisher_no']);

    return MedalRoundEntry(
      medalId: _int(json['medal_id']),
      holderName: _text(json['holder_name']).isEmpty
          ? 'นักเดินทาง'
          : _text(json['holder_name']),
      avatarUrl: avatar.isEmpty ? null : avatar,
      finisherNo: no,
      finisherLabel: _text(json['finisher_label']).isEmpty
          ? 'Finisher #$no'
          : _text(json['finisher_label']),
      isMe: json['is_me'] == true,
      kudosCount: _int(json['kudos_count']),
      kudoedByMe: json['kudoed_by_me'] == true,
    );
  }
}

@immutable
class MedalRound {
  final String? tripName;
  final List<MedalRoundEntry> finishers;

  const MedalRound({required this.tripName, required this.finishers});

  factory MedalRound.fromJson(Map<String, dynamic> json) => MedalRound(
    tripName: _text(json['trip_name']).isEmpty
        ? null
        : _text(json['trip_name']),
    finishers: [
      for (final m in _maps(json['finishers'])) MedalRoundEntry.fromJson(m),
    ],
  );
}

// ── ชาเลนจ์ ─────────────────────────────────────────────────────────────────

@immutable
class ChallengeItem {
  final String key;
  final String title;
  final String description;
  final String metric;
  final String icon;
  final double current;
  final double target;
  final String unit;
  final double progress;
  final bool completed;
  final DateTime? completedOn;

  const ChallengeItem({
    required this.key,
    required this.title,
    required this.description,
    required this.metric,
    required this.icon,
    required this.current,
    required this.target,
    required this.unit,
    required this.progress,
    required this.completed,
    required this.completedOn,
  });

  /// "12.4 / 100 กม." — ระยะทางมีทศนิยม ที่เหลือเป็นจำนวนเต็ม
  String get progressLabel {
    String fmt(double v) {
      if (metric == 'distance') {
        final fixed = v.toStringAsFixed(1);
        return fixed.endsWith('.0')
            ? fixed.substring(0, fixed.length - 2)
            : fixed;
      }
      return thousands(v.round());
    }

    return '${fmt(current > target && completed ? target : current)} / ${fmt(target)} $unit';
  }

  factory ChallengeItem.fromJson(Map<String, dynamic> json) {
    final progress = _double(json['progress']).clamp(0.0, 1.0);

    return ChallengeItem(
      key: _text(json['key']),
      title: _text(json['title']),
      description: _text(json['description']),
      metric: _text(json['metric']),
      icon: _text(json['icon']),
      current: _double(json['current']),
      target: _double(json['target']),
      unit: _text(json['unit']),
      progress: progress,
      completed: json['completed'] == true,
      completedOn: DateTime.tryParse(_text(json['completed_on'])),
    );
  }
}

@immutable
class ChallengePeriod {
  final String period;
  final String label;
  final int daysLeft;
  final List<ChallengeItem> challenges;

  const ChallengePeriod({
    required this.period,
    required this.label,
    required this.daysLeft,
    required this.challenges,
  });

  int get completedCount => challenges.where((c) => c.completed).length;

  factory ChallengePeriod.fromJson(Map<String, dynamic> json) =>
      ChallengePeriod(
        period: _text(json['period']),
        label: _text(json['label']),
        daysLeft: _int(json['days_left']),
        challenges: [
          for (final c in _maps(json['challenges'])) ChallengeItem.fromJson(c),
        ],
      );
}

@immutable
class ChallengeHistoryItem {
  final String title;
  final String icon;
  final String periodLabel;
  final String completedLabel;

  const ChallengeHistoryItem({
    required this.title,
    required this.icon,
    required this.periodLabel,
    required this.completedLabel,
  });

  factory ChallengeHistoryItem.fromJson(Map<String, dynamic> json) =>
      ChallengeHistoryItem(
        title: _text(json['title']),
        icon: _text(json['icon']),
        periodLabel: _text(json['period_label']),
        completedLabel: _text(json['completed_label']),
      );
}

@immutable
class ChallengeBoard {
  final ChallengePeriod month;
  final ChallengePeriod year;
  final List<ChallengeHistoryItem> history;

  const ChallengeBoard({
    required this.month,
    required this.year,
    required this.history,
  });

  factory ChallengeBoard.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> map(Object? v) =>
        v is Map ? Map<String, dynamic>.from(v) : const {};

    return ChallengeBoard(
      month: ChallengePeriod.fromJson(map(json['month'])),
      year: ChallengePeriod.fromJson(map(json['year'])),
      history: [
        for (final h in _maps(json['history']))
          ChallengeHistoryItem.fromJson(h),
      ],
    );
  }
}

// ── สรุปทั้งปี ──────────────────────────────────────────────────────────────

@immutable
class YearReviewMedal {
  final int id;
  final String finisherLabel;
  final DateTime? earnedOn;
  final MedalDesign design;

  const YearReviewMedal({
    required this.id,
    required this.finisherLabel,
    required this.earnedOn,
    required this.design,
  });

  int? get buddhistYear => earnedOn == null ? null : earnedOn!.year + 543;
}

@immutable
class YearReview {
  final int year;
  final String yearLabel;
  final List<int> availableYears;
  final String holderName;
  final int tripsCount;
  final double distanceKm;
  final int climbM;
  final double inthanonMultiple;
  final int daysOnTrail;
  final int gpsTrips;
  final int monthsActive;
  final String? topMonth;
  final int topMonthTrips;
  final List<String> places;
  final ({String name, double distanceKm})? longest;
  final ({String name, int elevationM})? highest;
  final int companionsCount;
  final int kudosReceived;
  final int challengesCompleted;
  final List<YearReviewMedal> medals;

  const YearReview({
    required this.year,
    required this.yearLabel,
    required this.availableYears,
    required this.holderName,
    required this.tripsCount,
    required this.distanceKm,
    required this.climbM,
    required this.inthanonMultiple,
    required this.daysOnTrail,
    required this.gpsTrips,
    required this.monthsActive,
    required this.topMonth,
    required this.topMonthTrips,
    required this.places,
    required this.longest,
    required this.highest,
    required this.companionsCount,
    required this.kudosReceived,
    required this.challengesCompleted,
    required this.medals,
  });

  bool get isEmpty => tripsCount == 0;

  factory YearReview.fromJson(Map<String, dynamic> json) {
    final longest = json['longest'];
    final highest = json['highest'];

    return YearReview(
      year: _int(json['year']),
      yearLabel: _text(json['year_label']),
      availableYears: [
        for (final y
            in json['available_years'] is List
                ? json['available_years'] as List
                : [])
          if (int.tryParse('$y') != null) int.parse('$y'),
      ],
      holderName: _text(json['holder_name']),
      tripsCount: _int(json['trips_count']),
      distanceKm: _double(json['distance_km']),
      climbM: _int(json['climb_m']),
      inthanonMultiple: _double(json['inthanon_multiple']),
      daysOnTrail: _int(json['days_on_trail']),
      gpsTrips: _int(json['gps_trips']),
      monthsActive: _int(json['months_active']),
      topMonth: _text(json['top_month']).isEmpty
          ? null
          : _text(json['top_month']),
      topMonthTrips: _int(json['top_month_trips']),
      places: [
        for (final p in json['places'] is List ? json['places'] as List : [])
          if (_text(p).isNotEmpty) _text(p),
      ],
      longest: longest is Map
          ? (
              name: _text(longest['name']),
              distanceKm: _double(longest['distance_km']),
            )
          : null,
      highest: highest is Map
          ? (
              name: _text(highest['name']),
              elevationM: _int(highest['elevation_m']),
            )
          : null,
      companionsCount: _int(json['companions_count']),
      kudosReceived: _int(json['kudos_received']),
      challengesCompleted: _int(json['challenges_completed']),
      medals: [
        for (final m in _maps(json['medals']))
          YearReviewMedal(
            id: _int(m['id']),
            finisherLabel: _text(m['finisher_label']),
            earnedOn: DateTime.tryParse(_text(m['earned_on'])),
            design: MedalDesign.fromJson(
              m['design'] is Map
                  ? Map<String, dynamic>.from(m['design'] as Map)
                  : const {},
            ),
          ),
      ],
    );
  }
}

/// 12345 → "12,345"
String thousands(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer(negative ? '-' : '');

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }

  return buffer.toString();
}
