import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../alarm/alarm_list.dart';
import '../profile/profile.dart';
import 'make_group.dart';
import '../group_alarm/make_group_alarm.dart';

class GroupListPage extends StatefulWidget {
  const GroupListPage({super.key});

  @override
  State<GroupListPage> createState() => _GroupListPageState();
}

class _GroupListPageState extends State<GroupListPage> {
  int _currentIndex = 1; // 共有アラームタブを選択状態にする
  String? selectedGroupId;
  List<Map<String, dynamic>> groups = [];

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final QuerySnapshot result = await FirebaseFirestore.instance
          .collection('groups')
          .get();

      final List<Map<String, dynamic>> userGroups = [];
      
      for (var doc in result.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final members = List<Map<String, dynamic>>.from(data['members'] ?? []);
        
        if (members.any((member) => member['uid'] == uid)) {
          data['id'] = doc.id;
          userGroups.add(data);
        }
      }

      setState(() {
        groups = userGroups;
      });
    } catch (e) {
      print('グループ読み込みエラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(selectedGroupId != null 
            ? groups.firstWhere((g) => g['id'] == selectedGroupId)['name'] 
            : "共有アラーム"),
        actions: selectedGroupId != null ? [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == "members") {
                _showMembersList();
              } else if (value == "edit") {
                _editGroup();
              } else if (value == "leave") {
                _leaveGroup();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: "members",
                child: Text("メンバー一覧"),
              ),
              const PopupMenuItem(
                value: "edit",
                child: Text("グループ編集"),
              ),
              const PopupMenuItem(
                value: "leave",
                child: Text("グループ脱退"),
              ),
            ],
          ),
        ] : null,
      ),
      body: Row(
        children: [
          // 左側のグループアイコンリスト
          Container(
            width: 80,
            color: Colors.grey[200],
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: groups.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MakeGroupPage()),
                        ).then((_) => _loadGroups());
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green,
                          border: Border.all(color: Colors.grey, width: 2),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  );
                }
                final group = groups[index - 1];
                final isSelected = selectedGroupId == group['id'];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedGroupId = group['id'];
                      });
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(group['color']),
                        border: isSelected 
                            ? Border.all(color: Colors.blue, width: 3)
                            : null,
                      ),
                      child: Icon(
                        IconData(group['icon'], fontFamily: 'MaterialIcons'),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // 右側のメインコンテンツエリア
          Expanded(
            child: selectedGroupId != null
                ? _buildGroupContent(groups.firstWhere((g) => g['id'] == selectedGroupId))
                : groups.isEmpty
                    ? const Center(
                        child: Text(
                          "グループがありません",
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      )
                    : const Center(
                        child: Text(
                          "グループを選択してください",
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AlarmListPage()),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            );
          }
        },
        items: const [
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
      floatingActionButton: selectedGroupId != null ? FloatingActionButton(
        onPressed: () {
          final group = groups.firstWhere((g) => g['id'] == selectedGroupId);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MakeGroupAlarmPage(
                groupId: selectedGroupId!,
                groupName: group['name'],
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ) : null,
    );
  }

  Widget _buildGroupContent(Map<String, dynamic> group) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Text(
            "${group['name']}の共有アラーム",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const Expanded(
          child: Center(
            child: Text(
              "共有アラームがありません",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  void _showMembersList() {
    final group = groups.firstWhere((g) => g['id'] == selectedGroupId);
    final members = List<Map<String, dynamic>>.from(group['members'] ?? []);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${group['name']}のメンバー"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(member['color'] ?? 0xFF2196F3),
                  child: Icon(
                    IconData(member['icon'] ?? Icons.person.codePoint, fontFamily: 'MaterialIcons'),
                    color: Colors.white,
                  ),
                ),
                title: Text(member['name'] ?? 'Unknown'),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("閉じる"),
          ),
        ],
      ),
    );
  }

  void _editGroup() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("グループ編集機能は実装予定です")),
    );
  }

  void _leaveGroup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("グループ脱退"),
        content: const Text("本当にこのグループから脱退しますか？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("キャンセル"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performLeaveGroup();
            },
            child: const Text("脱退"),
          ),
        ],
      ),
    );
  }

  Future<void> _performLeaveGroup() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || selectedGroupId == null) return;

    try {
      final groupDoc = FirebaseFirestore.instance.collection('groups').doc(selectedGroupId!);
      final groupData = await groupDoc.get();
      
      if (groupData.exists) {
        final data = groupData.data() as Map<String, dynamic>;
        final members = List<Map<String, dynamic>>.from(data['members'] ?? []);
        
        members.removeWhere((member) => member['uid'] == uid);
        
        await groupDoc.update({'members': members});
        
        setState(() {
          selectedGroupId = null;
        });
        
        _loadGroups();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("グループから脱退しました")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("脱退に失敗しました: $e")),
        );
      }
    }
  }
}