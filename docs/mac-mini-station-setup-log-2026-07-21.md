# Mac mini制作ステーション構築記録

記録日: 2026-07-21

## 保存先

- 制作ステーション: `/Volumes/TRANSCEND/YOJI-STATION`
- Webプロジェクト: `/Volumes/TRANSCEND/YOJI-STATION/YOJI/WEB/yoji-hana`

## 第1段階で完了したこと

- 外付けSSD `TRANSCEND` への書き込み確認
- 制作フォルダ一式の作成
- `infoworks-jp/yoji-hana` リポジトリのクローン
- 初回バックアップの作成
- 毎日午前3時の自動バックアップ設定
- Mac起動時の自動バックアップ設定

初回バックアップ:

`/Volumes/TRANSCEND/YOJI-STATION/BACKUP/2026-07-21_20-08-15`

## 第2段階で完了したこと

デスクトップに `YOJI-STATION` フォルダを作成し、以下を配置。

- `1 最新版に更新.command`
- `2 ブラウザで確認.command`
- `3 画像を最適化.command`
- `4 GitHubへ公開.command`
- `Web用画像`
- `YOJI-HANA Web`
- `写真をここへ`

追加された自動化:

- GitHubから最新版を安全に取得
- ローカル変更がある場合は上書きせず停止
- ローカルブラウザ確認
- 写真をWeb用JPEG・最大幅2400pxへ変換
- 変更内容をGitHubへ公開
- 公開後にサイトを表示
- 1時間ごとの安全な自動同期

## 実動確認

以下の表示まで確認済み。

- `==> 初回同期`
- `==> 完了`
- `デスクトップに YOJI-STATION フォルダを作成しました。`

Finder上でも、上記ショートカットとフォルダの作成を確認した。

## 重要な訂正記録

初回はSSD名を誤って `/Volumes/TRANSCFND` と指定して失敗した。
実際のボリューム名は `/Volumes/TRANSCEND`。
修正版ではSSD名を自動検出し、書き込み可否も確認する方式へ変更した。

## 現在の状態

Mac mini制作ステーションの第1・第2段階は構築済みで、フォルダ作成、GitHub同期、バックアップ、定期同期、操作用ショートカットの作成まで確認済み。
