#!/bin/zsh
set -euo pipefail

REPO_URL="https://github.com/infoworks-jp/yoji-hana.git"

say(){ printf '\n==> %s\n' "$1"; }
fail(){ printf '\nERROR: %s\n' "$1" >&2; exit 1; }

# Use an explicit path when supplied. Otherwise prefer the mounted TRANSCEND SSD,
# then fall back to a local folder in the user's home directory.
if [[ $# -ge 1 && -n "${1:-}" ]]; then
  ROOT="$1"
elif [[ -d "/Volumes/TRANSCEND" ]]; then
  ROOT="/Volumes/TRANSCEND/YOJI-STATION"
else
  ROOT="$HOME/YOJI-STATION"
fi

# Validate the parent before creating anything substantial.
PARENT="${ROOT:h}"
[[ -d "$PARENT" ]] || fail "保存先の親フォルダが見つかりません: $PARENT"
TESTFILE="$PARENT/.yoji-station-write-test-$$"
if ! ( : > "$TESTFILE" ) 2>/dev/null; then
  fail "保存先へ書き込めません: $PARENT"
fi
rm -f "$TESTFILE"

PROJECT="$ROOT/YOJI/WEB/yoji-hana"

say "保存先を確認"
echo "$ROOT"

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
  fail "Git が見つかりません。xcode-select --install を実行してください。"
fi

say "YOJI & HANA リポジトリを同期"
if [[ -d "$PROJECT/.git" ]]; then
  git -C "$PROJECT" pull --ff-only
elif [[ -e "$PROJECT" ]]; then
  fail "既存フォルダがあり、Gitリポジトリではありません: $PROJECT"
else
  git clone "$REPO_URL" "$PROJECT"
fi

say "自動バックアップスクリプトを作成"
cat > "$ROOT/backup-station.sh" <<'BACKUP'
#!/bin/zsh
set -euo pipefail
ROOT="${1:-$HOME/YOJI-STATION}"
[[ -d "$ROOT" ]] || { echo "Station not found: $ROOT" >&2; exit 1; }
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

say "毎日午前3時とMac起動時のバックアップを設定"
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
