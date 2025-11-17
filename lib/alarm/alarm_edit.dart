import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  @override
  void initState() {
    super.initState();
    final t = widget.alarmData['time'].split(":");
    selectedTime = TimeOfDay(hour: int.parse(t[0]), minute: int.parse(t[1]));
    selectedDays = List<String>.from(widget.alarmData['days'] ?? []);
    alarmType = widget.collectionName == 'normal_alarm' ? 'normal' : 'emergency';
    sound = widget.alarmData['sound'];
    enabled = widget.alarmData['enabled'] ?? true;
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

    final newTime = "${selectedTime.hour}:${selectedTime.minute}";
    final newCollection = alarmType == 'normal' ? 'normal_alarm' : 'emergency_alarm';

    // 元のアラームを削除
    await FirebaseFirestore.instance
        .collection(widget.collectionName)
        .doc(widget.alarmId)
        .delete();

    // 新しいコレクションに追加
    await FirebaseFirestore.instance.collection(newCollection).add({
      'userId': widget.alarmData['userId'],
      'time': newTime,
      'days': selectedDays,
      'enabled': enabled,
      'sound': sound,
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("アラームが更新されました")),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AlarmListPage()),
      (_) => false,
    );
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
