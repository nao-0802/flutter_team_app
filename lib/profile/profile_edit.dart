import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _nameController = TextEditingController();
  final _birthdayController = TextEditingController();
  IconData _selectedIcon = Icons.person;
  Color _selectedColor = Colors.blue;
  bool _isLoading = false;

  final List<IconData> _availableIcons = [
    Icons.person,
    Icons.face,
    Icons.account_circle,
    Icons.sentiment_satisfied,
    Icons.pets,
    Icons.star,
    Icons.favorite,
    Icons.work,
    Icons.school,
    Icons.home,
    Icons.sports_soccer,
    Icons.music_note,
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
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      _nameController.text = data['name'] ?? '';
      _birthdayController.text = data['birthday'] ?? '';
      
      if (data['profileIcon'] != null) {
        _selectedIcon = IconData(data['profileIcon'], fontFamily: 'MaterialIcons');
      }
      if (data['profileColor'] != null) {
        _selectedColor = Color(data['profileColor']);
      }
    }
  }



  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _birthdayController.text = "${picked.year}/${picked.month}/${picked.day}";
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final email = FirebaseAuth.instance.currentUser?.email;
    
    if (uid == null) return;

    try {
      final data = {
        'name': _nameController.text,
        'email': email,
        'birthday': _birthdayController.text,
        'profileIcon': _selectedIcon.codePoint,
        'profileColor': _selectedColor.value,
      };

      await FirebaseFirestore.instance.collection('users').doc(uid).set(data);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("プロフィールが保存されました")),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProfilePage()),
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("プロフィール編集"),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: const Text("保存", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: _selectedColor,
                    child: Icon(_selectedIcon, size: 60, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                const Text("アイコンを選択"),
                SizedBox(
                  height: 80,
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
                            radius: 25,
                            backgroundColor: _selectedIcon == icon ? _selectedColor : Colors.grey[300],
                            child: Icon(icon, color: _selectedIcon == icon ? Colors.white : Colors.grey[600]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                const Text("色を選択"),
                SizedBox(
                  height: 60,
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
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: _selectedColor == color 
                                  ? Border.all(color: Colors.black, width: 3)
                                  : null,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveProfile,
                  icon: const Icon(Icons.save),
                  label: const Text("プロフィールを更新"),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "名前",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: TextEditingController(
                    text: FirebaseAuth.instance.currentUser?.email ?? '',
                  ),
                  decoration: const InputDecoration(
                    labelText: "メールアドレス",
                    border: OutlineInputBorder(),
                  ),
                  enabled: false,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _birthdayController,
                  decoration: const InputDecoration(
                    labelText: "誕生日（任意）",
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  readOnly: true,
                  onTap: _selectDate,
                ),
              ],
            ),
    );
  }
}