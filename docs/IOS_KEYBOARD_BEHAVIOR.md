# iPhone-native typing behavior: on-device findings and acceptance tests

## First A/B experiment, October 29, 2026

The iPhone XS Max user tested the optimized, color-coded Key Scratch Lab build:

| Mode | Sample timing | Observed |
| --- | --- | --- |
| Blue (full width, shared worker) | 12 ms | As responsive as App Store Ortholinear |
| Red (split, shared worker) | 10-15 ms | Responsive in host and notes |
| Green (split, dedicated worker) | 12 ms | Feels as responsive as Red |
| Amber (no live suggestions) | 10 ms | No noticeable improvement; missed predictions |
| Purple (narrow notes) | 15 ms | Fine swipe speed, but notes too narrow |

These are individual badge observations, not a statistical latency benchmark. Default to Green's split panel (30%) and preserve suggestions. Swiping performance is no longer the primary blocker.

## Changes after the test (pending compilation and device verification)

1. **Glide spacing:** a swiped word now leaves an owned trailing space, so manual letter-by-letter typing and subsequent swipes don't merge. A following punctuation mark replaces the owned space. One literal Space after a glide accepts the implicit separator without inserting another.
2. **English pronoun:** a swiped "i" is uppercase "I"; typed lowercase "i" is capitalized at a word boundary, including "i'm", without capitalizing the first letter of ordinary words like "inside".
3. **Accented letters:** English built-in QWERTY now supplies long-press alternatives (a, e, i, o, u, c, n, s, y, z and others). The original popup is used for selecting them.
4. **First Delete after glide:** removes the most recently inserted whole swiped word (including its provisional space), only when the caret context still ends in exactly that insertion. A subsequent Delete removes one character. Host edits invalidate the pending whole-word action.
5. **Space-bar trackpad:** a short hold activates trackpad mode. Horizontal drags move by character. Vertical drags in the scratchpad follow the real rendered line layout. In the host text field the public iOS text proxy only exposes text characters; the implementation moves vertically across explicit newline characters, not arbitrary soft-wrapped visual lines.
6. **Consistent iPhone key positions:** the new enabled-by-default setting puts Shift / #+= at the left end of the third row and Delete at the right end on every page. Return remains bottom right. English QWERTY rows have 10, 9 and 7 letters and a centered second row. The previous Ortholinear geometry remains behind an Experiment Lab toggle.

### Additional notes fixes

- **Touch-first scratchpad clipboard:** the Copy/Paste menu words have been removed from the panel. A finger held on text selects a word and opens iOS's floating edit menu with Copy, Cut, Paste, Select All, and Insert in App. The action menu belongs only to the scratchpad, never the host field. Hold empty note space to paste at the caret. Copy/Cut/Paste require optional iOS **Allow Full Access** for the keyboard extension; otherwise the actions are disabled and the menu identifies the missing permission. As with native editing, iOS may ask permission to paste from another app.
- **Automatic host focus:** changes to the host text input, selection, and document identifier cause the scratchpad to stop intercepting typing. An unchanged-caret tap in an already-focused host field may not generate any keyboard-extension notification. In that exceptional case only, a small upper-right icon returns typing to the host. We cannot make arbitrary host taps observable through public keyboard APIs.
- The scratchpad now shares the same punctuation/double-space-period processing as the host app.
- Two taps can select a word, three taps can select a paragraph. These gesture recognizers require physical-device testing.
- Changes to host text input focus are used to switch away from scratchpad editing when possible. The OS does **not** report every tap in the app above a third-party keyboard, especially a tap that leaves the caret unchanged. The App switch stays available as a reliable fallback.
- Clipboard Copy/Paste is restricted by iOS unless the third-party keyboard is granted **Allow Full Access**. Key Scratch provides short error text and an explanation in the Lab. It does not transmit text off-device.

## Device test script

Use the Green configuration with English enabled and the iPhone key-positions toggle on. Use the same real application text field and note editor for each relevant test.

- Swipe "you", then tap "a", then swipe "problem": verify "You a problem", not "youa problem"; try "you and I would like a fix" with the letter I swiped and typed.
- Swipe an intentionally wrong word. Without moving the caret, tap Delete once: the entire word disappears; tap Delete again: prior text loses one character, not a whole second word.
- Swipe "garden" and type "window" character by character. Verify a space remains between them; repeat with punctuation after "garden" and ensure the period attaches.
- Type "i am" and "i'm" in both destinations, and "inside" to check false capitalization.
- Press and hold A, E, O and N. Verify accented alternatives appear and can be selected in the narrow split layout.
- Type two spaces quickly after a manually typed word in notes: expect a period and one space.
- Drag from Space left/right/up/down through several visual lines in the notes field; then test across explicit newlines in the host. Soft-wrapped host lines are a platform limitation.
- Visit letters, 123, #+= and back: Shift / symbols and Delete occupy the same third-row positions, Return is always bottom right. Check that symbols are legible and can be tapped.
- Double tap a note word or triple tap a paragraph. Hold a finger on text and use the floating Copy/Cut menu; hold empty space for Paste. First enable **Allow Full Access** on the iPhone's keyboard settings. No permanent Copy/Paste toolbar should appear.
- Tap the host app text field after working in notes. Typing should return there automatically when the app reports a focus/selection change. If the app gives no notification, use the small fallback icon, and record which host apps exhibit this.

**Status:** Source changes are committed on the feature branch. Do not merge into main until the iOS build and physical-device tests pass.
