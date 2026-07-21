#!/bin/zsh
set -euo pipefail

ROOT="${1:-/Volumes/TRANSCEND/YOJI-STATION}"
PROJECT="$ROOT/YOJI/WEB/yoji-hana"
BIN="$ROOT/BIN"
DROP="$ROOT/YOJI/PHOTO/DROP"
WEBIMG="$ROOT/YOJI/PHOTO/WEB"
LOG="$ROOT/LOGS"

say(){ printf '\n==> %s\n' "$1"; }
fail(){ echo "ERROR: $1" >&2; exit 1; }

[[ -d "$ROOT" ]] || fail "制作ステーションが見つかりません: $ROOT"
[[ -d "$PROJECT/.git" ]] || fail "Webプロジェクトが見つかりません: $PROJECT"
mkdir -p "$BIN" "$DROP" "$WEBIMG" "$LOG"

say "更新スクリプトを作成"
cat > "$BIN/update-yoji-hana.command" <<EOF
#!/bin/zsh
set -euo pipefail
PROJECT="$PROJECT"
cd "\$PROJECT"
if [[ -n "\$(git status --porcelain)" ]]; then
  echo "ローカル変更があるため自動更新を停止しました。"
  git status --short
  read -k 1 "?キーを押して閉じる..."
  exit 1
fi
git pull --ff-only
echo "最新状態へ更新しました。"
open "https://infoworks-jp.github.io/yoji-hana/?v=\$(date +%s)"
EOF
chmod +x "$BIN/update-yoji-hana.command"

say "安全な公開スクリプトを作成"
cat > "$BIN/publish-yoji-hana.command" <<EOF
#!/bin/zsh
set -euo pipefail
PROJECT="$PROJECT"
cd "\$PROJECT"
git pull --rebase --autostash
if [[ -z "\$(git status --porcelain)" ]]; then
  echo "公開する変更はありません。"
  read -k 1 "?キーを押して閉じる..."
  exit 0
fi
printf "変更内容:\n"
git status --short
git add -A
MESSAGE="Mac mini update \$(date '+%Y-%m-%d %H:%M')"
git commit -m "\$MESSAGE"
git push
echo "GitHubへ公開しました。"
open "https://infoworks-jp.github.io/yoji-hana/?v=\$(date +%s)"
EOF
chmod +x "$BIN/publish-yoji-hana.command"

say "ローカル確認スクリプトを作成"
cat > "$BIN/preview-yoji-hana.command" <<EOF
#!/bin/zsh
set -euo pipefail
PROJECT="$PROJECT"
PORT=8765
cd "\$PROJECT"
if lsof -iTCP:\$PORT -sTCP:LISTEN >/dev/null 2>&1; then
  open "http://127.0.0.1:\$PORT"
  exit 0
fi
python3 -m http.server \$PORT > "$LOG/preview.log" 2>&1 &
sleep 1
open "http://127.0.0.1:\$PORT"
EOF
chmod +x "$BIN/preview-yoji-hana.command"

say "画像最適化スクリプトを作成"
cat > "$BIN/optimize-images.command" <<EOF
#!/bin/zsh
set -euo pipefail
DROP="$DROP"
WEBIMG="$WEBIMG"
mkdir -p "\$DROP" "\$WEBIMG"
setopt null_glob
files=("\$DROP"/*.(jpg|jpeg|png|heic|tif|tiff)(N))
if (( \${#files[@]} == 0 )); then
  echo "PHOTO/DROP に画像を入れてから実行してください。"
  open "\$DROP"
  read -k 1 "?キーを押して閉じる..."
  exit 0
fi
for src in "\${files[@]}"; do
  base="\${src:t:r}"
  out="\$WEBIMG/\${base}.jpg"
  sips -s format jpeg -s formatOptions 82 --resampleWidth 2400 "\$src" --out "\$out" >/dev/null
  echo "作成: \$out"
done
open "\$WEBIMG"
EOF
chmod +x "$BIN/optimize-images.command"

say "Finderから使えるショートカットをデスクトップへ作成"
DESKTOP="$HOME/Desktop/YOJI-STATION"
mkdir -p "$DESKTOP"
ln -sfn "$PROJECT" "$DESKTOP/YOJI-HANA Web"
ln -sfn "$DROP" "$DESKTOP/写真をここへ"
ln -sfn "$WEBIMG" "$DESKTOP/Web用画像"
ln -sfn "$BIN/update-yoji-hana.command" "$DESKTOP/1 最新版に更新.command"
ln -sfn "$BIN/preview-yoji-hana.command" "$DESKTOP/2 ブラウザで確認.command"
ln -sfn "$BIN/optimize-images.command" "$DESKTOP/3 画像を最適化.command"
ln -sfn "$BIN/publish-yoji-hana.command" "$DESKTOP/4 GitHubへ公開.command"

say "1時間ごとの安全な自動同期を設定"
SYNC="$BIN/hourly-safe-sync.sh"
cat > "$SYNC" <<EOF
#!/bin/zsh
PROJECT="$PROJECT"
LOG="$LOG/hourly-sync.log"
{
  echo "--- \$(date) ---"
  cd "\$PROJECT" || exit 1
  if [[ -n "\$(git status --porcelain)" ]]; then
    echo "ローカル変更あり: 自動pullをスキップ"
    exit 0
  fi
  git pull --ff-only
} >> "\$LOG" 2>&1
EOF
chmod +x "$SYNC"
PLIST="$HOME/Library/LaunchAgents/jp.yoji.station.sync.plist"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>jp.yoji.station.sync</string>
<key>ProgramArguments</key><array><string>$SYNC</string></array>
<key>StartInterval</key><integer>3600</integer>
<key>RunAtLoad</key><true/>
<key>StandardOutPath</key><string>$LOG/sync-launchd.log</string>
<key>StandardErrorPath</key><string>$LOG/sync-launchd-error.log</string>
</dict></plist>
EOF
launchctl bootout gui/$(id -u) "$PLIST" 2>/dev/null || true
launchctl bootstrap gui/$(id -u) "$PLIST"

say "初回同期"
"$SYNC" || true

say "完了"
echo "デスクトップに YOJI-STATION フォルダを作成しました。"
echo "1 更新 / 2 確認 / 3 画像最適化 / 4 公開 の順で使えます。"
open "$DESKTOP"
