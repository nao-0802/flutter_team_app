import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../main.dart';

class PrankPage extends StatefulWidget {
  final Map<String, dynamic> targetMember;
  final String groupId;

  const PrankPage({
    super.key,
    required this.targetMember,
    required this.groupId,
  });

  @override
  State<PrankPage> createState() => _PrankPageState();
}

class _PrankPageState extends State<PrankPage> {
  final _nameController = TextEditingController();
  String? selectedSound;

  final sounds = [
    {'name': 'やさしい朝', 'file': 'gentle_morning.mp3'},
    {'name': 'さわやかアラーム', 'file': 'fresh_day.mp3'},
    {'name': 'しっかり起床', 'file': 'wake_up_strong.mp3'}
  ];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.targetMember['name'] ?? '';
  }

  Future<void> _changeName() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('名前を入力してください')),
      );
      return;
    }

    try {
      // 一時的な名前変更をFirestoreに保存
      final today = DateTime.now().toIso8601String().split('T')[0];
      await FirebaseFirestore.instance
          .collection('prank_records')
          .doc('${today}_${widget.groupId}_${widget.targetMember['uid']}')
          .set({
        'targetUid': widget.targetMember['uid'],
        'groupId': widget.groupId,
        'date': today,
        'tempName': _nameController.text.trim(),
        'prankedBy': FirebaseAuth.instance.currentUser?.uid,
        'prankedAt': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('名前を変更しました（今日限定）')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('名前変更に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _sendInstantAlarm() async {
    if (selectedSound == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('アラーム音を選択してください')),
      );
      return;
    }

    try {
      // 即時アラーム通知を送信
      await flutterLocalNotificationsPlugin.zonedSchedule(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'イタズラアラーム！',
        '${widget.targetMember['name']}さんへのイタズラアラームです',
        tz.TZDateTime.now(tz.local).add(const Duration(seconds: 2)),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'alarm_channel',
            'アラーム通知',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          ),
        ),
        payload: selectedSound!,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('イタズラアラームを送信しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('アラーム送信に失敗しました: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.targetMember['name']}へのイタズラ'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // ターゲットメンバー表示
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: widget.targetMember['color'] != null
                    ? Color(widget.targetMember['color'])
                    : Colors.blue,
                child: Icon(
                  widget.targetMember['icon'] != null
                      ? IconData(widget.targetMember['icon'], fontFamily: 'MaterialIcons')
                      : Icons.person,
                  color: Colors.white,
                ),
              ),
              title: Text(widget.targetMember['name'] ?? '名前なし'),
              subtitle: const Text('まだ起きていないようです...'),
              trailing: const Icon(Icons.cancel, color: Colors.red),
            ),
          ),
          const SizedBox(height: 24),

          // 名前変更
          const Text(
            '名前を変更する（今日限定）',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '新しい名前',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _changeName,
            icon: const Icon(Icons.edit),
            label: const Text('名前を変更'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 32),

          // 即時アラーム
          const Text(
            '即時アラームを送信',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: selectedSound,
            isExpanded: true,
            hint: const Text('アラーム音を選択'),
            items: sounds.map((s) {
              return DropdownMenuItem(
                value: s['file'],
                child: Text(s['name']!),
              );
            }).toList(),
            onChanged: (v) => setState(() => selectedSound = v),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _sendInstantAlarm,
            icon: const Icon(Icons.alarm),
            label: const Text('即時アラーム送信'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          ],
        ),
      ),
    );
  }
}