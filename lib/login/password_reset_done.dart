import 'package:flutter/material.dart';

class PasswordResetDonePage extends StatelessWidget {
  const PasswordResetDonePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('パスワード再設定メールを送信しました。', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: const Text('ログイン画面に戻る'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
