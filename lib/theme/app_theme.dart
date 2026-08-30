import 'package:flutter/material.dart';

/// Latin + numeral face (assets/fonts/Inter-Variable.ttf, declared in
/// pubspec.yaml). A variable font, so any [FontWeight] (incl. w800/w900) is
/// rendered exactly. Set as the primary family on every platform.
const String _latinFont = 'Inter';

/// Thai face (assets/fonts/LINESeedSansTH_A_*.ttf, Regular 400 + Bold 700).
/// Declared as the fallback after [_latinFont] so Latin/numeric glyphs render in
/// Inter while Thai code points — which Inter lacks — fall through to LINE Seed
/// Sans TH. This is the "LINE Seed Sans TH + Inter" pairing: crisp Latin
/// numerals, clean modern Thai text. (Only Regular/Bold are shipped, so the
/// in-between weights and w800 headings render at the nearest weight, 700.)
const String _thaiFont = 'LINE Seed Sans TH';

/// Fallback chain applied alongside [_latinFont] everywhere.
const List<String> _fontFallback = [_thaiFont];

/// Both fonts are shipped in the bundle, so there is no runtime font download.
///
/// App-wide text style in [_latinFont] with the [_thaiFont] fallback. The single
/// chokepoint every call site routes through. Mirrors the `GoogleFonts.*`
/// named-parameter signature so it stays a drop-in replacement at every call
/// site.
TextStyle appFont({
  TextStyle? textStyle,
  Color? color,
  Color? backgroundColor,
  double? fontSize,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  double? letterSpacing,
  double? wordSpacing,
  TextBaseline? textBaseline,
  double? height,
  Locale? locale,
  Paint? foreground,
  Paint? background,
  List<Shadow>? shadows,
  List<FontFeature>? fontFeatures,
  TextDecoration? decoration,
  Color? decorationColor,
  TextDecorationStyle? decorationStyle,
  double? decorationThickness,
}) {
  return (textStyle ?? const TextStyle()).copyWith(
    fontFamily: _latinFont,
    fontFamilyFallback: _fontFallback,
    color: color,
    backgroundColor: backgroundColor,
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    letterSpacing: letterSpacing,
    wordSpacing: wordSpacing,
    textBaseline: textBaseline,
    height: height,
    locale: locale,
    foreground: foreground,
    background: background,
    shadows: shadows,
    fontFeatures: fontFeatures,
    decoration: decoration,
    decorationColor: decorationColor,
    decorationStyle: decorationStyle,
    decorationThickness: decorationThickness,
  );
}

/// App type scale (LINE Seed Sans TH + Inter). Lean on **weight** for hierarchy
/// more than size, and keep generous line-height so Thai diacritics (สระบน/ล่าง,
/// ไม้โท) never collide. Every style flows through [appFont] so the Inter→LINE
/// Seed Sans TH fallback is always attached.
///
/// | Role                  | Size | Weight     |
/// |-----------------------|------|------------|
/// | [displayHero]         | 30   | Bold (700) |
/// | [h1]                  | 24   | Bold (700) |
/// | [h2]                  | 19   | SemiBold   |
/// | [subtitle]            | 16   | Medium     |
/// | [body]                | 14   | Regular    |
/// | [caption]             | 12   | Medium     |
class AppText {
  AppText._();

  /// Display / Hero — large price figures, the booking-success screen. 28–32sp.
  static TextStyle displayHero({Color? color}) => appFont(
    fontSize: sizeHero,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.5,
    color: color,
  );

  /// Heading 1 — large trip titles ("ทริปดำน้ำเกาะเต่า 3 วัน 2 คืน"). 22–24sp.
  static TextStyle h1({Color? color}) => appFont(
    fontSize: sizeH1,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.3,
    color: color,
  );

  /// Heading 2 — section headers ("ไฮไลท์ของทริป", "ตารางเดินทาง"). 18–20sp.
  static TextStyle h2({Color? color}) => appFont(
    fontSize: sizeH2,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: color,
  );

