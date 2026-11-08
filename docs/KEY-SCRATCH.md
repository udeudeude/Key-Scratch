# Key Scratch: iPhone keyboard with a local scratchpad

A fork of Ortholinear that adds a note panel beside its offline swipe keyboard. Development branch: `feature/scratchpad-first-pass`; draft PR #1. Keep main/upstream Ortholinear intact while the fork is tested on-device.

## Current design

The temporary five-color mode comparison is complete and **the colored modes and latency badge are removed**. The normal keyboard uses the responsive dedicated swipe worker, live suggestions and one adjustable split. Older color-mode preferences automatically migrate to the standard layout. The companion app now has a straightforward **Scratchpad & layout** settings screen instead of the Experiment Lab.

**Portrait:** notes on the left at 30% width by default; the setting remains adjustable. The right-hand keyboard keeps the same geometry and tappable hit targets.

**Landscape:** rows are reduced to at most 34 pt, the bottom controls to 32 pt, and the suggestion strip to 30 pt, with 2 pt visual row spacing and no extra header. This yields an approximately **172 pt** keyboard, about 17% shorter than the previous 208 pt landscape layout, without disabling predictions. The keyboard is positioned at the **right edge of the keyboard extension**, at a usable width of about 390–430 pt. Every remaining point of the extension's width belongs to the scratchpad at left and center. This never overwrites portrait settings. Apple's own globe and microphone controls may occupy reserved areas outside the extension; third-party keyboards cannot move those system controls.

The scratchpad now has a thin neutral border and 6 pt rounded corners matching the keycaps, with a subtle blue active-focus border. The new app icon refers to a **metal key scratching dark car paint**, rather than a computer keyboard key.

## The ★ character finder

Tap ★ for a lightweight finder with **Favorites**, **Symbols**, and **Wrap**. Favorites offers recently inserted and saved characters. Symbols has a broad offline catalog of arrows, mathematics, typography, shapes, technical signs, currency, numbers, mathematical lettering, phonetics, Greek and other letters, music, braille, and emoji. Pick a category and scroll. The catalog is loaded lazily only when ★ opens, and its scrolling grid reuses cells.

Tap the **search line** to type a name with the built-in miniature search keypad. This search does not type into the host text field. Tap **Results** to see matches for phrases like `therefore`, `arrow right` or `mathematical script small x`, or type a hexadecimal code such as `u2192` or `u+2192`. Tap the search line again to refine it, or **Clear** on the keypad to search afresh. Wrap offers quotes, parentheses, brackets, braces, asterisks, Markdown delimiters and up to twelve custom pairs from the companion app.

**Close without inserting:** the × key replaces ★ in **the exact original key position** at the bottom of the keyboard, in portrait and landscape. Tapping × closes ★ without changing the document or its selection. Inserting a character or wrapping text closes the panel automatically. The in-app preview uses the same interface. This is a substantial curated Unicode repertoire rather than all Unicode or Apple's proprietary emoji features; invisible modifiers and control characters are omitted.

## Multiple note pages and send-to-app

The scratchpad now has **three permanent, compact numbered tabs** at the bottom without a +. Pages 4–8, if previously created or added in the full-size companion app, remain accessible through an overflow ⋯ menu. No existing pages are removed; old notebooks with fewer than three pages are padded with empty pages. Each tab has independent text, selection and scroll position when reopened. The companion app's **Scratchpad** editor has corresponding page tabs, add, clear-current-page and delete-page controls.

On first use of the new notebook, the previous one-page note is preserved verbatim as **page 1**. The original note remains in legacy storage as a fallback rather than being destructively migrated. The new notebook is saved to the existing private App Group, with each edit updating only its own page so notes in other pages are not overwritten.

The **arrow in the bottom-right scratchpad toolbar**, after the three tabs (and optional overflow), is an insertion action: insert the selected text into the host app, or the entire active note page when no text is selected. It has a larger 36 pt touch target and an explicit accessibility label. The button no longer merely deactivates note editing. The existing custom menu **Insert in App** calls the same transfer function.

### Page image shelf and direct image pasting

Every scratchpad page has an image shelf, separate from editable text.

