import 'dart:async';
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:joguman_pomodoro/providers/angle_provider.dart';
import 'package:joguman_pomodoro/providers/data_provider.dart';
import 'package:joguman_pomodoro/providers/theme_provider.dart';
import 'package:joguman_pomodoro/screens/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:timezone/data/latest.dart' as tz;

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  print('background : ');
}

// local notification plugin 초기화
Future<void> _initLocalNotification() async {
  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
  AndroidInitializationSettings android = const AndroidInitializationSettings("@mipmap/ic_launcher");
  DarwinInitializationSettings ios = const DarwinInitializationSettings(
    requestSoundPermission: true,
    requestBadgePermission: false,
    requestAlertPermission: true,
  );
  InitializationSettings settings = InitializationSettings(android: android, iOS: ios);
  await plugin.initialize(
    settings,
    onDidReceiveNotificationResponse: (details) {
      print('payload : ${details.payload}');
    },
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );
}

Future<void> main() async {
  await Hive.initFlutter();
  // await JustAudioBackground.init(
  //   androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
  //   androidNotificationChannelName: 'Audio playback',
  //   androidNotificationOngoing: true,
  // );
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // await Alarm.init();
  await _initLocalNotification();
  tz.initializeTimeZones();
  await EasyLocalization.ensureInitialized();
  await Hive.openBox('themeBox');

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ko'), Locale('ja'), Locale('zh-Hans'), Locale('zh-Hant')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AngleProvider()),
        ChangeNotifierProvider(create: (context) => DataProvider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: AppLifecycleHandler(
        child: ResponsiveSizer(builder: (p0, p1, p2) {
          return MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            initialRoute: '/',
            scrollBehavior: AppScrollBehavior(),
            title: '조구만 뽀모도로',
            home: const HomeScreen(),
          );
        }),
      ),
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class AppLifecycleHandler extends StatefulWidget {
  final Widget child;

  const AppLifecycleHandler({required this.child, super.key});

  @override
  _AppLifecycleHandlerState createState() => _AppLifecycleHandlerState();
}

class _AppLifecycleHandlerState extends State<AppLifecycleHandler> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    print(state);
    context.read<DataProvider>().setLifecycleState(state);

    if (state == AppLifecycleState.resumed) {}
  }

  stopAllNotification() async {
    // final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
