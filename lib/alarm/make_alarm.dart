import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../main.dart';
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
            icon: const Icon(Icons.save),
            label: const Text("保存"),
            onPressed: _saveAlarm,
          )
        ],
      ),
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

    final data = {
      'userId': uid,
      'time': "${selectedTime!.hour}:${selectedTime!.minute}",
      'days': selectedDays,
      'enabled': true,
      'sound': sound,
    };

    final col = alarmType == 'normal' ? 'normal_alarm' : 'emergency_alarm';

    await FirebaseFirestore.instance.collection(col).add(data);

    // 通知（音は payload で渡し、AlarmRingPage で再生）
    await flutterLocalNotificationsPlugin.zonedSchedule(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      "アラーム",
      "アラームの時間です",
      tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'alarm_channel',
          'アラーム通知',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
      ),
      payload: sound!,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
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
