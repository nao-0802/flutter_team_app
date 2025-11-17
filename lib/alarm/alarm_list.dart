import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'make_alarm.dart';
import 'alarm_edit.dart';

class AlarmListPage extends StatefulWidget {
  const AlarmListPage({super.key});

  @override
  State<AlarmListPage> createState() => _AlarmListPageState();
}

class _AlarmListPageState extends State<AlarmListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("アラーム一覧"),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: "通常アラーム"),
            Tab(text: "緊急アラーム"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _alarmList("normal_alarm"),
          _alarmList("emergency_alarm"),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MakeAlarmPage()),
          );
          setState(() {});
        },
      ),
    );
  }

  Widget _alarmList(String collection) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text("ログインが必要です"));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;

        if (docs.isEmpty) return const Center(child: Text("アラームなし"));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            return ListTile(
              leading: const Icon(Icons.alarm),
              title: Text(data['time'] ?? '??'),
              subtitle: data['days'] != null
                  ? Text("繰り返し: ${(data['days'] as List).join('・')}")
                  : null,
              trailing: Switch(
                value: data['enabled'] ?? true,
                onChanged: (v) {
                  FirebaseFirestore.instance
                      .collection(collection)
                      .doc(doc.id)
                      .update({'enabled': v});
                },
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AlarmEditPage(
                      alarmId: doc.id,
                      collectionName: collection,
                      alarmData: data,
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
