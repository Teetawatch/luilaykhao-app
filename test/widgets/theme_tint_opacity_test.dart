import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/theme/app_theme.dart';

/// Resolves a theme colour inside a real [MaterialApp] so `Theme.of` works.
Future<Color> _resolve(
  WidgetTester tester,
  Brightness brightness,
  Color Function(BuildContext) pick,
) async {
  late Color seen;
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark
          ? AppTheme.darkTheme
          : AppTheme.lightTheme,
      home: Builder(
        builder: (context) {
          seen = pick(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return seen;
}

void main() {
  // Tinted chips sit on plain cards, never over a photo. A translucent tint
  // there buys nothing and costs correctness: the chip changes colour whenever
  // something scrolls behind it. The tint helpers therefore mix the hue *into*
  // the surface and hand back an opaque colour.
  group('tint helpers are opaque', () {
    final helpers = <String, Color Function(BuildContext)>{
      'selectedTint': AppTheme.selectedTint,
      'warningTint': AppTheme.warningTint,
      'successTint': AppTheme.successTint,
      'dangerTint': AppTheme.dangerTint,
      'infoTint': AppTheme.infoTint,
    };

    for (final brightness in Brightness.values) {
      for (final entry in helpers.entries) {
        testWidgets('${entry.key} — ${brightness.name}', (tester) async {
          final color = await _resolve(tester, brightness, entry.value);
          expect(color.a, 1.0, reason: '${entry.key} ต้องทึบ ไม่ใช่สีโปร่ง');
        });
      }
    }

    testWidgets('tintOf keeps an arbitrary hue opaque too', (tester) async {
      final color = await _resolve(
        tester,
        Brightness.light,
        (context) => AppTheme.tintOf(context, const Color(0xFF7C3AED)),
      );
      expect(color.a, 1.0);
    });
  });

  testWidgets('a tint reads as a pale wash, not the raw hue', (tester) async {
    final tint = await _resolve(tester, Brightness.light, AppTheme.selectedTint);
    final surface = await _resolve(tester, Brightness.light, AppTheme.surface);

    // 10% of the hue mixed into white: close to the surface, clearly not the
    // hue itself — the guard against someone "fixing" this to a solid emerald.
    expect(tint, isNot(AppTheme.primaryColor));
    expect((tint.r - surface.r).abs(), lessThan(0.2));
    expect((tint.g - surface.g).abs(), lessThan(0.2));
    expect((tint.b - surface.b).abs(), lessThan(0.2));
  });
}
