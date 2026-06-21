# Tank Multiplayer ABC Roadmap

## Goal

Build a playable Godot 4.7 3D/2.5D Steam multiplayer tank prototype: players host or join a Steam lobby, copy/paste lobby IDs, start a basic match, drive tanks on Terrain3D terrain, fire projectiles, and synchronize host-authoritative crater and damage events.

## Current Evidence

- Project branch: `main`, pushed to `fuzzy/main`.
- Active project path: `E:/Godot_With_Steam/external/vimayer-steam-local-multiplayer-lobby-template`.
- Godot version target: 4.7, Forward Plus.
- Current main scene: `res://scenes/cursor_mvp/cursor_mvp.tscn`.
- Steam base exists in `res://scripts/globals/Online.gd` using GodotSteam, app ID `480`, `SteamMultiplayerPeer`, Steam lobby create/join, friend invite callback handling, and player registry.
- `project.godot` currently sets `3d/physics_engine="Jolt Physics"`.
- Terrain3D is not installed yet.
- ABC1 recommendation: use Terrain3D v1.0.2-stable as a gated addon spike, install to `addons/terrain_3d`, then smoke-test with Godot 4.7 before relying on it.
- ABC3 operator docs exist in `TANK_MP_RUNBOOK.md`.
- ABC2/ABC2b initial foundation exists: `TankGame`, `LobbyStartScreen`, placeholder `TerrainWorld`, `Tank`, and `Projectile` scenes.
- Voxel terrain is intentionally out of scope for the MVP because no tunnels, caves, or terrain overhangs are required.
- Current known unrelated dirty file: `scenes/player_character/dependencies/robot_model/3DGodotRobot.glb.import`.

## Project Preferences

- Prefer node-, scene-, resource-, project-setting-, and inspector-based Godot work.
- Use code only where behavior, networking, terrain mutation, or gameplay logic requires it.
- Keep scenes structured and reusable.
- Prefer proven addons/plugins over reinventing engine-level systems.
- Keep Steam lobby/network bootstrap in `Online.gd` unless a narrow integration point is required.

## Non-Goals

- No voxel engine for the MVP.
- No tunnels, overhangs, caves, or volumetric terrain carving.
- No rewrite of GodotSteam or `Online.gd`.
- No full vehicle-physics framework unless simple tank movement fails.
- No final art, economy, matchmaking browser, teams, persistence, or ranking.
- No edits to unrelated dirty/import files.

## Stop Rules

- Stop on hotfile conflicts or unrelated staged files.
- Stop if a slice would require destructive git commands.
- Stop if secrets, tokens, or private IDs would be committed or logged.
- Stop if Terrain3D is not compatible with the local Godot 4.7 runtime.
- Stop if Terrain3D runtime terrain/collision deformation cannot support MVP crater gameplay.
- Stop if tests fail outside the slice scope and the fix is unclear.
- Stop before pushing if remote, branch, or staged scope is unclear.

## Slices

### ABC0-roadmap

Owner: Charlie

Status: in progress
Completion note:
- Roadmap saved in this file.

Outcome:
- Save this roadmap as the durable ABC execution contract.

Allowed files:
- `TANK_MP_ABC_ROADMAP.md`

Verification:
- `git status --short --branch`
- Completed.

### ABC1-addon-spike

Owner: Bob

Execution mode: explorer
Status: done

Outcome:
- Determine the safest Terrain3D installation path for Godot 4.7 on Windows.
- Confirm whether the addon supports editor terrain creation, collision, runtime height modification, and runtime collision refresh well enough for crater gameplay.

Allowed files:
- Read-only: `project.godot`, `addons/`, `README.md`, `AI_CODEBASE_OVERVIEW.md`, `CURSOR_MVP_RUNBOOK.md`

Forbidden:
- Do not install addon files yet.
- Do not edit vendored GodotSteam or the 3D controller addon.

Verification:
- Read-only findings with exact install recommendation and risks.
- Completed: Bob recommended Terrain3D v1.0.2-stable, with Godot 4.7/D3D12/runtime-collision as explicit smoke-test gates.

### ABC2-scene-foundation

Owner: Bob

Execution mode: worker
Status: partial

Outcome:
- Create the node-first scene foundation for the tank prototype without replacing the current cursor MVP yet.

