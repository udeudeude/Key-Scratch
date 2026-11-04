# Key Scratch

A custom iPhone keyboard with an always-visible, editable scratchpad. Built from the open-source **Ortholinear** keyboard, retaining its swipe recognition, optional languages, and local-first design.

## Features

- A compact iOS-style typing area beside **persistent, independent scratchpad pages** (three to start, up to eight). The keyboard shows three compact permanent tabs and no + button. Existing optional extra pages remain accessible through an overflow menu; the companion app offers full-size page editing and page management. Original single-page notes migrate intact to Page 1.
- A **local image shelf on each page**, with a visible **Paste** action in the keyboard and **Paste image** beside **Add images** in the companion app. Copy a picture in Photos, then paste it directly onto the current scratchpad page; it is stored as an attachment rather than inline text. Preview, remove or copy thumbnails for pasting elsewhere. Photos are downscaled, with small thumbnails so normal typing remains responsive. Maximum 12 images per page.
- Tap the **scratchpad** to type into it, or a text field in the host app to type there. The former Notes/App key is now **★ Favorites**: it opens personal one-tap emoji and Unicode symbols, with recent characters first. The companion app's **Scratchpad & layout → Browse & manage favorites** screen offers a searchable, categorized Unicode/emoji library plus text entry using Apple's emoji keyboard and clipboard import. Hold ★ to cycle enabled languages. The system globe still switches among installed keyboards, including Apple's Emoji keyboard.
- Swipe typing, suggested corrections, long-press accents, **0 → °** and numeral holds for Unicode fractions, superscripts and subscripts (including ½ under 2, ⅓ and ⅔ under 3, ¼ and ¾ under 4), punctuation and math holds (‽ and ⸘ on both ! and ?, ÷ on /, × on *, currencies on $, ‰ on %, ≠ and ≈ on =, ¡ on !), optional digit flicks, stable Delete/Return positions, a text-labeled **return** key, blue context-sensitive Go/Search/Send/Done keys, extra URL/email punctuation keys, smart punctuation and spacing.
- Double-tap word selection, triple-tap paragraph selection, and a floating edit menu in the compact scratchpad. Selection is visibly highlighted.
- The scratchpad's bottom-right arrow, positioned beside the page tabs rather than over text, **inserts selected note text into the host app**, or the entire page when nothing is selected. A large touch target and the menu's Insert in App action provide two ways to do it.
- **Full Access**, when the user enables it, permits Copy/Paste and local note sharing with the containing app. The companion app has a full-size note editor and Share/Export. No text is uploaded.
- Portrait: adjustable split (30% notes by default). **Landscape: a 172 pt compact keyboard at the far right**, with the notes filling all remaining extension space to the left. iOS-owned globe, microphone and home-indicator areas are outside the extension's layout.
- **Left-handed layout** reverses keyboard and scratchpad in both orientations, with the same adjustable proportions.
- Optional **CRT scratchpad style** inspired by [Temporarily Leave the Universe](https://github.com/udeudeude/Temporarily-Leave-the-Universe): green phosphor, amber or composite-TV palettes, all rendered natively without a browser or animation loop.
- Thin, rounded scratchpad outline along the top and sides in the same color as the keyboard backing, and familiar iOS system colors. The home-screen icon **and matching in-app header** depict a metal key scratching car paint. English-first sample text replaces the legacy Ukrainian placeholder.

## Install and test on iPhone

The development branch is `feature/scratchpad-first-pass`; don't merge it until on-device testing passes.

For a Mac folder that already contains the signed Xcode project, run these commands **from that folder**:

```sh
curl -fL https://raw.githubusercontent.com/udeudeude/Key-Scratch/feature/scratchpad-first-pass/tools/update-device.sh -o update-key-scratch.sh
sh update-key-scratch.sh
```

Reopen `Ortholinear.xcodeproj` (the existing development project name is kept to preserve local signing), choose **Product → Clean Build Folder**, and press **Command-R**. In iPhone Settings → General → Keyboard → Keyboards → Key Scratch, enable **Allow Full Access** for clipboard and local note sharing. Open the keyboard once to migrate older notes before opening the companion app's full-size Scratchpad.

See [setup, behavior and caveats](docs/KEY-SCRATCH.md) and [device tests](docs/IOS_KEYBOARD_BEHAVIOR.md).

## Platform limitations

iOS controls the system keyboard-switcher controls outside the extension's permitted area. Within the extension, Key Scratch allocates the entire remaining width to the notes in landscape. Third-party keyboards cannot reliably detect every tap that leaves the host app's caret unchanged, or inspect the host app's soft-wrapped text-line geometry. Tap the note or host text field to choose where typing goes.

## Origins

Key Scratch is a fork of [Igor Varyvoda's Ortholinear](https://github.com/IgorVaryvoda/Ortholinear). The codebase retains internal upstream target names and some legacy layout-file identifiers for compatibility. The Ortholinear-derived code retains the [MIT License](LICENSE). Original Key Scratch scratchpad contributions carry separate [non-commercial terms](LICENSE-KEY-SCRATCH-NC.md), where explicitly marked. See the [licensing map](KEY-SCRATCH-LICENSING.md) for scope and outstanding third-party resource checks.
