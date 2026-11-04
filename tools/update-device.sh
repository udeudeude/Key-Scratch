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
# An older generated project may not compile newly added Swift files even
# when they are downloaded into its folder. Detect that before replacing files.
if [ -f Ortholinear.xcodeproj/project.pbxproj ] && \
   ! grep -q 'ScratchpadView.swift' Ortholinear.xcodeproj/project.pbxproj; then
    echo "Your signed Xcode project does not include ScratchpadView.swift." >&2
    echo "Add KeyboardExtension/ScratchpadView.swift to the OrtholinearKeyboard target in Xcode before updating." >&2
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

# Refresh the full Swift core, not only the files changed in the earliest
# prototype. Otherwise a signed checkout can silently retain stale behavior.
fetch "Core/AutoCapitalization.swift"
fetch "Core/CustomLayout.swift"
fetch "Core/DeleteRepeat.swift"
fetch "Core/GlideDecoder.swift"
fetch "Core/KeyboardAppearance.swift"
fetch "Core/KeyboardModel.swift"
fetch "Core/LanguageMemory.swift"
fetch "Core/LayoutRecovery.swift"
fetch "Core/PunctuationSpacing.swift"
fetch "Core/Suggestions.swift"
fetch "Core/TextExpansion.swift"
fetch "Core/TextNavigation.swift"
fetch "SharedUI/PreferenceStore.swift"
fetch "SharedUI/KeyboardView.swift"
fetch "SharedUI/KeyboardPalette.swift"
fetch "SharedUI/KeyboardTips.swift"
fetch "App/AppearanceSettings.swift"
fetch "App/LanguageSettings.swift"
fetch "App/SuggestionSettings.swift"
fetch "App/LayoutWorkshop.swift"
fetch "App/OrtholinearApp.swift"
fetch "App/ContentView.swift"
fetch "App/PreviewSurface.swift"
fetch "KeyboardExtension/ScratchpadView.swift"
fetch "KeyboardExtension/KeyboardViewController.swift"
fetch "SharedUI/SuggestionBar.swift"
fetch "SharedUI/SystemSuggestions.swift"
fetch "App/ProHooks.swift"
fetch "KeyboardExtension/Info.plist"
fetch "App/Info.plist"
# The app icon is a binary PNG. Download it atomically rather than treating it
# as Swift source; keep signed local project intact.
fetch "Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
# A normal image set is required for UIImage/SwiftUI Image lookup; the special
# AppIcon asset cannot be loaded by Image("AppIcon") in the app's header.
mkdir -p "Resources/Assets.xcassets/KeyScratchIcon.imageset"
fetch "Resources/Assets.xcassets/KeyScratchIcon.imageset/Contents.json"
fetch "Resources/Assets.xcassets/KeyScratchIcon.imageset/KeyScratchIcon.png"

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
echo "Open Key Scratch on iPhone: Scratchpad for full-size notes, or Scratchpad & layout for portrait settings."
echo "Open the updated keyboard once before using the companion Scratchpad, to migrate old notes."
echo "For Copy/Paste and shared notes: iPhone Settings > General > Keyboard > Keyboards > Key Scratch > Allow Full Access."
echo "Reopen the keyboard after changing permissions or layout settings. Rotate the phone to test compact landscape mode."