Expected scenes:
- `res://scenes/tank_game/tank_game.tscn`
- `res://scenes/tank/tank.tscn`
- `res://scenes/projectile/projectile.tscn`
- `res://scenes/terrain/terrain_world.tscn`
- `res://scenes/ui/lobby_start_screen.tscn`

Structure target:

```text
TankGame
├── World
│   ├── Terrain
│   ├── Tanks
│   ├── Projectiles
│   └── Props
├── Cameras
│   └── GameCamera
├── Networking
└── UI
    └── LobbyStartScreen
```

Verification:
- New scenes open in Godot without missing-script errors.
- Scripts pass `--check-only` where present.
- Initial scenes and scripts created; Terrain3D-backed terrain still pending ABC5.

### ABC2b-basic-lobby-screen

Owner: Bob

Execution mode: worker
Status: partial

Outcome:
- Build a basic Steam lobby start screen for early multiplayer testing.

Required UI:
- Host button.
- Lobby ID line edit.
- Copy lobby ID button.
- Paste lobby ID button.
- Join button.
- Start match button.
- Status label.

Behavior:
- Host creates Steam lobby through existing `Online.host_steam_lobby()`.
- Lobby ID is displayed after host success.
- Copy writes lobby ID to clipboard.
- Paste reads clipboard into the join field.
- Join calls `Online.join_steam_lobby(lobby_id)`.
- Start Match is host-only.
- Start Match sends a reliable start event and switches all peers from lobby state to match state.
- For MVP, switching to match may simply hide the lobby UI and spawn/show the empty `TankGame` world.

Verification:
- Host can create lobby.
- Lobby ID can be copied.
- Client can paste and join by ID.
- Client cannot start the match.
- Host can start the match.
- Initial UI scene and behavior exist; two-machine Steam gate still pending manual test.

### ABC3-operator-docs

Owner: Alice

Execution mode: worker
Status: done

Outcome:
- Write operator-facing setup and test instructions for two machines.

Allowed files:
- `TANK_MP_RUNBOOK.md`
- `README.md` only if a short pointer to the runbook is useful.

Required content:
- Godot 4.7 requirement.
- Steam client requirement.
- Spacewar app ID `480`.
- Host, copy lobby ID, paste, join, start match flow.
- Launcher environment variable note.
- Go, Partial, No-Go, Deferred language.

Verification:
- Docs-only slice.
- Completed in `TANK_MP_RUNBOOK.md`.

### ABC4-local-tank

Owner: Bob

Execution mode: worker

Outcome:
- Implement a local tank scene with simple controllable 3D top-down behavior.

Node requirements:
- Root `CharacterBody3D`.
- `CollisionShape3D`.
- `Chassis`.
- `TurretPivot`.
- `Turret`.
- `Muzzle`.
- Exported inspector tuning for speed, reverse speed, turn speed, turret turn behavior, health, and fire cooldown.

Behavior:
- W/S drive forward/reverse.
- A/D rotate chassis.
- Turret aims via mouse ray against ground/terrain.
- Left click emits or calls a fire request.

Verification:
- Local play: tank drives and turret aims.
- Script check passes.

### ABC5-terrain-driving

Owner: Bob

Execution mode: worker

Outcome:
- Integrate Terrain3D or the selected terrain solution enough for tanks to drive over visible 2.5D terrain.

Requirements:
- Terrain setup should be node/resource/inspector based.
- Tank samples terrain height and normal where needed.
- Camera is orthographic top-down or slight isometric.
- Movement stays stable over slopes and shallow craters.

Verification:
- Local play: tank drives over terrain without falling through or jittering badly.

### ABC6-projectiles-craters

Owner: Bob

Execution mode: worker

Outcome:
- Add local projectile impact, crater deformation, and radius damage.

Requirements:
- `Projectile.tscn` uses nodes for visual/collision.
- Host/local impact computes crater event data.
- Terrain deformation lowers a circular/soft crater.
- Damage uses linear falloff: `damage = max_damage * (1.0 - distance / radius)`.
- Crater settings are inspector exported where practical.

Verification:
- Local play: fire projectile, impact creates crater, nearby tank health changes.

### ABC7-steam-game-bridge

Owner: Charlie

