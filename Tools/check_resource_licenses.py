#!/usr/bin/env python3
"""Verify committed suggestion assets against their documented provenance manifest."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
manifest = json.loads((ROOT / "Tools/suggestion-data-manifest.json").read_text())
assert manifest["generator"] == "Tools/build_suggestion_data.py"
required = {"DictionaryCredits.txt", "en.orthlex", "uk.orthlex",
            "en-context.json", "uk-context.json"}
assert required == set(manifest["assets"]), "Suggestion asset inventory changed"
for name, expected in manifest["assets"].items():
    path = ROOT / "Core/SuggestionData" / name
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    assert actual == expected, f"Checksum mismatch: {name}"
    if name.endswith("-context.json"):
        payload = json.loads(path.read_text())
        assert payload["license"] == "CC-BY-SA-4.0", name
        assert "credits" in payload, name
    if name.endswith(".orthlex"):
        assert path.read_bytes()[:8] == b"ORTHLEX1", name
credits = (ROOT / "Core/SuggestionData/DictionaryCredits.txt").read_text()
for term in ("wordfreq", "SCOWL", "VESUM", "English EWT", "UA-GEC", "CC BY-SA 4.0"):
    assert term in credits, f"Missing provenance: {term}"
icons = [
    ROOT / "Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png",
    ROOT / "Resources/Assets.xcassets/KeyScratchIcon.imageset/KeyScratchIcon.png",
]
assert all(p.exists() and p.read_bytes()[:8] == b"\\x89PNG\\r\\n\\x1a\\n" for p in icons)
assert icons[0].read_bytes() == icons[1].read_bytes(), "App icon copies differ"
print("Suggestion-data hashes, embedded licenses, attribution and app icons verified.")
