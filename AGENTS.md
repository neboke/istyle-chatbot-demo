# AGENTS.md

このリポジトリは、顧客への提案で見せる **チャットボット体験デモ（単一HTML）** を置く場所です。
AI エージェント（Claude Code / Codex など）も人間も、作業前にこのファイルを読んでください。

## 構成

```
public/index.html            Istyle（架空のコスプレ衣装店）デモ
public/nangoku.html          南国酒家を題材にした非公式デモ
public/_routes.json          すべてのURLで認証処理を実行する設定
functions/_middleware.js     ベーシック認証の処理
.gitignore                  秘密情報・開発用ファイルの除外設定
AGENTS.md                   このファイル（共通ルール）
CLAUDE.md                   Claude Code 用。AGENTS.md を読み込むだけ
.claude/skills/              作業手順（new-demo / review-demo）
docs/tasks/                 作業指示書（プロンプト）
index.html                  移行期間中のGitHub Pages用コピー
nangoku.html                移行期間中のGitHub Pages用コピー
```

- 現在の公開先は GitHub Pages（`https://neboke.github.io/istyle-chatbot-demo/`）。Cloudflare Pagesへの移行準備中です。
- Cloudflare Pagesの公開対象は `public/` のみです。`functions/` はリポジトリ直下に置き、公開フォルダーには含めません。
- `AGENTS.md`、`.claude/`、`docs/`、秘密情報ファイルは `public/` に置きません。
- 公開を途切れさせないため、直下のHTMLは切り替えまで残します。Cloudflare本番の動作確認とGitHub Pages停止後、別PRで整理します。
- デモHTMLのビルド工程はありません。HTMLをブラウザで直接開けば画面は動きます。ただし認証処理の確認には、CloudflareまたはWranglerの実行環境が必要です。
- 移行手順は `docs/tasks/cloudflare-migration.md` を参照してください。

## 認証と公開設定

- ユーザー名とパスワードは `BASIC_AUTH_USER` / `BASIC_AUTH_PASS` から読みます。実際の値をコードに書きません。
- CloudflareではProductionとPreviewの両方にSecretとして設定します。
- 認証なし・誤った認証は401、認証情報の設定忘れは500とし、デモを表示しません。
- `public/_routes.json` は全URLを認証対象にし、認証を省略するURLを設けません。
- Cloudflare設定時は、Functionsの利用上限に達してもページを公開しない「Fail closed」を選択します。
- ローカルの秘密情報は `.dev.vars` に置き、Git管理から除外します。
- HTTPSで利用します。デモ閲覧用の共通認証は、GitHubやCloudflare管理画面へのログインとは別です。

## デモの品質基準（必ず守る）

### 1. 構造
- **1デモ = 1つの HTML ファイル**。CSS と JS は同じファイル内に書く。CDN・Web フォント・画像ファイルなどの外部依存は使わない（必要なら PR で相談）。
- 画面は **「お客様向け体験」** と **「管理画面」** の2タブ構成。既存デモ（`public/index.html`）の構造・クラス名・関数名（`bot` / `send` / `renderAdmin` / `view` など）に合わせる。
- 管理画面には、件数カード・費用対効果の試算（想定時間 × 時間単価 − 運用費）・受付一覧・対応履歴を置く。

### 2. 表示と免責
- `<header>` の直下に `.notice` バーを置き、次の4点を書く：
  1. 提案用デモであること
  2. 商品・価格などが架空であること（実在企業が題材なら「非公式」であること）
  3. 送信・予約・決済は行わないこと
  4. 実在企業が題材なら、情報確認日（YYYY年M月D日）
- 予約・在庫・価格・アレルギー・納期は **確約しない文言** にし、「担当者／店舗の確認が必要」と案内する。
- 実在企業を題材にする場合は、ロゴ・写真・商標的な装飾を使わず、出典として公式ページへリンクする。

### 3. 安全性
- **デモHTMLから外部送信をしない**：`fetch` / `XMLHttpRequest` / `sendBeacon` / 外部への `<form action>` / 解析タグは書かない。
- **データを保存しない**：`localStorage` / `sessionStorage` / Cookie は使わない（再読み込みで消える仕様）。
- **ユーザー入力は `textContent` で表示する**。`innerHTML` は固定文字列（コード内の定数）にしか使わない。
- 外部リンクには必ず `target="_blank" rel="noopener noreferrer"` を付ける。
- 入力値は検証する（日付は実在する日か、人数・数量は範囲内か、メールアドレスの形式か）。

### 4. 見た目・アクセシビリティ
- `<html lang="ja">`、viewport の meta、チャット欄は `role="log" aria-live="polite"`、タブは `aria-pressed`、`:focus-visible` を付ける。
- ブレークポイントは `980px` と `580px`。スマホ幅（375px）で横スクロールが出ないこと。
- 金額は `Intl.NumberFormat("ja-JP",{style:"currency",currency:"JPY"})` で整形し、人数は「名」、数量は「着／点」など単位を付ける。**チャットの画面と管理画面で同じ表記にする。**

### 5. 変わりやすい情報
- 休業日・キャンペーン期間・価格など、時間がたつと変わる値は **script の先頭の定数にまとめ**、コメントで確認日と出典 URL を書く。関数の中に直接書かない。

## 作業の流れ

1. **`main` に直接 push しない。** ブランチを切る：`demo/<名前>`（新規デモ）、`fix/<内容>`（修正）、`chore/<内容>`（その他）。
2. 新しいデモは skill `new-demo` の手順で `public/` に作る。
3. push の前に skill `review-demo` でセルフレビューし、`check.sh` が通ることを確認する。
4. PR を作る。本文には「何を・なぜ・どう確認したか」と、スマホ幅のスクリーンショットを付ける。
5. レビューで承認されてから `main` にマージする。

### コミットメッセージ
- 1行目は日本語で、要点を50文字程度にまとめる（例：`南国酒家デモ：管理画面の予算表示を円表記に統一`）。
- **本文にコードを貼らない。** 差分は Git が記録しています。

## やってはいけないこと
- 秘密情報（API キー・パスワード・本物の顧客情報）をコミットする。パスワードは Cloudflare のSecretに入れる。
- リポジトリの公開設定、GitHub Pagesの設定、ブランチ保護の変更を独断で行う（オーナーに依頼する）。
- 既存デモの文言・仕様を、依頼の範囲を超えて書き換える。