  /// Subtitle / Body Large — form field labels, primary menus, sub-package
  /// names. 16sp. Pass [strong] for the SemiBold + accent-colour emphasis case.
  static TextStyle subtitle({Color? color, bool strong = false}) => appFont(
    fontSize: sizeSubtitle,
    fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
    height: 1.4,
    color: color,
  );

  /// Body — trip details and long-form copy. 14sp is the most comfortable read
  /// on mobile; height 1.5 gives Thai text room to breathe.
  static TextStyle body({Color? color, bool strong = false}) => appFont(
    fontSize: sizeBody,
    fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
    height: 1.5,
    color: color,
  );

  /// Caption / Label — dates, seats-left, short tags ("เหลือ 2 ที่สุดท้าย").
  /// 11–12sp.
  static TextStyle caption({Color? color, bool strong = false}) => appFont(
    fontSize: sizeCaption,
    fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
    height: 1.35,
    color: color,
  );

  /// Primary CTA label ("จองทริปนี้", "ชำระเงิน") — 16sp Bold for buttons
  /// sized ~48–56dp tall.
  static TextStyle button({Color? color}) => appFont(
    fontSize: sizeSubtitle,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
    color: color,
  );

  /// Micro — badge/pill text, seat numbers, tiny overlay labels. 10sp is the
  /// floor; anything smaller is unreadable in Thai once diacritics stack.
  static TextStyle micro({Color? color, bool strong = false}) => appFont(
    fontSize: sizeMicro,
    fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
    height: 1.3,
    color: color,
  );

  /// Label — the app's workhorse for dense rows, chips and metadata lines.
  /// Sits between [caption] and [body]. 13sp.
  static TextStyle label({Color? color, bool strong = false}) => appFont(
    fontSize: sizeLabel,
    fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
    height: 1.4,
    color: color,
  );

  /// Title — card headers and sheet titles that sit below a section [h2].
  /// 18sp, matching [AppTheme.appBarTitleSize].
  static TextStyle title({Color? color}) => appFont(
    fontSize: sizeTitle,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: color,
  );

  /// The canonical type ramp. Every `fontSize:` in the app resolves to one of
  /// these — no half-points, no in-between sizes. Ordered smallest to largest.
  static const double sizeMicro = 10;
  static const double sizeCaption = 12;
  static const double sizeLabel = 13;
  static const double sizeBody = 14;
  static const double sizeSubtitle = 16;
  static const double sizeTitle = 18;
  static const double sizeH2 = 20;
  static const double sizeH1 = 24;
  static const double sizeHero = 30;
}

class AppTheme {
  /// Applies the bundled [_latinFont] + [_thaiFont] fallback across the whole
  /// [TextTheme] on every platform.
  static TextTheme _textTheme(TextTheme base) {
    return base.apply(
      fontFamily: _latinFont,
      fontFamilyFallback: _fontFallback,
    );
  }

  // Premium Emerald & Slate Palette
  static const Color primaryColor = Color(0xFF059669); // Emerald 600
  static const Color accentColor = Color(0xFF10B981); // Emerald 500
  static const Color errorColor = Color(0xFFE11D48); // Rose 600
  static const Color warningColor = Color(0xFFD97706); // Amber 600
  static const Color flashSaleColor = Color(0xFFEA580C); // Orange 600 — flash sale

  static const Color textMain = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600

  static const Color bgLight = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color outlineColor = Color(0xFFE2E8F0); // Slate 200
  static const Color bgDark = Color(0xFF0B1220); // Slate 950
  static const Color surfaceDark = Color(0xFF111827); // Gray 900
  static const Color outlineDark = Color(0xFF334155); // Slate 700

  static const double radiusSmall = 16;
  static const double radiusMedium = 24;
  static const double radiusLarge = 32;

  /// Corner-radius ramp. Every `BorderRadius.circular(...)` in the app resolves
  /// to one of these six — the app previously carried 27 distinct values, which
  /// reads as hand-tuning rather than a system.
  ///
  /// | Token        | Value | Use                                          |
  /// |--------------|-------|----------------------------------------------|
  /// | [radiusXs]   | 8     | swatches, tiny thumbnails, inline tags       |
  /// | [radiusSm]   | 12    | dense list rows, compact controls            |
  /// | [radiusMd]   | 16    | the default — cards, buttons, fields, sheets |
  /// | [radiusLg]   | 24    | large surfaces, hero cards, modal sheets     |
  /// | [radiusXl]   | 32    | full-bleed panels, onboarding art            |
  /// | [radiusPill] | 999   | chips, badges, thin progress bars            |
  static const double radiusXs = 8;
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 24;
  static const double radiusXl = 32;
  static const double radiusPill = 999;

