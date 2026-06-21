# Tank MP VFX ABC Plan

Goal: add a first usable combat-feedback layer for the tank match: muzzle flash on fire, impact burst on projectile hit, smoke/dust after terrain craters, and optional SFX hooks, without changing Steam/lobby behavior.

Current evidence:
- Main scene is `res://scenes/tank_game/tank_game.tscn`.
- Projectile impact flow already exists in `scenes/projectile/projectile.gd` via `impacted(hit_data)`.
- Tank fire flow already exists in `scenes/tank/tank_controller.gd` via `projectile_fired(spawn_data)`.
- Terrain deformation already exists in `scenes/terrain/terrain_world.gd` via `crater_applied(event)`.
- Local asset candidates found:
  - Smoke: `E:/0_Asset Library/Visual FX/Smoke2D/T_smoke_flipbook.png`.
  - Explosion/Dust: `E:/0_Asset Library/Tilesets/Tiny Swords/Particle FX/Explosion_01.png`, `Explosion_02.png`, `Dust_01.png`, `Dust_02.png`.
  - Muzzle/impact packages: `E:/Godot-VFX-Staging/source/MuzzleFlashVFX.zip`, `ImpactVFX.zip`, `SmokeVFX.zip`.
  - SFX: explosion/impact files under `E:/0_Asset Library/Sound FX/`.
- Worktree note: `scenes/player_character/dependencies/robot_model/3DGodotRobot.glb.import` is already modified and is out of scope.

Non-goals:
- Do not redesign Steam/lobby/networking.
- Do not modify `addons/godotsteam`, `addons/godot_mcp`, or vendored controller code.
- Do not import full VFX zip packs in the first slice.
- Do not commit or revert the existing robot import change.
- Do not implement toon shader or water in this VFX slice; keep them as follow-up tracks.

Stop rules:
- Stop on secrets, foreign staged files, destructive git needs, or unrelated hotfile conflicts.
- Stop if Godot import/check requires changing project-level settings outside the allowed scope.
- Stop if an asset license is unclear for files being copied into the repo.
- Stop if focused Godot checks fail and the fix would leave the allowed paths.

Slices:
- ABC0-roadmap: create this plan and delegate path-scoped work.
- ABC1-vfx-contract: define a minimal VFX hook contract and docs/runbook notes.
- ABC2-vfx-implementation: add reusable VFX scenes/scripts/resources and connect projectile/tank hooks.
- ABC3-validation: run script checks and a local tank-scene smoke check; inspect for scope drift.
- ABC4-next-visuals: update the plan with follow-up tracks for toon shader and water after VFX is proven.

First visual test:
- Start `res://scenes/tank_game/tank_game.tscn` locally.
- Fire one tank shot at visible terrain.
- Confirm a short muzzle flash appears at the firing tank.
- Confirm an impact burst appears at the projectile hit point.
- Confirm smoke or dust remains briefly at the crater.
- Confirm the crater still appears once and gameplay flow stays unchanged.

First-slice asset intent:
- Use the smallest local asset subset needed for muzzle flash, impact burst, and crater smoke/dust.
- Prefer existing local candidates listed above before importing larger zip packs.
- Keep SFX hooks optional; no audio mix gate in the first slice.
- Do not include toon shader or water work in this slice. Track both as follow-up visual work after the combat VFX gate is proven.

Paths:
- Alice path: docs/operator wording only.
  - Allowed: `TANK_MP_VFX_ABC_PLAN.md`, `TANK_MP_RUNBOOK.md`.
  - Complete when the user-facing VFX test instructions and Go/Partial/No-Go language are clear.
- Bob path: implementation only.
  - Allowed: `scenes/vfx/`, `assets/vfx/`, `assets/audio/`, `scenes/projectile/projectile.gd`, `scenes/projectile/projectile.tscn`, `scenes/tank/tank_controller.gd`, `scenes/tank/tank.tscn`, `scenes/tank_game/tank_game.gd`, `scenes/tank_game/tank_game.tscn`.
  - Complete when projectile impact and tank fire can spawn local visual effects without changing gameplay authority.
- Charlie path: integration and verification.
  - Allowed: plan file, test commands, narrow fixes in Bob-owned files after handoff.
  - Complete when checks pass and in-scope changes are ready for a focused commit/push or an explicit handoff.

Verification:
- `E:/Godot_With_Steam/tools/godot-4.7/Godot_v4.7-stable_win64_console.exe --headless --path E:/Godot_With_Steam/external/vimayer-steam-local-multiplayer-lobby-template --check-only --script res://scenes/projectile/projectile.gd`
- `E:/Godot_With_Steam/tools/godot-4.7/Godot_v4.7-stable_win64_console.exe --headless --path E:/Godot_With_Steam/external/vimayer-steam-local-multiplayer-lobby-template --check-only --script res://scenes/tank/tank_controller.gd`
- Run the tank scene headless long enough to load, if feasible in the local Godot setup.
- Manual visual gate: fire once in `tank_game.tscn`; expect muzzle flash, impact burst, dust/smoke at hit, no duplicate gameplay crater on clients.

Release language:
- Go: one tank shot shows muzzle flash, impact burst, and crater smoke/dust; focused checks pass; no unrelated files staged.
- Partial: at least one VFX category works, and every missing category has a named blocker and next owner.
- No-Go: runtime errors, broken projectile/crater flow, duplicate crater authority, or unrelated files staged.
- Deferred: toon shader, water, richer imported zip-pack VFX, and full audio mix.
