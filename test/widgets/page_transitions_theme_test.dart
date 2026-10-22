import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/theme/app_theme.dart';

/// ทรานซิชันเปลี่ยนหน้าของทั้งแอป — ตั้งที่ theme ที่เดียว
void main() {
  test('iOS เลื่อนแบบ Cupertino (ปัดขอบจอย้อนกลับได้)', () {
    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      expect(
        theme.pageTransitionsTheme.builders[TargetPlatform.iOS],
        isA<CupertinoPageTransitionsBuilder>(),
      );
    }
  });

  test('Android: predictive back บนพื้นสีเดียวกับหน้า ไม่แฟลชสีระหว่างจาง', () {
    final light = AppTheme.lightTheme.pageTransitionsTheme
        .builders[TargetPlatform.android];
    final dark = AppTheme.darkTheme.pageTransitionsTheme
        .builders[TargetPlatform.android];

    expect(light, isA<PredictiveBackPageTransitionsBuilder>());
    expect(dark, isA<PredictiveBackPageTransitionsBuilder>());
    expect(
      (light! as PredictiveBackPageTransitionsBuilder).fallbackColor,
      AppTheme.lightTheme.scaffoldBackgroundColor,
    );
    expect(
      (dark! as PredictiveBackPageTransitionsBuilder).fallbackColor,
      AppTheme.darkTheme.scaffoldBackgroundColor,
    );
  });
}
