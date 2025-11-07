import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'make_alarm.dart';
import 'alarm_edit.dart'; // ← 追加！

class AlarmListPage extends StatefulWidget {
  const AlarmListPage({super.key});

  @override
  State<AlarmListPage> createState() => _AlarmListPageState();
}

class _AlarmListPageState extends State<AlarmListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('アラーム一覧'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '通常アラーム'),
            Tab(text: '緊急アラーム'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('メニューが押されました')),
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAlarmList('normal_alarm'),
          _buildAlarmList('emergency_alarm'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MakeAlarmPage()),
          );
          setState(() {});
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildAlarmList(String collectionName) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('ログイン情報がありません'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collectionName)
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('アラームが登録されていません'));
        }

        final alarms = snapshot.data!.docs;

        return ListView.builder(
          itemCount: alarms.length,
          itemBuilder: (context, index) {
            final alarmDoc = alarms[index];
            final alarm = alarmDoc.data() as Map<String, dynamic>;
            return ListTile(
              leading: const Icon(Icons.alarm),
              title: Text(alarm['time'] ?? '不明', style: const TextStyle(fontSize: 24)),
              subtitle: (alarm['days'] != null && (alarm['days'] as List).isNotEmpty)
                  ? Text('繰り返し：${(alarm['days'] as List).join('・')}')
                  : null,
              trailing: Switch(
                value: alarm['enabled'] ?? true,
                onChanged: (value) {
                  FirebaseFirestore.instance
                      .collection(collectionName)
                      .doc(alarmDoc.id)
                      .update({'enabled': value});
                },
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AlarmEditPage(
                      alarmId: alarmDoc.id,
                      collectionName: collectionName,
                      alarmData: alarm,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
