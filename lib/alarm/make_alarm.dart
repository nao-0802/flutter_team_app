import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../alarm/alarm_list.dart'; // 一覧画面に戻るため
import '../../main.dart';

class MakeAlarmPage extends StatefulWidget {
  const MakeAlarmPage({super.key});

  @override
  State<MakeAlarmPage> createState() => _MakeAlarmPageState();
}

class _MakeAlarmPageState extends State<MakeAlarmPage> {
  String alarmType = 'normal';
  TimeOfDay? selectedTime;
  List<String> selectedDays = [];
  String? selectedSound;

  final List<Map<String, String>> soundOptions = [
    {'name': 'やさしい朝', 'file': 'gentle_morning.mp3'},
    {'name': 'さわやかアラーム', 'file': 'fresh_day.mp3'},
    {'name': 'しっかり起床', 'file': 'wake_up_strong.mp3'},
  ];

  final List<String> daysOfWeek = ['月', '火', '水', '木', '金', '土', '日'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('アラーム作成'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text('アラーム種別', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: RadioListTile(
                    title: const Text('通常アラーム'),
                    value: 'normal',
                    groupValue: alarmType,
                    onChanged: (v) => setState(() => alarmType = v!),
                  ),
                ),
                Expanded(
                  child: RadioListTile(
                    title: const Text('緊急アラーム'),
                    value: 'emergency',
                    groupValue: alarmType,
                    onChanged: (v) => setState(() => alarmType = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text('アラーム時刻', style: TextStyle(fontWeight: FontWeight.bold)),
            ListTile(
              title: Text(
                selectedTime == null
                    ? '未設定'
                    : '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 20),
              ),
              trailing: const Icon(Icons.access_time),
              onTap: _pickTime,
            ),
            const Divider(),

            const Text('リマインド曜日', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: daysOfWeek.map((day) {
                final isSelected = selectedDays.contains(day);
                return FilterChip(
                  label: Text(day),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedDays.add(day);
                      } else {
                        selectedDays.remove(day);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const Divider(),

            const Text('アラーム音', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: selectedSound,
              hint: const Text('アラーム音を選択'),
              isExpanded: true,
              items: soundOptions.map((sound) {
                return DropdownMenuItem(
                  value: sound['file'],
                  child: Text(sound['name']!),
                );
              }).toList(),
              onChanged: (value) => setState(() => selectedSound = value),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _saveAlarm,
              icon: const Icon(Icons.save),
              label: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  /// 時刻を選択
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

  /// Firestoreへ保存し、アラームをスケジュール
  Future<void> _saveAlarm() async {
    if (selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('時刻を設定してください')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final alarmData = {
      'userId': user.uid,
      'time':
          '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}',
      'days': selectedDays,
      'sound': selectedSound ?? 'gentle_morning.mp3',
      'enabled': true,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final collection =
        alarmType == 'normal' ? 'normal_alarm' : 'emergency_alarm';
    await FirebaseFirestore.instance.collection(collection).add(alarmData);

    await _scheduleNotification();

    if (!mounted) return;

    // ✅ 保存完了メッセージを表示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('アラームを保存しました！')),
    );

    // ✅ 少し待ってから一覧画面に戻る
    await Future.delayed(const Duration(seconds: 1));

    // ✅ AlarmListPage へ確実に遷移（スタックをリセット）
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AlarmListPage()),
      (route) => false,
    );
  }

  /// 通知スケジュール設定
  Future<void> _scheduleNotification() async {
    if (selectedTime == null) return;

    final now = DateTime.now();
    final scheduleTime = DateTime(
      now.year,
      now.month,
      now.day,
      selectedTime!.hour,
      selectedTime!.minute,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'アラーム',
      '設定時刻になりました',
      tz.TZDateTime.from(scheduleTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'alarm_channel',
          'アラーム通知',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          fullScreenIntent: true,
        ),
      ),
      payload: 'alarm_ring:${selectedSound ?? 'gentle_morning.mp3'}',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
