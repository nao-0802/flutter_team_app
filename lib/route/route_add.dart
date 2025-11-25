import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RouteAddPage extends StatefulWidget {
  const RouteAddPage({super.key});

  @override
  State<RouteAddPage> createState() => _RouteAddPageState();
}

class _RouteAddPageState extends State<RouteAddPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("路線を追加"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: "路線名を入力",
                hintText: "例: 山手線、東海道線",
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _searchRoutes,
                ),
              ),
              onSubmitted: (_) => _searchRoutes(),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final route = _searchResults[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.train),
                        title: Text(route['name'] ?? ''),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('会社: ${route['corporation'] ?? ''}'),
                            Text('コード: ${route['code'] ?? ''}'),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => _addRoute(route),
                          child: const Text("追加"),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _searchRoutes() async {
    if (_searchController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _searchResults = [];
    });

    try {
      final searchTerm = _searchController.text.trim();
      final url = 'http://api.ekispert.jp/v1/json/operationLine?key=test_z3CW8YscwmD&name=${Uri.encodeComponent(searchTerm)}&nameMatchType=partial&serviceInformationProvider=rescuenow&limit=50';
      
      print('Searching routes: $url');
      
      final response = await http.get(Uri.parse(url));
      
      print('Route search response code: ${response.statusCode}');
      print('Route search response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = <Map<String, dynamic>>[];
        
        if (data['ResultSet'] != null) {
          final corporations = data['ResultSet']['Corporation'] ?? [];
          final lines = data['ResultSet']['Line'] ?? [];
          
          // Corporation情報をマップ化
          final corpMap = <String, String>{};
          if (corporations is List) {
            for (var corp in corporations) {
              corpMap[corp['code']] = corp['Name'] ?? '';
            }
          }
          
          // Line情報を処理
          final lineList = lines is List ? lines : [lines];
          for (var line in lineList) {
            final corpIndex = line['corporationIndex'];
            final corpCode = _findCorporationCode(corporations, corpIndex);
            final corpName = corpMap[corpCode] ?? '';
            
            routes.add({
              'name': line['Name'] ?? '',
              'code': line['code'] ?? '',
              'corporation': corpName,
              'color': line['Color'],
            });
          }
        }

        setState(() {
          _searchResults = routes;
        });
        
        if (_searchResults.isEmpty) {
          _showError('該当する路線が見つかりませんでした');
        }
      } else {
        _showError('検索に失敗しました (${response.statusCode})');
      }
    } catch (e) {
      print('Error: $e');
      _showError('ネットワークエラーが発生しました: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _findCorporationCode(dynamic corporations, String? corpIndex) {
    if (corporations == null || corpIndex == null) return '';
    
    final corpList = corporations is List ? corporations : [corporations];
    for (var corp in corpList) {
      if (corp['index'] == corpIndex) {
        return corp['code'] ?? '';
      }
    }
    return '';
  }



  Future<void> _addRoute(Map<String, dynamic> route) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance.collection('user_routes').add({
        'userId': uid,
        'routeName': route['name'],
        'routeCode': route['code'],
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('路線を追加しました')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('追加に失敗しました');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}