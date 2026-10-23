#!/usr/bin/env bash
# デモ HTML の機械チェック。NG があれば終了コード 1。
# 使い方: bash .claude/skills/review-demo/check.sh [file.html ...]
set -u
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

if [ $# -gt 0 ]; then
  files=("$@")
else
  files=()
  while IFS= read -r f; do files+=("$f"); done < <(ls *.html public/*.html 2>/dev/null)
fi
[ ${#files[@]} -eq 0 ] && { echo "対象の HTML がありません"; exit 1; }

ng=0
fail() { echo "  NG    $1"; ng=$((ng+1)); }
warn() { echo "  要確認 $1"; }
hits() { grep -nE "$1" "$f" | cut -c1-120 | sed 's/^/          /'; }

for f in "${files[@]}"; do
  echo "== $f"
  grep -q '<html lang="ja">' "$f"              || fail 'html に lang="ja" がない'
  grep -q 'name="viewport"' "$f"               || fail 'viewport の meta がない'
  grep -q 'class="notice"' "$f"                || fail '.notice（免責バー）がない'
  grep -q 'aria-live' "$f"                     || fail 'チャット欄に aria-live がない'
  grep -q 'focus-visible' "$f"                 || fail ':focus-visible のスタイルがない'

  if grep -qE 'fetch\(|XMLHttpRequest|sendBeacon|WebSocket' "$f"; then
    fail '外部通信のコードがある'; hits 'fetch\(|XMLHttpRequest|sendBeacon|WebSocket'
  fi
  if grep -qE 'localStorage|sessionStorage|document\.cookie' "$f"; then
    fail 'データを保存するコードがある'; hits 'localStorage|sessionStorage|document\.cookie'
  fi
  if grep -qE '<script[^>]+src=|<link[^>]+stylesheet' "$f"; then
    fail '外部の script/CSS を読み込んでいる'; hits '<script[^>]+src=|<link[^>]+stylesheet'
  fi
  if grep -E 'target="_blank"' "$f" | grep -vq 'noopener'; then
    fail 'target="_blank" に rel="noopener noreferrer" がない'
  fi
  if grep -qE 'href="http://' "$f"; then
    fail 'http:// のリンクがある（https にする）'; hits 'href="http://'
  fi
  if grep -qE 'innerHTML|outerHTML|insertAdjacentHTML|document\.write' "$f"; then
    warn 'innerHTML 等を使っている。ユーザー入力が入らないか確認'; hits 'innerHTML|outerHTML|insertAdjacentHTML|document\.write'
  fi
  if grep -qE '"20[0-9]{2}-[0-9]{2}-[0-9]{2}"' "$f"; then
    warn '日付が直接書かれている。先頭の定数にまとまっているか、過ぎていないか確認'
    grep -oE '"20[0-9]{2}-[0-9]{2}-[0-9]{2}"' "$f" | sort -u | tr '\n' ' ' | sed 's/^/          /'; echo
  fi
done

echo
if [ $ng -gt 0 ]; then echo "結果: NG ${ng}件"; exit 1; fi
echo "結果: NG 0件"
