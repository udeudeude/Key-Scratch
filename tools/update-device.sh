#!/bin/sh
# Refresh the iPhone test sources without regenerating the Xcode project.
# Intended for ZIP checkouts of feature/scratchpad-first-pass.
set -eu

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)
if [ -d "$SCRIPT_DIR/KeyboardExtension" ]; then
    cd "$SCRIPT_DIR"
else
    cd "$SCRIPT_DIR/.."
fi
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

fetch "Core/KeyboardModel.swift"
fetch "SharedUI/PreferenceStore.swift"
fetch "Core/PunctuationSpacing.swift"
fetch "Core/Suggestions.swift"
fetch "Core/TextNavigation.swift"
fetch "SharedUI/KeyboardView.swift"
fetch "SharedUI/KeyboardPalette.swift"
fetch "App/AppearanceSettings.swift"
fetch "App/ContentView.swift"
fetch "KeyboardExtension/ScratchpadView.swift"
fetch "KeyboardExtension/KeyboardViewController.swift"
fetch "SharedUI/SuggestionBar.swift"
fetch "KeyboardExtension/Info.plist"
fetch "App/Info.plist"
# The app icon is a binary PNG. Download it atomically rather than treating it
# as Swift source; keep signed local project intact.
fetch "Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

# App Store Ortholinear is optimized. Compare it against an optimized Key Scratch,
# not Swift's (much slower) default Debug configuration.
SCHEME="Ortholinear.xcodeproj/xcshareddata/xcschemes/Ortholinear.xcscheme"
if [ -f "$SCHEME" ]; then
    BACKUP="$SCHEME.before-key-scratch-release"
    if [ ! -f "$BACKUP" ]; then
        cp "$SCHEME" "$BACKUP"
    fi
    /usr/bin/perl -0pi -e 's{(<LaunchAction[[:space:]]+buildConfiguration[[:space:]]*=[[:space:]]*")Debug(")}{${1}Release${2}}s' "$SCHEME"
    echo "Selected optimized Release for Xcode Run (original scheme backed up)."
else
    echo "Could not find scheme. In Xcode: Product > Scheme > Edit Scheme > Run > Build Configuration: Release."
fi

echo ""
echo "Updated. Keep your existing Xcode project and signing team."
echo "In Xcode: Product > Clean Build Folder, then Run (Command-R)."
echo "Open Key Scratch on iPhone: Scratchpad for full-size notes, or Experiment Lab to test modes."
echo "Open the updated keyboard once before using the companion Scratchpad, to migrate old notes."
echo "For Copy/Paste and shared notes: iPhone Settings > General > Keyboard > Keyboards > Key Scratch > Allow Full Access."
echo "Reopen the keyboard after changing permissions or experiment settings."
