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
set -u
DROP="$DROP"
WEBIMG="$WEBIMG"
LOGFILE="$LOG/image-optimize.log"
mkdir -p "\$DROP" "\$WEBIMG" "\${LOGFILE:h}"

found=0
created=0
skipped=0
failed=0

: > "\$LOGFILE"

while IFS= read -r -d '' src; do
  (( found++ ))
  rel="\${src#\$DROP/}"
  rel_dir="\${rel:h}"
  base="\${rel:t:r}"

  if [[ "\$rel_dir" == "." ]]; then
    out_dir="\$WEBIMG"
  else
    out_dir="\$WEBIMG/\$rel_dir"
  fi
  mkdir -p "\$out_dir"
  out="\$out_dir/\${base}.jpg"

  if [[ -f "\$out" && "\$out" -nt "\$src" ]]; then
    echo "既存: \$out"
    (( skipped++ ))
    continue
  fi

  if sips -s format jpeg -s formatOptions 82 --resampleWidth 2400 "\$src" --out "\$out" >>"\$LOGFILE" 2>&1; then
    echo "作成: \$out"
    (( created++ ))
  else
    echo "失敗: \$src"
    rm -f "\$out"
    (( failed++ ))
  fi
done < <(find "\$DROP" -type f \( \
  -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o \
  -iname '*.heic' -o -iname '*.heif' -o -iname '*.tif' -o \
  -iname '*.tiff' -o -iname '*.bmp' -o -iname '*.gif' -o \
  -iname '*.webp' \
\) -print0)

echo ""
echo "===== 処理結果 ====="
echo "検出画像: \$found 枚"
echo "新規・更新: \$created 枚"
echo "変換済み: \$skipped 枚"
echo "変換失敗: \$failed 枚"
echo "Web用合計: \$(find "\$WEBIMG" -type f -iname '*.jpg' | wc -l | tr -d ' ') 枚"

if (( found == 0 )); then
  echo "PHOTO/DROPとその下のフォルダに画像が見つかりませんでした。"
  open "\$DROP"
else
  open "\$WEBIMG"
fi

if (( failed > 0 )); then
  echo "失敗の詳細: \$LOGFILE"
fi

echo ""
read -k 1 "?キーを押して閉じる..."
EOF
chmod +x "$BIN/optimize-images.command"

say "写真一覧シート作成スクリプトを作成"
cat > "$BIN/create-photo-catalog.command" <<EOF
#!/bin/zsh
set -euo pipefail
WEBIMG="$WEBIMG"
CATALOG="$ROOT/YOJI/PHOTO/写真一覧.html"
CSV="$ROOT/YOJI/PHOTO/写真一覧.csv"

python3 - "\$WEBIMG" "\$CATALOG" "\$CSV" <<'PY'
from pathlib import Path
from urllib.parse import quote
import csv
import html
import sys

root = Path(sys.argv[1])
out_html = Path(sys.argv[2])
out_csv = Path(sys.argv[3])
files = sorted(root.rglob('*.jpg'), key=lambda p: str(p).lower())

rows = []
cards = []
for i, path in enumerate(files, 1):
    rel = path.relative_to(root)
    src = 'WEB/' + '/'.join(quote(part) for part in rel.parts)
    name = str(rel)
    rows.append([i, name, '', ''])
    cards.append(f'''<article class="card">
      <a href="{src}" target="_blank"><img loading="lazy" src="{src}" alt="{html.escape(name)}"></a>
      <div class="num">No.{i:03d}</div>
      <div class="name">{html.escape(name)}</div>
      <div class="choice">□ 主役　□ 補助　□ 不使用</div>
    </article>''')

page = f'''<!doctype html>
<html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>YOJI &amp; HANA 写真一覧</title>
<style>
*{{box-sizing:border-box}} body{{margin:0;background:#111;color:#eee;font-family:-apple-system,BlinkMacSystemFont,"Helvetica Neue",sans-serif}}
header{{position:sticky;top:0;z-index:2;padding:18px 24px;background:rgba(17,17,17,.94);border-bottom:1px solid #444}}
h1{{margin:0 0 4px;font-size:22px}} p{{margin:0;color:#bbb}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:16px;padding:20px}}
.card{{background:#1d1d1d;border:1px solid #3a3a3a;border-radius:10px;overflow:hidden}}
.card img{{width:100%;height:210px;object-fit:cover;display:block;background:#000}}
.num{{font-weight:700;font-size:18px;padding:10px 12px 2px}}
.name{{padding:0 12px 8px;color:#bbb;font-size:12px;overflow-wrap:anywhere;min-height:40px}}
.choice{{padding:9px 12px 12px;border-top:1px solid #333;font-size:13px}}
@media print{{header{{position:static}} .grid{{grid-template-columns:repeat(4,1fr);gap:8px;padding:8px}} .card img{{height:150px}} .choice{{font-size:11px}}}}
</style></head>
<body><header><h1>YOJI &amp; HANA 写真一覧</h1><p>全 {len(files)} 枚。画像を押すと原寸表示します。</p></header>
<main class="grid">{''.join(cards)}</main></body></html>'''

out_html.write_text(page, encoding='utf-8')
with out_csv.open('w', newline='', encoding='utf-8-sig') as f:
    w = csv.writer(f)
    w.writerow(['番号', 'ファイル名', '分類', 'メモ'])
    w.writerows(rows)
print(f'写真一覧を作成しました: {len(files)} 枚')
print(out_html)
print(out_csv)
PY

open "\$CATALOG"
echo ""
read -k 1 "?キーを押して閉じる..."
EOF
chmod +x "$BIN/create-photo-catalog.command"

say "Finderから使えるショートカットをデスクトップへ作成"
DESKTOP="$HOME/Desktop/YOJI-STATION"
mkdir -p "$DESKTOP"
ln -sfn "$PROJECT" "$DESKTOP/YOJI-HANA Web"
ln -sfn "$DROP" "$DESKTOP/写真をここへ"
ln -sfn "$WEBIMG" "$DESKTOP/Web用画像"
ln -sfn "$BIN/update-yoji-hana.command" "$DESKTOP/1 最新版に更新.command"
ln -sfn "$BIN/preview-yoji-hana.command" "$DESKTOP/2 ブラウザで確認.command"
ln -sfn "$BIN/optimize-images.command" "$DESKTOP/3 画像を最適化.command"
ln -sfn "$BIN/create-photo-catalog.command" "$DESKTOP/4 写真一覧を作る.command"
ln -sfn "$BIN/publish-yoji-hana.command" "$DESKTOP/5 GitHubへ公開.command"

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
echo "1 更新 / 2 確認 / 3 画像最適化 / 4 写真一覧 / 5 公開 の順で使えます。"
open "$DESKTOP"
