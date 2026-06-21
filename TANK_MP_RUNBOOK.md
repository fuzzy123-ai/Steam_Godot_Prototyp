# Tank Multiplayer Operator Runbook

## Purpose

This runbook is for the upcoming two-machine Tank Multiplayer prototype gate.

The basic target flow is:

1. Host creates a Steam lobby.
2. Host copies the lobby ID.
3. Client pastes the lobby ID and joins.
4. Host picks the v0.2 tank placeholder and seed setup.
5. Host clicks `Start Match`.
6. Both peers leave the lobby screen and enter the match.

Current note: the existing cursor MVP already proves the Steam lobby path. The tank match screen, tank gameplay, and Terrain3D integration are still being built.

## Version 0.1 Local Gameplay Gate

Version 0.1 requires one basic tank that can drive, aim at a mouse target, show a muzzle-to-target line trace, shoot, hit a target, and apply simple health damage.

- The aim trace is green when the muzzle has a clear path to the mouse target.
- The aim trace is red and stops at terrain or prop obstruction.
- Turret and gun aim are arcade-flat for 0.1: terrain slope affects driving and line blocking, not barrel elevation or ballistics.
- Armor deflection, directional hit zones, structured hit events, polished hit VFX, drones, spider tanks, and countermeasures are post-0.1 only.

## Version 0.2 Lobby Setup Gate

Version 0.2 adds the first lobby-facing setup controls without implementing gameplay selection yet.

- `TankOptionButton` exposes placeholder tank choices: `Basic`, `Light`, and `Heavy`.
- `SeedInput` accepts an optional numeric seed. Empty seed means the next integration may randomize at match creation.
- `RandomizeSeedButton` fills `SeedInput` with a numeric seed for repeatable operator tests.
- `Start Match` remains host-only and keeps the existing no-argument `start_match_requested` signal for compatibility.
- The lobby script exposes `get_match_setup()` for the next integration step. It returns a Dictionary with `tank_id`, `tank_label`, `seed`, and `map_id`.

## Requirements

- Godot 4.7.
- Steam client running on each test machine before launching Godot.
- Two Steam accounts if testing on two machines.
- Spacewar development AppID `480` through `steam_appid.txt`.
- Project path:
  `E:\Godot_With_Steam\external\vimayer-steam-local-multiplayer-lobby-template`
- Workspace Godot 4.7 editor:
  `E:\Godot_With_Steam\tools\godot-4.7\Godot_v4.7-stable_win64.exe`

With AppID `480`, Steam presence may show as Spacewar. That is expected for development testing.

## Launch

Preferred workspace launcher:

```bat
E:\Godot_With_Steam\open-vimayer-template-godot-4.7.cmd
```

For a standalone clone or a different local Godot install, set `GODOT_EXE` before running the project launcher:

```bat
set "GODOT_EXE=E:\Godot_With_Steam\tools\godot-4.7\Godot_v4.7-stable_win64.exe"
```

If using the older cursor MVP launchers during bring-up, keep the same Steam and AppID requirements:

```bat
E:\Godot_With_Steam\run-steam-cursor-mvp.cmd
E:\Godot_With_Steam\run-steam-cursor-mvp-safe.cmd
```

Use the safe launcher if Godot shows renderer or shader-cache startup problems.

## Two-Machine Test

Run this once the lobby start screen exists for the tank prototype.

1. Start Steam on both machines.
2. Confirm both machines use Godot 4.7 and AppID `480`.
3. Launch the project on the host.
4. Host clicks `Host Lobby`.
5. Host confirms that a lobby ID appears.
6. Host clicks `Copy Lobby ID`.
7. Send the lobby ID to the client through the chosen test channel.
8. Launch the project on the client.
9. Client pastes the lobby ID into the lobby ID field.
10. Client clicks `Join`.
11. Confirm both peers show a joined lobby state.
12. Confirm the client cannot start the match.
13. Host selects a tank placeholder.
14. Host either enters a numeric seed or clicks `Randomize`.
15. Host clicks `Start Match`.
16. Confirm both peers switch from the lobby screen into the match.

For the first tank gate, entering an empty or placeholder match world is acceptable if both peers transition together.

## Expected Result

- Host can create a Steam lobby.
- Lobby ID copy/paste works.
- Client can join by pasted lobby ID.
- Start match is host-only.
- Host can choose a placeholder tank and numeric seed before starting.
- Host `Start Match` reliably moves both peers into the match state.

## Decision Language

Go:

- Basic lobby and start flow works on two machines.
- Tank local loop works: mouse targeting, green/red muzzle trace, shooting, direct hits, and simple health damage.
- Steam multiplayer match starts.
- Craters and damage synchronize across two peers.

Partial:

- Lobby and local tank/terrain loop works, but multiplayer crater sync or late join is incomplete.
- Host and client can enter a placeholder match together, but gameplay sync is not ready.

No-Go:

- Steam lobby creation or join is broken in a way that blocks two-machine testing.
- Host `Start Match` does not move both peers into the same match state.
- Terrain3D cannot be installed or cannot provide usable runtime deformation/collision for the MVP.

Deferred:

- Terrain3D v1.0.2 is installed and passed the first Godot 4.7 smoke test.
- The smoke scene is `res://scenes/terrain/terrain3d_smoke_test.tscn`.
- The smoke test confirmed runtime height changes and collision refresh calls. Player-facing tank driving on Terrain3D is still a separate gate.
- Voxel terrain.
- Advanced vehicle physics.
- Polished UI.
- Teams, scoring, respawn rules, matchmaking browser, final art, audio, replay UI, and dedicated server.

## Handoff Notes

- Keep the Steam bootstrap in `res://scripts/globals/Online.gd`.
- `res://scenes/ui/lobby_start_screen.gd` still emits `start_match_requested` with no arguments. Charlie can call `get_match_setup()` on the lobby instance before hiding it when wiring tank selection into `TankGame`.
- Keep AppID `480` for prototype testing unless a real Steam app ID is explicitly assigned.
- Do not log or persist private tokens, Steam credentials, chat IDs, or unrelated machine-specific secrets.
- Treat the Terrain3D result as a gate: if the addon spike fails, report `No-Go` for crater terrain until an alternative is chosen.
