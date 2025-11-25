import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'route_add.dart';

class RouteListPage extends StatefulWidget {
  const RouteListPage({super.key});

  @override
  State<RouteListPage> createState() => _RouteListPageState();
}

class _RouteListPageState extends State<RouteListPage> {
  Map<String, Map<String, dynamic>> _operationStatus = {};
  bool _isLoadingStatus = false;

  @override
  void initState() {
    super.initState();
    // 画面表示時に運行状況を自動取得
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshOperationStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("路線情報"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshOperationStatus,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RouteAddPage()),
              );
              setState(() {});
            },
          ),
        ],
      ),
      body: _routeList(),
    );
  }

  Widget _routeList() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text("ログインが必要です"));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('user_routes')
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.train, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text("登録された路線がありません"),
                Text("右上の+ボタンから路線を追加してください"),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            final routeCode = data['routeCode'] ?? '';
            final status = _operationStatus[routeCode];
            
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: Icon(
                  Icons.train,
                  color: _getStatusColor(status?['status']),
                ),
                title: Text(data['routeName'] ?? ''),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('路線コード: $routeCode'),
                    if (status != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '運行状況: ${_getStatusText(status['status'])}',
                            style: TextStyle(
                              color: _getStatusColor(status['status']),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            status['information'] ?? '',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      )
                    else if (_isLoadingStatus)
                      const Text('運行状況を取得中...')
                    else
                      const Text('運行状況: 未取得'),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteRoute(doc.id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _refreshOperationStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _isLoadingStatus = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('user_routes')
          .where('userId', isEqualTo: uid)
          .get();

      final Map<String, Map<String, dynamic>> statusMap = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final routeCode = data['routeCode'] as String?;
        if (routeCode != null && routeCode.isNotEmpty) {
          final status = await _getOperationStatus(routeCode);
          if (status != null) {
            statusMap[routeCode] = status;
          }
        }
      }

      setState(() {
        _operationStatus = statusMap;
        _isLoadingStatus = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingStatus = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('運行状況の取得に失敗しました')),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _getOperationStatus(String routeCode) async {
    try {
      // 登録路線の運行路線コードを取得
      final operationLineCode = await _getOperationLineCode(routeCode);
      if (operationLineCode == null) {
        return {
          'status': 'unknown',
          'information': 'この路線は運行情報の取得に対応していません',
        };
      }
      
      // 特定路線の運行情報を取得
      final url = 'http://api.ekispert.jp/v1/json/operationLine/service/rescuenow/information?key=test_z3CW8YscwmD&operationLineCode=$operationLineCode';
      print('Requesting operation info for line code $operationLineCode: $url');
      
      final response = await http.get(Uri.parse(url));
      
      print('Operation info response code: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Informationの型を安全にチェック
        if (data['ResultSet']['Information'] != null) {
          final info = data['ResultSet']['Information'];
          if (info is List) {
            print('Operation info found: ${info.length} items');
            for (var item in info) {
              print('- ${item['Line']['Name']}: ${item['status']} (${item['Datetime']})');
            }
          } else if (info is Map) {
            print('Operation info found: 1 item');
            print('- ${info['Line']['Name']}: ${info['status']} (${info['Datetime']})');
          } else {
            print('Operation info found: unknown format');
          }
        } else {
          print('Operation info found: 0 items');
        }
      } else {
        print('Operation info response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['ResultSet'] != null && data['ResultSet']['Information'] != null) {
          final informationList = data['ResultSet']['Information'];
          List<dynamic> infoArray;
          
          // Informationが配列かオブジェクトかを判定
          if (informationList is List) {
            infoArray = informationList;
          } else if (informationList is Map) {
            infoArray = [informationList];
          } else {
            print('Unexpected Information format: ${informationList.runtimeType}');
            infoArray = [];
          }
          
          print('Processing ${infoArray.length} information items');
          
          print('Looking for route code: $routeCode');
          
          try {
            for (var info in infoArray) {
              // 情報の日付をチェック（古い情報を除外）
              if (!_isRecentInformation(info['Datetime'])) {
                print('Skipping old information: ${info['Datetime']}');
                continue;
              }
              
              if (info['Line'] != null) {
                final lineName = info['Line']['Name'] ?? '';
                final lineCode = info['Line']['code'] ?? '';
                print('Checking API route: $lineName (code: $lineCode)');
                
                // 運行路線コードで完全一致チェック
                if (lineCode == operationLineCode) {
                  print('Route match found! Code: $lineCode');
                  final status = info['status'] ?? '正常運行';
                  final comment = _getCommentText(info['Comment']);
                  
                  return {
                    'status': _convertStatusToCode(status),
                    'information': comment.isNotEmpty ? comment : status,
                  };
                }
              }
            }
          } catch (e) {
            print('Error processing information array: $e');
            print('Information data type: ${infoArray.runtimeType}');
            print('Information content: $infoArray');
          }
          
          print('No matching route found for code: $routeCode');
        }
        
        // APIから情報が取得できたが、該当路線の運行情報がない
        print('API response received but no operation issues found for line code $operationLineCode');
        return {
          'status': 'normal',
          'information': '現在、運行情報はありません（正常運行の可能性）',
        };
      } else {
        print('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting operation status: $e');
    }
    
    // エラー時は取得失敗として返す
    return {
      'status': 'unknown',
      'information': '運行情報の取得に失敗しました',
    };
  }



  bool _isRouteMatch(String registeredRoute, String apiRoute) {
    if (registeredRoute.isEmpty || apiRoute.isEmpty) return false;
    
    // 部分一致でチェック（例：「山手線」と「ＪＲ山手線」）
    return apiRoute.contains(registeredRoute) || registeredRoute.contains(apiRoute);
  }

  String _getCommentText(dynamic comment) {
    if (comment == null) return '';
    
    if (comment is List && comment.isNotEmpty) {
      // shortコメントを優先
      for (var c in comment) {
        if (c['status'] == 'short' && c['text'] != null) {
          return c['text'];
        }
      }
      // shortがない場合は最初のコメント
      if (comment.first['text'] != null) {
        return comment.first['text'];
      }
    }
    
    return '';
  }

  Future<String?> _getOperationLineCode(String routeCode) async {
    // 登録時の運行路線コードをそのまま使用
    print('Using route code directly as operation line code: $routeCode');
    return routeCode;
  }

  bool _isRecentInformation(String? datetime) {
    if (datetime == null) return true;
    
    try {
      final infoDate = DateTime.parse(datetime);
      final now = DateTime.now();
      final daysDiff = now.difference(infoDate).inDays;
      
      // 30日以内の情報のみ有効とする
      return daysDiff <= 30;
    } catch (e) {
      print('Error parsing datetime: $datetime');
      return true; // パースエラーの場合は有効とする
    }
  }

  String _convertStatusToCode(String status) {
    if (status.contains('遅延')) return 'delay';
    if (status.contains('運転見合わせ') || status.contains('中止')) return 'suspend';
    return 'normal';
  }

  String _determineStatusFromInfo(String infoText) {
    final lowerText = infoText.toLowerCase();
    if (lowerText.contains('遅延') || lowerText.contains('遅れ')) {
      return 'delay';
    } else if (lowerText.contains('運転見合わせ') || lowerText.contains('中止') || lowerText.contains('停止')) {
      return 'suspend';
    } else if (lowerText.contains('正常') || lowerText.contains('平常')) {
      return 'normal';
    } else {
      return 'normal'; // デフォルトは正常運行
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'normal':
        return Colors.green;
      case 'delay':
        return Colors.orange;
      case 'suspend':
        return Colors.red;
      case 'unknown':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'normal':
        return '正常運行';
      case 'delay':
        return '遅延';
      case 'suspend':
        return '運転見合わせ';
      case 'unknown':
        return '情報取得不可';
      default:
        return '不明';
    }
  }

  void _deleteRoute(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("削除確認"),
        content: const Text("この路線を削除しますか？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("キャンセル"),
          ),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('user_routes')
                  .doc(docId)
                  .delete();
              Navigator.pop(context);
            },
            child: const Text("削除"),
          ),
        ],
      ),
    );
  }
}