import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'travel_widgets.dart' show textOf;

/// Departure-day weather forecast card. Reads the `schedule['weather']` payload
/// the backend attaches (condition, temperature range, rain chance) and shows a
/// coloured advisory banner when the forecast is rough — informational only;
/// the trip still departs as scheduled. Shared by the trip detail and booking
/// detail screens. Styled in the spirit of Apple Weather.
class WeatherCard extends StatelessWidget {
  final Map<String, dynamic> weather;

  /// Header label above the condition. Defaults to the booking-context copy;
  /// the trip detail passes a "selected date" variant.
  final String label;

  /// Compact, single-row inline variant — used where the forecast is supporting
  /// context (e.g. under the date picker on trip detail) rather than a hero
  /// element. The full gradient card is kept for the booking detail screen.
  final bool compact;

  const WeatherCard({
    super.key,
    required this.weather,
    this.label = 'พยากรณ์อากาศวันเดินทาง',
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final severity = textOf(weather['severity'], 'none');
    final desc = textOf(weather['description_th']);
    final pop = num.tryParse(weather['pop']?.toString() ?? '') ?? 0;
    final popPercent = (pop * 100).round();
    final tempMin = num.tryParse(weather['temp_min']?.toString() ?? '');
    final tempMax = num.tryParse(weather['temp_max']?.toString() ?? '');
    final code = textOf(weather['condition_code']);

    final gradient = _gradientFor(code);

    final note = switch (severity) {
      'warning' =>
        'อากาศไม่ค่อยดี เตรียมเสื้อกันฝน รองเท้ากันลื่น และกันน้ำให้อุปกรณ์',
      'advisory' => 'มีโอกาสฝน เตรียมเสื้อกันฝนติดไปเผื่อไว้',
      _ => null,
    };

    if (compact) {
      return _buildCompact(
        context,
        desc: desc,
        code: code,
        gradient: gradient,
        tempMin: tempMin,
        tempMax: tempMax,
        popPercent: popPercent,
        severity: severity,
        note: note,
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: label + condition on the left, weather glyph on the right.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.event_rounded,
                          size: 13,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          label,
                          style: appFont(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Text(
                        desc,
                        style: appFont(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(_iconFor(code), color: Colors.white, size: 30),
              ),
            ],
          ),

          // Temperature — Apple Weather daily style: the high is the headline
          // figure, with the low shown dimmed beside it (no redundant pill).
          if (tempMax != null) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${tempMax.round()}°',
                  style: appFont(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    letterSpacing: -1,
                    color: Colors.white,
                  ),
                ),
                if (tempMin != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    'ต่ำสุด ${tempMin.round()}°',
                    style: appFont(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.70),
                    ),
                  ),
                ],
              ],
            ),
          ],

          // Metric pills.
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(Icons.water_drop_rounded, 'โอกาสฝน $popPercent%'),
            ],
          ),

          // Advisory — frosted chip, only when the forecast is rough.
          if (note != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    severity == 'warning'
                        ? Icons.warning_amber_rounded
                        : Icons.cloudy_snowing,
                    size: 17,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note,
                      style: appFont(
                        fontSize: 12.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Single-row inline forecast: a small coloured glyph, the condition + temps,
  /// and a rain-chance pill — sized to sit quietly under the date picker. The
  /// rough-weather advisory still appears below, but as a tinted note rather
  /// than a frosted chip on a hero gradient.
  Widget _buildCompact(
    BuildContext context, {
    required String desc,
    required String code,
    required List<Color> gradient,
    required num? tempMin,
    required num? tempMax,
    required int popPercent,
    required String severity,
    required String? note,
  }) {
    final isDark = AppTheme.isDark(context);
    final onSurface = AppTheme.onSurface(context);
    final muted = AppTheme.mutedText(context);
    final tempText = tempMax != null
        ? '${tempMax.round()}°${tempMin != null ? ' / ${tempMin.round()}°' : ''}'
        : '';

    final noteColor = severity == 'warning'
        ? AppTheme.warningColor
        : const Color(0xFF3B82F6);

    // Tint the whole card with the sky colour so it still reads clearly as the
    // weather card among the other plain cards — just compact, not a hero.
    final sky = gradient.last;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: sky.withValues(alpha: isDark ? 0.22 : 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sky.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconFor(code), color: Colors.white, size: 22),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: appFont(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (desc.isNotEmpty)
                          Flexible(
                            child: Text(
                              desc,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: appFont(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: onSurface,
                              ),
                            ),
                          ),
                        if (tempText.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            '· $tempText',
                            style: appFont(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.water_drop_rounded,
                      size: 13,
                      color: Color(0xFF3B82F6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$popPercent%',
                      style: appFont(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: noteColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    severity == 'warning'
                        ? Icons.warning_amber_rounded
                        : Icons.umbrella_rounded,
                    size: 15,
                    color: noteColor,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      note,
                      style: appFont(
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: onSurface.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: appFont(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Sky-condition gradient in the spirit of Apple Weather — the colour conveys
  /// the mood (clear/cloud/rain/storm) rather than a flat severity tint.
  List<Color> _gradientFor(String conditionCode) {
    final group = conditionCode.isNotEmpty ? conditionCode[0] : '';
    return switch (group) {
      '2' => const [Color(0xFF3E4C66), Color(0xFF232C3F)], // thunderstorm
      '3' => const [Color(0xFF5B7C9D), Color(0xFF3C566F)], // drizzle
      '5' => const [Color(0xFF4E6E8E), Color(0xFF2F4858)], // rain
      '6' => const [Color(0xFF7FA8C9), Color(0xFF587FA0)], // snow
      '7' => const [Color(0xFF8A93A0), Color(0xFF5E6672)], // fog / haze
      '8' => conditionCode == '800'
          ? const [Color(0xFF4A95D6), Color(0xFF2C6FB5)] // clear sky
          : const [Color(0xFF6E8AA8), Color(0xFF4C6582)], // clouds
      _ => const [Color(0xFF4A95D6), Color(0xFF2C6FB5)],
    };
  }

  IconData _iconFor(String conditionCode) {
    final group = conditionCode.isNotEmpty ? conditionCode[0] : '';
    return switch (group) {
      '2' => Icons.thunderstorm_rounded,
      '3' => Icons.grain_rounded,
      '5' => Icons.cloudy_snowing,
      '6' => Icons.ac_unit_rounded,
      '7' => Icons.foggy,
      '8' => conditionCode == '800'
          ? Icons.wb_sunny_rounded
          : Icons.cloud_rounded,
      _ => Icons.cloud_outlined,
    };
  }
}
