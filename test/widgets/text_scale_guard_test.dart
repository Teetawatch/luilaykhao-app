import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/widgets/text_scale_guard.dart';

/// Reads the scale that actually reaches the subtree below the guard.
Future<double> _scaleUnderGuard(WidgetTester tester, double systemScale) async {
  late double seen;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(systemScale)),
      child: TextScaleGuard(
        child: Builder(
          builder: (context) {
            seen = MediaQuery.textScalerOf(context).scale(10) / 10;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  return seen;
}

void main() {
  testWidgets('an ordinary font-size preference passes through untouched', (
    tester,
  ) async {
    expect(await _scaleUnderGuard(tester, 1.0), 1.0);
    expect(await _scaleUnderGuard(tester, 1.2), closeTo(1.2, 0.001));
  });

  testWidgets('an extreme font-size setting is capped, not obeyed', (
    tester,
  ) async {
    // Both platforms allow well past 2x; the dense trip/booking rows overflow
    // long before that.
    expect(
      await _scaleUnderGuard(tester, 2.5),
      TextScaleGuard.maxScaleFactor,
    );
  });

  testWidgets('shrinking is allowed down to the floor', (tester) async {
    expect(await _scaleUnderGuard(tester, 0.9), closeTo(0.9, 0.001));
    expect(
      await _scaleUnderGuard(tester, 0.5),
      TextScaleGuard.minScaleFactor,
    );
  });
}
