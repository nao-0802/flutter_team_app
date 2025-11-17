import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../alarm/alarm_list.dart';
import '../group/group_list.dart';
import 'profile_edit.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _currentIndex = 2; // プロフィールタブを選択状態にする
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    setState(() {
      _userData = doc.exists ? doc.data() : {};
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("プロフィール"),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileEditPage()),
              );
              _loadUserData();
            },
          ),
        ],
      ),
      body: _userData == null
          ? const Center(child: CircularProgressIndicator())
          : _userData!.isEmpty || _userData!['name'] == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person_add, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        "プロフィールの登録を行ってください",
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ProfileEditPage()),
                          );
                          _loadUserData();
                        },
                        child: const Text("プロフィールを登録"),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: _userData!['profileColor'] != null
                            ? Color(_userData!['profileColor'])
                            : Colors.blue,
                        child: Icon(
                          _userData!['profileIcon'] != null
                              ? IconData(_userData!['profileIcon'], fontFamily: 'MaterialIcons')
                              : Icons.person,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildInfoCard("名前", _userData!['name'] ?? '未設定'),
                    const SizedBox(height: 16),
                    _buildInfoCard("メールアドレス", user?.email ?? ''),
                    const SizedBox(height: 16),
                    _buildInfoCard("誕生日", _userData!['birthday'] ?? '未設定'),
                  ],
                ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AlarmListPage()),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const GroupListPage()),
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

  Widget _buildInfoCard(String label, String value) {
    return Card(
      child: ListTile(
        title: Text(label),
        subtitle: Text(value),
      ),
    );
  }
}