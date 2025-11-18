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
import 'alarm_detail_page.dart';

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
  String? selectedAlarmId;

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
            width: 60,
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
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green,
                          border: Border.all(color: Colors.grey, width: 2),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 20,
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
                      width: 44,
                      height: 44,
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
                        size: 20,
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
      padding: const EdgeInsets.all(8),
      itemCount: alarms.length,
      itemBuilder: (context, index) {
        final alarm = alarms[index];
        
        final isSelected = selectedAlarmId == alarm['id'];
        
        return GestureDetector(
          onTap: () {
            setState(() {
              selectedAlarmId = alarm['id'];
            });
          },
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity! < -100) {
              _showAlarmDetail(alarm, type);
            }
          },
          onLongPress: () {
            _showAlarmDetail(alarm, type);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue[50] : Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                left: isSelected ? BorderSide(color: Colors.blue, width: 3) : BorderSide.none,
              ),
            ),
            child: Row(
              children: [
                Text(
                  type == "緊急アラーム" ? "🚨" : "⏰",
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatTime(alarm['time'] ?? ''),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if ((alarm['days'] as List?)?.isNotEmpty == true)
                        Text(
                          (alarm['days'] as List).join(', '),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      Text(
                        '← 左スワイプで詳細',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: alarm['enabled'] ?? false,
                    onChanged: (value) {
                      _toggleAlarm(alarm['id'], value, type == "緊急アラーム");
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAlarmDetail(Map<String, dynamic> alarm, String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlarmDetailPage(
          alarm: alarm,
          type: type,
          groupId: selectedGroupId!,
          onWakeUpConfirm: () => _confirmWakeUpForAlarm(alarm['id']),
          onEdit: () => _editAlarm(alarm, type == "緊急アラーム"),
        ),
      ),
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

  String _formatTime(String time) {
    if (time.isEmpty) return '';
    final parts = time.split(':');
    if (parts.length != 2) return time;
    
    final hour = int.tryParse(parts[0])?.toString().padLeft(2, '0') ?? parts[0];
    final minute = int.tryParse(parts[1])?.toString().padLeft(2, '0') ?? parts[1];
    
    return '$hour:$minute';
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