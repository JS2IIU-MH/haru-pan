# Android 実機テスト手順（簡潔）

## 前提
- Android SDK とデバイス（またはエミュレータ）が接続されていること
- USB デバッグが有効な実機、または動作可能なエミュレータ
- `flutter` のセットアップが完了していること（`flutter doctor` を通過）

## 必須設定

1. 依存取得

```bash
flutter pub get
```

2. Android マニフェストにパーミッションを追加（`android/app/src/main/AndroidManifest.xml`）

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

3. リポジトリ確認（通常は不要）
- `android/build.gradle` の `repositories` に `google()` と `mavenCentral()` が含まれていることを確認してください。

4. 実行権限（デバッグ中にADBで付与する場合）

```bash
adb devices
adb shell pm grant <your.package.name> android.permission.CAMERA
```

## 実機での手順

1. アプリをインストールして起動

```bash
flutter run -d <device-id>
```

2. `ScanPage` を開いてカメラプレビューで撮影し、結果画面で合計を確認します。

3. 評価用CSVの出力（`EvaluatorPage` を利用）
- `EvaluatorPage` で「評価を実行」を押すと、評価結果がアプリのドキュメントディレクトリに `eval_results.csv` として出力されます。

## CSV を端末から取得する方法

- 通常のアプリのドキュメントは `/data/user/0/<package>/files/` に生成されます。
- デバッグビルドであれば `run-as` を使ってファイルを取り出せます。

```bash
adb exec-out run-as <your.package.name> cat files/eval_results.csv > eval_results.csv
```

## 注意点とトラブルシューティング
- カメラが利用できない／初期化に失敗する場合: Android のカメラ権限と `minSdkVersion` を確認してください。
- ML Kit の OCR で例外が出る場合: `flutter pub get` を再実行し、Gradle の同期（`flutter clean` → `flutter pub get`）を試してください。
- 実機で動作確認する際は、`logcat` を併用してエラーを確認してください。

## 推奨コマンド一覧

```bash
flutter pub get
flutter run -d <device-id>
flutter build apk --release
adb exec-out run-as <your.package.name> cat files/eval_results.csv > eval_results.csv
```

---
追加の自動テストやCI連携を作る場合はご相談ください。
