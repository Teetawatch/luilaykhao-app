import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'l10n/generated/app_localizations.dart';

import 'providers/app_provider.dart';
import 'providers/notification_preferences.dart';
import 'providers/tracking_provider.dart';
import 'providers/trip_alert_provider.dart';
import 'providers/article_provider.dart';
import 'providers/wishlist_provider.dart';
import 'screens/customer_app_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/analytics_service.dart';
import 'services/push_notification_service.dart';
import 'services/rating_prompt_service.dart';
import 'theme/app_theme.dart';
import 'widgets/active_seat_lock_overlay.dart';
import 'widgets/app_error_boundary.dart';
import 'widgets/biometric_lock_gate.dart';
import 'widgets/force_update_screen.dart';
import 'widgets/offline_banner.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppErrorBoundary.install();
  // Tighter image memory budget — keeps decoded image cache under ~80 MB on
  // mid-range devices where trip thumbnails can otherwise accumulate.
  PaintingBinding.instance.imageCache
    ..maximumSize = 200
    ..maximumSizeBytes = 80 * 1024 * 1024;
  await initializeDateFormatting('th_TH');
  await AnalyticsService.instance.initialize();
  unawaited(RatingPromptService.instance.recordFirstLaunch());
  unawaited(PushNotificationService.instance.initialize());

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const LuilaykhaoApp());
}

class _OnboardingGate extends StatefulWidget {
  const _OnboardingGate();

  @override
  State<_OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<_OnboardingGate> {
  bool? _shouldShow;

  @override
  void initState() {
    super.initState();
    OnboardingScreen.shouldShow().then((value) {
      if (mounted) setState(() => _shouldShow = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_shouldShow == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    if (_shouldShow == true) {
      return OnboardingScreen(
        onComplete: () => setState(() => _shouldShow = false),
      );
    }
    return const CustomerAppScreen();
  }
}

void _handleSessionExpired() {
  final navigator = appNavigatorKey.currentState;
  if (navigator == null) return;
  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );
  final messenger = ScaffoldMessenger.maybeOf(navigator.context);
  messenger?.showSnackBar(
    const SnackBar(content: Text('เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่')),
  );
}

class LuilaykhaoApp extends StatelessWidget {
  const LuilaykhaoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          final provider = AppProvider();
          provider.setOnSessionExpired(_handleSessionExpired);
          provider.boot();
          return provider;
        }),
        ChangeNotifierProvider(create: (_) => TrackingProvider()),
        ChangeNotifierProvider(create: (_) => WishlistProvider()..load()),
        ChangeNotifierProvider(create: (_) => TripAlertProvider()),
        ChangeNotifierProvider(create: (_) => ArticleProvider()),
        ChangeNotifierProvider(
          create: (_) => NotificationPreferences()..load(),
        ),
      ],
      child: Consumer<AppProvider>(
        builder: (context, app, _) {
          final overlayStyle = app.isDarkMode
              ? SystemUiOverlayStyle.light.copyWith(
                  statusBarColor: Colors.transparent,
                  systemNavigationBarColor: AppTheme.bgDark,
                  systemNavigationBarIconBrightness: Brightness.light,
                )
              : SystemUiOverlayStyle.dark.copyWith(
                  statusBarColor: Colors.transparent,
                  systemNavigationBarColor: Colors.white,
                  systemNavigationBarIconBrightness: Brightness.dark,
                );

          final analyticsObserver = AnalyticsService.instance.observer;
          return MaterialApp(
            navigatorKey: appNavigatorKey,
            title: 'ลุยเลเขา',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: app.themeMode,
            navigatorObservers: [
              ?analyticsObserver,
            ],
            locale: app.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) {
              final body = app.versionGate.blocked
                  ? ForceUpdateScreen(result: app.versionGate)
                  : BiometricLockGate(
                      child: ActiveSeatLockOverlay(
                        navigatorKey: appNavigatorKey,
                        child: child ?? const SizedBox.shrink(),
                      ),
                    );
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: overlayStyle,
                child: OfflineBanner(child: body),
              );
            },
            home: const _OnboardingGate(),
          );
        },
      ),
    );
  }
}
