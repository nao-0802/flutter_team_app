import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditGroupPage extends StatefulWidget {
  final String groupId;
  final Map<String, dynamic> groupData;

  const EditGroupPage({
    super.key,
    required this.groupId,
    required this.groupData,
  });

  @override
  State<EditGroupPage> createState() => _EditGroupPageState();
}

class _EditGroupPageState extends State<EditGroupPage> {
  final _groupNameController = TextEditingController();
  IconData _selectedIcon = Icons.group;
  Color _selectedColor = Colors.blue;
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

  @override
  void initState() {
    super.initState();
    _groupNameController.text = widget.groupData['name'] ?? '';
    _selectedIcon = IconData(widget.groupData['icon'] ?? Icons.group.codePoint, fontFamily: 'MaterialIcons');
    _selectedColor = Color(widget.groupData['color'] ?? Colors.blue.value);
  }

  Future<void> _updateGroup() async {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('グループ名を入力してください')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .update({
        'name': _groupNameController.text.trim(),
        'icon': _selectedIcon.codePoint,
        'color': _selectedColor.value,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('グループが更新されました')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新に失敗しました: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('グループ削除'),
        content: const Text('このグループを削除しますか？この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('グループが削除されました')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('グループ編集'),
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
                const Text('アイコンを選択'),
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
                const Text('色を選択'),
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
                    labelText: 'グループ名',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),

                // 変更ボタン
                ElevatedButton.icon(
                  onPressed: _updateGroup,
                  icon: const Icon(Icons.save),
                  label: const Text('変更'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                const SizedBox(height: 16),

                // 削除ボタン
                ElevatedButton.icon(
                  onPressed: _deleteGroup,
                  icon: const Icon(Icons.delete),
                  label: const Text('削除'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
    );
  }
}