  // ---------------------------------------------------------------------------
  // Semantic palette
  //
  // One family per meaning. The app previously mixed Tailwind *slate* and
  // *gray* greys plus a bespoke set, and both *emerald* and *teal* greens —
  // two neutrals and two brand hues reading as accidental drift. Everything
  // now resolves to the emerald brand ramp + a single slate neutral ramp.
  // ---------------------------------------------------------------------------

  /// Brand emerald ramp — the only green family in the app.
  static const Color brandDark = Color(0xFF065F46); // Emerald 800
  static const Color brandDeep = Color(0xFF047857); // Emerald 700
  static const Color brandMid = Color(0xFF10B981); // Emerald 500
  static const Color brandSoft = Color(0xFF6EE7B7); // Emerald 300
  static const Color brandTint = Color(0xFFECFDF5); // Emerald 50

  /// Semantic hues. Each pairs with a theme-aware `*Tint` / `*OnTint` helper so
  /// callers never hand-roll a background/foreground pair.
  static const Color successColor = Color(0xFF16A34A); // Green 600
  static const Color infoColor = Color(0xFF2563EB); // Blue 600
  static const Color dangerColor = errorColor; // Rose 600 — alias

  /// Neutral slate ramp — the app's single grey family.
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate50 = Color(0xFFF8FAFC);

  /// LINE brand green — a third-party mark, deliberately outside the ramp.
  static const Color lineBrandColor = Color(0xFF06C755);

  /// Tinted background for a semantic hue, weighted for the active theme.
  /// Dark mode needs more weight for the tint to register against a dark
  /// surface, and the hue itself stays the foreground.
  ///
  /// The result is **opaque**: the hue is mixed into the surface colour rather
  /// than laid over it at an alpha. Same shade as the old translucent version
  /// on a plain card, but it no longer shifts when something scrolls behind it
  /// (a tinted chip on a SliverAppBar used to change colour mid-scroll).
  static Color tintOf(BuildContext context, Color hue) {
    return Color.lerp(surface(context), hue, isDark(context) ? 0.18 : 0.10)!;
  }

  /// Readable foreground for [tintOf]. In light mode the saturated hue reads
  /// fine on its own tint; in dark mode it is lifted so it clears the surface.
  static Color onTintOf(BuildContext context, Color hue) {
    return isDark(context)
        ? Color.lerp(hue, Colors.white, 0.35)!
        : Color.lerp(hue, Colors.black, 0.15)!;
  }

  static Color successTint(BuildContext context) =>
      tintOf(context, successColor);
  static Color dangerTint(BuildContext context) => tintOf(context, dangerColor);
  static Color infoTint(BuildContext context) => tintOf(context, infoColor);

  /// ขนาดหัวข้อ AppBar มาตรฐานของทั้งแอป ใช้ที่เดียวคือ [appBarTheme]
  /// หน้าจอทั่วไปไม่ต้องกำหนดขนาดเอง ปล่อยให้รับจากธีม
  /// หน้าที่จำเป็นต้องกำหนดสไตล์เอง (เช่น title เป็น Column พร้อมบรรทัดรอง)
  /// ให้ใช้ [appBarTitleStyle] เพื่อให้ได้ขนาด/น้ำหนักเดียวกัน
  static const double appBarTitleSize = 18;

