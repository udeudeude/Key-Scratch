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

## Compact layout and typography

- Key Scratch's ordinary letter rows are now **62 pt** instead of 72 pt; the control row is **48 pt** instead of 56 pt, and the suggestion strip is **36 pt** instead of 44 pt. Row spacing is also reduced. In its standard configuration the combined keyboard is approximately **278 pt** tall instead of **328 pt** (about **15% shorter**).
- Existing geometry that matches untouched Ortholinear factory defaults migrates to these shorter values. Deliberately customized sizes are retained. The **Big letters** preset still offers the original 72 pt rows.
- The notes now use **11 pt San Francisco system text (medium weight)** rather than 10 pt monospaced text. Smaller insets preserve room for more characters in the narrow panel.
- The notes control bar is 42 pt instead of 48 pt.
- You can adjust row and key heights later through the companion app's keyboard geometry settings. If you choose larger rows, the suggestion strip returns to 44 pt.

## Lag investigation

The unmodified Ortholinear app is responsive on the same iPhone XS Max. That makes Key Scratch's added geometry, note UI, or suggestion routing the likely regression. Our current hypothesis is that suggestions and swipe decoding contend for work. The fork now runs glide decoding independently at high priority, warms its dictionary when the language changes, and avoids forced suggestion rebuilds on every note character. This is **not yet a measured fix**: compare original Ortholinear and the new Key Scratch directly on-device using the same phrases, and inspect the Xcode console for non-text glide-to-insertion timing.

## Experiment lab (in the companion app)

Open **Key Scratch > Key Scratch Experiment Lab**. Select one color-coded mode, change the sliders, then press **Apply and test**. The included TextEditor invokes the real installed third-party keyboard. Use the iOS globe key to switch to Key Scratch. Switch to another keyboard and back after applying changes so iOS creates/reloads the extension and reads the shared settings again. You can do this without recompiling.

The five modes deliberately attack different hypotheses:

| Color / name | Notes width | Swipe implementation | Live suggestions |
| --- | --- | --- | --- |
| Blue · Full width | 0% | Original shared worker | On |
| Red · Shared split | Adjustable (default 30%) | Original shared worker | On |
| Green · Split | Same width as Red | Independent prioritized worker | On |
| Amber · Quiet | Same width as Green | Independent prioritized worker | Off |
| Purple · Narrow notes | 10 percentage points narrower than Green (minimum 16%) | Independent prioritized worker | On |

Compare Blue versus Red to isolate the notes panel; Red versus Green to isolate the glide worker; Green versus Amber to isolate live suggestions; and Green versus Purple to isolate keyboard width. Use the same words, language and geometry settings for each pair.

The keyboard displays a **matching colored label**; after a successful glide, that label shows the locally measured glide-to-insertion time in milliseconds. It records no words. Use **Copy configuration** in the lab to report exact settings. Never compare modes using different language/dictionary layouts without noting that difference.

Lab controls: notes width (18–42%), note font size (9–16 pt), system text / rounded / serif / monospaced fonts, letter-row height, control-row height, row spacing, and an English-only shortcut. The original Ortholinear languages remain in the project, even if English is the only one enabled.

**Performance caveat:** The App Store's Ortholinear is a Release-optimized build, while Xcode normally Runs in unoptimized Debug. The device update script automatically backs up the generated Xcode scheme and changes *Run* to optimized Release so perceived lag can be compared fairly. Debug build settings are preserved for testing. If you regenerate with XcodeGen, the project.yml Run scheme also selects Release.

Settings use Ortholinear's App Group file. If Xcode signing prevents App Group access, the app reports that sharing failed rather than pretending the keyboard received the new settings. In that case fix signing before relying on A/B comparison.

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
