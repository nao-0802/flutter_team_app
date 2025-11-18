import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupMembersPage extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupMembersPage({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupMembersPage> createState() => _GroupMembersPageState();
}

class _GroupMembersPageState extends State<GroupMembersPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final groupDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get();

      if (groupDoc.exists) {
        final data = groupDoc.data() as Map<String, dynamic>;
        final members = List<Map<String, dynamic>>.from(data['members'] ?? []);
        setState(() {
          _members = members;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('メンバー読み込みエラー: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    try {
      final QuerySnapshot allUsers = await FirebaseFirestore.instance
          .collection('users')
          .get();

      final List<Map<String, dynamic>> users = [];
      
      for (var doc in allUsers.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['name'] ?? '').toString().toLowerCase();
        final email = (data['email'] ?? '').toString().toLowerCase();
        final searchQuery = query.toLowerCase();
        
        // 既にメンバーでないかチェック
        final isAlreadyMember = _members.any((member) => member['uid'] == doc.id);
        
        if (!isAlreadyMember && (name.contains(searchQuery) || email.contains(searchQuery))) {
          data['uid'] = doc.id;
          users.add(data);
        }
      }

      setState(() => _searchResults = users);
    } catch (e) {
      print('検索エラー: $e');
    }
  }

  Future<void> _addMember(Map<String, dynamic> user) async {
    try {
      final newMember = {
        'uid': user['uid'],
        'name': user['name'] ?? 'Unknown',
        'email': user['email'] ?? '',
      };

      final updatedMembers = [..._members, newMember];

      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .update({'members': updatedMembers});

      setState(() {
        _members = updatedMembers;
        _searchResults.clear();
        _searchController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メンバーを追加しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('追加に失敗しました: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.groupName}のメンバー'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // メンバー検索
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'ユーザー名またはメールアドレスで検索',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: _searchUsers,
                  ),
                ),

                // 検索結果
                if (_searchResults.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '検索結果',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final user = _searchResults[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: user['profileColor'] != null
                              ? Color(user['profileColor'])
                              : Colors.blue,
                          child: Icon(
                            user['profileIcon'] != null
                                ? IconData(user['profileIcon'], fontFamily: 'MaterialIcons')
                                : Icons.person,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(user['name'] ?? '名前なし'),
                        subtitle: Text(user['email'] ?? ''),
                        trailing: IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => _addMember(user),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                ],

                // 現在のメンバー
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'メンバー一覧',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _members.length,
                    itemBuilder: (context, index) {
                      final member = _members[index];
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
                        subtitle: Text(member['email'] ?? ''),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}