#!/usr/bin/env bash
# デモHTMLの機械チェック。NGがあれば終了コード1。
# 使い方: bash .claude/skills/review-demo/check.sh [file.html ...]
set -u
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" || exit 1

# 指定がなければpublic内を検査する。
shopt -s nullglob
if [ $# -gt 0 ]; then
  files=("$@")
elif [ -d public ]; then
  files=(public/*.html)
else
  files=(*.html)
fi
shopt -u nullglob

if [ ${#files[@]} -eq 0 ]; then
  echo "対象のHTMLがありません"
  exit 1
fi

ng=0
fail() { echo "  NG    $1"; ng=$((ng+1)); }
warn() { echo "  要確認 $1"; }
hits() {
  grep -nE -- "$1" "$f" |
    cut -c1-120 |
    sed 's/^/          /'
}

for f in "${files[@]}"; do
  echo "== $f"

  if [ ! -f "$f" ] || [ ! -r "$f" ]; then
    fail "ファイルが存在しないか、読み取れません"
    continue
  fi

  grep -q '<html lang="ja">' "$f" ||
    fail 'htmlにlang="ja"がない'
  grep -q 'name="viewport"' "$f" ||
    fail 'viewportのmetaがない'
  grep -q 'class="notice"' "$f" ||
    fail '.notice（免責バー）がない'
  grep -q 'aria-live' "$f" ||
    fail 'チャット欄にaria-liveがない'
  grep -q 'focus-visible' "$f" ||
    fail ':focus-visibleのスタイルがない'

  if grep -qE 'fetch\(|XMLHttpRequest|sendBeacon|WebSocket' "$f"; then
    fail '外部通信のコードがある'
    hits 'fetch\(|XMLHttpRequest|sendBeacon|WebSocket'
  fi

  if grep -qE 'localStorage|sessionStorage|document\.cookie' "$f"; then
    fail 'データを保存するコードがある'
    hits 'localStorage|sessionStorage|document\.cookie'
  fi

  if grep -qE '<script[^>]+src=|<link[^>]+stylesheet' "$f"; then
    fail '別ファイルのscript/CSSを読み込んでいる'
    hits '<script[^>]+src=|<link[^>]+stylesheet'
  fi

  # noopenerとnoreferrerの両方を検査する。
  if grep -E 'target="_blank"' "$f" | grep -vq 'noopener'; then
    fail 'target="_blank"の行にnoopenerがない'
  fi
  if grep -E 'target="_blank"' "$f" | grep -vq 'noreferrer'; then
    fail 'target="_blank"の行にnoreferrerがない'
  fi

  if grep -qE 'href="http://' "$f"; then
    fail 'http://のリンクがある（httpsにする）'
    hits 'href="http://'
  fi

  if grep -qE 'innerHTML|outerHTML|insertAdjacentHTML|document\.write' "$f"; then
    warn 'innerHTML等を使っている。ユーザー入力が入らないか確認'
    hits 'innerHTML|outerHTML|insertAdjacentHTML|document\.write'
  fi

  if grep -qE '"20[0-9]{2}-[0-9]{2}-[0-9]{2}"' "$f"; then
    warn '日付の定数化・確認日・有効期間を目視で確認'
    grep -oE '"20[0-9]{2}-[0-9]{2}-[0-9]{2}"' "$f" |
      sort -u |
      tr '\n' ' ' |
      sed 's/^/          /'
    echo
  fi
done

echo
if [ "$ng" -gt 0 ]; then
  echo "結果: NG ${ng}件"
  exit 1
fi
echo "結果: NG 0件"
