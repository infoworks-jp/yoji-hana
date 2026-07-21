#!/bin/zsh
set -euo pipefail

REPO_URL="https://github.com/infoworks-jp/yoji-hana.git"
ROOT="${1:-$HOME/YOJI-STATION}"
PROJECT="$ROOT/YOJI/WEB/yoji-hana"

say(){ printf '\n==> %s\n' "$1"; }

say "制作ステーションのフォルダを作成"
mkdir -p \
  "$ROOT/YOJI/PHOTO/ORIGINAL" \
  "$ROOT/YOJI/PHOTO/WEB" \
  "$ROOT/YOJI/VIDEO/ORIGINAL" \
  "$ROOT/YOJI/VIDEO/EXPORT" \
  "$ROOT/YOJI/MUSIC" \
  "$ROOT/YOJI/LOGO" \
  "$ROOT/YOJI/WEB" \
  "$ROOT/TSUBASA/OCR" \
  "$ROOT/TSUBASA/EXCEL" \
  "$ROOT/TSUBASA/DASHBOARD" \
  "$ROOT/RIO/DESIGN" \
  "$ROOT/RIO/DOCUMENTS" \
  "$ROOT/BACKUP"

say "Git の確認"
if ! command -v git >/dev/null 2>&1; then
  echo "Git が見つかりません。xcode-select --install を実行してください。"
  exit 1
fi

say "YOJI & HANA リポジトリを同期"
if [[ -d "$PROJECT/.git" ]]; then
  git -C "$PROJECT" pull --ff-only
else
  git clone "$REPO_URL" "$PROJECT"
fi

say "自動バックアップスクリプトを作成"
cat > "$ROOT/backup-station.sh" <<'BACKUP'
#!/bin/zsh
set -euo pipefail
ROOT="${1:-$HOME/YOJI-STATION}"
STAMP=$(date +%Y-%m-%d_%H-%M-%S)
DEST="$ROOT/BACKUP/$STAMP"
mkdir -p "$DEST"
rsync -a --exclude '.git' --exclude 'BACKUP' "$ROOT/YOJI/" "$DEST/YOJI/"
rsync -a --exclude 'BACKUP' "$ROOT/TSUBASA/" "$DEST/TSUBASA/"
rsync -a --exclude 'BACKUP' "$ROOT/RIO/" "$DEST/RIO/"
find "$ROOT/BACKUP" -mindepth 1 -maxdepth 1 -type d -mtime +30 -exec rm -rf {} +
echo "Backup completed: $DEST"
BACKUP
chmod +x "$ROOT/backup-station.sh"

say "Mac起動時に毎日バックアップする設定を作成"
PLIST="$HOME/Library/LaunchAgents/jp.yoji.station.backup.plist"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>jp.yoji.station.backup</string>
<key>ProgramArguments</key><array><string>$ROOT/backup-station.sh</string><string>$ROOT</string></array>
<key>StartCalendarInterval</key><dict><key>Hour</key><integer>3</integer><key>Minute</key><integer>0</integer></dict>
<key>RunAtLoad</key><true/>
<key>StandardOutPath</key><string>$ROOT/BACKUP/backup.log</string>
<key>StandardErrorPath</key><string>$ROOT/BACKUP/backup-error.log</string>
</dict></plist>
PLIST
launchctl bootout gui/$(id -u) "$PLIST" 2>/dev/null || true
launchctl bootstrap gui/$(id -u) "$PLIST"

say "初回バックアップ"
"$ROOT/backup-station.sh" "$ROOT"

say "完了"
echo "制作フォルダ: $ROOT"
echo "Webプロジェクト: $PROJECT"
echo "毎日午前3時とMac起動時にバックアップします。"
