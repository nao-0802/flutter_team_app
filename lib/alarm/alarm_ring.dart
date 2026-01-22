import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_team_app/alarm/make_alarm.dart';

class AlarmRingPage extends StatefulWidget {
  final AlarmSettings alarmSettings;
  final String? groupId;
  final String? alarmId;

  const AlarmRingPage({
    super.key,
    required this.alarmSettings,
    this.groupId,
    this.alarmId,
  });

  @override
  State<AlarmRingPage> createState() => _AlarmRingPageState();
}

class _AlarmRingPageState extends State<AlarmRingPage> {
  bool _alarmStopped = false;
  bool _wakeUpConfirmed = false;

  Future<void> _stopAlarm() async {
    await Alarm.stop(widget.alarmSettings.id);
    setState(() => _alarmStopped = true);

    if (widget.groupId != null && widget.alarmId != null) {
      await _recordAlarmStopped();
      await _rescheduleNextAlarm();
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

    final today = DateTime.now().toIso8601String().split('T')[0];
    final recordId = '${today}_${widget.groupId}_${widget.alarmId}';

    await FirebaseFirestore.instance
        .collection('wake_up_records')
        .doc(recordId)
        .set({
      'groupId': widget.groupId,
      'alarmId': widget.alarmId,
      'date': today,
      'records.$uid.alarmStopped': true,
      'records.$uid.stoppedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<void> _recordWakeUpConfirmed() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final today = DateTime.now().toIso8601String().split('T')[0];
    final recordId = '${today}_${widget.groupId}_${widget.alarmId}';

    await FirebaseFirestore.instance
        .collection('wake_up_records')
        .doc(recordId)
        .set({
      'records.$uid.wakeUpConfirmed': true,
      'records.$uid.confirmedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

    Future<void> _rescheduleNextAlarm() async {
        if (widget.alarmId == null || widget.groupId == null) return;

        final alarmDoc = await FirebaseFirestore.instance
            .collection(widget.groupId!)
            .doc(widget.alarmId!)
            .get();
        
        if (!alarmDoc.exists) return;

        final data = alarmDoc.data()!;
        if (data['enabled'] != true) return;

        final timeParts = data['time'].split(':');
        final time = TimeOfDay(
            hour: int.parse(timeParts[0]),
            minute: int.parse(timeParts[1]),
        );

        final List<String> days = List<String>.from(data['data'] ?? []);

        if (days.isEmpty) return;

        final nextDateTime = calclulateNextAlarmDateTime(time, days);

        await Alarm.set(
            alarmSettings: AlarmSettings(
                id: widget.alarmId.hashCode,
                dateTime: nextDateTime,
                assetAudioPath: 'assets/sounds/${data['sound']}',
                loopAudio: true,
                vibrate: true,
                notificationTitle: 'アラーム',
                notificationBody: 'アラームの時間です'
            ),
        );

        print('次回アラーム: $nextDateTime');
    }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 戻るボタン無効（emergency対策）
      canPop:false,
      child: Scaffold(
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
                    backgroundColor:
                        _wakeUpConfirmed ? Colors.grey : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child:
                      Text(_wakeUpConfirmed ? "起床確認済み" : "起床確認"),
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
      ),
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

  for (int i = 1; i <= 7; i++) {
    final candidate = DateTime(
      now.year,
      now.month,
      now.day + i,
      time.hour,
      time.minute,
    );

    if (targets.contains(candidate.weekday)) {
      return candidate;
    }
  }

  return now.add(const Duration(days: 1));
}
