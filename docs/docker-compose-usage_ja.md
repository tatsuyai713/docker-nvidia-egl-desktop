# Docker Compose 利用ガイド

このガイドは `start-container.sh` の処理を素の `docker compose` コマンドで再現する方法を説明します。ヘルパーの `compose-env.sh` は同じ環境変数を計算して `.env` に書き出すため、Selkies / KasmVNC / noVNC いずれのモードでも CLI・VS Code・提供スクリプト間で挙動を揃えられます。

## 前提条件

- Docker + Docker Compose がインストール済み
- `./build-user-image.sh` でユーザー用イメージをビルド済み

## デフォルト構成を再現する

1. `start-container.sh` と同じ引数を使って環境変数を生成します。
2. そのままカレントシェルに適用するか `.env` に保存し、リポジトリ直下で `docker compose -f docker-compose.user.yml up -d` を実行します。

> `.env` が存在する場合、Docker Compose が自動で読み込むため `--env-file` は不要です。

## 基本ワークフロー

### 1. 環境変数を生成

```bash
# 例1: 現在のシェルに export
source <(./compose-env.sh --gpu nvidia --all --vnc-type selkies)

# 例2: .env に保存
./compose-env.sh --gpu intel --vnc-type kasm --env-file .env
```

### 2. スタックを起動

```bash
# バックグラウンド起動
docker compose -f docker-compose.user.yml up -d

# ログを見ながら起動
docker compose -f docker-compose.user.yml up
```

### 3. 停止・クリーンアップ

```bash
# サービス停止
docker compose -f docker-compose.user.yml stop

# コンテナ削除（ボリュームは残す）
docker compose -f docker-compose.user.yml down
```

## GPU / VNC モードを選ぶ

ヘルパーを使って必要な組み合わせを生成します。

```bash
# NVIDIA + Selkies
./compose-env.sh --gpu nvidia --all --vnc-type selkies --env-file .env

# Intel + KasmVNC
./compose-env.sh --gpu intel --vnc-type kasm --env-file .env

# ソフトウェアレンダリング + noVNC
./compose-env.sh --gpu none --vnc-type novnc --env-file .env
```

ホスト側ポート一覧：

- Web UI: `10000 + UID`（例: UID 1000 → 11000）
- Selkies TURN: `13000 + UID`
- Selkies UDP 範囲: `40000 + (UID-1000)*200` 〜 `+100`
- KasmVNC 追加ポート: WebSocket 6900+, kclient 3000+, audio 4900+, nginx 12000+（`UID % 1000` を加算）

## トラブルシューティング

- **KasmVNC の 11000 番にアクセスできない**: `--vnc-type kasm` で `.env` を再生成し、`docker compose down && docker compose up -d` を実行。コンテナ内で `PULSE_SERVER=unix:/tmp/runtime-<user>/pulse/native` になっているか確認する。
- **環境変数が反映されない**: `.env` と同じディレクトリで `docker compose` を実行するか、起動前に再度 `compose-env.sh` を読み込む。
- **コンテナが起動しない**: ユーザーイメージが存在するか確認（`docker images | grep devcontainer-ubuntu-egl-desktop-$(whoami)`）。無ければ `./build-user-image.sh` で再ビルドする。

VS Code 専用の手順は `docs/vscode-devcontainer-usage.md` を参照してください。
