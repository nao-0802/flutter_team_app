import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  final List<String> daysOfWeek = ['月', '火', '水', '木', '金', '土', '日'];
  final List<String> soundOptions = ['サウンドA', 'サウンドB', 'サウンドC'];

  @override
  void initState() {
    super.initState();
    final data = widget.alarmData;
    alarmType = widget.collectionName == 'normal_alarm' ? 'normal' : 'emergency';
    selectedSound = data['sound'];
    selectedDays = List<String>.from(data['days'] ?? []);

    // 🔹 Firestoreでは "HH:mm" 形式の文字列なので分割してTimeOfDayに変換
    if (data['time'] != null && data['time'].contains(':')) {
      final parts = data['time'].split(':');
      selectedTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('アラーム編集'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
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
                    onChanged: (value) => setState(() => alarmType = value!),
                  ),
                ),
                Expanded(
                  child: RadioListTile(
                    title: const Text('緊急アラーム'),
                    value: 'emergency',
                    groupValue: alarmType,
                    onChanged: (value) => setState(() => alarmType = value!),
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
                  value: sound,
                  child: Text(sound),
                );
              }).toList(),
              onChanged: (value) => setState(() => selectedSound = value),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _updateAlarm,
              icon: const Icon(Icons.save),
              label: const Text('更新'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _deleteAlarm,
              icon: const Icon(Icons.delete),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              label: const Text('削除'),
            ),
          ],
        ),
      ),
    );
  }

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
    if (picked != null) {
      setState(() => selectedTime = picked);
    }
  }

  /// 🔹 アラーム更新
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
      'sound': selectedSound ?? '未選択',
    };

    final currentCollection = widget.collectionName;
    final newCollection =
        alarmType == 'normal' ? 'normal_alarm' : 'emergency_alarm';

    // 🔹 コレクションが変わる場合（通常⇔緊急の切り替え）
    if (currentCollection != newCollection) {
      final oldDoc =
          FirebaseFirestore.instance.collection(currentCollection).doc(widget.alarmId);
      final snapshot = await oldDoc.get();
      if (snapshot.exists) {
        await FirebaseFirestore.instance.collection(newCollection).add({
          ...snapshot.data()!,
          ...newData,
        });
        await oldDoc.delete();
      }
    } else {
      await FirebaseFirestore.instance
          .collection(currentCollection)
          .doc(widget.alarmId)
          .update(newData);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('アラームを更新しました')),
    );
    Navigator.pop(context);
  }

  /// 🔹 アラーム削除
  Future<void> _deleteAlarm() async {
    await FirebaseFirestore.instance
        .collection(widget.collectionName)
        .doc(widget.alarmId)
        .delete();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('アラームを削除しました')),
    );
    Navigator.pop(context);
  }
}
