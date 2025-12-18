# VS Code Dev Container Configuration

このディレクトリのファイルは `./create-devcontainer-config.sh` によって生成され、`start-container.sh` と同じ環境変数を `.devcontainer/.env` に書き出します。VS Code は起動前に `.devcontainer/sync-env.sh` を実行し、同じ値をリポジトリ直下の `.env` にコピーしてから `docker compose` を実行します。

## 生成された設定

- GPU: intel
- VNC Type: kasm
- Display Server: Xvfb
- Resolution: 1920x1080@60Hz
- HTTPS (Web UI): https://localhost:11000
- Kasm WebSocket: 6900
- Kasm kclient: 3000
- Kasm Audio Relay: 4900
- Kasm nginx: 12000
- TURN Server: disabled

## VS Code での利用手順
1. Dev Containers 拡張機能をインストールする
2. ワークスペースを開き、`F1` → `Dev Containers: Reopen in Container` を実行
3. VS Code が `.devcontainer/.env` を同期してから `docker compose` を起動

## 再設定
設定を変更したい場合はリポジトリルートで `./create-devcontainer-config.sh` を再実行し、案内に従ってください。スクリプト完了後に VS Code 側で「Rebuild Container」を選択すると新しい設定が反映されます。
