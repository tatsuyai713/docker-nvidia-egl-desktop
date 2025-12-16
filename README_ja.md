# docker-selkies-egl-desktop

## Devcontainer 向けクイックスタート

ローカル開発環境（Devcontainerスタイル）で数分以内に利用できます。  
元の Selkies EGL Desktop は Kubernetes クラスター向けのマルチテナント配信を想定していますが、このフォークは開発者が手元で扱いやすいように再パッケージしたものです。

```bash
# 1)（任意）事前ビルド済みベースイメージをプル
docker pull ghcr.io/tatsuyai713/devcontainer-ubuntu-egl-desktop-base:24.04

# 2) ユーザーイメージをビルド（英語）
./build-user-image.sh

# 2b) 日本語環境をビルド
./build-user-image.sh JP

# 3) コンテナ起動（Selkies、ソフトウェアレンダリング）
./start-container.sh

# 4) NVIDIA GPUで起動（Selkies）
./start-container.sh --gpu nvidia --all

# 5) KasmVNCで起動（NVIDIA、クリップボード対応）
./start-container.sh --gpu nvidia --all --vnc-type kasm

# 6) noVNCで起動（NVIDIA、クリップボード対応）
./start-container.sh --gpu nvidia --all --vnc-type novnc

# 7) noVNCを短縮オプションで起動（Intel）
./start-container.sh --gpu intel -v novnc

# 8) Xorgで起動（Intel、Vulkan対応）
./start-container.sh --gpu intel --xorg

# 9) ブラウザで開く（例：UID 1000 の場合）
# http://localhost:11000  （HTTPS有効時は https://localhost:11000）
```

本来の Selkies EGL Desktop は Kubernetes を前提としたリモートデスクトップ基盤（GPUスケジューリングやマルチユーザー）です。  
本フォークは *ローカル開発用途* に絞り、Devcontainer と同じ感覚で Selkies/KasmVNC デスクトップを立ち上げられるようにツール類やドキュメントを再構成しています。

---

## 🚀 このフォークの主な改善点

このリポジトリは Devcontainer 利用を主目的に最適化したフォークです。上流のストリーミング基盤は維持しつつ、手元マシンで素早く KDE デスクトップを起動できるよう UID/GID 自動一致、対話的パスワード入力、多言語ドキュメントなどを揃えています：

### アーキテクチャの改善

- **🏗️ 2段階ビルドシステム:** ベースイメージ（5-10 GB、事前ビルド済み）とユーザーイメージ（~100 MB、1-2分でビルド）に分割
  - ベースイメージにすべてのシステムパッケージとデスクトップ環境を含む
  - ユーザーイメージはUID/GIDが一致する特定のユーザーを追加
  - もう30〜60分のビルド時間は不要！

- **🔒 非rootコンテナ実行:** デフォルトでコンテナはユーザー権限で実行
  - すべての `fakeroot` ハックと権限昇格の回避策を削除
  - システムとユーザー操作の適切な権限分離
  - 特定の操作に必要な場合はsudoアクセス可能

- **📁 自動UID/GID一致:** ファイル権限がシームレスに機能
  - ユーザーイメージは自動的にホストのUID/GIDに一致
  - マウントされたホストディレクトリの所有権が正しい
  - 共有フォルダで「permission denied」エラーが発生しない

### ユーザーエクスペリエンスの向上

- **🔐 安全なパスワード管理:** ビルド時のインタラクティブなパスワード入力
  - 隠されたパスワード入力（コマンドにプレーンテキストなし）
  - タイプミスを防ぐための確認プロンプト
  - パスワードはイメージに安全に保存される

- **💻 Ubuntu Desktop標準環境:** 完全な`.bashrc`設定
  - Gitブランチ検出付きのカラープロンプト
  - 履歴の最適化（ignoredups、追記モード、タイムスタンプ）
  - 便利なエイリアス（ll、la、grepカラーなど）
  - Ubuntu Desktopターミナル体験と完全一致

- **🎮 柔軟なGPU選択:** わかりやすさのための必須コマンド引数
  - `all` - 使用可能なすべてのGPUを使用
  - `none` - ソフトウェアレンダリング（GPU不使用）
  - `0,1` - 特定のGPUデバイス
  - 誤ったGPU割り当てを防止

- **🖥️ トリプルディスプレイモード:** ストリーミングプロトコルを選択
  - **Selkies GStreamer（デフォルト）:** WebRTCで低遅延、音声/映像ストリーミング内蔵、ゲームに適している
  - **KasmVNC:** kclient音声サポート付きWebSocket経由VNC、互換性が高い、GPUなしで動作、クリップボードと双方向音声（スピーカー/マイク）対応
  - **noVNC:** ホスト音声パススルー付き基本VNC（ホストPulseAudio経由の音声出力のみ）、クリップボード対応
  - `--vnc-type`または`-v`引数で切り替え

- **🖥️ 動的解像度調整:** SelkiesおよびKasmVNCモードで、クライアントのブラウザサイズに合わせて解像度が自動的に調整されます。

- **🖥️ Xサーバーオプション:** Xサーバーの種類を選択
  - **Xvfb（デフォルト）:** VirtualGLハードウェアアクセラレーション付き仮想Xサーバー、高い互換性
  - **Xorg:** 直接ハードウェアアクセラレーション付き実Xサーバー（`--xorg`オプション使用）
  - 両方ともVirtualGLまたは直接GPUアクセスでハードウェアアクセラレーション対応

- **🔐 SSL証明書管理:** 自動HTTPS設定
  - インタラクティブな証明書生成スクリプト
  - `ssl/`フォルダからの自動検出
  - 優先順位システム：ssl/フォルダ → 環境変数 → HTTPフォールバック

### 開発者エクスペリエンス

- **📦 バージョン固定:** 再現可能なビルドを保証
  - VirtualGL 3.1.4、KasmVNC 1.4.0、Selkies 1.6.2
  - NVIDIA VAAPI 0.0.14、RustDesk 1.4.4
  - もう「昨日は動いたのに」問題はない

- **🛠️ 完全な管理スクリプト:** すべての操作用のシェルスクリプト
  - `build-user-image.sh` - パスワードプロンプト付きでビルド
  - `start-container.sh [--gpu <type>] [--vnc-type <type> | -v <type>]` - GPU選択とVNCタイプで起動
  - `stop/restart/logs/shell-container.sh` - ライフサイクル管理
  - `commit-container.sh` - 変更を保存
  - `generate-ssl-cert.sh` - SSL証明書ジェネレーター

