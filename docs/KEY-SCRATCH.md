# Key Scratch: experimental keyboard

This fork retains Ortholinear's offline glide engine and adds a local scratchpad occupying 30% of the keyboard width. It is an **unverified prototype**, not a release.

## Current behavior

- The scratchpad is visible to the left of the Ortholinear keys.
- Tap **Edit** to route individual key presses, Space, Return and Delete into the scratchpad. Tap **Done** to resume typing in the host app.
- Tap within the note to move the insertion point. Select text using the text view's normal selection gestures where available.
- **Paste** appends clipboard text outside edit mode or inserts at the caret in edit mode.
- **Copy** copies selected note text or the entire note.
- **Insert** inserts the entire note into the host text field.
- **Clear** erases the local note (currently no undo).
- Notes are stored in the keyboard extension's UserDefaults. Deleting the app can delete the note. They do **not** sync with other devices or the companion app.

## Known gaps

- Glide/swipe typing and word suggestions **inside the scratchpad** are not yet integrated. Glide in the host app is inherited from Ortholinear, but must be tested at 70% keyboard width.
- iOS text replacements are handled by Ortholinear for host-app typing, not yet within the note.
- The scratchpad uses a non-editable UITextView with custom insertion, so that the keyboard does not recursively invoke another system keyboard. Selection and caret placement need device validation.
- The note area is fixed at 30%, font at 10 points. No collapse, adjustable width, multi-note support, sync, or reliable undo.
- Some system text fields (passwords and certain secure contexts) refuse third-party keyboards.
- The prototype has not been compiled or tested on an iPhone.

## Build and test on a Mac

1. Install Xcode from the App Store, launch it once, and install command-line tools if prompted.
2. Clone this repository, then check out the `feature/scratchpad-first-pass` branch.
3. Install XcodeGen (`brew install xcodegen`), then run `xcodegen generate` from the repository root. The checked-in `.xcodeproj` predates the new file and identifiers, so **regeneration is required**.
4. Open `Ortholinear.xcodeproj` and select the `Ortholinear` scheme.
5. Under Signing & Capabilities, choose your Apple Personal Team for **both** app and keyboard extension. Change bundle identifiers and app-group entitlement if your team cannot register the proposed values. They must agree across both targets.
6. Run on a simulator first. Then connect the iPhone and run the app.
7. On the iPhone, open Settings > General > Keyboard > Keyboards > Add New Keyboard > Key Scratch. Switch with the globe key in an ordinary text field.
8. Test the Edit/Done switch, note persistence after leaving and returning to the app, selected-text replacement, delete at Unicode character boundaries, clipboard actions, and host-app glide accuracy.

The GitHub Actions workflow `.github/workflows/ios-build.yml` compiles the simulator target without signing. A simulator artifact is **not** installable directly on a physical iPhone.

## Design principles

Do not request Full Access unless a future feature truly needs it. Do not record text typed into host apps. Keep all note data local by default. Maintain upstream Ortholinear licensing and attribution.
