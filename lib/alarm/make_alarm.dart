import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ← 追加！

class MakeAlarmPage extends StatefulWidget {
  const MakeAlarmPage({Key? key}) : super(key: key);

  @override
  State<MakeAlarmPage> createState() => _MakeAlarmPageState();
}

class _MakeAlarmPageState extends State<MakeAlarmPage> {
  String alarmType = 'normal'; // normal / emergency
  TimeOfDay? selectedTime;
  List<String> selectedDays = [];
  String? selectedSound;

  final List<String> daysOfWeek = ['月', '火', '水', '木', '金', '土', '日'];
  final List<String> soundOptions = ['サウンドA', 'サウンドB', 'サウンドC'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('アラーム作成'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // 戻るボタンでalarm_list.dartに戻る
          },
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
              onPressed: _saveAlarm,
              icon: const Icon(Icons.save),
              label: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  /// 24時間表記で時刻選択ダイアログを表示
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
    if (picked != null) {
      setState(() => selectedTime = picked);
    }
  }

  /// Firestoreにアラームを保存（ユーザーID付き）
  Future<void> _saveAlarm() async {
    if (selectedTime == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('時刻を設定してください')));
      return;
    }

    // 🔹 現在ログインしているユーザーを取得
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ユーザー情報が見つかりません')),
      );
      return;
    }

    final alarmData = {
      'userId': user.uid, // ✅ ここでユーザーIDを紐づけ！
      'time':
          '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}',
      'days': selectedDays,
      'sound': selectedSound ?? '未選択',
      'enabled': true,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final collection =
        alarmType == 'normal' ? 'normal_alarm' : 'emergency_alarm';

    await FirebaseFirestore.instance.collection(collection).add(alarmData);

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('アラームを保存しました（$collection）')));
    Navigator.pop(context);
  }
}