Execution mode: worker

Outcome:
- Connect `TankGame` to existing `Online.gd` lobby/player registry.

Requirements:
- Do not rewrite Steam bootstrap.
- Spawn one tank per `Online.players` entry.
- Maintain peer-ID naming/authority pattern.
- Keep the lobby start screen as the first user-visible flow.

Verification:
- Host and joined client both enter match and see expected player slots/tanks.

### ABC8-network-sync

Owner: Bob and Charlie

Execution mode: worker

Outcome:
- Synchronize tank state and crater/damage events.

Requirements:
- Clients send input, aim, and fire intent to host.
- Host owns projectile impact, crater event, and damage decisions.
- Tank state uses lightweight unreliable sync.
- Crater and damage events use reliable RPCs.
- Event IDs dedupe crater application.

Verification:
- Two instances: host shot creates the same crater and damage on both peers.

### ABC9-late-join-replay

Owner: Charlie

Execution mode: worker

Outcome:
- Add reliable replay of crater events for late joiners.

Requirements:
- Host stores crater event log.
- New peers receive current tank/player state plus crater replay after joining.
- Duplicate crater sequence IDs are ignored.

Verification:
- Client joining after explosions sees the same terrain state after replay.

### ABC10-integration-go

Owner: Charlie

Execution mode: worker

Outcome:
- Final focused integration, test pass, commit, and push.

Verification:
- `git status --short --branch`
- Script checks for touched scripts.
- Scene open checks where possible.
- Manual Steam gate on two machines if available.

Completion:
- Stage only in-scope files.
- Commit with focused message.
- Push current branch to `fuzzy`.

## Paths

### Alice Path

Scope:
- Operator docs, runbooks, Go/No-Go language, short README pointers.

Path completion:
- Docs are accurate for the current scene flow and launchers.
- Docs mention known manual gates and current limitations.
- Handoff card is provided.

### Bob Path

Scope:
- Terrain addon spike, scene foundation, lobby UI implementation, tank movement, terrain driving, projectile/crater local gameplay, focused script checks.

Path completion:
- Local non-network gameplay loop exists or the path is blocked with exact technical reason.
- All changed files are listed.
- Tests/checks are reported.
- Handoff card is provided.

### Charlie Path

Scope:
- Roadmap, scope control, integration, Steam bridge, multiplayer sync, late-join replay, final tests, git hygiene, push.

Path completion:
- Multiplayer flow is integrated and tested enough for a Go/Partial/No-Go decision.
- In-scope changes are committed and pushed, unless stopped by a rule.

## Verification Plan

- `git status --short --branch`
- Godot script `--check-only` for every new or changed script.
- Open new scenes in Godot editor or via Godot MCP when available.
- Current script checks passed for:
  - `res://scenes/ui/lobby_start_screen.gd`
  - `res://scenes/tank_game/tank_game.gd`
  - `res://scenes/tank/tank_controller.gd`
  - `res://scenes/projectile/projectile.gd`
  - `res://scenes/terrain/terrain_world.gd`
- Current boot check passed:
  - `Godot_v4.7-stable_win64_console.exe --headless --log-file E:/Godot_With_Steam/runtime_logs/boot-tank-game.log --path <project> --quit-after 3`
- Local gameplay gate: host/offline tank scene runs, tank moves, turret aims.
- Terrain gate: tank drives on terrain; crater changes visible terrain and collision enough for MVP.
- Steam gate: host creates lobby, lobby ID copy works, client paste/join works, host starts match.
- Multiplayer gameplay gate: tank state, projectile impact, crater event, and damage are visible on both peers.

## Release Language

Go:
- Basic lobby and start flow works.
- Tank local loop works.
- Steam multiplayer match starts.
- Craters and damage synchronize across two peers.

Partial:
- Lobby and local tank/terrain loop works, but multiplayer crater sync or late join is incomplete.

No-Go:
- Terrain3D cannot be installed or cannot provide usable runtime deformation/collision for the MVP.
- Steam lobby creation/join is broken in a way that blocks two-machine testing.

Deferred:
- Voxel terrain.
- Advanced vehicle physics.
- Polished UI.
- Teams, scoring, respawn rules, matchmaking browser, final art, audio, replay UI, and dedicated server.
