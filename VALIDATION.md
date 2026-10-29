# Publication verification — 2026-10-29

This is a fresh source snapshot. Private editor/runtime directories, exports, binaries and the
unattributed default engine icon are excluded. Existing game mechanics and procedural audio remain.

## Passed

- Godot **4.7.2.stable.official.ed1daf0bf**, Standard console executable.
- **18 verification stages**, including editor import, main/battle scene smokes and logic/physics suites.
- **363 explicit assertions, 0 failures** across the result-bearing suites.
- Added save-library, cartography, echo-contract and perception suites to `tools/verify.ps1`.
- The input guard is a Node helper for visual tests and is not a standalone SceneTree test.
- Source-only Gitleaks scan completed with no findings; final committed-history scan precedes publication.

All checks ran against this publication copy. APPDATA was isolated in a task-specific temporary
profile; the development project's user saves/settings were not used.

## Not run

Interactive gameplay, GPU/rendering/visual QA, packaging/export and performance acceptance.
Headless checks establish loading and tested logic, not visual quality or a complete finished game.

```powershell
$env:GODOT_BIN = 'path/to/Godot_4.7.2_console.exe'
./tools/verify.ps1
```

The development history is summarized in docs/PROGRESS.md. Earlier historical checks and remaining
features must not be confused with the verification above. Resource provenance: assets/audio/SOURCE.md.
