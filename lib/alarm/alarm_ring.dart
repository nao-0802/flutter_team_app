import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class AlarmRingPage extends StatefulWidget {
  final String sound;

  const AlarmRingPage({
    super.key,
    required this.sound,
  });

  @override
  State<AlarmRingPage> createState() => _AlarmRingPageState();
}

class _AlarmRingPageState extends State<AlarmRingPage> {
  late AudioPlayer player;

  @override
  void initState() {
    super.initState();
    player = AudioPlayer();
    player.play(AssetSource("sounds/${widget.sound}"));
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.alarm, size: 120, color: Colors.red),
            const SizedBox(height: 20),
            const Text(
              "アラーム！",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                player.stop();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text("止める"),
            ),
          ],
        ),
      ),
    );
  }
}
