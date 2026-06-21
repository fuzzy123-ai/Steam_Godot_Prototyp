# SPIDER PREVIEW CAMERA ABC

Goal: make the Spider Mech visibly playable as its own unit, make the lobby map preview render from the selected/default seed, and switch gameplay framing to a readable angled top-down camera.

Current evidence:
- `spider_mech_definition.tres` selects `spider_mech_visual.tscn` and sets `hide_default_visuals = true`.
- `tank_game.gd` currently hides only `LowPolyBody`, leaving the default turret visible.
- `spider_mech_visual.tscn` scales the FBX model to `0.008`, which is likely too small beside the default tank rig.
- `map_preview_renderer.gd` calls `apply_seed()`, but `terrain_world.tscn` disables generated preview mesh rebuild by default and its `PreviewMesh` starts hidden.
- `tank_game.tscn` already uses an angled orthographic camera, but the requested read is more clearly diagonal/isometric.

Non-goals:
- No Steam lobby refactor.
- No multiplayer authority rewrite.
- No final leg animation blend tree.
- No unrelated VFX, projectile, runbook, or AGENTS cleanup.

Stop rules:
- Stop on unrelated staged files, secrets, destructive git, or scope creep.
- Stop on any Godot `ERROR:` output that cannot be fixed within this roadmap.
- Stop rather than overwrite unrelated dirty edits in files touched by earlier work.

Slices:
- ABC0-roadmap: record scope, risks, verification, and Go language.
- ABC1-spider-visual: hide default tank meshes for visual overrides and scale/position the Spider Mech so it is visible in match.
- ABC2-spider-movement: add a data-driven `walker` movement mode with camera-relative omni movement and body turn toward travel direction.
- ABC3-map-preview: force preview terrain to generate visible preview mesh from default/typed seed.
- ABC4-camera: tune match camera to a more diagonal angled top-down view.
- ABC5-verification: run focused script parser checks and headless scene smoke checks with the console Godot binary and prepared log directory.

Verification:
- `--check-only --script` for changed scripts.
- Headless boot of `res://scenes/tank_game/tank_game.tscn` with no `ERROR:` lines.
- Headless probe that selects `spider_mech` and confirms default turret meshes are hidden and a visible override mesh exists.
- Headless probe that applies lobby preview seed and confirms `PreviewMesh.visible == true` and has a mesh.

Release language:
- Go: Spider selection shows the mech model, the default turret is not visible, Spider movement is walker-like, preview renders for default and typed seed, and camera framing shows terrain depth.
- Partial: one visual/manual gate remains but parser and smoke checks are clean.
- No-Go: any Godot `ERROR:` remains or Spider/preview cannot be proven visible.
