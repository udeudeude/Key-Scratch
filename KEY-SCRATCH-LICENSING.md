# Key Scratch licensing map

## Inherited Ortholinear code

The existing [MIT License](LICENSE) remains in force for Ortholinear and its derived portions, including edits made in inherited Swift files. Its copyright notice must be retained. The MIT grant allows commercial use, sale and redistribution of those portions.

## Original Key Scratch material

- `KeyboardExtension/ScratchpadView.swift`: a file introduced on the Key Scratch development branch (not present in the upstream baseline). Original portions owned by Key Scratch contributors carry the separate [Key Scratch Non-Commercial License](LICENSE-KEY-SCRATCH-NC.md), identified by a file-level notice. Any copied or third-party portions retain their previous rights.
- `Resources/Assets.xcassets/KeyScratchIcon.imageset/KeyScratchIcon.png`: introduced on the development branch. **Not relicensed yet**: artwork ownership and any source materials need confirmation.
- `docs/KEY-SCRATCH.md`, `docs/IOS_KEYBOARD_BEHAVIOR.md`: introduced on the development branch. **Not relicensed yet**: their contributions and authorship have not been established.
- `App/ContentView.swift`, `KeyboardExtension/KeyboardViewController.swift`, `Core/*`, `SharedUI/*` and other modified inherited files: contain upstream-derived code and new changes. **No blanket relicensing**; distinguishing original contributions requires a line-by-line provenance audit.

The non-commercial license does not override any MIT permissions for upstream code. It is not an OSI-approved open-source license.

## Bundled suggestion resources: provenance and license audit (November 2026)

The repository already contains a detailed machine-readable provenance manifest at [Tools/suggestion-data-manifest.json](Tools/suggestion-data-manifest.json), the reproducible generator at [Tools/build_suggestion_data.py](Tools/build_suggestion_data.py), and a comprehensive notice file at [Core/SuggestionData/DictionaryCredits.txt](Core/SuggestionData/DictionaryCredits.txt). These are the authoritative records for the English and Ukrainian suggestion resources.

| Resource | Source and licensing | Distribution |
| --- | --- | --- |
| `Core/SuggestionData/en.orthlex`, `uk.orthlex` | Derived word-frequency data from **wordfreq 3.1.1** (Robyn Speer); generated lexicons identify **CC BY-SA 4.0**. | Bundled binary indexes, with embedded metadata. |
| `en-context.json`, `uk-context.json` | Generated context tables identify **CC BY-SA 4.0**; English EWT training data is CC BY-SA 4.0; UA-GEC training data is CC BY 4.0. | Bundled generated tables with embedded credits. |
| English spelling filter | SCOWL via **spylls 0.1.7**; SCOWL copyright notice retained in credits. | Source dictionary and spylls engine are build-time only. |
| Ukrainian spelling filter | VESUM Hunspell **6.8.5**, Andriy Rysin and contributors, **MPL 1.1**. | Original affix/dictionary files are build-time only. |
| wordfreq code and data | wordfreq code **Apache 2.0**; underlying data has additional CC BY-SA 4.0 and attribution terms, including SUBTLEX and OpenSubtitles. | Python dependency is build-time only; credits are included. |
| Candidate-generation technique | Inspired by SymSpell (Wolf Garbe). | Native implementation, no SymSpell port bundled. |

The generator pins downloaded upstream resources and SHA-256 hashes; the manifest records hashes for the five generated artifacts. The full credits include source URLs, attribution notices and license texts, including the required credit to **Robyn Speer** and the SUBTLEX authors.

**Conclusion for the audited suggestion data:** The generated assets are not proprietary Key Scratch material. Keep them under their stated attribution/share-alike terms and ship the full `DictionaryCredits.txt` with builds. Do not apply the Key Scratch non-commercial license to the generated data. Their terms allow commercial use subject to their conditions, rather than imposing a non-commercial restriction.

**Audit boundary:** This verifies provenance and documented licenses for the bundled English/Ukrainian suggestion assets and their build-time inputs. It does not independently verify the complete contents of every binary asset, artwork ownership, or all dependencies that may be introduced in future builds. Retain the existing credits and re-run the manifest audit when regenerating dictionaries.

The development notes also refer to an external project's AGPL-3.0-or-later interface code as visual inspiration; they state that no game text or artwork was copied. This reference alone does not establish that AGPL code is bundled.

## Development and publication

The Key Scratch scratchpad implementation was merged into `main` after successful physical iPhone testing. Installation still requires Xcode and developer signing; no App Store release is claimed.

