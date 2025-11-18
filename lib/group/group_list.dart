import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../alarm/alarm_list.dart';
import '../profile/profile.dart';
import 'make_group.dart';
import '../group_alarm/make_group_alarm.dart';
import 'group_members.dart';
import 'edit_group.dart';
import 'prank_page.dart';
import '../group_alarm/edit_group_alarm.dart';

class GroupListPage extends StatefulWidget {
  const GroupListPage({super.key});

  @override
  State<GroupListPage> createState() => _GroupListPageState();
}

class _GroupListPageState extends State<GroupListPage> with TickerProviderStateMixin {
  int _currentIndex = 1; // 共有アラームタブを選択状態にする
  String? selectedGroupId;
  List<Map<String, dynamic>> groups = [];
  TabController? _tabController;
  List<Map<String, dynamic>> groupAlarms = [];
  List<Map<String, dynamic>> emergencyAlarms = [];
  Set<String> expandedAlarms = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadGroups();
    _cleanupOldRecords(); // 古い起床記録をクリーンアップ
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
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
                      _loadGroupAlarms(group['id']);
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
          ).then((_) => _loadGroupAlarms(selectedGroupId!)); // アラーム作成後にリストを更新
        },
        child: const Icon(Icons.add),
      ) : null,
    );
  }

  void _editAlarm(Map<String, dynamic> alarm, bool isEmergency) {
    final collection = isEmergency ? 'group_emergency_alarm' : 'group_normal_alarm';
    final group = groups.firstWhere((g) => g['id'] == selectedGroupId, orElse: () => <String, dynamic>{});
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditGroupAlarmPage(
          alarmId: alarm['id'],
          collectionName: collection,
          alarmData: alarm,
          groupId: selectedGroupId!,
          groupName: group['name'] ?? '',
        ),
      ),
    ).then((_) => _loadGroupAlarms(selectedGroupId!));
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
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "アラーム"),
            Tab(text: "緊急アラーム"),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAlarmList(groupAlarms, "アラーム"),
              _buildAlarmList(emergencyAlarms, "緊急アラーム"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAlarmList(List<Map<String, dynamic>> alarms, String type) {
    if (alarms.isEmpty) {
      return Center(
        child: Text(
          "${type}がありません",
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: alarms.length,
      itemBuilder: (context, index) {
        final alarm = alarms[index];
        final isExpanded = expandedAlarms.contains(alarm['id']);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  type == "緊急アラーム" ? Icons.warning : Icons.alarm,
                  color: type == "緊急アラーム" ? Colors.red : Colors.blue,
                ),
                title: const Text('アラーム'),
                subtitle: Text(
                  '${alarm['time'] ?? ''} - ${(alarm['days'] as List?)?.join(', ') ?? '毎日'}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: () => _confirmWakeUpForAlarm(alarm['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(60, 30),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      child: const Text('起床', style: TextStyle(fontSize: 12)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _editAlarm(alarm, type == "緊急アラーム"),
                    ),
                    Switch(
                      value: alarm['enabled'] ?? false,
                      onChanged: (value) {
                        _toggleAlarm(alarm['id'], value, type == "緊急アラーム");
                      },
                    ),
                    IconButton(
                      icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                      onPressed: () {
                        setState(() {
                          if (isExpanded) {
                            expandedAlarms.remove(alarm['id']);
                          } else {
                            expandedAlarms.add(alarm['id']);
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
              if (isExpanded) _buildMemberStatus(alarm),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMemberStatus(Map<String, dynamic> alarm) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('wake_up_records')
          .doc('${DateTime.now().toIso8601String().split('T')[0]}_${selectedGroupId}_${alarm['id']}')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          );
        }

        final doc = snapshot.data!;
        final docData = doc.data() as Map<String, dynamic>?;
        final records = doc.exists && docData != null
            ? (docData['records'] as Map<String, dynamic>?) ?? {}
            : <String, dynamic>{};
        
        print('メンバー状況デバッグ - ドキュメント存在: ${doc.exists}, レコード: $records');
        if (selectedGroupId == null) return Container();
        final group = groups.firstWhere((g) => g['id'] == selectedGroupId, orElse: () => <String, dynamic>{});
        final members = List<Map<String, dynamic>>.from(group['members'] ?? []);

        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'メンバー起床状況',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...members.map((member) {
                final uid = member['uid'];
                final memberRecord = records[uid] as Map<String, dynamic>?;
                final wakeUpConfirmed = memberRecord?['wakeUpConfirmed'] ?? false;
                final currentUid = FirebaseAuth.instance.currentUser?.uid;
                final isCurrentUser = uid == currentUid;
                final alarmTimePassed = _isAlarmTimePassed(alarm);
                
                // 自分が起床確認済みかチェック
                final currentUserRecord = records[currentUid] as Map<String, dynamic>?;
                final currentUserWakeUpConfirmed = currentUserRecord?['wakeUpConfirmed'] ?? false;
                
                // イタズラ条件: 自分が起床確認済み かつ 相手が未確認 かつ 他人 かつ 時刻経過
                final canPrank = currentUserWakeUpConfirmed && !wakeUpConfirmed && !isCurrentUser && alarmTimePassed;
                
                print('メンバー: ${member['name']}, 起床確認: $wakeUpConfirmed, 自分: $isCurrentUser, 自分の起床確認: $currentUserWakeUpConfirmed, 時刻経過: $alarmTimePassed, イタズラ可能: $canPrank');
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: member['color'] != null
                        ? Color(member['color'])
                        : Colors.blue,
                    child: Icon(
                      member['icon'] != null
                          ? IconData(member['icon'], fontFamily: 'MaterialIcons')
                          : Icons.person,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(member['name'] ?? '名前なし'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        wakeUpConfirmed ? Icons.check_circle : Icons.cancel,
                        color: wakeUpConfirmed ? Colors.green : Colors.red,
                      ),
                      if (canPrank) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.sentiment_very_dissatisfied, color: Colors.orange),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PrankPage(
                                  targetMember: member,
                                  groupId: selectedGroupId!,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }



  bool _isAlarmTimePassed(Map<String, dynamic> alarm) {
    final timeStr = alarm['time'] as String?;
    if (timeStr == null) return true; // 時刻がない場合はイタズラ可能
    
    final timeParts = timeStr.split(':');
    if (timeParts.length != 2) return true;
    
    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (hour == null || minute == null) return true;
    
    final now = DateTime.now();
    final alarmTime = DateTime(now.year, now.month, now.day, hour, minute);
    
    print('アラーム時刻チェック - 現在: ${now.hour}:${now.minute}, アラーム: $hour:$minute, 経過: ${now.isAfter(alarmTime)}');
    
    return now.isAfter(alarmTime);
  }

  Future<void> _loadGroupAlarms(String groupId) async {
    try {
      // 通常のアラーム取得
      final alarmQuery = await FirebaseFirestore.instance
          .collection('group_normal_alarm')
          .where('groupId', isEqualTo: groupId)
          .get();

      // 緊急アラーム取得
      final emergencyQuery = await FirebaseFirestore.instance
          .collection('group_emergency_alarm')
          .where('groupId', isEqualTo: groupId)
          .get();

      if (mounted) {
        setState(() {
          groupAlarms = alarmQuery.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();

          emergencyAlarms = emergencyQuery.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
      }
    } catch (e) {
      print('アラーム読み込みエラー: $e');
    }
  }

  Future<void> _confirmWakeUpForAlarm(String alarmId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || selectedGroupId == null) return;

    final today = DateTime.now().toIso8601String().split('T')[0];
    final recordId = '${today}_${selectedGroupId}_$alarmId';
    
    print('起床確認開始 - UID: $uid, RecordID: $recordId');
    
    try {
      await FirebaseFirestore.instance
          .collection('wake_up_records')
          .doc(recordId)
          .set({
        'groupId': selectedGroupId,
        'alarmId': alarmId,
        'date': today,
        'records': {
          uid: {
            'wakeUpConfirmed': true,
            'confirmedAt': Timestamp.now(),
          }
        }
      }, SetOptions(merge: true));
      
      print('起床確認データ保存完了');
      
      // 全員の起床確認をチェック
      await _checkAndResetIfAllConfirmed(alarmId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('起床確認しました')),
        );
      }
    } catch (e) {
      print('起床確認エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('起床確認に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _toggleAlarm(String alarmId, bool enabled, bool isEmergency) async {
    try {
      final collection = isEmergency ? 'group_emergency_alarm' : 'group_normal_alarm';
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(alarmId)
          .update({'enabled': enabled});

      setState(() {
        if (isEmergency) {
          final index = emergencyAlarms.indexWhere((alarm) => alarm['id'] == alarmId);
          if (index != -1) {
            emergencyAlarms[index]['enabled'] = enabled;
          }
        } else {
          final index = groupAlarms.indexWhere((alarm) => alarm['id'] == alarmId);
          if (index != -1) {
            groupAlarms[index]['enabled'] = enabled;
          }
        }
      });
    } catch (e) {
      print('アラーム更新エラー: $e');
    }
  }

  Future<void> _checkAndResetIfAllConfirmed(String alarmId) async {
    if (selectedGroupId == null) return;
    
    final today = DateTime.now().toIso8601String().split('T')[0];
    final recordId = '${today}_${selectedGroupId}_$alarmId';
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('wake_up_records')
          .doc(recordId)
          .get();
      
      if (!doc.exists || doc.data() == null) return;
      
      final data = doc.data() as Map<String, dynamic>;
      final records = data['records'] as Map<String, dynamic>? ?? {};
      
      // グループメンバー数を取得
      if (selectedGroupId == null) return;
      final group = groups.firstWhere((g) => g['id'] == selectedGroupId, orElse: () => <String, dynamic>{});
      final members = List<Map<String, dynamic>>.from(group['members'] ?? []);
      
      // 全員が起床確認したかチェック
      bool allConfirmed = true;
      for (final member in members) {
        final memberRecord = records[member['uid']] as Map<String, dynamic>?;
        if (memberRecord?['wakeUpConfirmed'] != true) {
          allConfirmed = false;
          break;
        }
      }
      
      // 全員確認済みなら記録を削除
      if (allConfirmed) {
        await FirebaseFirestore.instance
            .collection('wake_up_records')
            .doc(recordId)
            .delete();
        
        print('全員起床確認完了 - データをリセットしました: $recordId');
      }
    } catch (e) {
      print('起床確認チェックエラー: $e');
    }
  }

  Future<void> _cleanupOldRecords() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayStr = yesterday.toIso8601String().split('T')[0];
    
    try {
      final query = await FirebaseFirestore.instance
          .collection('wake_up_records')
          .where('date', isLessThan: yesterdayStr)
          .get();
      
      for (final doc in query.docs) {
        await doc.reference.delete();
      }
      
      if (query.docs.isNotEmpty) {
        print('古い起床記録を削除しました: ${query.docs.length}件');
      }
    } catch (e) {
      print('古い記録削除エラー: $e');
    }
  }

  void _showMembersList() {
    if (selectedGroupId == null) return;
    final group = groups.firstWhere((g) => g['id'] == selectedGroupId, orElse: () => <String, dynamic>{});
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupMembersPage(
          groupId: selectedGroupId!,
          groupName: group['name'],
        ),
      ),
    ).then((_) => _loadGroups()); // メンバー追加後にグループ情報を更新
  }

  void _editGroup() {
    if (selectedGroupId == null) return;
    final group = groups.firstWhere((g) => g['id'] == selectedGroupId, orElse: () => <String, dynamic>{});
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditGroupPage(
          groupId: selectedGroupId!,
          groupData: group,
        ),
      ),
    ).then((result) {
      if (result == true) {
        _loadGroups(); // グループ情報を更新
        setState(() {
          selectedGroupId = null; // 削除された場合のため選択をクリア
        });
      }
    });
  }

  void _leaveGroup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("グループ脱退"),
        content: const Text("グループから脱退しますか？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("いいえ"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performLeaveGroup();
            },
            child: const Text("はい"),
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
            const SnackBar(content: Text("脱退しました")),
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