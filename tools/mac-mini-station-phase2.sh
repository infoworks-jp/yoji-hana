#!/bin/zsh
set -euo pipefail

ROOT="${1:-/Volumes/TRANSCEND/YOJI-STATION}"
PROJECT="$ROOT/YOJI/WEB/yoji-hana"
BIN="$ROOT/BIN"
DROP="$ROOT/YOJI/PHOTO/DROP"
WEBIMG="$ROOT/YOJI/PHOTO/WEB"
PHOTO="$ROOT/YOJI/PHOTO"
LOG="$ROOT/LOGS"
DESKTOP="$HOME/Desktop/YOJI-STATION"
SITEPHOTOS="$PROJECT/photos"

fail(){ echo "ERROR: $1" >&2; exit 1; }
[[ -d "$ROOT" ]] || fail "制作ステーションが見つかりません: $ROOT"
[[ -d "$PROJECT/.git" ]] || fail "Webプロジェクトが見つかりません: $PROJECT"
mkdir -p "$BIN" "$DROP" "$WEBIMG" "$PHOTO" "$LOG" "$DESKTOP" "$SITEPHOTOS"

cat > "$BIN/optimize-images.command" <<EOF
#!/bin/zsh
set -u
DROP="$DROP"
WEBIMG="$WEBIMG"
LOGFILE="$LOG/image-optimize.log"
mkdir -p "\$DROP" "\$WEBIMG" "\${LOGFILE:h}"
found=0; created=0; skipped=0; failed=0
: > "\$LOGFILE"
while IFS= read -r -d '' src; do
  (( found++ ))
  rel="\${src#\$DROP/}"; rel_dir="\${rel:h}"; base="\${rel:t:r}"
  [[ "\$rel_dir" == "." ]] && out_dir="\$WEBIMG" || out_dir="\$WEBIMG/\$rel_dir"
  mkdir -p "\$out_dir"; out="\$out_dir/\${base}.jpg"
  if [[ -f "\$out" && "\$out" -nt "\$src" ]]; then (( skipped++ )); continue; fi
  if sips -s format jpeg -s formatOptions 82 --resampleWidth 2400 "\$src" --out "\$out" >>"\$LOGFILE" 2>&1; then (( created++ )); else rm -f "\$out"; (( failed++ )); fi
