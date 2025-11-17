import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'group_list.dart';

class MakeGroupPage extends StatefulWidget {
  const MakeGroupPage({super.key});

  @override
  State<MakeGroupPage> createState() => _MakeGroupPageState();
}

class _MakeGroupPageState extends State<MakeGroupPage> {
  final _groupNameController = TextEditingController();
  final _searchController = TextEditingController();
  IconData _selectedIcon = Icons.group;
  Color _selectedColor = Colors.blue;
  List<Map<String, dynamic>> _selectedMembers = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  final List<IconData> _availableIcons = [
    Icons.group,
    Icons.work,
    Icons.school,
    Icons.home,
    Icons.sports_soccer,
    Icons.music_note,
    Icons.favorite,
    Icons.star,
    Icons.local_cafe,
    Icons.fitness_center,
  ];

  final List<Color> _availableColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.teal,
    Colors.indigo,
    Colors.brown,
    Colors.grey,
  ];

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
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      
      for (var doc in allUsers.docs) {
        if (doc.id == currentUid) continue; // 自分を除外
        
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['name'] ?? '').toString().toLowerCase();
        final email = (data['email'] ?? '').toString().toLowerCase();
        final searchQuery = query.toLowerCase();
        
        if (name.contains(searchQuery) || email.contains(searchQuery)) {
          data['uid'] = doc.id;
          users.add(data);
        }
      }

      setState(() {
        _searchResults = users;
      });
    } catch (e) {
      print('検索エラー: $e');
    }
  }

  void _addMember(Map<String, dynamic> user) {
    if (!_selectedMembers.any((member) => member['uid'] == user['uid'])) {
      setState(() {
        _selectedMembers.add(user);
        _searchResults.clear();
        _searchController.clear();
      });
    }
  }

  void _removeMember(String uid) {
    setState(() {
      _selectedMembers.removeWhere((member) => member['uid'] == uid);
    });
  }

  Future<void> _createGroup() async {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("グループ名を入力してください")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser!;
      
      // 現在のユーザー情報を取得
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      final currentUserData = currentUserDoc.data() ?? {};
      currentUserData['uid'] = currentUser.uid;
      currentUserData['name'] = currentUserData['name'] ?? 'Unknown';
      currentUserData['email'] = currentUser.email ?? '';

      // メンバーリストに現在のユーザーを追加
      final List<Map<String, dynamic>> allMembers = [currentUserData, ..._selectedMembers];

      // グループをFirestoreに保存
      await FirebaseFirestore.instance.collection('groups').add({
        'name': _groupNameController.text.trim(),
        'icon': _selectedIcon.codePoint,
        'color': _selectedColor.value,
        'members': allMembers.map((member) => {
          'uid': member['uid'] ?? '',
          'name': member['name'] ?? 'Unknown',
          'email': member['email'] ?? '',
        }).toList(),
        'createdBy': currentUser.uid,
        'createdAt': Timestamp.now(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("グループが作成されました")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const GroupListPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("エラー: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("グループ作成"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // グループアイコン表示
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: _selectedColor,
                    child: Icon(_selectedIcon, size: 40, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),

                // アイコン選択
                const Text("アイコンを選択"),
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _availableIcons.length,
                    itemBuilder: (context, index) {
                      final icon = _availableIcons[index];
                      return Padding(
                        padding: const EdgeInsets.all(4),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedIcon = icon),
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: _selectedIcon == icon ? _selectedColor : Colors.grey[300],
                            child: Icon(icon, size: 20, color: _selectedIcon == icon ? Colors.white : Colors.grey[600]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // 色選択
                const Text("色を選択"),
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _availableColors.length,
                    itemBuilder: (context, index) {
                      final color = _availableColors[index];
                      return Padding(
                        padding: const EdgeInsets.all(4),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedColor = color),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: _selectedColor == color 
                                  ? Border.all(color: Colors.black, width: 2)
                                  : null,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // グループ名入力
                TextField(
                  controller: _groupNameController,
                  decoration: const InputDecoration(
                    labelText: "グループ名",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),

                // メンバー検索
                const Text("メンバーを追加（任意）"),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: "ユーザー名またはメールアドレスで検索",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: _searchUsers,
                ),
                const SizedBox(height: 16),

                // 検索結果
                if (_searchResults.isNotEmpty) ...[
                  const Text("検索結果"),
                  ..._searchResults.map((user) => ListTile(
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
                  )),
                  const SizedBox(height: 16),
                ],

                // 選択されたメンバー
                if (_selectedMembers.isNotEmpty) ...[
                  const Text("選択されたメンバー"),
                  ..._selectedMembers.map((member) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: member['profileColor'] != null
                          ? Color(member['profileColor'])
                          : Colors.blue,
                      child: Icon(
                        member['profileIcon'] != null
                            ? IconData(member['profileIcon'], fontFamily: 'MaterialIcons')
                            : Icons.person,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(member['name'] ?? '名前なし'),
                    subtitle: Text(member['email'] ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () => _removeMember(member['uid']),
                    ),
                  )),
                  const SizedBox(height: 24),
                ],

                // 作成ボタン
                ElevatedButton.icon(
                  onPressed: _createGroup,
                  icon: const Icon(Icons.create),
                  label: const Text("グループを作成"),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
    );
  }
}