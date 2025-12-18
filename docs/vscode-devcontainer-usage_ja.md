# VS Code Dev Container ガイド

このドキュメントは Dev Container 設定の生成方法、VS Code からワークスペースを開く手順、および本リポジトリでデスクトップ Web UI を利用するときのトラブルシュートをまとめたものです。

## 前提条件

- VS Code と **Dev Containers** 拡張機能
- ホストに Docker + Docker Compose がインストール済み
- `./build-user-image.sh` でユーザー専用イメージをビルド済み

## セットアップ手順

### 1. Dev Container 設定を生成

対話スクリプトを実行します。

```bash
./create-devcontainer-config.sh
```

このスクリプトは `compose-env.sh`（`start-container.sh` と同じロジック）を呼び出して `.devcontainer/.env` を生成します。VS Code は起動前に `.devcontainer/sync-env.sh` を実行し、この `.env` をワークスペース直下へコピーしてから `docker compose` を実行するため、CLI から起動しても Dev Container から起動しても同じ設定になります。

設定時に尋ねられる内容：

1. **GPU モード** – なし / NVIDIA / Intel / AMD
2. **VNC タイプ** – Selkies (WebRTC) / KasmVNC / noVNC
3. **TURN サーバー** – Selkies の遠隔利用が必要な場合のみ有効化
4. **ディスプレイサーバー** – Xorg か Xvfb
5. **ディスプレイ設定** – 解像度とリフレッシュレート

生成されるファイル（`.devcontainer/` 配下）：

- `devcontainer.json`：VS Code 用メタデータ
- `docker-compose.override.yml`：ワークスペースマウントのオーバーライド
- `.env`：スクリプトが算出した環境変数
- `README.md`：選択内容のサマリ

### 2. リポジトリをコンテナで開く

1. VS Code でフォルダを開く
2. `F1` → 「Dev Containers: Reopen in Container」（またはステータスバーの `><` アイコン）
3. コンテナのビルド・接続後、initialize/postCreate フックが実行される

### 3. リモートデスクトップへアクセス

- Web UI は `https://localhost:(10000 + UID)`（UID 1000 → 11000）で公開されます。
- `devcontainer.json` で宣言したポートは自動転送されます。VS Code の **ポート** パネルで 11000 を確認し、「ブラウザーで開く」をクリックしてトンネルを作成してください。
- `sudo ./install-ca-cert.sh` を実行して生成済み CA を信頼ストアに登録すると、HTTPS 警告を抑止できます（Web UI を開く各マシンで実施）。

## コンテナ内での作業

- **ターミナル**：VS Code で開くターミナルはすべてコンテナ内で実行され、ワーキングディレクトリは `/home/<user>/workspace` です。
- **拡張機能**：`devcontainer.json -> customizations.vscode.extensions` に列挙された拡張機能が自動でインストールされます。
- **ファイル同期**：リポジトリはバインドマウントされているため、ホストとコンテナの変更は常に同期されます。

## よくある問題

| 症状 | 対処 |
| --- | --- |
| 11000 番の Web UI が開かない | Dev Container を再ビルドして `.devcontainer/sync-env.sh` に `.env` を再コピーさせ、`PULSE_SERVER=unix:/tmp/runtime-<user>/pulse/native` になっているか確認し、ポート 11000 が転送されていることを確かめる。 |
| GPU が認識されない | `./create-devcontainer-config.sh` を再実行して GPU 設定を選び直し、再ビルド後にホストユーザーが `video` / `render` グループに所属しているか確認する。 |
| 環境変数の変更が反映されない | `.devcontainer/.env` を編集したら「Dev Containers: Rebuild Container」を実行し、新しい値を同期させる。 |

## Dev Container をリセットしたい場合

Dev Container は既存コンテナを再利用します。完全に作り直すには：

1. `F1` → 「Dev Containers: Rebuild and Reopen in Container」
2. もしくは Docker CLI / Desktop で既存コンテナを削除してから「Dev Containers: Reopen in Container」を実行

CLI のみで運用する場合は `docs/docker-compose-usage.md` を参照してください。