done < <(find "\$DROP" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.heic' -o -iname '*.heif' -o -iname '*.tif' -o -iname '*.tiff' -o -iname '*.bmp' -o -iname '*.gif' -o -iname '*.webp' \) -print0)
echo "検出画像: \$found 枚 / 新規・更新: \$created 枚 / 変換済み: \$skipped 枚 / 失敗: \$failed 枚"
[[ "\${AUTO_RUN:-0}" == "1" ]] || { open "\$WEBIMG"; echo; read -k 1 "?キーを押して閉じる..."; }
EOF
chmod +x "$BIN/optimize-images.command"

cat > "$BIN/create-photo-catalog.command" <<EOF
#!/bin/zsh
set -euo pipefail
WEBIMG="$WEBIMG"
CATALOG="$PHOTO/写真一覧.html"
CSV="$PHOTO/写真一覧.csv"
python3 - "\$WEBIMG" "\$CATALOG" "\$CSV" <<'PY'
from pathlib import Path
from urllib.parse import quote
import csv, html, sys
root, out_html, out_csv = map(Path, sys.argv[1:4])
files = sorted(root.rglob('*.jpg'), key=lambda p: str(p).lower())
cards=[]; rows=[]
for i,p in enumerate(files,1):
    rel=p.relative_to(root); name=str(rel); src='WEB/'+'/'.join(quote(x) for x in rel.parts)
    rows.append([i,name,'',''])
    cards.append(f'<article><a href="{src}" target="_blank"><img loading="lazy" src="{src}" alt="{html.escape(name)}"></a><b>No.{i:03d}</b><small>{html.escape(name)}</small></article>')
page=f'''<!doctype html><html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>YOJI & HANA 写真一覧</title><style>*{{box-sizing:border-box}}body{{margin:0;background:#111;color:#eee;font-family:-apple-system,sans-serif}}header{{position:sticky;top:0;background:#111;padding:18px 24px;border-bottom:1px solid #444;z-index:2}}h1{{margin:0;font-size:22px}}main{{display:grid;grid-template-columns:repeat(auto-fill,minmax(210px,1fr));gap:14px;padding:18px}}article{{background:#1d1d1d;border:1px solid #3a3a3a;border-radius:10px;overflow:hidden}}img{{width:100%;height:210px;object-fit:cover;display:block}}b,small{{display:block;padding:8px 11px}}small{{padding-top:0;color:#bbb;overflow-wrap:anywhere}}</style></head><body><header><h1>YOJI & HANA 写真一覧 — {len(files)}枚</h1></header><main>{''.join(cards)}</main></body></html>'''
out_html.write_text(page,encoding='utf-8')
with out_csv.open('w',newline='',encoding='utf-8-sig') as f:
    w=csv.writer(f); w.writerow(['番号','ファイル名','分類','メモ']); w.writerows(rows)
print(f'写真一覧を作成: {len(files)} 枚')
PY
open "\$CATALOG"
[[ "\${AUTO_RUN:-0}" == "1" ]] || { echo; read -k 1 "?キーを押して閉じる..."; }
EOF
chmod +x "$BIN/create-photo-catalog.command"

cat > "$BIN/sync-site-photos.command" <<EOF
#!/bin/zsh
set -euo pipefail
WEBIMG="$WEBIMG"
SITEPHOTOS="$SITEPHOTOS"
PROJECT="$PROJECT"
mkdir -p "\$SITEPHOTOS"
find "\$SITEPHOTOS" -type f -iname '*.jpg' -delete
copied=0
while IFS= read -r -d '' src; do
  rel="\${src#\$WEBIMG/}"
  safe="\${rel//\//__}"
  cp -f "\$src" "\$SITEPHOTOS/\$safe"
  (( copied+=1 ))
done < <(find "\$WEBIMG" -type f -iname '*.jpg' -print0 | sort -z)
python3 - "\$SITEPHOTOS" "\$PROJECT/photos.json" <<'PY'
from pathlib import Path
import json, sys
root=Path(sys.argv[1]); out=Path(sys.argv[2])
files=sorted([p.name for p in root.glob('*.jpg')], key=str.lower)
out.write_text(json.dumps(files, ensure_ascii=False, indent=2), encoding='utf-8')
print(f'全写真マニフェスト: {len(files)} 枚')
PY
echo "サイト用写真を全件同期: \$copied 枚"
EOF
chmod +x "$BIN/sync-site-photos.command"

cat > "$BIN/preview-yoji-hana.command" <<EOF
#!/bin/zsh
PROJECT="$PROJECT"; PORT=8765; cd "\$PROJECT"
lsof -iTCP:\$PORT -sTCP:LISTEN >/dev/null 2>&1 || python3 -m http.server \$PORT > "$LOG/preview.log" 2>&1 &
sleep 1; open "http://127.0.0.1:\$PORT"
EOF
chmod +x "$BIN/preview-yoji-hana.command"

cat > "$BIN/publish-yoji-hana.command" <<EOF
#!/bin/zsh
set -euo pipefail
PROJECT="$PROJECT"
AUTO_RUN=1 "$BIN/optimize-images.command"
AUTO_RUN=1 "$BIN/create-photo-catalog.command"
"$BIN/sync-site-photos.command"
cd "\$PROJECT"
git pull --rebase --autostash
if [[ -n "\$(git status --porcelain)" ]]; then
  git add -A
  git commit -m "Publish all YOJI & HANA photographs \$(date '+%Y-%m-%d %H:%M')"
  git push
fi
open "https://infoworks-jp.github.io/yoji-hana/?v=\$(date +%s)"
EOF
chmod +x "$BIN/publish-yoji-hana.command"

cat > "$BIN/update-yoji-hana.command" <<EOF
#!/bin/zsh
set -euo pipefail
ROOT="$ROOT"; PROJECT="$PROJECT"
cd "\$PROJECT"
if [[ -n "\$(git status --porcelain)" ]]; then echo "ローカル変更があるため停止しました。"; git status --short; read -k 1 "?キーを押して閉じる..."; exit 1; fi
git pull --ff-only
/bin/zsh "\$PROJECT/tools/mac-mini-station-phase2.sh" "\$ROOT"
"$BIN/sync-site-photos.command"
cd "\$PROJECT"
if [[ -n "\$(git status --porcelain)" ]]; then
  git add -A
  git commit -m "Publish all YOJI & HANA photographs \$(date '+%Y-%m-%d %H:%M')"
  git push
fi
open "https://infoworks-jp.github.io/yoji-hana/?v=\$(date +%s)"
echo "更新・全写真同期・サイト公開が完了しました。"
EOF
chmod +x "$BIN/update-yoji-hana.command"

ln -sfn "$PROJECT" "$DESKTOP/YOJI-HANA Web"
ln -sfn "$DROP" "$DESKTOP/写真をここへ"
ln -sfn "$WEBIMG" "$DESKTOP/Web用画像"
ln -sfn "$BIN/update-yoji-hana.command" "$DESKTOP/1 最新版に更新.command"
ln -sfn "$BIN/preview-yoji-hana.command" "$DESKTOP/2 ブラウザで確認.command"
ln -sfn "$BIN/optimize-images.command" "$DESKTOP/3 画像を最適化.command"
ln -sfn "$BIN/create-photo-catalog.command" "$DESKTOP/4 写真一覧を作る.command"
ln -sfn "$BIN/publish-yoji-hana.command" "$DESKTOP/5 GitHubへ公開.command"

AUTO_RUN=1 "$BIN/optimize-images.command"
AUTO_RUN=1 "$BIN/create-photo-catalog.command"
"$BIN/sync-site-photos.command"
echo "YOJI-STATIONを更新しました。今後は写真フォルダ内の全画像を自動で公開します。"