- **👥 マルチユーザーサポート:** 各ユーザーが独立した環境を持つ
  - イメージ名にユーザー名を含む：`devcontainer-ubuntu-egl-desktop-{username}:24.04`
  - コンテナ名にユーザー名を含む：`devcontainer-egl-desktop-{username}`
  - 各ユーザーが自分のUID/GIDで独自のイメージをビルド
  - 同じホスト上の複数ユーザーで競合なし

- **🔧 利便性向上機能:**
  - KasmVNCはデフォルトでスケーリング有効の自動接続
  - ホームディレクトリが`~/host_home`にマウントされアクセスが簡単
  - コンテナホスト名が`$(hostname)-Container`に設定
  - 詳細な日本語ドキュメント（SCRIPTS.md）

- **🌐 多言語サポート:** 日本語環境が利用可能
  - ビルド時に`JP`引数を渡すと日本語入力（Mozc）が有効になる
  - 自動タイムゾーン（Asia/Tokyo）とロケール（ja_JP.UTF-8）設定
  - 日本でのより高速なダウンロードのためのRIKENミラーリポジトリ
  - fcitx入力メソッドフレームワークを含む
  - US/Englishがデフォルトのまま

- **⌨️ 自動キーボード検出:** ホストキーボードレイアウトを自動設定
  - `/etc/default/keyboard`（システムデフォルト）から読み取り
  - `setxkbmap -query`（現在のXセッション）へフォールバック
  - 日本語（jp106）、US、UK、ドイツ語、フランス語などをサポート
  - SelkiesとKasmVNCの両モードで動作
  - `KEYBOARD_LAYOUT`環境変数で手動オーバーライド可能

- **🌐 Chrome Sandbox永続的修正:** Chromeがコンテナで正しく動作
  - `/usr/local/bin`のラッパースクリプトが`--no-sandbox`フラグを保証
  - Chromeパッケージの更新後も手動介入なしで動作
  - ユーザースクリプトや手動修正が不要

- **🖥️ デスクトップショートカット:** 標準デスクトップ環境体験
  - ホームとゴミ箱アイコンが自動的に作成される
  - XDGユーザーディレクトリが設定される（デスクトップ、ダウンロード、ドキュメントなど）
  - すべての言語設定で一貫した体験

### このフォークを選ぶ理由

| オリジナルプロジェクト | このフォーク |
|-----------------|-----------|
| Pullするだけで使用可能 | ローカルビルド（1〜2分）|
| rootコンテナ | ユーザー権限コンテナ |
| 手動UID/GID設定 | 自動一致 |
| コマンドにパスワード | インタラクティブな安全入力 |
| 汎用bash | Ubuntu Desktop bash |
| GPU自動検出 | GPU明示的選択 |
| バージョンドリフト | バージョン固定 |
| 手動SSL設定 | 自動検出+ジェネレーター |
| 単一ユーザー重視 | マルチユーザー最適化 |
| 英語のみ | 多言語（EN/JP）|

---

## クイックスタート

```bash
# 1. ユーザーイメージをビルド（パスワードがプロンプトされます）
./build-user-image.sh              # 英語環境（デフォルト）
./build-user-image.sh JP           # Mozc入力付き日本語環境

# 2. SSL証明書を生成（オプション、HTTPS用）
./generate-ssl-cert.sh

# 3. コンテナを起動
./start-container.sh                      # ソフトウェアレンダリング（GPUなし）、Selkiesモード
./start-container.sh --gpu nvidia --all            # すべてのGPU（NVIDIA）、Selkiesモード
./start-container.sh --gpu intel             # Intel統合GPU、Selkiesモード
./start-container.sh --gpu amd            # AMD GPU、Selkiesモード
./start-container.sh --gpu nvidia --all --vnc-type kasm      # NVIDIA GPUでKasmVNCモード（クリップボード対応）
./start-container.sh --gpu intel --vnc-type kasm          # Intel GPUでKasmVNCモード（クリップボード対応）
./start-container.sh --gpu nvidia --num 0 --vnc-type kasm              # NVIDIA GPU 0でKasmVNC（クリップボード対応）
# 注：--gpuを指定しない場合はソフトウェアレンダリングがデフォルト
# 注：キーボードレイアウトはホストシステムから自動検出されます

# 4. ブラウザでアクセス
# → http://localhost:8080 （または https://localhost:8080 HTTPS有効時）

# 5. 変更を保存（コンテナを削除する前に重要！）
./commit-container.sh              # コンテナの状態をイメージに保存
./commit-container.sh restart --gpu nvidia --all  # 保存してすべてのGPUで再起動

# 6. コンテナを停止
./stop-container.sh                # 停止（コンテナは保持され、再起動可能）
./stop-container.sh rm             # 停止して削除（コミット後のみ！）

# 7. ディスプレイモードの切り替え（再作成が必要）
./commit-container.sh              # まず変更を保存！
./stop-container.sh rm             # コンテナを削除
./start-container.sh --gpu intel --vnc-type kasm     # KasmVNCモードで再作成
```

これだけです！🎉

---

## 目次

