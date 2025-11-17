import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'signup_done.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
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

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Firebase Authentication にユーザー作成
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Firestore にプロフィール登録
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'birthday': _birthdayController.text.trim(),
        'profileIcon': _selectedIcon.codePoint,
        'profileColor': _selectedColor.value,
        'createdAt': Timestamp.now(),
      });

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SignUpDonePage()),
      );
    } on FirebaseAuthException catch (e) {
      String message = '登録に失敗しました。';
      if (e.code == 'email-already-in-use') {
        message = 'このメールアドレスは既に登録されています。';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新規登録')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: _selectedColor,
                  child: Icon(_selectedIcon, size: 40, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
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
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '名前'),
                validator: (v) => v!.isEmpty ? '名前を入力してください' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'メールアドレス'),
                validator: (v) => v!.contains('@') ? null : '有効なメールを入力してください',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'パスワード'),
                obscureText: true,
                validator: (v) => v!.length < 6 ? '6文字以上で入力してください' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _birthdayController,
                decoration: const InputDecoration(
                  labelText: '誕生日（任意）',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: _selectDate,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _signUp,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('登録'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