  static TextStyle appBarTitleStyle(BuildContext context, {Color? color}) {
    return appFont(
      color: color ?? onSurface(context),
      fontSize: appBarTitleSize,
      fontWeight: FontWeight.w800,
    );
  }

  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color background(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  static Color surface(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
  }

  static Color subtleSurface(BuildContext context) {
    return isDark(context) ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
  }

  static Color fieldSurface(BuildContext context) {
    return isDark(context) ? const Color(0xFF1E293B) : const Color(0xFFF7F8F7);
  }

  static Color onSurface(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  static Color mutedText(BuildContext context) {
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  static Color border(BuildContext context) {
    return Theme.of(context).colorScheme.outline;
  }

  static Color selectedTint(BuildContext context) =>
      tintOf(context, primaryColor);

  static Color warningTint(BuildContext context) =>
      tintOf(context, warningColor);

  static BoxDecoration cardDecoration(
    BuildContext context, {
    double radius = radiusMedium,
    Color? color,
    Color? borderColor,
    double shadowOpacity = 0.035,
  }) {
    return BoxDecoration(
      color: color ?? surface(context),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? border(context).withValues(alpha: 0.55),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        surfaceTint: Colors.transparent,
        onSurface: textMain,
        surface: surfaceLight,
        outline: outlineColor,
      ),
      scaffoldBackgroundColor: bgLight,
      textTheme: _textTheme(
        ThemeData.light().textTheme,
      ).apply(bodyColor: textMain, displayColor: textMain),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: textMain,
        centerTitle: true,
        // มาตรฐานหัวข้อ AppBar ของทั้งแอป: 18 / w800 — หน้าไหนไม่ต้องกำหนดเอง
        titleTextStyle: appFont(
          color: textMain,
          fontSize: appBarTitleSize,
          fontWeight: FontWeight.w800,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceLight,
        elevation: 0,
        indicatorColor: primaryColor.withValues(alpha: 0.1),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return appFont(
            fontSize: AppText.sizeCaption,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected ? primaryColor : textSecondary,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: surfaceLight,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: const BorderSide(color: outlineColor, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F5F9), // Slate 100
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        hintStyle: appFont(color: textSecondary.withValues(alpha: 0.5)),
      ),
      // One shape for every toast in the app. Set here rather than at the call
      // sites: the app raises snackbars from 131 places, only 19 of which had
      // opted into floating, so the rest were rendering as square edge-to-edge
      // bars. Theming it centrally fixes all of them without touching a call.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textMain,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        contentTextStyle: appFont(
          color: Colors.white,
          fontSize: AppText.sizeBody,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        actionTextColor: brandSoft,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          textStyle: appFont(
            fontWeight: FontWeight.w800,
            fontSize: AppText.sizeSubtitle,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    const darkTextMain = Color(0xFFF8FAFC);
    const darkTextSecondary = Color(0xFFCBD5E1);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentColor,
        brightness: Brightness.dark,
        surfaceTint: Colors.transparent,
        primary: accentColor,
        secondary: primaryColor,
        surface: surfaceDark,
        onSurface: darkTextMain,
        outline: outlineDark,
        error: errorColor,
      ),
      scaffoldBackgroundColor: bgDark,
      textTheme: _textTheme(
        ThemeData.dark().textTheme,
      ).apply(bodyColor: darkTextMain, displayColor: darkTextMain),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: darkTextMain,
        centerTitle: true,
        // มาตรฐานหัวข้อ AppBar ของทั้งแอป: 18 / w800 — หน้าไหนไม่ต้องกำหนดเอง
        titleTextStyle: appFont(
          color: darkTextMain,
          fontSize: appBarTitleSize,
          fontWeight: FontWeight.w800,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceDark,
        elevation: 0,
        indicatorColor: accentColor.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return appFont(
            fontSize: AppText.sizeCaption,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected ? accentColor : darkTextSecondary,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: const BorderSide(color: outlineDark, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: accentColor, width: 2),
        ),
        hintStyle: appFont(color: darkTextSecondary.withValues(alpha: 0.62)),
      ),
      // Mirrors the light theme, but lifted off the dark scaffold: a slate
      // surface with a hairline border reads as a toast where near-black
      // would disappear into the background.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: outlineDark),
        ),
        contentTextStyle: appFont(
          color: darkTextMain,
          fontSize: AppText.sizeBody,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        actionTextColor: brandSoft,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: const Color(0xFF052E24),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          textStyle: appFont(
            fontWeight: FontWeight.w800,
            fontSize: AppText.sizeSubtitle,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
