#!/usr/bin/env bash
set -eo pipefail -u

[[ $(pacman -Qs html-xml-utils) ]] || sudo pacman -S --noconfirm html-xml-utils
[[ $(pacman -Qs kepubify-bin) ]] || paru -S --aur --noconfirm kepubify-bin

URL=https://dieterplex.github.io/rust-ebookshelf/
KOBO=/run/media/$USER/KOBOeReader

HTML=$(curl --silent $URL | hxnormalize -x -l 256)
BOOKS=$(
  echo "$HTML" |
    hxselect -s '\n' -c 'tbody tr td:nth-child(2)' |
    sed 's/ <.*//'
)
# LINKS=$(
#   echo "$HTML" |
#     hxselect -s '\n' -c 'tbody tr td:nth-child(3)' |
#     sed 's/[^"]*"//' | sed 's/.epub.*//'
# )

echo "$BOOKS" | while read -r BOOK; do

  if [[ 
    $BOOK == 'CXX Documentation' ||
    $BOOK == 'CXX-Qt Documentation' ||
    $BOOK == 'FLTK-rs Book' ]]; then
    echo "skip $BOOK"
    continue
  else
    echo "process $BOOK"
  fi

  LINK=$(echo "$BOOK" | jq --raw-input --raw-output '@uri')
  curl --silent "$URL""$LINK".epub >"$BOOK".epub

  7z x "$BOOK".epub -o"$BOOK" >/dev/null
  pushd "$BOOK" >/dev/null
  fd --type=file --extension=html |
    xargs --delimiter='\n' sed -i '/^\s*\/\/ --snip--/d'
  fd --type=file --extension=html |
    xargs --delimiter='\n' sed -i -E "s/#\s+(.*)$/<span class='boring'>\1<\/span>/"
  7z a -tzip "$BOOK".epub -- * >/dev/null
  mv "$BOOK".epub ..
  popd >/dev/null
  rm -rf "$BOOK"

  kepubify \
    --inplace "$BOOK".epub \
    --css 'html { font-family: Georgia !important; font-size: 16px; }' \
    --css 'code, p code, pre code, ul li code { color: #000 !important; font-family: Cascadia Code; font-size: 15px; }' \
    --css 'span.caption code, a code span { color: #404040 !important; font-family: Cascadia Code; font-size: 15px; }' \
    --css 'h1 code, h2 code, h3 code, h4 code, h5 code, h6 code { font-size: 1em; }' \
    --css 'h1 code span, h2 code span, h3 code span, h4 code span, h5 code span, h6 code span { font-family: Georgia; }' \
    --css 'span.caption { color: #404040; font-weight: normal; }' \
    --css 'a span { color: #404040; }' \
    --css 'span.boring { color: #808080; }' \
    >/dev/null
  rm "$BOOK".epub

  [[ -d $KOBO ]] && cp "$BOOK".kepub.epub "$KOBO"

done
