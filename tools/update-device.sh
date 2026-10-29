#!/bin/sh
# Refresh the iPhone test sources without regenerating the Xcode project.
# Intended for ZIP checkouts of feature/scratchpad-first-pass.
set -eu

cd "$(dirname "$0")/.."
if [ ! -d KeyboardExtension ] || [ ! -d SharedUI ] || [ ! -d App ]; then
    echo "Run from a Key Scratch project checkout with KeyboardExtension, SharedUI and App folders." >&2
    exit 1
fi

BASE="https://raw.githubusercontent.com/udeudeude/Key-Scratch/feature/scratchpad-first-pass"
fetch() {
    target=$1
    temp="$target.download.$$"
    echo "Updating $target"
    if ! curl --fail --location --silent --show-error --retry 2 "$BASE/$target" --output "$temp"; then
        rm -f "$temp"
        exit 1
    fi
    if [ ! -s "$temp" ]; then
        echo "Empty download for $target" >&2
        rm -f "$temp"
        exit 1
    fi
    mv "$temp" "$target"
}

fetch "KeyboardExtension/ScratchpadView.swift"
fetch "KeyboardExtension/KeyboardViewController.swift"
fetch "SharedUI/SuggestionBar.swift"
fetch "KeyboardExtension/Info.plist"
fetch "App/Info.plist"

echo ""
echo "Updated. Keep your existing Xcode project and signing team."
echo "In Xcode: Product > Clean Build Folder, then Run (Command-R)."
echo "On iPhone: Settings > General > Keyboard > Keyboards > Key Scratch > Allow Full Access for clipboard."
