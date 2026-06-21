# DISPLAY SETTINGS ABC

Goal: add a usable in-game settings entry for resolution, window mode, ESC pause/options, and clean game exit.

Current evidence:
- Main scene is `res://scenes/tank_game/tank_game.tscn`.
- Existing UI lives under the `UI` CanvasLayer.
- `project.godot` already uses canvas stretch with expand aspect.

Non-goals:
- No Steam lobby flow refactor.
- No unrelated Tank/VFX/Runbook changes.
- No platform-specific launcher changes.

Stop rules:
- Stop on unrelated staged files, secrets, destructive git, or edits outside the settings/menu scope.
- Stop if Godot validation requires changing unrelated import assets.

Slices:
- ABC0-roadmap: record scope, risks, and gates.
- ABC1-display-manager: detect system resolution, persist display mode, default to borderless fullscreen, and keep the manager embedded in the settings scene if the editor autoload path is unavailable.
- ABC2-settings-menu: add top-right settings button, resolution and mode controls.
- ABC3-esc-quit: ESC opens menu with continue/options/quit.
- ABC4-verification: validate scripts and run a headless smoke where possible.

Verification:
- GDScript validation for new/changed scripts.
- Godot headless boot of `res://scenes/tank_game/tank_game.tscn` when available.

Go language:
- Go: menu opens from icon and ESC; mode/resolution apply; quit calls lobby cleanup then exits.
- Partial: code validates but runtime smoke is blocked by local editor/runtime limits.
- No-Go: syntax errors, missing autoload, or scene fails to load.
