import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'make_alarm.dart';
import 'alarm_edit.dart';
import '../logout/logout.dart';
import '../group/group_list.dart';
import '../profile/profile.dart'; 

class AlarmListPage extends StatefulWidget {
  const AlarmListPage({super.key});

  @override
  State<AlarmListPage> createState() => _AlarmListPageState();
}

class _AlarmListPageState extends State<AlarmListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  int _currentIndex = 0; // アラームタブを選択状態にする
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists) {
      setState(() {
        _userData = doc.data();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("アラーム一覧"),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == "logout") {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LogoutPage()),
                );
              }
            },
            itemBuilder: (context) {
              final user = FirebaseAuth.instance.currentUser;
              return [
                PopupMenuItem(
                  enabled: false,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: _userData?['profileColor'] != null
                              ? Color(_userData!['profileColor'])
                              : Colors.blue,
                          child: Icon(
                            _userData?['profileIcon'] != null
                                ? IconData(_userData!['profileIcon'], fontFamily: 'MaterialIcons')
                                : Icons.person,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _userData?['name'] ?? '未設定',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                user?.email ?? '',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: "logout",
                  child: Text("ログアウト"),
                ),
              ];
            },
          ),
        ],
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
            MaterialPageRoute(builder: (context) => const MakeAlarmPage()),
          );
          setState(() {});
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const GroupListPage()),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            );
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.alarm),
            label: "アラーム",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: "共有アラーム",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "プロフィール",
          ),
        ],
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
              title: Text(_formatTime(data['time'] ?? '??')),
              subtitle: data['days'] != null && (data['days'] as List).isNotEmpty
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

  String _formatTime(String time) {
    if (time == '??') return time;
    final parts = time.split(':');
    if (parts.length != 2) return time;
    final hour = parts[0].padLeft(2, '0');
    final minute = parts[1].padLeft(2, '0');
    return '$hour:$minute';
  }
}

