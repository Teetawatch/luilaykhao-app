import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'providers/app_provider.dart';
import 'providers/tracking_provider.dart';
import 'screens/customer_app_screen.dart';
import 'services/push_notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('th_TH');
  await PushNotificationService.instance.initialize();

  SystemChrome.setPreferredOrientations([
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
      child: MaterialApp(
        title: 'ลุยเลเขา',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const CustomerAppScreen(),
      ),
    );
  }
}
