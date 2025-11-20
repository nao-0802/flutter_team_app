# 環境セットアップ手順

## 必要な環境
- Flutter SDK 3.0以上
- Android SDK 35
- Java 17

## 初回セットアップ

1. プロジェクトをクローン
```bash
git clone https://github.com/nao-0802/flutter_team_app.git
cd flutter_team_app
```

2. 依存関係を取得
```bash
flutter pub get
```

3. アプリを実行
```bash
flutter run
```

## 注意事項
- `android/local.properties`はデフォルト設定でコミット済み
- 個別の環境設定が必要な場合のみ、パスを調整してください

## トラブルシューティング

### Android SDK関連エラーが出る場合
```bash
flutter clean
cd android
./gradlew clean
cd ..
flutter pub get
```

### VS Code Java拡張機能でエラーが出る場合
Java拡張機能を無効化してください（Flutter開発には不要）