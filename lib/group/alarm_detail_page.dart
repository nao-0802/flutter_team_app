import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'prank_page.dart';

class AlarmDetailPage extends StatelessWidget {
  final Map<String, dynamic> alarm;
  final String type;
  final String groupId;
  final VoidCallback onWakeUpConfirm;
  final VoidCallback onEdit;

  const AlarmDetailPage({
    super.key,
    required this.alarm,
    required this.type,
    required this.groupId,
    required this.onWakeUpConfirm,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${type == "緊急アラーム" ? "🚨" : "⏰"} ${_formatTime(alarm['time'] ?? '')}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.pop(context);
              onEdit();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '時刻: ${_formatTime(alarm['time'] ?? '')}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '曜日: ${(alarm['days'] as List?)?.join(', ') ?? '毎日'}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      onWakeUpConfirm();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('起床確認しました')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('起床確認', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _buildMemberStatus(),
          ),
        ],
      ),
    );
  }

  String _formatTime(String time) {
    if (time.isEmpty) return '';
    final parts = time.split(':');
    if (parts.length != 2) return time;
    
    final hour = int.tryParse(parts[0])?.toString().padLeft(2, '0') ?? parts[0];
    final minute = int.tryParse(parts[1])?.toString().padLeft(2, '0') ?? parts[1];
    
    return '$hour:$minute';
  }

  Widget _buildMemberStatus() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('wake_up_records')
          .doc('${DateTime.now().toIso8601String().split('T')[0]}_${groupId}_${alarm['id']}')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final doc = snapshot.data!;
        final docData = doc.data() as Map<String, dynamic>?;
        final records = doc.exists && docData != null
            ? (docData['records'] as Map<String, dynamic>?) ?? {}
            : <String, dynamic>{};

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('groups')
              .doc(groupId)
              .snapshots(),
          builder: (context, groupSnapshot) {
            if (!groupSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final groupData = groupSnapshot.data!.data() as Map<String, dynamic>?;
            final members = List<Map<String, dynamic>>.from(groupData?['members'] ?? []);

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];
                final uid = member['uid'];
                final memberRecord = records[uid] as Map<String, dynamic>?;
                final wakeUpConfirmed = memberRecord?['wakeUpConfirmed'] ?? false;
                final currentUid = FirebaseAuth.instance.currentUser?.uid;
                final isCurrentUser = uid == currentUid;
                final alarmTimePassed = _isAlarmTimePassed(alarm);
                
                final currentUserRecord = records[currentUid] as Map<String, dynamic>?;
                final currentUserWakeUpConfirmed = currentUserRecord?['wakeUpConfirmed'] ?? false;
                final canPrank = currentUserWakeUpConfirmed && !wakeUpConfirmed && !isCurrentUser && alarmTimePassed;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: member['color'] != null
                            ? Color(member['color'])
                            : Colors.blue,
                        child: Icon(
                          member['icon'] != null
                              ? IconData(member['icon'], fontFamily: 'MaterialIcons')
                              : Icons.person,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member['name'] ?? '名前なし',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              wakeUpConfirmed ? '起床済み' : '未起床',
                              style: TextStyle(
                                fontSize: 14,
                                color: wakeUpConfirmed ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        wakeUpConfirmed ? Icons.check_circle : Icons.cancel,
                        color: wakeUpConfirmed ? Colors.green : Colors.red,
                        size: 24,
                      ),
                      if (canPrank) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.sentiment_very_dissatisfied,
                            color: Colors.orange,
                            size: 24,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PrankPage(
                                  targetMember: member,
                                  groupId: groupId,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  bool _isAlarmTimePassed(Map<String, dynamic> alarm) {
    final timeStr = alarm['time'] as String?;
    if (timeStr == null) return true;
    
    final timeParts = timeStr.split(':');
    if (timeParts.length != 2) return true;
    
    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (hour == null || minute == null) return true;
    
    final now = DateTime.now();
    final alarmTime = DateTime(now.year, now.month, now.day, hour, minute);
    
    return now.isAfter(alarmTime);
  }
}