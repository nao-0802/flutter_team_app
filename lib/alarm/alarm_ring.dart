import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AlarmRingPage extends StatefulWidget {
  final String sound;
  final String? groupId;
  final String? alarmId;

  const AlarmRingPage({
    super.key,
    required this.sound,
    this.groupId,
    this.alarmId,
  });
  
  // payloadからgroupIdとalarmIdを取得するヘルパーメソッド
  static AlarmRingPage fromPayload(String payload) {
    final parts = payload.split('|');
    if (parts.length >= 3) {
      return AlarmRingPage(
        sound: parts[0],
        groupId: parts[1],
        alarmId: parts[2],
      );
    }
    return AlarmRingPage(sound: payload);
  }

  @override
  State<AlarmRingPage> createState() => _AlarmRingPageState();
}

class _AlarmRingPageState extends State<AlarmRingPage> {
  late AudioPlayer player;
  bool _alarmStopped = false;
  bool _wakeUpConfirmed = false;

  @override
  void initState() {
    super.initState();
    player = AudioPlayer();
    
    // payloadからsoundを抽出
    final soundFile = widget.sound.contains('|') 
        ? widget.sound.split('|')[0] 
        : widget.sound;
    
    player.play(AssetSource("sounds/$soundFile"));
  }

  Future<void> _stopAlarm() async {
    await player.stop();
    setState(() => _alarmStopped = true);
    
    if (widget.groupId != null && widget.alarmId != null) {
      await _recordAlarmStopped();
    }
  }

  Future<void> _confirmWakeUp() async {
    setState(() => _wakeUpConfirmed = true);
    
    if (widget.groupId != null && widget.alarmId != null) {
      await _recordWakeUpConfirmed();
    }
  }

  Future<void> _recordAlarmStopped() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // payloadからgroupIdとalarmIdを取得
    String? groupId = widget.groupId;
    String? alarmId = widget.alarmId;
    
    if (groupId == null || alarmId == null) {
      final parts = widget.sound.split('|');
      if (parts.length >= 3) {
        groupId = parts[1];
        alarmId = parts[2];
      }
    }
    
    if (groupId == null || alarmId == null) return;

    final today = DateTime.now().toIso8601String().split('T')[0];
    final recordId = '${today}_${groupId}_$alarmId';

    try {
      await FirebaseFirestore.instance
          .collection('wake_up_records')
          .doc(recordId)
          .set({
        'groupId': groupId,
        'alarmId': alarmId,
        'date': today,
        'records.${uid}.alarmStopped': true,
        'records.${uid}.stoppedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('アラーム停止記録エラー: $e');
    }
  }

  Future<void> _recordWakeUpConfirmed() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // payloadからgroupIdとalarmIdを取得
    String? groupId = widget.groupId;
    String? alarmId = widget.alarmId;
    
    if (groupId == null || alarmId == null) {
      final parts = widget.sound.split('|');
      if (parts.length >= 3) {
        groupId = parts[1];
        alarmId = parts[2];
      }
    }
    
    if (groupId == null || alarmId == null) return;

    final today = DateTime.now().toIso8601String().split('T')[0];
    final recordId = '${today}_${groupId}_$alarmId';

    try {
      await FirebaseFirestore.instance
          .collection('wake_up_records')
          .doc(recordId)
          .set({
        'records.${uid}.wakeUpConfirmed': true,
        'records.${uid}.confirmedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('起床確認記録エラー: $e');
    }
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.alarm, size: 120, color: Colors.red),
            const SizedBox(height: 20),
            const Text(
              "アラーム！",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            if (!_alarmStopped) ...[
              ElevatedButton(
                onPressed: _stopAlarm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text("止める"),
              ),
            ] else ...[
              const Text(
                "アラームを停止しました",
                style: TextStyle(fontSize: 18, color: Colors.green),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _wakeUpConfirmed ? null : _confirmWakeUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _wakeUpConfirmed ? Colors.grey : Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: Text(_wakeUpConfirmed ? "起床確認済み" : "起床確認"),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("閉じる"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