1. **Paste copied pictures directly:** Copy a photo or picture in Photos, Safari, Files, or another app. In the compact Key Scratch keyboard, tap the **image with a downward arrow** at the beginning of the shelf just above the page tabs, even when the shelf is empty. This imports an image **from the clipboard into the current scratchpad page**; it does not copy an image out of the scratchpad. Alternatively choose **Paste** in the scratchpad's text-selection menu. In the full-size companion **Scratchpad**, tap **Paste image** beside **Add images**. The picture is saved on the current page as an attachment, not inserted among the words.
2. **Import from Photos:** In the companion app, use **Add images** to select up to eight at a time through the system Photos picker. This button is in the full-size companion editor, not the keyboard extension.
3. Images from both paths are downscaled to a maximum dimension of **1,200 px** with separate **180 px** thumbnails. Both JPEG files live in the private App Group `ScratchpadImages/` folder. Each page has a limit of **12 images**. The copied/selected originals are left untouched.
4. In the compact keyboard, tap a thumbnail to **copy it back to the iOS clipboard** for pasting into a host app that accepts images. Hold a thumbnail to preview. To **remove** an image, hold its thumbnail, choose **Remove image…**, then **Confirm removal**. The same long-press menu also offers Preview. In the companion app, tap a thumbnail to preview, or hold it for Copy and Remove from page (with confirmation). This deletes only the saved attachment and thumbnail, not your original photo.
5. **Allow Full Access** is needed to paste or copy clipboard images through the keyboard extension. The companion app can paste directly without that keyboard permission. If the clipboard contains text, ordinary **Paste** in the scratchpad menu still pastes text; the explicit shelf button only accepts pictures.
6. Deleting an image or its page removes the associated local image copies once the updated notebook is saved. Earlier notebooks without image metadata retain their text and page selections.

The shelf occupies only **28 pt** with a compact import icon on empty pages, expanding to **45 pt** for the thumbnails. The keyboard normally decodes only small thumbnails, opening the full image on deliberate preview or Copy. No network uploads, background image processing in the keyboard extension or rich-text conversion.

Images **cannot be inserted directly into another app** via `UITextDocumentProxy.insertText`; that Apple API accepts text. Sending a saved image outward uses explicit Copy followed by Paste in the receiving app.

## Handedness and optional native terminal appearance

The **Scratchpad & layout** settings screen includes **Left-handed layout** (off by default). When enabled, the letter keyboard takes the left side and the scratchpad occupies the right. The split reverses in both portrait and landscape, while existing width and height settings remain unchanged.

The scratchpad's rounded outline now traces **only its top and two side edges**, using the *exact background color behind the keys* from the active keyboard theme, including its dark appearance. There is no bottom outline.

The **Scratchpad appearance** picker has four choices: Standard, Terminal · green, Terminal · amber and Terminal · composite TV. The three terminal palettes adapt the display from the user's [Temporarily Leave the Universe](https://github.com/udeudeude/Temporarily-Leave-the-Universe) project: near-black glass, Courier-style monospaced phosphor text, low-contrast 4 pt scanlines and static, softly illuminated corners. The underlying editor remains the **same selectable and locally saved UITextView**. The terminal does **not** import that project's game, JavaScript, network-served font, or WebView. These are native UIKit rendering choices with fixed overlays and no animation timers. Terminal style remains opt-in to minimize unnecessary rendering cost.

The source repo's interface license is AGPL-3.0-or-later for independently authored interface work, with distinct reservations for third-party game content. This is a native adaptation of its visual vocabulary; no Eamon game text or graphic artwork is copied.

## iPhone-style controls and language switching

Tap the compact note panel to type there. Tap a host-app text field to return typing to the app. The bottom-row **★** opens the favorites panel and inserts into the active destination. The eight most recent characters surface first. To populate favorites, use **Scratchpad & layout → Browse & manage favorites**: browse categories of symbols and emoji, search by name, tap to add/remove, or type/paste arbitrary characters with Apple's standard Emoji keyboard. Up to 48 favorites are stored locally. Hold ★ to cycle enabled languages. Apple's native emoji keyboard is available in the companion app's entry field but cannot be embedded into the custom keyboard extension.

The space bar reads **space**. The system globe still opens the next enabled iOS keyboard or a keyboard chooser on hold. To use Apple's Emoji keyboard, enable that keyboard in iOS Settings and switch to it with the globe. Key Scratch cannot open Apple's Emoji keyboard directly, and does not pretend otherwise.

English is now the default for new installs. Existing default UA+EN setups migrate to English first while retaining Ukrainian as an enabled optional language. Additional layouts remain available in Settings, with no unrelated language gate.

