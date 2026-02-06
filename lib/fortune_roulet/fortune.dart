import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FortunePage extends StatefulWidget {
  const FortunePage({super.key});

  @override
  State<FortunePage> createState() => _FortunePageState();
}

class _FortunePageState extends State<FortunePage> {
    String? _fortune;
    String? _luckeyItem;

    @override
    void initState() {
        super.initState();
        _loadFortune();
    }

    Future<void> _loadFortune() async {
        final prefs = await SharedPreferences.getInstance();
        final savedDate = prefs.getString('fortune_date');
        final savedFortune = prefs.getString('fortune_text');
        final savedLuckeyItem = prefs.getString('luckey_text');

        final today = DateTime.now().toIso8601String().substring(0, 10);

        if (savedDate == today && savedFortune != null) {
            setState(() {
                _fortune = savedFortune;
                _luckeyItem = savedLuckeyItem;
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

        final luckeyItems = [
            "赤いペン",
            "青いハンカチ",
            "星柄のアクセサリー",
            "小さな鏡",
            "新品のノート",
            "白いスニーカー",
            "ゴールドのリング",
            "木製のキーホルダー",
            "香り付き消しゴム",
            "四つ葉モチーフ",
            "腕時計",
            "シンプルなトートバッグ",
            "ミントガム",
            "レモン味のキャンディ",
            "お気に入りのマグカップ",
            "パステルカラーのペン",
            "小銭入れ",
            "新しい靴下",
            "ハート柄アイテム",
            "スマホストラップ",
            "クリアファイル",
            "日記帳",
            "ヘアゴム",
            "リップクリーム",
            "お守り",
            "鍵付きのポーチ",
            "イヤホン",
            "シルバーアクセサリー",
            "花柄の小物",
            "メモ帳",
            "香水（少量）",
            "ミニタオル",
            "ペンケース",
            "キャンバストート",
            "マスキングテープ",
            "お気に入りのボールペン",
            "サングラス",
            "折りたたみ傘",
            "星形チャーム",
            "新しい下着",
            "スマホケース",
            "カーディガン",
            "キーホルダー付き鍵",
            "マグネット",
            "ブレスレット",
            "しおり",
            "小さなぬいぐるみ",
            "ハンドクリーム",
            "革小物",
            "エコバッグ",
            "チョコレート",
            "フルーツキャンディ",
            "ノートパソコン",
            "ペンライト",
            "シンプルな指輪",
            "スカーフ",
            "ミニポーチ",
            "ボディミスト",
            "新しいマスク",
            "カラフルな靴ひも",
            "ハート型シール",
            "星座モチーフ",
            "目覚まし時計",
            "ブックカバー",
            "小さな観葉植物",
            "コインケース",
            "チェック柄アイテム",
            "水筒",
            "手帳",
            "新品の付箋",
            "革のブレスレット",
            "シンプルなネックレス",
            "ハンドタオル",
            "お気に入りの写真",
            "ペンダント",
            "スマートウォッチ",
            "ノイズキャンセリングイヤホン",
            "小さなチャーム",
            "カラーインクペン",
            "ポストカード",
            "ミニミラー",
            "新しい歯ブラシ",
            "香り付きキャンドル",
            "シンプルな帽子",
            "カフェのポイントカード",
            "レザーキーケース",
            "スタンプ",
            "お気に入りの本",
            "シンプルなバックパック",
            "マグネットクリップ",
            "ガラス製ペン",
            "星のピンバッジ",
            "小さな巾着",
            "キャンドル型ライト",
            "新しいボール",
            "カラフルなペン立て"
            "ハート型アクセ",
            "フレーム付き写真",
            "小さな鈴",
            "今日初めて使うアイテム",
        ];

        final result = fourtunes[DateTime.now().millisecondsSinceEpoch % fourtunes.length];
        final luckeyResult = luckeyItems[DateTime.now().millisecondsSinceEpoch % luckeyItems.length];
        final today = DateTime.now().toIso8601String().substring(0, 10);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fortune_date', today);
        await prefs.setString('fortune_text', result);
        await prefs.setString('luckey_text',luckeyResult);

        setState(() {
          _fortune = result;
          _luckeyItem = luckeyResult;
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
                                '今日の運勢は\n$_fortune\n$_luckeyItem',
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

