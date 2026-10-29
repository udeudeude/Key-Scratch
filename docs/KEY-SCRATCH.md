# Key Scratch: local notes and Ortholinear keyboard

An experimental fork of Ortholinear for iPhone. The notes occupy the left 30% of the keyboard while the existing keys and offline swipe recognizer remain on the right.

## Interaction: second iPhone test build

- **Tap anywhere in the notes panel to begin typing into it.** No separate Edit button. Tap **App** to resume typing into the app above the keyboard. The control says **Notes** when the app is active.
- **Swipe typing, individual keys, word suggestions, Backspace, cursor gestures and text replacements** route to the active destination. Swipe decoding has a high-priority worker independent of ordinary suggestion jobs.
- Tap within the note to position the insertion point. Press **Paste** to insert clipboard text at that point.
- **Copy** copies selected text or the entire note when nothing is selected.
- **Insert** inserts selected note text or the entire note into the app above.
- **Hold Clear** requires a long press and permanently erases the note (no undo yet).
- The note persists in the keyboard extension's local UserDefaults, not in the containing app. There is no cross-device synchronization.

## Clipboard permission

Apple's keyboard sandbox requires the optional **Allow Full Access** permission for system clipboard operations. Key Scratch requests eligibility for that permission, but local typing and notes continue to work without it.

On iPhone: **Settings > General > Keyboard > Keyboards > Key Scratch (possibly Ortholinear on earlier builds) > Allow Full Access**. Enable it if you need Copy/Paste. No network requests or uploads are implemented in this fork. When access is off, the clipboard buttons display an explanation instead of failing silently.

## Updating your already-installed development copy

The existing Xcode project includes every Swift file changed by this pass. **Do not regenerate the Xcode project** simply to refresh these files: that may reset your Personal Team signing selection.

In Terminal, inside your extracted Key Scratch project folder, run these two commands:

    curl -fL https://raw.githubusercontent.com/udeudeude/Key-Scratch/feature/scratchpad-first-pass/tools/update-device.sh -o update-key-scratch.sh
    sh update-key-scratch.sh

The script updates only the changed source files and Info.plists, preserving your local Xcode signing choices. Then in Xcode choose **Product > Clean Build Folder**, and press **Command-R** to reinstall on the connected phone.

For a fresh checkout, install XcodeGen, generate the project, select a signing team for the app and keyboard extension, and run.

## Limits and test criteria

- The previous version was built and installed successfully on an iPhone XS Max, but had slow glide insertion and unintuitive note editing. This revision needs a new on-device test.
- Decode performance improvement is a hypothesis until measured. Xcode's Debug console now prints glide-to-text latency in milliseconds without logging the typed words.
- iOS may show a clipboard paste permission prompt.
- The notes intentionally use a selectable, non-editable UITextView with custom keyboard insertion to avoid summoning a second keyboard. Native text-selection gestures and cursor positions need device validation.
- Width is fixed at 30% and text at 10 points. Multi-note support, synchronization, comprehensive undo, and adjustable geometry remain future work.
- Secure text fields and certain host apps do not permit third-party keyboards.
- Avoid storing irreplaceable text until persistence and stability have been verified.

## Privacy

See PRIVACY.md for the fork's local-storage and optional clipboard-access policy. Neither note contents nor typed host-app text are transmitted.
