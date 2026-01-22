import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _alarmNotificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _alarmNotificationsEnabled =
          prefs.getBool('alarm_notifications_enabled') ?? true;
    });
  }

  Future<void> _toggleNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alarm_notifications_enabled', value);
    setState(() {
      _alarmNotificationsEnabled = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('通知設定')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('アラーム通知'),
            subtitle: const Text('アラームの通知を受け取る'),
            value: _alarmNotificationsEnabled,
            onChanged: _toggleNotification,
          ),
          if (!_alarmNotificationsEnabled)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '通知がオフになっています。',
                style: TextStyle(color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }
}
