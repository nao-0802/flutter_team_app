import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../main.dart';

class MakeGroupAlarmPage extends StatefulWidget {
  final String groupId;
  final String groupName;

  const MakeGroupAlarmPage({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<MakeGroupAlarmPage> createState() => _MakeGroupAlarmPageState();
}

class _MakeGroupAlarmPageState extends State<MakeGroupAlarmPage> {
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
      appBar: AppBar(title: Text("${widget.groupName} - アラーム作成")),
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
      'groupId': widget.groupId,
      'time': "${selectedTime!.hour}:${selectedTime!.minute}",
      'days': selectedDays,
      'enabled': true,
      'sound': sound,
      'createdAt': Timestamp.now(),
    };

    final col = alarmType == 'normal' ? 'group_normal_alarm' : 'group_emergency_alarm';

    // アラームを保存してIDを取得
    final docRef = await FirebaseFirestore.instance.collection(col).add(data);
    final alarmId = docRef.id;

    // 実際のアラーム時刻に通知を設定
    final now = DateTime.now();
    var alarmDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      selectedTime!.hour,
      selectedTime!.minute,
    );

    // 過去の時刻の場合は翌日に設定
    if (alarmDateTime.isBefore(now)) {
      alarmDateTime = alarmDateTime.add(const Duration(days: 1));
    }

    final tzDateTime = tz.TZDateTime.from(alarmDateTime, tz.local);
    
    print('グループアラーム設定: ${tzDateTime.toString()}');
    
    await flutterLocalNotificationsPlugin.zonedSchedule(
      alarmId.hashCode,
      "グループアラーム",
      "${widget.groupName}のアラームの時間です！",
      tzDateTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'alarm_channel',
          'アラーム通知',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
      ),
      payload: '${sound!}|${widget.groupId}|$alarmId',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    // テスト用: 5秒後にもテスト通知
    await flutterLocalNotificationsPlugin.zonedSchedule(
      999998,
      "グループアラームテスト",
      "5秒後のテスト通知です",
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
      payload: '${sound!}|${widget.groupId}|$alarmId',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("グループアラームが保存されました")),
    );

    Navigator.pop(context);
  }
}