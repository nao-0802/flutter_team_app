import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MenuListPage extends StatefulWidget {
  final List<Map<String, String>> menus;

  const MenuListPage({super.key, required this.menus});

  @override
  State<MenuListPage> createState() => _MenuListPageState();
}

class _MenuListPageState extends State<MenuListPage> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _saveMenus() async {
    final prefs = await SharedPreferences.getInstance();
    final list = widget.menus
        .map((e) => '${e['name']}|${e['imagePath']}')
        .toList();
    await prefs.setStringList('menus', list);
  }

  Future<void> _addMenu() async {
    final nameController = TextEditingController();
    File? selectedImage;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('献立を追加'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '献立名'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo),
                  label: const Text('画像を選択'),
                  onPressed: () async {
                    final picked =
                        await _picker.pickImage(source: ImageSource.gallery);
                    if (picked != null) {
                      setDialogState(() {
                        selectedImage = File(picked.path);
                      });
                    }
                  },
                ),
                if (selectedImage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Image.file(
                      selectedImage!,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () async {
                  if (nameController.text.isNotEmpty &&
                      selectedImage != null) {
                    setState(() {
                      widget.menus.add({
                        'name': nameController.text,
                        'imagePath': selectedImage!.path,
                      });
                    });
                    await _saveMenus();
                  }
                  Navigator.pop(context);
                },
                child: const Text('追加'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('献立一覧')),
      body: widget.menus.isEmpty
          ? const Center(child: Text('献立がありません'))
          : ListView.builder(
              itemCount: widget.menus.length,
              itemBuilder: (context, index) {
                final menu = widget.menus[index];
                return Dismissible(
                  key: ValueKey(menu['imagePath']),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) async {
                    setState(() {
                      widget.menus.removeAt(index);
                    });
                    await _saveMenus();
                  },
                  child: ListTile(
                    leading: Image.file(
                      File(menu['imagePath']!),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                    title: Text(menu['name']!),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addMenu,
        child: const Icon(Icons.add),
      ),
    );
  }
}
