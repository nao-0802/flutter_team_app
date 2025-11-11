import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../alarm/alarm_list.dart'; // 一覧に戻るため
import '../../main.dart';

class AlarmEditPage extends StatefulWidget {
  final String alarmId;
  final String collectionName;
  final Map<String, dynamic> alarmData;

  const AlarmEditPage({
    super.key,
    required this.alarmId,
    required this.collectionName,
    required this.alarmData,
  });

  @override
  State<AlarmEditPage> createState() => _AlarmEditPageState();
}

class _AlarmEditPageState extends State<AlarmEditPage> {
  late String alarmType;
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
  void initState() {
    super.initState();
    alarmType = widget.collectionName == 'normal_alarm' ? 'normal' : 'emergency';

    final timeStr = widget.alarmData['time'] ?? '07:00';
    final parts = timeStr.split(':');
    selectedTime = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 7,
      minute: int.tryParse(parts[1]) ?? 0,
    );
    selectedDays = List<String>.from(widget.alarmData['days'] ?? []);
    selectedSound = widget.alarmData['sound'] ?? 'gentle_morning.mp3';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('アラーム編集'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AlarmListPage()),
          ),
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

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _updateAlarm,
                  icon: const Icon(Icons.save),
                  label: const Text('更新'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: _deleteAlarm,
                  icon: const Icon(Icons.delete),
                  label: const Text('削除'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 時刻選択
  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? now,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => selectedTime = picked);
  }

  /// アラーム更新
  Future<void> _updateAlarm() async {
    if (selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('時刻を設定してください')),
      );
      return;
    }

    final newData = {
      'time':
          '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}',
      'days': selectedDays,
      'sound': selectedSound ?? 'gentle_morning.mp3',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection(widget.collectionName)
        .doc(widget.alarmId)
        .update(newData);

    await _scheduleNotification();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('アラームを更新しました')),
    );

    await Future.delayed(const Duration(seconds: 1));

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AlarmListPage()),
      (route) => false,
    );
  }

  /// アラーム削除
  Future<void> _deleteAlarm() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: const Text('このアラームを削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除')),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseFirestore.instance
        .collection(widget.collectionName)
        .doc(widget.alarmId)
        .delete();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('アラームを削除しました')),
    );

    await Future.delayed(const Duration(seconds: 1));

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AlarmListPage()),
      (route) => false,
    );
  }

  /// 通知再設定
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
      'アラーム更新',
      '設定された時間になりました',
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
