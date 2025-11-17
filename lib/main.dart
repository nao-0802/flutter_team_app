import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'firebase_options.dart';
import 'login/login.dart';
import 'alarm/alarm_ring.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Permission.notification.request();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);

  // 通知タップ → AlarmRingPage を開く
  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (details) {
      if (details.payload != null) {
        navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => AlarmRingPage(sound: details.payload!),
        ));
      }
    },
  );

  // 通知チャンネル
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'alarm_channel',
    'アラーム通知',
    description: 'アラーム用通知チャンネル',
    importance: Importance.max,
    playSound: true,
  );

  final androidImpl =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  await androidImpl?.createNotificationChannel(channel);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      home: const LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
