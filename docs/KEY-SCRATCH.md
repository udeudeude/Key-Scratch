# Key Scratch: iPhone keyboard with a local scratchpad

A fork of Ortholinear that adds a note panel beside its offline swipe keyboard. Development branch: `feature/scratchpad-first-pass`; draft PR #1. Keep main/upstream Ortholinear intact while the fork is tested on-device.

## Working design from the first real iPhone XS Max experiment

Five color-coded modes remain available in the companion app's **Key Scratch Lab**. Recorded single-swipe badge times were approximately Blue 12 ms, Red 10–15 ms, Green 12 ms, Amber 10 ms, Purple 15 ms. The user reported no noticeable lag in any mode; disabling suggestions did not help, and Purple's notes were too narrow. **Green, about 30% note width, with live suggestions, is the preferred starting configuration.**

Mode comparisons: Blue ↔ Red tests the added panel; Red ↔ Green tests the independent glide worker; Green ↔ Amber tests live prediction; Green ↔ Purple tests panel width. Treat the milliseconds as individual local timing samples, not statistical benchmarks.

## Note editing

- Tap text in the narrow notes area to direct Ortholinear typing and swipe recognition to that area. Keyboard suggestions and text replacements also apply to notes.
- Tap twice to select a word, or three times to select a paragraph. Gesture handling gives higher tap counts priority, but requires another physical-device test. Long-press a word for a floating edit menu; **Select Paragraph** there provides a more reliable fallback.
- Long-press the note for **Copy, Cut, Paste, Select All, Select Paragraph, Insert in App**, or a guarded **Clear…** submenu. These are actions on the scratchpad, not the app above the keyboard. Copy/Cut/Paste require Allow Full Access.
- Changing focus to a host app is automatic when iOS informs the extension about a text-field or selection change. An unchanged-caret tap into the already-selected host field may not generate a notification. A small upper-right arrow in the notes area is the reliable fallback.
- Notes are stored locally. Older extension-only notes are migrated to the local App Group on the first launch of the updated keyboard. The extension also keeps a local fallback copy.

### Full-size note editor

Open the **Key Scratch** companion app and choose **Scratchpad**. This presents the same note in an ordinary iOS text editor, with native selection, Paste, Copy All, **Share / export**, and a confirmed Clear action. Edits are saved locally and are loaded into the split keyboard when it next appears. If the shared note hasn't yet been migrated, the companion editor protects the existing note by asking you to open the upgraded keyboard once before editing.

This is local device sharing, not cloud syncing. Export important notes periodically until persistence has been thoroughly verified.

## Allow Full Access

The keyboard extension has `RequestsOpenAccess: true`, but iOS requires the user to authorize it:

**iPhone Settings → General → Keyboard → Keyboards → Key Scratch → Allow Full Access → On.** Then switch away from Key Scratch and back. The containing app can't change this switch.

Full Access is used for keyboard **UIPasteboard** operations and writing the shared local App Group note. It permits broader capabilities at the iOS sandbox level, but this fork doesn't upload typed words, notes or clipboard contents; no networking code is used for the keyboard's typing features. See [PRIVACY.md](../PRIVACY.md).

## Native iOS behavior improvements awaiting physical device verification

- Swiping inserts a temporary trailing separator, preventing manually typed letters from joining the word. Punctuation can replace that separator.
- Standalone English lowercase "i" becomes "I" at a word boundary, while "inside" remains lowercase.
- English long-press accents are available; the popup now appears near the held key. Holding and releasing unchanged types the original letter; horizontal drag chooses accents.
- First Delete immediately following a glide removes the entire most recently swiped word if the caret still matches; later Deletes use normal character deletion.
- Press-and-hold Space activates cursor movement, including up/down through the scratchpad's rendered soft-wrapped lines. For text fields in other apps, Apple provides only a text proxy, not their visual line layout: this implementation handles explicit newlines but cannot precisely match all visual line wraps.
- An enabled-by-default "iPhone key positions" option puts Shift / #+= at the lower-left of the third row, Delete at its right, and Return in the lower-right control position on every page. Ortholinear's original geometry remains available in the Lab.
- The scratchpad now applies punctuation spacing and quick-double-space period rules too.

## Updating the existing signed Xcode checkout

In Terminal, inside the extracted project folder that already builds on the iPhone:

```sh
curl -fL https://raw.githubusercontent.com/udeudeude/Key-Scratch/feature/scratchpad-first-pass/tools/update-device.sh -o update-key-scratch.sh
sh update-key-scratch.sh
```

The script replaces existing source and plist files, preserving the local Xcode project and signing settings. It backs up and updates the Run scheme to optimized **Release**, since comparing an unoptimized Xcode Debug build to App Store Ortholinear can exaggerate perceived latency.

Reopen `Ortholinear.xcodeproj`, select **Product → Clean Build Folder**, then **Command-R** to build/install on the plugged-in iPhone. Do not run XcodeGen again just to update these files: project regeneration may reset signing.

Then enable Full Access in iOS Settings, open the keyboard once to migrate old notes, and open the companion app's full-size Scratchpad. Try Green before adjusting dimensions.

## Outstanding verification

The source is committed but these refinements are not yet fully device-tested. Verify compile and Swift core tests in GitHub Actions, then test long-press accents, three-tap paragraph selection, long-press menu Copy/Paste, full-size note persistence, capitalization, swipe spacing/undo, shifted key positions, and Space trackpad. Keep original notes backed up, as this is an experimental build. Secure text fields and apps that reject third-party keyboards remain outside the keyboard extension's control.

See [the detailed acceptance tests](IOS_KEYBOARD_BEHAVIOR.md).