- [前提条件](#前提条件)
- [2段階ビルドシステム](#2段階ビルドシステム)
- [インストール](#インストール)
- [使用方法](#使用方法)
- [スクリプトリファレンス](#スクリプトリファレンス)
- [設定](#設定)
- [HTTPS/SSL](#httpsssl)
- [トラブルシューティング](#トラブルシューティング)
- [高度なトピック](#高度なトピック)

---

## 前提条件

- **Docker** 19.03以降
- **GPU**（オプション、ハードウェアアクセラレーション用）
  - **NVIDIA GPU** ✅ テスト済み
    - ドライバーバージョン450.80.02以降
    - Maxwell世代以降
    - NVIDIA Container Toolkitインストール済み
  - **Intel GPU** ✅ テスト済み
    - Intel統合グラフィックス（HD Graphics、Iris、Arc）
    - Quick Sync Videoサポート
    - VA-APIドライバーはコンテナに含まれる
    - **ホスト側のセットアップが必要**（詳細は下記参照）
  - **AMD GPU** ⚠️ 部分的にテスト済み
    - VCE/VCNエンコーダー付きRadeonグラフィックス
    - VA-APIドライバーはコンテナに含まれる
    - **ホスト側のセットアップが必要**（詳細は下記参照）
- **Linuxホスト**（Ubuntu 20.04以降推奨）

---

## 2段階ビルドシステム

このプロジェクトは、高速セットアップと適切なファイル権限のために2段階ビルドアプローチを使用します：

```
┌─────────────────────────┐
│ ベースイメージ (5-10 GB)│  ← メンテナーがビルド、レジストリからプル
│  • すべてのシステムパッケージ│
│  • デスクトップ環境      │
│  • プリインストールアプリ│
└────────────┬────────────┘
             │
             ↓ からビルド
┌────────────┴────────────┐
│ユーザーイメージ (~100MB)│  ← あなたがビルド（1-2分）
│  • あなたのユーザー名    │
│  • あなたのUID/GID       │
│  • あなたのパスワード    │
└─────────────────────────┘
```

**メリット：**

- ✅ **高速セットアップ:** 30〜60分のビルド待ちなし
- ✅ **適切な権限:** ファイルがホストのUID/GIDに一致
- ✅ **マルチユーザー:** 各ユーザーが独自の隔離された環境を持つ
- ✅ **簡単な更新:** 新しいベースイメージをプル、ユーザーイメージを再ビルド

**UID/GID一致が重要な理由：**

- ホストディレクトリ（`$HOME`など）をマウントする場合、ファイルの所有権が一致する必要がある
- UID/GIDが一致しないと、権限エラーが発生する
- ユーザーイメージは自動的にホストの資格情報に一致する

---

## Intel/AMD GPU ホスト側セットアップ

IntelまたはAMD GPUでハードウェアエンコーディング（VA-API）を使用する場合、ホスト側で以下のセットアップが必要です：

### 1. ユーザーをvideo/renderグループに追加

コンテナがGPUデバイス（`/dev/dri/*`）にアクセスするには、ホストユーザーが`video`と`render`グループのメンバーである必要があります：

```bash
# ユーザーをvideo/renderグループに追加
sudo usermod -aG video,render $USER

# グループ変更を反映するため、ログアウトして再ログインまたはシステム再起動
# 確認：
groups
# 出力に「video」と「render」が含まれることを確認
```

### 2. VA-APIドライバーのインストール（Intelの場合）

Intel GPUでハードウェアエンコーディングを使用する場合：

```bash
# VA-APIツールとIntelドライバーをインストール
sudo apt update
sudo apt install vainfo intel-media-va-driver-non-free

# インストール確認（H.264エンコーディングサポートを確認）：
vainfo
# 出力に「VAProfileH264Main : VAEntrypointEncSlice」などが含まれることを確認
```

### 3. VA-APIドライバーのインストール（AMDの場合）

AMD GPUでハードウェアエンコーディングを使用する場合：

```bash
# VA-APIツールとAMDドライバーをインストール
sudo apt update
sudo apt install vainfo mesa-va-drivers

# インストール確認：
vainfo
# 出力に「VAProfileH264Main : VAEntrypointEncSlice」などが含まれることを確認
```

**注意：**
- NVIDIA GPUの場合、これらのセットアップは不要です
- ホスト側のVA-APIが正しく動作していれば、コンテナ内でも自動的に動作します
- グループ変更後は必ずログアウト/再ログインまたは再起動してください

---

## インストール

### 1. ベースイメージをプル

ベースイメージは事前にビルドされ、レジストリから入手可能です：

```bash
# ユーザーイメージをビルドする際に自動的にプルされます
# または手動でプル：
docker pull ghcr.io/tatsuyai713/devcontainer-ubuntu-egl-desktop-base:latest
# または特定バージョン：
docker pull ghcr.io/tatsuyai713/devcontainer-ubuntu-egl-desktop-base:24.04
```


### 2. ユーザーイメージをビルド

ホストのUID/GIDに一致する個人用イメージを作成します：

```bash
# 英語環境（デフォルト）
./build-user-image.sh
# 日本語環境
./build-user-image.sh JP
```

実行時にパスワードが2回プロンプトされ、約1〜2分でビルドが完了します。

**補足：自動化やカスタマイズ用の環境変数例**

```bash
# ベースイメージのバージョン指定
BASE_IMAGE_TAG=v1.0 ./build-user-image.sh
# パスワード自動指定（自動化用）
USER_PASSWORD=mysecurepassword ./build-user-image.sh
# キャッシュなしでビルド
NO_CACHE=true ./build-user-image.sh
```

**高度なカスタムビルド例（複数ユーザー用）**

```bash
docker build \
  --build-arg BASE_IMAGE=ghcr.io/tatsuyai713/devcontainer-ubuntu-egl-desktop-base:24.04 \
  --build-arg USER_NAME=johndoe \
  --build-arg USER_UID=1001 \
  --build-arg USER_GID=1001 \
  --build-arg USER_PASSWORD=johnspassword \
  -f files/Dockerfile.user \
  -t devcontainer-ubuntu-egl-desktop-johndoe:24.04 \
  .
```

---

## 使用方法

### コンテナの起動

`start-container.sh`スクリプトはGPUとディスプレイモードのオプション引数を使用します：

```bash
# 構文: ./start-container.sh [--gpu <type>] [--vnc-type <type> | -v <type>]
# デフォルト：オプション未指定の場合はSelkiesでソフトウェアレンダリング

# NVIDIA GPUオプション：
./start-container.sh --gpu nvidia --all            # 使用可能なすべてのNVIDIA GPUを使用
./start-container.sh --gpu nvidia --num 0                 # NVIDIA GPU 0のみを使用
./start-container.sh --gpu nvidia --num 0,1            # NVIDIA GPU 0と1を使用

# Intel/AMD GPUオプション：
./start-container.sh --gpu intel          # Intel統合GPU（Quick Sync Video）を使用
./start-container.sh --gpu amd               # AMD GPU（VCE/VCN）を使用

# ソフトウェアレンダリング：
./start-container.sh                      # GPUなし（ソフトウェアレンダリング、デフォルト）
./start-container.sh --gpu none           # GPUなしを明示的に指定

# ディスプレイモードオプション：
./start-container.sh --gpu nvidia --all            # Selkies GStreamer（WebRTC、デフォルト）
./start-container.sh --gpu intel --vnc-type kasm       # Intel GPUでKasmVNC（WebSocket経由のVNC、クリップボード対応）
./start-container.sh --gpu nvidia --all --vnc-type novnc         # NVIDIA GPUでnoVNC（クリップボード対応）
./start-container.sh --vnc-type novnc                   # ソフトウェアレンダリングでnoVNC

# キーボードレイアウトのオーバーライド（デフォルトは自動検出）：
KEYBOARD_LAYOUT=jp ./start-container.sh --gpu intel        # 日本語キーボード
KEYBOARD_LAYOUT=us ./start-container.sh --gpu intel    # USキーボード
KEYBOARD_LAYOUT=de KEYBOARD_MODEL=pc105 ./start-container.sh --gpu nvidia --all  # ドイツ語キーボード
```

**UIDベースのポート割り当て（マルチユーザーサポート）：**

ポートはユーザーIDに基づいて自動的に割り当てられ、同じホスト上で複数のユーザーが同時使用できます：

- **HTTPSポート**: `10000 + UID`（例：UID 1000 → ポート 11000）
- **TURNポート**: `13000 + UID`（例：UID 1000 → ポート 14000）
- **UDP範囲**: `40000 + (UID - 1000) × 200` から `+100`（例：UID 1000 → 40000-40100）

アクセス先：`http://localhost:${HTTPS_PORT}`（例：UID 1000の場合は `http://localhost:11000`）

**リモートアクセス（LAN/WAN）：**

TURNサーバーはSelkiesモードで**デフォルトで有効**になっており、追加オプションなしでリモートアクセスが可能です：

```bash
./start-container.sh --gpu intel          # TURNサーバーが自動的に有効化
```

TURNサーバーがリモートアクセス用のWebRTC接続を有効化します：
- **TURNポート**: UIDベース（例：UID 1000でポート 14000）
- **UDP範囲**: UIDベース（例：UID 1000で 40000-40100）
- LAN IPアドレスを自動検出して適切なルーティングを設定
- KasmVNCモードでは不要（VNCはWebRTCを使用しないため）

リモートPCからアクセス：`https://<ホストIP>:<HTTPSポート>`（例：UID 1000の場合は `https://192.168.1.100:11000`）

⚠️ **注意：** UDPポート範囲のマッピング（ユーザーあたり約100ポート）のため、コンテナ起動に時間がかかる場合があります。

**マルチユーザーサポート：**

複数のユーザーが同じホスト上でポートの競合なしで同時にコンテナを実行できます：
- 各ユーザーはUIDに基づいて固有のHTTPS、TURN、UDPポート範囲が割り当てられる
- 例：ユーザーA（UID 1000）はポート 11000、14000、40000-40100を使用
- 例：ユーザーB（UID 1001）はポート 11001、14001、40200-40300を使用

**コンテナの機能：**

- **コンテナの永続性:** 停止時に削除されない（再起動または変更のコミットが可能）
- **ホスト名:** `$(hostname)-Container`に設定
- **ホームマウント:** `~/host_home`で利用可能
- **コンテナ名:** `devcontainer-egl-desktop-{username}`
- **GPU柔軟性:** NVIDIA、Intel、AMD、またはソフトウェアレンダリング
- **自動キーボード検出:** ホストキーボードレイアウトが自動的に適用される

**重要：ディスプレイモードの切り替え**

⚠️ **ディスプレイモード（Selkies/KasmVNC）はコンテナ作成時に設定され、既存のコンテナでは変更できません。**

SelkiesとKasmVNCを切り替える必要がある場合：

```bash
# 方法1：削除して再作成
./stop-container.sh rm
./start-container.sh --gpu intel --vnc-type kasm # KasmVNCに切り替え

# 方法2：コミット、削除、再作成
./commit-container.sh              # まず変更を保存
./stop-container.sh rm
./start-container.sh --gpu intel      # Selkiesに切り替え

# 方法3：コミットして自動再起動
./commit-container.sh restart --gpu intel --vnc-type kasm  # 保存してKasmVNCに切り替え
```

startスクリプトはモードの不一致を検出し、手順付きの役立つエラーメッセージを表示します。

### 一般的なオプション

```bash
# HTTPSを使用
./generate-ssl-cert.sh
./start-container.sh --gpu nvidia --all

# 別のポートを使用
HTTPS_PORT=9090 ./start-container.sh --gpu nvidia --all

# 高解像度（4K）
DISPLAY_WIDTH=3840 DISPLAY_HEIGHT=2160 ./start-container.sh --gpu nvidia --all

# フォアグラウンドモード（ログを直接表示）
DETACHED=false ./start-container.sh --gpu nvidia --all

# カスタムコンテナ名
CONTAINER_NAME=my-desktop ./start-container.sh --gpu nvidia --all
```
```

### コンテナの停止

```bash
# コンテナを停止（再起動またはコミット用に保持）
./stop-container.sh

# コンテナを停止して削除
./stop-container.sh rm
# または
./stop-container.sh remove
```

**コンテナの永続性：**
- デフォルトでは、停止したコンテナは保持され、再起動できる
- コンテナを完全に削除するには`rm`オプションを使用
- 再起動：`./start-container.sh [--gpu <type>] [--vnc-type <type>]`

---

## スクリプトリファレンス

### コアスクリプト

| スクリプト | 説明 | 使用方法 |
|--------|-------------|-------|
| `build-user-image.sh` | ユーザー固有のイメージをビルド | `./build-user-image.sh` または `./build-user-image.sh JP` |
| `start-container.sh` | デスクトップコンテナを起動 | `./start-container.sh [--gpu <type>] [--vnc-type <type>]` |
| `stop-container.sh` | コンテナを停止 | `./stop-container.sh [rm\|remove]` |
| `generate-ssl-cert.sh` | 自己署名SSL証明書を生成 | `./generate-ssl-cert.sh` |

### 管理スクリプト

| スクリプト | 説明 | 使用方法 |
|--------|-------------|-------|
| `restart-container.sh` | コンテナを再起動 | `./restart-container.sh` |
| `logs-container.sh` | コンテナログを表示 | `./logs-container.sh` |
| `shell-container.sh` | コンテナシェルにアクセス | `./shell-container.sh` |
| `delete-image.sh` | ユーザー固有のイメージを削除 | `./delete-image.sh` |
| `commit-container.sh` | コンテナの変更をイメージに保存 | `./commit-container.sh [restart [--gpu <type>] [--vnc-type <type>]]` |

詳細な日本語ドキュメントについては、[SCRIPTS.md](SCRIPTS.md)を参照してください。

### スクリプトの例

**ログの表示：**

```bash
# 最後の100行を表示
./logs-container.sh

# リアルタイムでログをフォロー
FOLLOW=true ./logs-container.sh
```

**シェルへのアクセス：**

```bash
# あなたのユーザーとして
./shell-container.sh

# rootとして
AS_ROOT=true ./shell-container.sh
```

**変更の保存：**

コンテナ内でソフトウェアをインストールしたり変更を加えた場合：

```bash
# コンテナの状態をイメージに保存
./commit-container.sh

# 保存して自動的に再起動
./commit-container.sh restart --gpu nvidia --all      # すべてのNVIDIA GPUで再起動
./commit-container.sh restart --gpu intel    # Intel GPUで再起動
./commit-container.sh restart --gpu amd      # AMD GPUで再起動
./commit-container.sh restart --vnc-type kasm # VNCモードでGPUなしで再起動

# カスタムタグで保存
COMMIT_TAG=my-setup ./commit-container.sh

# 保存したイメージを使用
IMAGE_NAME=devcontainer-ubuntu-egl-desktop-$(whoami):my-setup \
  CONTAINER_NAME=my-desktop-2 \
  ./start-container.sh --gpu nvidia --all
```

**重要な注意事項：**

- ⚠️ **`./stop-container.sh rm`の前に必ずコミット** - コミットせずに削除すると変更が失われる
- ✅ イメージ名の形式は`devcontainer-ubuntu-egl-desktop-{username}:24.04`で簡単に再利用可能
- ✅ コミットされたイメージはコンテナ削除後も保持される
- ✅ 次回起動時にコミットされたイメージが自動的に使用される

**ワークフローの例：**

```bash
# 1. コンテナで作業、ソフトウェアをインストール、設定を構成
./shell-container.sh
# ... パッケージをインストール、環境を構成 ...
exit

# 2. 変更をイメージに保存
./commit-container.sh

# 3. 安全にコンテナを停止して削除（変更はイメージに保存されています）
./stop-container.sh rm

# 4. 次回起動時にコミットされたイメージがすべての変更とともに使用される
./start-container.sh --gpu intel

# 5. 保存した変更でディスプレイモードを切り替える：
./commit-container.sh restart --gpu intel --vnc-type kasm  # 保存してKasmVNCに切り替え
```

**イメージの削除：**

```bash
# ユーザーイメージを削除
./delete-image.sh

# 強制削除（関連するコンテナも削除）
FORCE=true ./delete-image.sh

# 特定のバージョンを削除
IMAGE_TAG=my-setup ./delete-image.sh

# 別のユーザーのイメージを削除
IMAGE_NAME=devcontainer-ubuntu-egl-desktop-otheruser ./delete-image.sh
```

---

## 設定

### ディスプレイ設定

```bash
# 解像度
DISPLAY_WIDTH=1920        # 幅（ピクセル）
DISPLAY_HEIGHT=1080       # 高さ（ピクセル）
DISPLAY_REFRESH=60        # リフレッシュレート（Hz）
DISPLAY_DPI=96            # DPI設定

./start-container.sh --gpu nvidia --all
```

### ビデオエンコーディング

```bash
# NVIDIA GPU（ハードウェアエンコーディング）
VIDEO_ENCODER=nvh264enc   # NVIDIAでH.264
VIDEO_BITRATE=8000        # kbps
FRAMERATE=60              # FPS

# ソフトウェアエンコーディング（GPUなし）
VIDEO_ENCODER=x264enc     # H.264ソフトウェア
VIDEO_BITRATE=4000        # CPUでより低いビットレート

./start-container.sh --gpu nvidia --all
```

**利用可能なエンコーダー：**

- `nvh264enc` - NVIDIA H.264（NVIDIA GPU必要）
- `x264enc` - ソフトウェアH.264（CPU）
- `vp8enc` - ソフトウェアVP8
- `vp9enc` - ソフトウェアVP9
- `vah264enc` - AMD/Intelハードウェアエンコーディング

### オーディオ設定

**ディスプレイモード別音声サポート:**

| モード | 音声出力 | 音声入力（マイク） | 技術 |
|------|-------------|-------------------------|------------|
| **Selkies** | ✅ 内蔵 | ✅ 内蔵 | WebRTC（ブラウザネイティブ） |
| **KasmVNC** | ✅ kclient | ✅ kclient | WebSocket + kasmbins音声システム |
| **noVNC** | ✅ ホストパススルー | ❌ 非対応 | ホストPulseAudioをコンテナにマウント |

**Selkies音声設定:**

```bash
AUDIO_BITRATE=128000      # 音声ビットレート（bps）（デフォルト：128000）
./start-container.sh --gpu nvidia --all
```

**KasmVNC音声（kclient）:**

KasmVNCモードは双方向音声に[LinuxServer.ioのkclient](https://github.com/linuxserver/kclient)を使用します：
- 音声サーバーはポート3000で動作（nginx経由でプロキシ）
- VirtualSpeaker/VirtualMicデバイス付きPipeWire-Pulseを使用
- WebSocket経由でブラウザからコンテナへの音声ストリーミング
- 自動音声デバイス設定

```bash
./start-container.sh --gpu nvidia --all --vnc-type kasm
# kclient Webインターフェースに音声コントロールが表示されます
```

**noVNC音声（ホストパススルー）:**

noVNCモードは音声出力のためにホストPulseAudioソケットをマウントします：
- コンテナアプリケーションはホストスピーカーから音声を再生
- ホストでPulseAudioが実行されている必要があります：`/run/user/$(id -u)/pulse/native`
- セキュリティのため読み取り専用マウント
- このモードではマイク入力は非対応

```bash
./start-container.sh --gpu nvidia --all --vnc-type novnc
# 音声は自動的にホストシステムから再生されます
```

### キーボード設定

**自動検出（デフォルト）：**

コンテナは以下からホストキーボードレイアウトを自動検出します：
1. `/etc/default/keyboard`（システムデフォルト設定）- **優先**
2. `setxkbmap -query`（現在のXセッション）- フォールバック

サポートされているレイアウトには：日本語（jp）、US（us）、UK（gb）、ドイツ語（de）、フランス語（fr）、スペイン語（es）、イタリア語（it）、韓国語（kr）、中国語（cn）などが含まれます。

**手動オーバーライド：**

```bash
# キーボードレイアウトを手動で指定
KEYBOARD_LAYOUT=jp ./start-container.sh --gpu intel              # 日本語キーボード
KEYBOARD_LAYOUT=us ./start-container.sh --gpu intel              # USキーボード
KEYBOARD_LAYOUT=de ./start-container.sh --gpu intel              # ドイツ語キーボード

# キーボードモデル付き（非標準キーボード用）
KEYBOARD_LAYOUT=jp KEYBOARD_MODEL=jp106 ./start-container.sh --gpu intel  # 日本語106キー

# キーボードバリアント付き
KEYBOARD_LAYOUT=us KEYBOARD_VARIANT=dvorak ./start-container.sh --gpu nvidia --all # Dvorakレイアウト

# 完全指定
KEYBOARD_LAYOUT=fr KEYBOARD_MODEL=pc105 KEYBOARD_VARIANT=azerty ./start-container.sh --gpu intel
```

**一般的なキーボードモデル：**
- `pc105` - 標準105キーPCキーボード（デフォルト）
- `jp106` - 日本語106/109キーキーボード
- `pc104` - US 104キーキーボード

**仕組み：**
- キーボードレイアウトはコンテナ作成時に設定される
- SelkiesとKasmVNCの両モードに適用される
- 設定はX11 XKB（setxkbmap）とKDEキーボード設定を使用
- アジア言語用のfcitx入力メソッドで動作

### ディスプレイモード

**Selkies GStreamer（デフォルト）：**

- WebRTCベースのストリーミング
- 低遅延、高パフォーマンス
- ゲームとグラフィックスに適している
- ✅ **音声ストリーミング対応：** WebRTC経由でリモートブラウザクライアントに音声が転送される

```bash
./start-container.sh --gpu nvidia --all       # デフォルトでSelkiesを使用
```

**KasmVNC：**

- WebSocket経由のVNCベースストリーミング
- 互換性が高い
- GPUなしで動作
- ✅ **音声対応：** kclient WebSocketストリーミングによる双方向音声（スピーカー＋マイク）
- クリップボード対応

```bash
./start-container.sh --gpu nvidia --all --vnc-type kasm # KasmVNCモードを有効化
```

---

## HTTPS/SSL

### 自動生成でクイックセットアップ

```bash
# 1. SSL証明書を生成（インタラクティブ）
./generate-ssl-cert.sh

# 2. 生成したCAをローカルの信頼ストアへ登録（sudoが必要）
sudo ./install-ca-cert.sh

# 3. コンテナを起動（ssl/フォルダを自動検出）
./start-container.sh --gpu nvidia --all
```

このスクリプトは：

- 自己署名証明書を生成
- デフォルトで`ssl/`フォルダに保存
- 使用例を提供

アクセス：<https://localhost:8080>（ブラウザにセキュリティ警告が表示されます）

### 生成されたCAの信頼設定

- `generate-ssl-cert.sh` はプライベートCA (`ssl/ca.crt`) とサーバー証明書を生成します。
- Web UI を開く **すべてのマシン** で `sudo ./install-ca-cert.sh` を実行し、以下にインポートしてください：
  - `/usr/local/share/ca-certificates`（システム全体の信頼）
  - Chrome/Chromium の NSS ストア（`certutil` が利用可能な場合に自動登録）
- `certutil` が無い場合は `libnss3-tools` をインストールするか、ブラウザ設定から `ssl/ca.crt` を手動でインポートしてください。
- Chrome が古い証明書をキャッシュしている場合は `chrome://net-internals/#hsts` で `localhost` のエントリを削除し、ブラウザを再起動してください。
- リモートクライアントで利用する場合は `ssl/ca.crt` をコピーし、そのマシンでも `sudo ./install-ca-cert.sh`（または手動インポート）を実施してください。

### 証明書の優先順位

`start-container.sh`スクリプトは次の順序で証明書を自動検出します：

1. `ssl/cert.pem`と`ssl/key.pem`（generate-ssl-cert.shから）
2. 環境変数`CERT_PATH`と`KEY_PATH`
3. 証明書が見つからない場合はHTTPSなしで実行

### カスタムSSL証明書の使用

```bash
CERT_PATH=/path/to/cert.pem \
  KEY_PATH=/path/to/key.pem \
  ./start-container.sh --gpu nvidia --all
```

### 手動証明書生成

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout key.pem -out cert.pem \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"
```

本番環境では、[Let's Encrypt](https://letsencrypt.org/)の証明書を使用してください。

---

## トラブルシューティング

### コンテナが起動しない

```bash
# ログを確認
./logs-container.sh

# イメージが存在するか確認
docker images | grep devcontainer-ubuntu-egl-desktop-base

# ユーザーイメージを再ビルド
./build-user-image.sh

# ポートが使用中か確認
sudo netstat -tulpn | grep 8080

# 別のポートを使用
HTTPS_PORT=8081 ./start-container.sh --gpu nvidia --all
```

### GPUが検出されない

```bash
# NVIDIAドライバーを確認
nvidia-smi

# DockerがGPUにアクセスできるか確認
docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi

# GPU問題が解決しない場合はソフトウェアレンダリングを使用
./start-container.sh
```

### 権限の問題

```bash
# rootとしてアクセス
AS_ROOT=true ./shell-container.sh

# ユーザーIDが一致するか確認
id  # ホスト上で
./shell-container.sh  # その後コンテナ内で'id'を実行

# UID/GIDが一致しない場合、ユーザーイメージを再ビルド
./delete-image.sh
./build-user-image.sh
```

### Webインターフェースにアクセスできない

```bash
# コンテナが実行中か確認
docker ps

# nginxが実行中か確認
./shell-container.sh
# コンテナ内で：supervisorctl status

# ファイアウォールを確認
sudo ufw status
sudo ufw allow 8080/tcp
```

### サービスが起動しない

```bash
# すべてのサービスを確認
./shell-container.sh
supervisorctl status

# 特定のサービスを再起動
./shell-container.sh
supervisorctl restart nginx

# サービスログを確認
./logs-container.sh
```

### UID/GIDの競合

マウントされたボリュームで権限エラーが発生した場合：

1. ホストのUID/GIDを確認：`id -u`と`id -g`
2. イメージが正しいUID/GIDでビルドされたか確認
3. 必要に応じてユーザーイメージを再ビルド：

```bash
./delete-image.sh
./build-user-image.sh
```

### キーボードレイアウトの問題

**誤った入力（例：@キーで2が出る）：**

```bash
# 検出されたキーボードレイアウトを確認
echo $KEYBOARD_LAYOUT  # システムと一致するはず

# ホストキーボード設定を確認
cat /etc/default/keyboard

# 正しいレイアウトでオーバーライド
./stop-container.sh rm
KEYBOARD_LAYOUT=jp KEYBOARD_MODEL=jp106 ./start-container.sh --gpu intel
```

**特に日本語キーボードの場合：**
- 106/109キー日本語キーボードには`KEYBOARD_LAYOUT=jp KEYBOARD_MODEL=jp106`を使用
- モデル`jp106`は正しい@キーの配置に重要
- `/etc/default/keyboard`が正しく設定されていれば自動検出が機能するはず

**キーボードがまったく動作しない：**

```bash
# setxkbmapがインストールされているか確認（ベースイメージに含まれているはず）
./shell-container.sh
which setxkbmap

# キーボード設定を手動でテスト
setxkbmap -layout jp -model jp106 -query
```

### ディスプレイモードの問題

**エラー：「Container was created with X mode, but you're trying to start it with Y mode」**

これは期待される動作です。ディスプレイモード（Selkies/KasmVNC）は既存のコンテナでは変更できません。

**解決策：**

```bash
# オプション1：現在のモードを維持
./start-container.sh --gpu intel  # 元のモードを使用

# オプション2：変更を保存して再作成
./commit-container.sh          # まず変更を保存！
./stop-container.sh rm         # コンテナを削除
./start-container.sh --gpu intel --vnc-type kasm  # 新しいモードで再作成

# オプション3：ワンステップでコミットと再作成
./commit-container.sh restart --gpu intel --vnc-type kasm
```

**なぜモードを変更できないのか？**
- ディスプレイモードはコンテナ作成時（`docker run`）に環境変数で設定される
- 実行中のコンテナは固定の環境変数を使用
- 既存のコンテナへの`docker start`は環境変数を変更しない

## 既知の制限

### Chrome のハードウェアアクセラレーションがソフトウェアにフォールバックする

- Selkies EGL セッション内で Chrome を実行すると、サンドボックス化された GPU プロセスが VirtualGL の `LD_PRELOAD` を取り除くため、`Requested GL implementation (gl=none,angle=none)` といったエラーで GPU 初期化に失敗します。  
- 動画を再生した瞬間に Chrome はソフトウェア描画/デコードへ切り替わります。これは仮想化された GL パイプラインでの Chromium の既知の制限で、単なるフラグ追加では解決できません。  
- 回避策：コンテナ内では Firefox を使用する、Selkies/KasmVNC へはホスト側 Chrome でアクセスする、もしくは Chrome の GPU を使いたい場合は KasmVNC モードへ切り替える。

### Safari で Basic 認証ダイアログが無限に繰り返される

- Selkies ではデフォルトで HTTP Basic 認証が有効です。Safari は WebSocket/WebRTC へのアップグレード時に `Authorization` ヘッダーを再送しないため、`/webrtc/signalling` などで 401 が返されるたびに macOS のログインダイアログが再表示されて先へ進めません。  
- 回避策：`SELKIES_ENABLE_BASIC_AUTH=false` を指定して Basic 認証を無効化する、Chrome/Firefox など別ブラウザを使用する、あるいは Selkies の前段に別のプロキシを置いて認証処理を代替させる。

### Vulkan アプリはフレームを表示できない

- Selkies はコンテナ内で Xvfb + VirtualGL によって KDE デスクトップを実行しており、実際の Xorg/DRI3 バックエンドが存在しません。そのため Vulkan アプリは `No DRI3 support detected` などを出して graphics/present 両方を兼ねるキューを見つけられず終了します。  
- Vulkan のプレゼンテーションには DRI3/DRM と実ディスプレイサーバが必須で、Selkies EGL パイプラインの対象外です。  
- 回避策：Vulkan ワークロードはホスト上で直接実行するか、実際の Xorg セッションに接続されたコンテナ（KasmVNC/GLX モードなど）で実行してください。WebRTC Selkies セッション内では動作しません。

### イメージの再ビルド

```bash
# キャッシュなしでユーザーイメージを再ビルド
NO_CACHE=true ./build-user-image.sh

# 最新のベースイメージをプル
docker pull ghcr.io/tatsuyai713/devcontainer-ubuntu-egl-desktop-base:latest
./build-user-image.sh
```

---

## 高度なトピック

### Docker Compose

docker-composeを希望する場合：

```bash
# 起動
USER_IMAGE=devcontainer-ubuntu-egl-desktop-$(whoami):24.04 \
  docker-compose -f docker-compose.user.yml up -d

# 停止
docker-compose -f docker-compose.user.yml down
```

### 環境変数リファレンス

<details>
<summary>完全な環境変数リストを展開</summary>

#### コンテナ設定

- `CONTAINER_NAME` - コンテナ名（デフォルト：`devcontainer-egl-desktop-$(whoami)`）
- `IMAGE_NAME` - 使用するイメージ（デフォルト：`devcontainer-ubuntu-egl-desktop-$(whoami):24.04`）
- `DETACHED` - バックグラウンドで実行（デフォルト：`true`）

#### ディスプレイ

- `DISPLAY_WIDTH` - 幅（ピクセル）（デフォルト：`1920`）
- `DISPLAY_HEIGHT` - 高さ（ピクセル）（デフォルト：`1080`）
- `DISPLAY_REFRESH` - リフレッシュレート（Hz）（デフォルト：`60`）
- `DISPLAY_DPI` - DPI設定（デフォルト：`96`）

#### 認証

- パスワードはイメージビルド時に設定（ランタイム設定不要）
- `SELKIES_BASIC_AUTH_PASSWORD` - Webインターフェースパスワード（必要に応じてランタイムで設定可能）

#### ビデオ

- `VIDEO_ENCODER` - ビデオエンコーダー（デフォルト：`nvh264enc`）
- `VIDEO_BITRATE` - ビデオビットレート（kbps）（デフォルト：`8000`）
- `FRAMERATE` - フレームレート（デフォルト：`60`）

#### オーディオ

- `AUDIO_BITRATE` - オーディオビットレート（bps）（デフォルト：`128000`）

#### HTTPS/SSL

- `ENABLE_HTTPS` - HTTPSを有効化（デフォルト：ssl/フォルダから自動検出）
- `SELKIES_HTTPS_CERT` - SSL証明書へのパス（コンテナ内）
- `SELKIES_HTTPS_KEY` - SSL秘密鍵へのパス（コンテナ内）
- `CERT_PATH` - 証明書ファイルへのホストパス（マウント用）
- `KEY_PATH` - 鍵ファイルへのホストパス（マウント用）

#### GPU

- GPU選択はコマンド引数経由：`all`、`none`、またはデバイス番号
- `ENABLE_NVIDIA` - 非推奨、代わりにコマンド引数を使用

#### ネットワーク

- `HTTPS_PORT` - バインドするホストポート（デフォルト：`8080`）

</details>

### GPUサポート

**NVIDIA GPU：**

- ドライバーバージョン450.80.02以降が必要
- Maxwell世代以降
- ハードウェアエンコーディング用のNVENCサポート

**AMD/Intel GPU：**

```bash
VIDEO_ENCODER=vah264enc ./start-container.sh --gpu intel
```

**ソフトウェアレンダリング（GPUなし）：**

```bash
VIDEO_ENCODER=x264enc ./start-container.sh
```

### 追加ボリュームのマウント

`start-container.sh`を編集してボリュームマウントを追加：

```bash
CMD="${CMD} -v /path/on/host:/path/in/container"
```

### 同じホスト上の複数ユーザー

各ユーザーは独自のイメージをビルドする必要があります：

```bash
# ユーザー1
USER_PASSWORD=user1pass ./build-user-image.sh

# ユーザー2（同じマシン上）
USER_PASSWORD=user2pass ./build-user-image.sh
```

各ユーザーはユーザー名とUID/GIDに一致する独自のタグ付きイメージをビルドします：
- イメージ：`devcontainer-ubuntu-egl-desktop-{username}:24.04`
- コンテナ：`devcontainer-egl-desktop-{username}`

---

## プロジェクト構造

```
docker-selkies-egl-desktop/
├── build-user-image.sh           # ユーザー固有のイメージをビルド
├── start-container.sh             # コンテナを起動
├── stop-container.sh              # コンテナを停止
├── restart-container.sh           # コンテナを再起動
├── logs-container.sh              # ログを表示
├── shell-container.sh             # シェルにアクセス
├── delete-image.sh                # ユーザーイメージを削除
├── commit-container.sh            # 変更を保存
├── generate-ssl-cert.sh           # SSL証明書を生成
├── docker-compose.yml             # Docker Compose設定（ベースイメージ）
├── docker-compose.user.yml        # Docker Compose設定（ユーザーイメージ）
├── egl.yml                        # 代替compose設定
├── ssl/                           # SSL証明書（自動検出）
│   ├── cert.pem
│   └── key.pem
└── files/                         # システムファイル
    ├── Dockerfile.base            # ベースイメージ定義
    ├── Dockerfile.user            # ユーザーイメージ定義
    ├── entrypoint.sh              # コンテナエントリーポイント
    ├── kasmvnc-entrypoint.sh      # KasmVNCセットアップ
    ├── selkies-gstreamer-entrypoint.sh  # Selkiesセットアップ
    ├── supervisord.conf           # Supervisor設定
    └── build-base-image.sh        # ベースイメージビルダー（メンテナー用）
```

---

## バージョン固定

外部依存関係は再現可能なビルドのために特定のバージョンに固定されています：

- **VirtualGL:** 3.1.4
- **KasmVNC:** 1.4.0
- **Selkies GStreamer:** 1.6.2
- **NVIDIA VAAPIドライバー:** 0.0.14
- **RustDesk:** 1.4.4

これらは[files/Dockerfile.base](files/Dockerfile.base)にビルド引数として定義されています。

---

## ベースイメージのビルド（メンテナー用）

ベースイメージをビルドする必要がある場合（通常はプロジェクトメンテナーのみ）：

```bash
cd files
./build-base-image.sh
```

または手動で：

```bash
docker build \
    -f files/Dockerfile.base \
    -t ghcr.io/tatsuyai713/devcontainer-ubuntu-egl-desktop-base:24.04 \
    .
```

ベースイメージのビルドには30〜60分かかり、以下が必要です：

- 高速なインターネット接続（約5〜10 GBのダウンロード）
- 20 GB以上の空きディスク容量
- BuildKitが有効なDocker

---

## 貢献

貢献を歓迎します！以下をお願いします：

1. リポジトリをフォーク
2. 機能ブランチを作成
3. プルリクエストを送信

ベースイメージの変更については、十分にテストし、必要に応じてバージョン番号を更新してください。

---

## ライセンス

**メインプロジェクト:**

Mozilla Public License 2.0

詳細は[LICENSE](LICENSE)ファイルを参照してください。

**サードパーティコンポーネント:**

このプロジェクトは以下のサードパーティオープンソースソフトウェアを使用しています：

- **kclient** ([LinuxServer.io/kclient](https://github.com/linuxserver/kclient))
  - KasmVNCモードの音声ストリーミング機能に使用
  - ライセンス: GNU General Public License v3.0 or later (GPL-3.0-or-later)
  - 著作権: LinuxServer.io team

サードパーティソフトウェアの完全な一覧とライセンスについては[THIRD-PARTY-LICENSES.md](THIRD-PARTY-LICENSES.md)を参照してください。

---

## 関連プロジェクト

- [docker-selkies-glx-desktop](https://github.com/selkies-project/docker-selkies-glx-desktop) - 専用X11サーバーでより良いパフォーマンス
- [Selkies GStreamer](https://github.com/selkies-project/selkies-gstreamer) - WebRTCストリーミングコンポーネント
- [KasmVNC](https://github.com/kasmtech/KasmVNC) - Webインターフェース付きVNCサーバー

---

## クレジット

### オリジナルプロジェクト

- **Selkies Project:** [github.com/selkies-project](https://github.com/selkies-project)
- **オリジナルメンテナー:** [@ehfd](https://github.com/ehfd)、[@danisla](https://github.com/danisla)
- **オリジナルリポジトリ:** [docker-selkies-egl-desktop](https://github.com/selkies-project/docker-selkies-egl-desktop)

### このフォーク

- **強化機能:** 2段階ビルドシステム、非root実行、UID/GID一致、安全なパスワード管理、管理スクリプト、SSL自動化、バージョン固定、マルチユーザーサポート
- **メンテナー:** [@tatsuyai713](https://github.com/tatsuyai713)
