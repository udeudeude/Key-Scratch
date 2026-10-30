# Key Scratch

A custom iPhone keyboard with an always-visible, editable scratchpad. Built from the open-source **Ortholinear** keyboard, retaining its swipe recognition, optional languages, and local-first design.

## Features

- A compact iOS-style typing area beside a **persistent local note**.
- Tap **Notes** to type into the scratchpad, **App** to return to the host text field. Hold the button to cycle enabled languages. The system globe is still available for other keyboards, including Emoji.
- Swipe typing, suggested corrections, long-press accents, optional digit flicks, stable Delete/Return positions, smart punctuation and spacing.
- Double-tap word selection, triple-tap paragraph selection, and a floating edit menu in the compact scratchpad. Selection is visibly highlighted.
- **Full Access**, when the user enables it, permits Copy/Paste and local note sharing with the containing app. The companion app has a full-size note editor and Share/Export. No text is uploaded.
- Portrait: adjustable split (30% notes by default). **Landscape: a shorter keyboard at the far right**, with the notes filling all remaining extension space to the left.
- Thin, rounded scratchpad border and familiar iOS system colors. App icon depicts a metal key scratching car paint.

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

iOS controls the system keyboard-switcher controls outside the extension's permitted area. Within the extension, Key Scratch allocates the entire remaining width to the notes in landscape. Third-party keyboards cannot reliably detect every tap that leaves the host app's caret unchanged, or inspect the host app's soft-wrapped text-line geometry. The Notes/App button is a reliable focus control.

## Origins

Key Scratch is a fork of [Igor Varyvoda's Ortholinear](https://github.com/IgorVaryvoda/Ortholinear). The codebase retains internal upstream target names and some legacy layout-file identifiers for compatibility. See the original repository and this repository's `LICENSE` for attribution and licensing.