iPhone-style light/dark keyboard colors and keycap shadows are the default; alternate themes remain under Appearance. The companion app now uses iOS system colors and a distinct metal-car-key icon. A visible blue selection highlight is drawn over ranges selected in the compact notes editor.

## Default spacing and typing behavior

Key Scratch's standard configuration uses **8 pt row gaps** and **3 pt column gaps**. Existing installations with the old untouched 2 pt gaps migrate to the new values; deliberately customized gap sizes are preserved. The Scratchpad & layout screen exposes both controls.

Tiny numbers and accented-letter hint labels are **hidden by default**, without disabling their actions: short downward flicks on top-row letters still type digits when digit flicks are enabled, and pressing/holding letters still displays accented alternatives. To show hints again, enable **Appearance → Key hints**.

English long-press menus put two mathematical letterforms first for **every A–Z key**: script (for example, 𝓍 and 𝓃) and bold italic (𝒙 and 𝒏). Familiar accented forms remain available after them; earlier experimental phonetic and subscript additions are omitted to avoid crowded menus. Shift converts these styled lowercase letters into the corresponding styled capitals. Other language layouts keep their own long-press options, and custom key alternatives take precedence. Built-in punctuation menus do not repeat the original key; holding **?** offers ¿, ‽ and ⸘, without a redundant !.

As on the iPhone keyboard, a tap on **space** from the 123 or #+= page switches back to the letter page, in both the host app and the compact scratchpad. User-created additional key pages stay open.

Hyphens and similar joining punctuation now attach directly to the preceding glided or suggested word, rather than retaining an unwanted automatic space. This covers hyphens and other dashes, slashes, apostrophes, closing brackets and typographic closers, plus percent and degree signs. Automatically added spaces are removed when appropriate, but a space the person explicitly typed is preserved. A following glide after a hyphen or slash also attaches without an unwanted leading space.

## Note editing

- Tap text in the narrow notes area to direct Ortholinear typing and swipe recognition to that area. Keyboard suggestions and text replacements also apply to notes.
- Tap twice to select a word, or three times to select a paragraph. Gesture handling gives higher tap counts priority, but requires another physical-device test. Long-press a word for a floating edit menu. Triple-tap selects the paragraph directly, so the redundant **Select Paragraph** menu entry is removed.
- Long-press the note for **Copy, Cut, Paste, Select All, Select Paragraph, Insert in App**, or a guarded **Clear…** submenu. These are actions on the scratchpad, not the app above the keyboard. Copy/Cut/Paste require Allow Full Access.
- Changing focus to a host app is automatic when iOS informs the extension about a text-field or selection change. An unchanged-caret tap into the already-selected host field may not generate a notification. The send-to-app arrow at the bottom-right of the scratchpad, alongside the page tabs, is the reliable fallback.
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
- English long-press accents and mathematical script/italic letterforms are available; the popup now appears near the held key. More than seven options use a two-row popup to avoid excessively narrow choices on iPhone. Holding and releasing unchanged types the original letter; drag across the popup to choose a variant.
- First Delete immediately following a glide removes the entire most recently swiped word if the caret still matches; later Deletes use normal character deletion.
- Press-and-hold Space activates cursor movement, including up/down through the scratchpad's rendered soft-wrapped lines. Small slides use finer 15 pt character steps after a 6 pt dead zone; longer drags accelerate and movement produces subtle selection feedback. For text fields in other apps, Apple provides only a text proxy, not their visual line layout: this implementation handles explicit newlines but cannot precisely match all visual line wraps.
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

Then enable Full Access in iOS Settings, open the keyboard once to migrate old notes, and open the companion app's full-size Scratchpad. Test scratchpad/host tap focus, the ★ favorites panel and landscape resizing before adjusting dimensions.

## Outstanding verification

The source is committed but these refinements are not yet fully device-tested. Verify compile and Swift core tests in GitHub Actions, then test long-press accents, three-tap paragraph selection, long-press menu Copy/Paste, full-size note persistence, capitalization, swipe spacing/undo, shifted key positions, and Space trackpad. Keep original notes backed up, as this is an experimental build. Secure text fields and apps that reject third-party keyboards remain outside the keyboard extension's control.

See [the detailed acceptance tests](IOS_KEYBOARD_BEHAVIOR.md).
