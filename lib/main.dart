import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'providers/app_provider.dart';
import 'providers/tracking_provider.dart';
import 'screens/customer_app_screen.dart';
import 'services/push_notification_service.dart';
import 'theme/app_theme.dart';
import 'widgets/active_seat_lock_overlay.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('th_TH');
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

class LuilaykhaoApp extends StatelessWidget {
  const LuilaykhaoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()..boot()),
        ChangeNotifierProvider(create: (_) => TrackingProvider()),
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

          return MaterialApp(
            navigatorKey: appNavigatorKey,
            title: 'ลุยเลเขา',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: app.themeMode,
            builder: (context, child) {
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: overlayStyle,
                child: ActiveSeatLockOverlay(
                  navigatorKey: appNavigatorKey,
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
            home: const CustomerAppScreen(),
          );
        },
      ),
    );
  }
}
