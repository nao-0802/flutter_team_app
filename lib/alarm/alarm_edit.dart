import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:alarm/alarm.dart';
import 'alarm_list.dart';

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
  late TimeOfDay selectedTime;
  late List<String> selectedDays;
  late String alarmType;
  late String? sound;
  late bool enabled;

  final sounds = [
    {'name': 'やさしい朝', 'file': 'gentle_morning.mp3'},
    {'name': 'さわやかアラーム', 'file': 'fresh_day.mp3'},
    {'name': 'しっかり起床', 'file': 'wake_up_strong.mp3'}
  ];

  final days = ['月', '火', '水', '木', '金', '土', '日'];

  late int alarmPackageId;

  @override
  void initState() {
    super.initState();
    final t = widget.alarmData['time'].split(":");
    selectedTime = TimeOfDay(hour: int.parse(t[0]), minute: int.parse(t[1]));
    selectedDays = List<String>.from(widget.alarmData['days'] ?? []);
    alarmType = widget.collectionName == 'normal_alarm' ? 'normal' : 'emergency';
    sound = widget.alarmData['sound'];
    enabled = widget.alarmData['enabled'] ?? true;

    alarmPackageId = widget.alarmData['alarmId'];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("アラーム編集")),
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
              "${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}",
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

          const Divider(),
          SwitchListTile(
            title: const Text("有効 / 無効"),
            value: enabled,
            onChanged: (v) => setState(() => enabled = v),
          ),

          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text("更新する"),
            onPressed: _save,
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete),
            label: const Text("削除する"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: _delete,
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => selectedTime = picked);
  }

  Future<void> _save() async {
    // バリデーションチェック
    if (sound == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("アラーム音を選択してください")),
      );
      return;
    }

    final newTime = "${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}";
    final newCollection = alarmType == 'normal' ? 'normal_alarm' : 'emergency_alarm';

    await Alarm.stop(alarmPackageId);

    if (widget.collectionName != newCollection) {
        await FirebaseFirestore.instance
            .collection(widget.collectionName)
            .doc(widget.alarmId)
            .delete();

        await FirebaseFirestore.instance.collection(newCollection).add({
        ...widget.alarmData,
        'time': newTime,
        'days': selectedDays,
        'sound': sound,
        'enabled': enabled,
        });
    } else {
        await FirebaseFirestore.instance
            .collection(newCollection)
            .doc(widget.alarmId)
            .update({
        'time': newTime,
        'days': selectedDays,
        'sound': sound,
        'enabled': enabled,
        });
    }

  // 🔥 ③ 次回アラーム再登録
  if (enabled) {
    await _scheduleNextAlarm(newCollection);
  }
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("アラームが更新されました")),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AlarmListPage()),
      (_) => false,
    );

    print('Alarm updated: $newCollection, $newTime, $selectedDays, $enabled, $sound');
  }

      Future<void> _scheduleNextAlarm(String collection) async {
        final now = DateTime.now();

        DateTime nextDateTime;

        if (selectedDays.isEmpty) {
            // 単発
            nextDateTime = DateTime(
            now.year,
            now.month,
            now.day,
            selectedTime.hour,
            selectedTime.minute,
            );

            if (nextDateTime.isBefore(now)) {
            nextDateTime = nextDateTime.add(const Duration(days: 1));
            }
        } else {
            nextDateTime =
                calculateNextAlarmDateTime(selectedTime, selectedDays);
        }

        await Alarm.set(
            alarmSettings: AlarmSettings(
            id: alarmPackageId,
            dateTime: nextDateTime,
            assetAudioPath: 'assets/sounds/$sound',
            loopAudio: alarmType == 'emergency',
            vibrate: true,
            notificationTitle: 'アラーム',
            notificationBody: 'アラームの時間です',
            ),
        );

        print('編集後アラーム再セット: $nextDateTime');
        }

  Future<void> _delete() async {
    await FirebaseFirestore.instance
        .collection(widget.collectionName)
        .doc(widget.alarmId)
        .delete();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("アラームが削除されました")),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AlarmListPage()),
      (_) => false,
    );
  }
}

DateTime calculateNextAlarmDateTime(
  TimeOfDay time,
  List<String> days,
) {
  final now = DateTime.now();

  final weekdayMap = {
    '月': DateTime.monday,
    '火': DateTime.tuesday,
    '水': DateTime.wednesday,
    '木': DateTime.thursday,
    '金': DateTime.friday,
    '土': DateTime.saturday,
    '日': DateTime.sunday,
  };

  final targets =
      days.map((d) => weekdayMap[d]!).toList()..sort();

  for (int i = 0; i < 7; i++) {
    final candidate = DateTime(
      now.year,
      now.month,
      now.day + i,
      time.hour,
      time.minute,
    );

    if (targets.contains(candidate.weekday) &&
        candidate.isAfter(now)) {
      return candidate;
    }
  }

  return now.add(const Duration(days: 1));
}
