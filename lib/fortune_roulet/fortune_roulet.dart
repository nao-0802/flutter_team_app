import 'package:flutter/material.dart';
import 'fortune.dart';
import 'roulet.dart';

class FortuneRouletPage extends StatefulWidget {
  const FortuneRouletPage({super.key});

  @override
  State<FortuneRouletPage> createState() => _FortuneRouletPageState();
}

class _FortuneRouletPageState extends State<FortuneRouletPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: const Text('占いルーレット'),
        ),
        body: Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                    FilledButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FortunePage())), 
                        child: const Text("占いを引く")
                    ),
                    FilledButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RouletPage())), 
                        child: const Text("ルーレットを回す")
                    )
                ],
            ),
        )
    );
  }
}