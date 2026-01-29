import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_team_app/main.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:alarm/alarm.dart';
import 'alarm_list.dart';

class MakeAlarmPage extends StatefulWidget {
  const MakeAlarmPage({super.key});

  @override
  State<MakeAlarmPage> createState() => _MakeAlarmPageState();
}

class _MakeAlarmPageState extends State<MakeAlarmPage> {
  TimeOfDay? selectedTime;
  List<String> selectedDays = [];
  String alarmType = "normal";
  String? sound;

  final sounds = [
    {'name': 'やさしい朝', 'file': 'gentle_morning.mp3'},
    {'name': 'さわやかアラーム', 'file': 'fresh_day.mp3'},
    {'name': 'しっかり起床', 'file': 'wake_up_strong.mp3'}
  ];

  final days = ['月', '火', '水', '木', '金', '土', '日'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("アラーム作成")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("アラーム種別"),
          Row(
            children: [
              Radio(
                value: 'normal',
                groupValue: alarmType,
                onChanged: (v) => setState(() => alarmType = v!),
              ),
              const Text("通常"),
              Radio(
                value: 'emergency',
                groupValue: alarmType,
                onChanged: (v) => setState(() => alarmType = v!),
              ),
              const Text("緊急"),
            ],
          ),
          const Divider(),

          // 時間
          ListTile(
            title: Text(
              selectedTime == null
                  ? "未設定"
                  : "${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}",
              style: const TextStyle(fontSize: 24),
            ),
            trailing: const Icon(Icons.access_time),
            onTap: _pickTime,
          ),

          const Divider(),

          const Text("曜日（任意）"),
          Wrap(
            spacing: 8,
            children: days.map((d) {
              final enable = selectedDays.contains(d);
              return FilterChip(
                label: Text(d),
                selected: enable,
                onSelected: (s) {
                  setState(() {
                    s ? selectedDays.add(d) : selectedDays.remove(d);
                  });
                },
              );
            }).toList(),
          ),

          const Divider(),
          const Text("アラーム音"),
          DropdownButton<String>(
            value: sound,
            isExpanded: true,
            hint: const Text("選択してください"),
            items: sounds.map((s) {
              return DropdownMenuItem(
                value: s['file'],
                child: Text(s['name']!),
              );
            }).toList(),
            onChanged: (v) => setState(() => sound = v),
          ),

          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.notifications),
            label: const Text("テスト通知"),
            onPressed: _testNotification,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text("保存"),
            onPressed: _saveAlarm,
          )
        ],
      ),
    );
  }

  Future<void> _testNotification() async {
    print('テスト通知を送信します...');
    final now = DateTime.now();
    DateTime datetime = DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute
    );

    await NotificationService.plugin.zonedSchedule(
      999,
      'テストアラーム',
      datetime.toString(),
      tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel', 
          'test_channelName',
          importance: Importance.max,
          priority: Priority.high
        )
      ),
      payload: '9999',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('テスト通知を送信しました。通知をタップしてアラーム音をテスト！')),
    );
  }

  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: now,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => selectedTime = picked);
  }

  Future<void> _saveAlarm() async {
    // バリデーションチェック
    if (selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("時刻を選択してください")),
      );
      return;
    }
    if (sound == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("アラーム音を選択してください")),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final alarmId = DateTime.now().millisecondsSinceEpoch % 2147483647;

    final data = {
      'userId': uid,
      'time': "${selectedTime!.hour}:${selectedTime!.minute}",
      'days': selectedDays,
      'enabled': true,
      'sound': sound,
      'alarmId' : alarmId
    };

    final col = alarmType == 'normal' ? 'normal_alarm' : 'emergency_alarm';

    await FirebaseFirestore.instance.collection(col).add(data);

    final nextDateTime = calclulateNextAlarmDateTime(selectedTime!, selectedDays);
    await Alarm.set(
            alarmSettings: AlarmSettings(
                id: alarmId,
                dateTime: nextDateTime,
                assetAudioPath: 'assets/sounds/$sound',
                loopAudio: alarmType == 'emergency',
                vibrate: true,
                notificationTitle: 'アラーム',
                notificationBody: 'アラームの時間です'   
            )
        );

    if (!mounted) return;

    // 保存成功のSnackBar表示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("アラームが保存されました")),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AlarmListPage()),
    );
  }
}

int dayToWeekday(String day) {
  switch (day) {
    case '月': return DateTime.monday;
    case '火': return DateTime.tuesday;
    case '水': return DateTime.wednesday;
    case '木': return DateTime.thursday;
    case '金': return DateTime.friday;
    case '土': return DateTime.saturday;
    case '日': return DateTime.sunday;
    default: return DateTime.monday;
  }
}

tz.TZDateTime nextWeekdayTime(
  int weekday,
  TimeOfDay time,
) {
  final now = tz.TZDateTime.now(tz.local);

  var scheduled = tz.TZDateTime(
    tz.local,
    now.year,
    now.month,
    now.day,
    time.hour,
    time.minute,
  );

  while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
    scheduled = scheduled.add(const Duration(days: 1));
  }

  return scheduled;
}

DateTime calclulateNextAlarmDateTime(
    TimeOfDay time,
    List<String> days,
) {
    final now = DateTime.now();

    if (days.isEmpty) {
        final today = DateTime(
            now.year,
            now.month,
            now.day,
            time.hour,
            time.minute
        );
        return today.isAfter(now)
            ? today
            : today.add(const Duration(days: 1));
    }

    final weekdayMap = {
        '月': DateTime.monday,
        '火': DateTime.tuesday,
        '水': DateTime.wednesday,
        '木': DateTime.thursday,
        '金': DateTime.friday,
        '土': DateTime.saturday,
        '日': DateTime.sunday,
    };

    final targets = days
        .where((d) => weekdayMap.containsKey(d))
        .map((d) => weekdayMap[d]!)
        .toList()
        ..sort();
    
    for (int i = 0; i < 7; i++) {
        final candidate = DateTime(
            now.year,
            now.month,
            now.day+i,
            time.hour,
            time.minute
        );

        if (targets.contains(candidate.weekday) && candidate.isAfter(now)) {
            return candidate;
        }
    }

    return now.add(const Duration(days: 1));
}
