import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'menu_list.dart';

class RouletPage extends StatefulWidget {
  const RouletPage({super.key});

  @override
  State<RouletPage> createState() => _RouletPageState();
}

class _RouletPageState extends State<RouletPage> {
  List<Map<String, String>> _menus = [];
  Map<String, String>? _result;

  @override
  void initState() {
    super.initState();
    _loadMenus();
  }

  Future<void> _loadMenus() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('menus') ?? [];

    setState(() {
      _menus = list.map((e) {
        final parts = e.split('|');
        return {
          'name': parts[0],
          'imagePath': parts[1],
        };
      }).toList();
    });
  }

  void _drawRoulette() {
    if (_menus.isEmpty) return;
    final random = Random();
    setState(() {
      _result = _menus[random.nextInt(_menus.length)];
    });
  }

  Future<void> _openMenuList() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MenuListPage(menus: _menus),
      ),
    );
    _loadMenus(); // 戻ったら再読込
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('献立ルーレット'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _openMenuList,
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: _result == null
                ? FilledButton(
                    onPressed: _drawRoulette,
                    child: const Text('ルーレットを回す'),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.file(
                        File(_result!['imagePath']!),
                        width: 250,
                        height: 250,
                        fit: BoxFit.cover,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _result!['name']!,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ],
                  ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('戻る'),
            ),
          ),
        ],
      ),
    );
  }
}
