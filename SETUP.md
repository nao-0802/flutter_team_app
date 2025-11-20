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

2. local.propertiesを設定
```bash
cp android/local.properties.template android/local.properties
```
`android/local.properties`を開いて、自分の環境に合わせてパスを修正してください。

3. 依存関係を取得
```bash
flutter pub get
```

4. アプリを実行
```bash
flutter run
```

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