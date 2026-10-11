#!/bin/zsh
set -euo pipefail
MD2NOTES_ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
MD2NOTES_APP_PATH="${1:-$MD2NOTES_ROOT/build/md2notes.app}"
if [[ "$MD2NOTES_APP_PATH" != /* ]]; then
  MD2NOTES_APP_PATH="$PWD/$MD2NOTES_APP_PATH"
fi
mkdir -p "$MD2NOTES_APP_PATH/Contents/MacOS" "$MD2NOTES_APP_PATH/Contents/Resources"
swiftc -parse-as-library -swift-version 5 -target x86_64-apple-macosx13.0 \
  -framework AppKit -framework WebKit -framework JavaScriptCore \
  "$MD2NOTES_ROOT/src/md2notes.swift" "$MD2NOTES_ROOT/src/Markdown.swift" \
  "$MD2NOTES_ROOT/tests/SelfTests.swift" \
  -o "$MD2NOTES_APP_PATH/Contents/MacOS/md2notes"
cp "$MD2NOTES_ROOT/resources/Info.plist" "$MD2NOTES_APP_PATH/Contents/Info.plist"
cp "$MD2NOTES_ROOT/resources/transform.js" "$MD2NOTES_APP_PATH/Contents/Resources/"
cp "$MD2NOTES_ROOT/vendor/marked/marked.js" "$MD2NOTES_ROOT/vendor/marked/Marked-LICENSE.txt" "$MD2NOTES_APP_PATH/Contents/Resources/"
cp "$MD2NOTES_ROOT/tests/markdown-fixture.md" "$MD2NOTES_APP_PATH/Contents/Resources/"
cp "$MD2NOTES_ROOT/docs/guide.md" "$MD2NOTES_APP_PATH/Contents/Resources/md2notes-guide.md"
codesign --force --sign - "$MD2NOTES_APP_PATH"
codesign --verify --deep --strict "$MD2NOTES_APP_PATH"
"$MD2NOTES_APP_PATH/Contents/MacOS/md2notes" --self-test
