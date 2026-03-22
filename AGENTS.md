# AGENTS.md

## Workspace rules
- このリポジトリでは、すべての Flutter コマンドを `pubspec.yaml` があるプロジェクトルートで実行すること。
- `flutter.bat` の絶対パスや SDK 内バイナリを直接指定して実行しないこと。
- まず現在の作業ディレクトリに `pubspec.yaml` が存在することを確認してから実行すること。
- Flutter 実行は PATH 上の `flutter` コマンドを使うこと。

## Standard commands
- 依存取得: `flutter pub get`
- 解析: `flutter analyze`
- テスト: `flutter test`

## Before running commands
1. 現在の作業ディレクトリを表示する
2. `pubspec.yaml` の存在を確認する
3. その後に Flutter コマンドを実行する