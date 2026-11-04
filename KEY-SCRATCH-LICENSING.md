# Key Scratch licensing map

## Inherited Ortholinear code

The existing [MIT License](LICENSE) remains in force for Ortholinear and its derived portions, including edits made in inherited Swift files. Its copyright notice must be retained. The MIT grant allows commercial use, sale and redistribution of those portions.

## Original Key Scratch material

- `KeyboardExtension/ScratchpadView.swift`: a file introduced on the Key Scratch development branch (not present in the upstream baseline). Original portions owned by Key Scratch contributors carry the separate [Key Scratch Non-Commercial License](LICENSE-KEY-SCRATCH-NC.md), identified by a file-level notice. Any copied or third-party portions retain their previous rights.
- `Resources/Assets.xcassets/KeyScratchIcon.imageset/KeyScratchIcon.png`: introduced on the development branch. **Not relicensed yet**: artwork ownership and any source materials need confirmation.
- `docs/KEY-SCRATCH.md`, `docs/IOS_KEYBOARD_BEHAVIOR.md`: introduced on the development branch. **Not relicensed yet**: their contributions and authorship have not been established.
- `App/ContentView.swift`, `KeyboardExtension/KeyboardViewController.swift`, `Core/*`, `SharedUI/*` and other modified inherited files: contain upstream-derived code and new changes. **No blanket relicensing**; distinguishing original contributions requires a line-by-line provenance audit.

The non-commercial license does not override any MIT permissions for upstream code. It is not an OSI-approved open-source license.

## Third-party and bundled resources

The upstream README states that bundled language data has separate licenses. The development branch also references an external project with AGPL-3.0-or-later interface code in the CRT-style design notes, while stating no game text or artwork was copied. These references do **not** establish rights to relicense language data or imported assets.

Before distributing a packaged build, inventory all bundled dictionaries, word lists, fonts, icons, libraries and other resources, record each source and license, and preserve their notices. The present review did not establish a complete per-resource license inventory.

## Development and publication

The Key Scratch scratchpad implementation was merged into `main` after successful physical iPhone testing. Installation still requires Xcode and developer signing; no App Store release is claimed.

## Resource-audit status

The repository includes language dictionaries and other bundled language data inherited from Ortholinear. Their separate license provenance has not been conclusively established by this review. Preserve all existing third-party notices and do not apply the Key Scratch non-commercial license to those resources. A complete redistribution inventory requires inspecting each bundled file and its upstream source.
