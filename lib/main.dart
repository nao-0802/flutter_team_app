import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_team_app/group_alarm/make_group_alarm.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:alarm/alarm.dart';
import 'dart:async';
import 'firebase_options.dart';
import 'login/login.dart';
import 'alarm/alarm_ring.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static FlutterLocalNotificationsPlugin get plugin => _plugin;
}

StreamSubscription? _instantAlarmSub;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

bool _alarmListenerRegisterd = false;

Future<void> onNotificationTap(NotificationResponse response) async {
  final payload = response.payload;
  if (payload == null) return;

  final parts = payload.split('|');
  final alarmId = parts[0];

  final snap = await FirebaseFirestore.instance
    .collection('group_normal_alarm')
    .doc(alarmId)
    .get();

    if (!snap.exists) return;

    final data = snap.data() as Map<String, dynamic>;
    final nextTime = calclulateNextAlarmDateTimeFromMap(data);
    await Alarm.set(
      alarmSettings: AlarmSettings(
      id: alarmId.hashCode,
      dateTime: nextTime,
      assetAudioPath: 'assets/sounds/${data['sound']}',
      loopAudio: data['alarmType'] == 'emergency',
      vibrate: true,
      notificationTitle: '${data['groupId']}グループアラーム',
      notificationBody: '時間です',
      ),
    );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));

  await Alarm.init();

  if (!_alarmListenerRegisterd) {
    _alarmListenerRegisterd = true;
    Alarm.ringStream.stream.listen((alarmSettings) {
        navigatorKey.currentState?.push(
            MaterialPageRoute(
                builder: (_) => AlarmRingPage(
                    alarmSettings: alarmSettings,
                    alarmId: alarmSettings.id.toString(),
                    ),
                ),
            );
        }
    );
  }

  

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Firebase initialization error: $e');
    // Firebase接続に失敗してもアプリは続行
  }

  // Web以外でのみ権限をリクエスト
  if (!kIsWeb) {
    await Permission.notification.request();
    
    // Android 12以降で正確なアラーム権限をリクエスト
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
  }

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);

  // 通知タップ → AlarmRingPage を開く
  await NotificationService.plugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      if (response.payload != null) {
        navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => AlarmRingPage.fromPayload(response.payload!),
        ));
      }
    },
  );

  // 通知チャンネル
  

  await NotificationService.plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()!.requestNotificationsPermission();

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

void startInstantAlarmListener(String myUid) {
  _instantAlarmSub = FirebaseFirestore.instance
  .collection('instant_alarms')
  .where('targetUid', isEqualTo: myUid)
  .snapshots()
  .listen((snapshot) {
  for (final doc in snapshot.docs) {
  _fireInstantAlarm(doc);
  }
  });
}

Future<void> _fireInstantAlarm(
QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
final data = doc.data();
final sound = data['sound'] as String;


final alarmId = DateTime.now().millisecondsSinceEpoch;


await Alarm.set(
alarmSettings: AlarmSettings(
id: alarmId,
dateTime: DateTime.now().add(const Duration(seconds: 1)),
assetAudioPath: 'assets/sounds/$sound',
loopAudio: true,
vibrate: true,
notificationTitle: '🚨 イタズラアラーム',
notificationBody: '起きてください！',
),
);


// 使い捨てなので削除
await doc.reference.delete();
}

DateTime calclulateNextAlarmDateTimeFromMap(
    Map<String, dynamic> data,
) {
  // "9:05" → TimeOfDay(9, 5)
  final timeParts = (data['time'] as String).split(':');
  final time = TimeOfDay(
    hour: int.parse(timeParts[0]),
    minute: int.parse(timeParts[1]),
  );

  final days = List<String>.from(data['days'] ?? []);

  return calclulateNextAlarmDateTime(time, days);
}