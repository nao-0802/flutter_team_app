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
  late TimeOfDay time;
  late List<String> days;
  late bool enabled;

  @override
  void initState() {
    super.initState();
    final t = widget.alarmData['time'].split(":");
    time = TimeOfDay(hour: int.parse(t[0]), minute: int.parse(t[1]));
    days = List<String>.from(widget.alarmData['days'] ?? []);
    enabled = widget.alarmData['enabled'] ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("アラーム編集")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              title: Text("${time.hour}:${time.minute}"),
              trailing: const Icon(Icons.access_time),
              onTap: _pickTime,
            ),
            const SizedBox(height: 30),
            SwitchListTile(
              title: const Text("有効 / 無効"),
              value: enabled,
              onChanged: (v) => setState(() => enabled = v),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _save,
              child: const Text("更新する"),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: _delete,
              child: const Text("削除する"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: time);
    if (picked != null) setState(() => time = picked);
  }

  Future<void> _save() async {
    final newTime = "${time.hour}:${time.minute}";

    await FirebaseFirestore.instance
        .collection(widget.collectionName)
        .doc(widget.alarmId)
        .update({
      'time': newTime,
      'days': days,
      'enabled': enabled,
    });

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

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AlarmListPage()),
      (_) => false,
    );
  }
}
