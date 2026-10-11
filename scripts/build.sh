#!/bin/zsh
set -euo pipefail
MD2NOTES_ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
MD2NOTES_APP_PATH="${1:-$MD2NOTES_ROOT/build/md2notes.app}"
if [[ "$MD2NOTES_APP_PATH" != /* ]]; then
  MD2NOTES_APP_PATH="$PWD/$MD2NOTES_APP_PATH"
fi
mkdir -p "$MD2NOTES_APP_PATH/Contents/MacOS" "$MD2NOTES_APP_PATH/Contents/Resources"
MD2NOTES_OBJ_DIR="$(mktemp -d)"
trap 'rm -rf "$MD2NOTES_OBJ_DIR"' EXIT
# Universal binary: Apple Silicon (arm64) + Intel (x86_64).
for MD2NOTES_ARCH in arm64 x86_64; do
  swiftc -parse-as-library -swift-version 5 -target "$MD2NOTES_ARCH-apple-macosx13.0" \
    -framework AppKit -framework WebKit -framework JavaScriptCore \
    "$MD2NOTES_ROOT/src/md2notes.swift" "$MD2NOTES_ROOT/src/Markdown.swift" \
    "$MD2NOTES_ROOT/tests/SelfTests.swift" \
    -o "$MD2NOTES_OBJ_DIR/md2notes-$MD2NOTES_ARCH"
done
lipo -create "$MD2NOTES_OBJ_DIR/md2notes-arm64" "$MD2NOTES_OBJ_DIR/md2notes-x86_64" \
  -output "$MD2NOTES_APP_PATH/Contents/MacOS/md2notes"
lipo "$MD2NOTES_APP_PATH/Contents/MacOS/md2notes" -verify_arch arm64 x86_64
cp "$MD2NOTES_ROOT/resources/Info.plist" "$MD2NOTES_APP_PATH/Contents/Info.plist"
cp "$MD2NOTES_ROOT/resources/transform.js" "$MD2NOTES_APP_PATH/Contents/Resources/"
cp "$MD2NOTES_ROOT/vendor/marked/marked.js" "$MD2NOTES_ROOT/vendor/marked/Marked-LICENSE.txt" "$MD2NOTES_APP_PATH/Contents/Resources/"
cp "$MD2NOTES_ROOT/tests/markdown-fixture.md" "$MD2NOTES_APP_PATH/Contents/Resources/"
cp "$MD2NOTES_ROOT/docs/guide.md" "$MD2NOTES_APP_PATH/Contents/Resources/md2notes-guide.md"
codesign --force --sign - "$MD2NOTES_APP_PATH"
codesign --verify --deep --strict "$MD2NOTES_APP_PATH"
"$MD2NOTES_APP_PATH/Contents/MacOS/md2notes" --self-test
# On Apple Silicon with Rosetta, also test the Intel slice.
if [[ "$(uname -m)" == arm64 ]] && arch -x86_64 /usr/bin/true 2>/dev/null; then
  arch -x86_64 "$MD2NOTES_APP_PATH/Contents/MacOS/md2notes" --self-test
fi
