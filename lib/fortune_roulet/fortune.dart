import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FortunePage extends StatefulWidget {
  const FortunePage({super.key});

  @override
  State<FortunePage> createState() => _FortunePageState();
}

class _FortunePageState extends State<FortunePage> {
    String? _fortune;

    @override
    void initState() {
        super.initState();
        _loadFortune();
    }

    Future<void> _loadFortune() async {
        final prefs = await SharedPreferences.getInstance();
        final savedDate = prefs.getString('fortune_date');
        final savedFortune = prefs.getString('fortune_text');

        final today = DateTime.now().toIso8601String().substring(0, 10);

        if (savedDate == today && savedFortune != null) {
            setState(() {
                _fortune = savedFortune;
            });
        }
    }

    Future<void> _drawFortune() async {
        final fourtunes = [
            '絶好調',
            '好調',
            '普通',
            '注意',
            '不調',
        ];

        final result = fourtunes[DateTime.now().millisecondsSinceEpoch % fourtunes.length];
        final today = DateTime.now().toIso8601String().substring(0, 10);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fortune_date', today);
        await prefs.setString('fortune_text', result);

        setState(() {
          _fortune = result;
        });
    }

    @override
    Widget build(BuildContext context) {
        return Scaffold(
            appBar: AppBar(
                title: const Text('占い'),
            ),
            body: Stack(
                children: [
                    Center(
                        child: _fortune == null
                            ? FilledButton(
                                onPressed: _drawFortune, 
                                child: const Text("占いを引く")
                                )
                            : Text(
                                '今日の運勢は\n$_fortune',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 24),
                            ),
                    ),

                    Positioned(
                        right: 16,
                        bottom: 16,
                        child: FilledButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('戻る'),
                        ),
                    )
                ],
            ),
        );
    }
}

