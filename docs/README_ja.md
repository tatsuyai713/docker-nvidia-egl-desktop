# ドキュメント概要

このフォルダーにはプロジェクトで参照する各種ガイドをまとめています。目的に合ったワークフロー別ドキュメントをここから選択してください。

## 利用可能なガイド

- VS Code Dev Container ガイド:
  - [English](vscode-devcontainer-usage.md)
  - [日本語](vscode-devcontainer-usage_ja.md)
  `.devcontainer` 設定の生成方法、VS Code からの起動手順、ポート転送のトラブルシュート、再ビルド方法などを段階的に説明しています。

- Docker Compose 利用ガイド:
  - [English](docker-compose-usage.md)
  - [日本語](docker-compose-usage_ja.md)
  CLI 前提の手順書で、`.env` の生成、Selkies/KasmVNC/noVNC の切り替え、GPU 設定、起動・停止方法、および Compose 実行時によくある問題の解決策をまとめています。

## ドキュメント運用ルール

- 英語版は `README.md`、日本語版は `_ja` 接尾辞付きのファイルに配置します。
- コマンド例はそのままコピーして実行できる形で記載してください。
- 手順を更新した場合は、英語・日本語の両方のドキュメントを忘れずに同期してください。

プロジェクト全体の概要はリポジトリ直下の `README.md` / `README_ja.md` を参照してください。
