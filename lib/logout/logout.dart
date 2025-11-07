import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'logout_done.dart';
import '../alarm/alarm_list.dart';

class LogoutPage extends StatelessWidget {
  const LogoutPage({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LogoutDonePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ログアウト確認')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('ログアウトしますか？', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => _logout(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('はい'),
                ),
                const SizedBox(width: 40),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AlarmListPage()),
                    );
                  },
                  child: const Text('いいえ'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
