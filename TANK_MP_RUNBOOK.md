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

## Version 0.2.1 Local Terrain Deformation Gate

Version 0.2.1 is a local-only terrain deformation slice. Projectile terrain impacts create crater events, the local terrain mesh/collision are rebuilt from those events, and the crater event list becomes the primitive contract for later multiplayer sync.

- Crater events are primitive data only: terrain-space `x`, `z`, `radius`, and `depth`.
- Terrain reconstruction is deterministic from the match seed, terrain generation settings, and the ordered crater event list.
- Peers should eventually sync crater events, not mesh buffers, image data, or Terrain3D collision state.
- v0.2.1 does not implement multiplayer crater replication, persistence, late-join replay, visual decals, particles, scorch marks, or chunked mesh optimization.
- Full preview mesh/collision rebuild after each crater is acceptable for this small local prototype gate.

Node and Inspector preference:

- Keep terrain visual/collision nodes in the scene so operators can inspect the setup.
- Crater parameters should be exported tunables on gameplay nodes, such as projectile crater radius/depth defaults.
- Runtime code should stay focused on terrain math, crater event logging, deterministic reconstruction, and projectile impact behavior.
- Avoid hardcoding tuning values in scripts when an exported Inspector value is reasonable.

Future multiplayer contract:

- The host can author crater events after validating projectile terrain impacts.
- Clients can apply the same ordered primitive events against the same seed/settings to reconstruct matching heights.
- A future fingerprint can compare reconstructed event state across peers without synchronizing mesh buffers.
- Network sync is explicitly deferred beyond v0.2.1.

## Version 0.2.2 Multiplayer Projectile and Terrain Deformation Gate

Version 0.2.2 extends the v0.2.1 crater contract into multiplayer and adds the first projectile spawn sync. Projectile spawns are synchronized from the host as small spawn events, while terrain deformation is synchronized as host-authoritative primitive crater events instead of mesh, image, collision, or Terrain3D state.

- The host broadcasts projectile spawn events so other peers see the shot.
- The host validates projectile terrain impacts and authors ordered crater events.
- Remote visual projectiles do not author damage or terrain deformation locally.
- Clients apply the same primitive events against the same match seed and terrain settings.
- The crater event fingerprint is based on seed/settings plus the ordered crater event list.
- Tank movement and targeting react automatically because tanks query the deformed terrain through `get_height_at()` and `get_normal_at()`.
- The v0.2.1 local-only history remains valid as the foundation for the multiplayer sync contract.

## Combat VFX Manual Gate

This is the first visual combat-feedback test. It checks only the tank-fire VFX path: muzzle flash, projectile impact burst, and smoke or dust at the crater.

- Intended asset set: the smallest local subset needed for muzzle flash, impact burst, and crater smoke/dust.
- Candidate sources: local smoke flipbook, Tiny Swords explosion/dust sprites, or staged VFX packages listed in `TANK_MP_VFX_ABC_PLAN.md`.
- Optional: SFX hooks may exist, but audio polish is not part of this gate.
- Deferred: toon shader and water are follow-up tracks, not part of this VFX slice.

Manual test:

1. Launch the project with the workspace Godot 4.7 launcher.
2. Start `res://scenes/tank_game/tank_game.tscn` locally.
3. Aim one tank shot at visible terrain.
4. Fire once.
5. Confirm a short muzzle flash appears at the firing tank.
6. Confirm an impact burst appears at the projectile hit point.
7. Confirm smoke or dust appears briefly at the crater.
8. Confirm the crater still appears once and tank gameplay remains responsive.

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

## Local Terrain Deformation Manual Gate

Run this after the v0.2.1 crater slice is implemented.

1. Launch the project with the workspace Godot 4.7 launcher.
2. Start a local match from the lobby or direct tank game entry point available in the current slice.
3. Aim at visible terrain.
4. Fire a projectile into the terrain.
5. Confirm a visible crater appears at the impact point.
6. Confirm tank aiming, movement, reload/ammo flow, and capture progress remain responsive after the crater rebuild.
7. Restart with the same seed and replay the same crater event sequence if a developer hook is available.
8. Confirm the reconstructed terrain shape matches the same seed plus ordered crater events.

## Multiplayer Projectile and Terrain Deformation Manual Gate

Run this after the v0.2.2 multiplayer projectile and crater sync slice is implemented.

1. Start a two-machine match from the lobby with a known numeric seed.
2. Host fires a projectile into visible terrain.
3. Confirm the client sees the projectile spawn and travel.
4. Confirm the host sees a crater at the impact point.
5. Confirm the client sees the same crater without authoring a local terrain deformation.
6. Drive and aim on both peers near the crater.
7. Confirm movement and targeting follow the deformed terrain on both peers.
8. Compare both peers using the same seed plus crater event fingerprint.
9. Confirm the ordered crater event list matches when the same host-authored crater sequence has been applied.

## Expected Result

- Host can create a Steam lobby.
- Lobby ID copy/paste works.
- Client can join by pasted lobby ID.
- Start match is host-only.
- Host can choose a placeholder tank and numeric seed before starting.
- Host `Start Match` reliably moves both peers into the match state.
- Local projectile hits on terrain create visible craters without freezing the editor or match.
- The deformation state can be described by seed/settings plus primitive crater events for future sync.
- In multiplayer, host-authored projectile spawns replicate so clients see shots.
- In multiplayer, host-authored projectile terrain impacts replicate as primitive crater events and produce matching deformed terrain on clients.
- Tank movement and targeting use the deformed terrain height/normal queries, so they respond to synchronized craters without separate movement or targeting sync rules.

## Decision Language

Go:

- Basic lobby and start flow works on two machines.
- Tank local loop works: mouse targeting, green/red muzzle trace, shooting, direct hits, and simple health damage.
- Steam multiplayer match starts.
- v0.2.1 local crater deformation works from projectile terrain hits and stays responsive.
- Future crater multiplayer sync has a primitive event contract: seed/settings plus ordered crater events.
- v0.2.2 multiplayer projectile/crater sync works: host fires into terrain, client sees the projectile and matching crater, and both peers compare equal by seed plus crater event fingerprint.
- Combat VFX works: one tank shot shows muzzle flash, impact burst, and crater smoke/dust without changing projectile or crater authority.

Partial:

- Lobby and local tank/terrain loop works, but multiplayer crater sync or late join is incomplete.
- Host and client can enter a placeholder match together, but gameplay sync is not ready.
- Manual crater application works, but projectile-triggered craters or deterministic replay still need another slice.
- Host projectile/crater events replicate, but peer fingerprint comparison or replay diagnostics need another pass.
- Some combat VFX appears, but a missing category has a named blocker and next owner.

No-Go:

- Steam lobby creation or join is broken in a way that blocks two-machine testing.
- Host `Start Match` does not move both peers into the same match state.
- Terrain3D cannot be installed or cannot provide usable runtime deformation/collision for the MVP.
- Local crater rebuild freezes the editor/match or breaks tank driving, aiming, or projectile flow.
- Client terrain diverges from the host after applying the same seed and host-authored crater events.
- Combat VFX causes runtime errors, breaks projectile/crater flow, or creates duplicate crater authority.

Deferred:

- Terrain3D v1.0.2 is installed and passed the first Godot 4.7 smoke test.
- The smoke scene is `res://scenes/terrain/terrain3d_smoke_test.tscn`.
- The smoke test confirmed runtime height changes and collision refresh calls. Player-facing tank driving on Terrain3D is still a separate gate.
- Voxel terrain.
- Advanced vehicle physics.
- Toon shader and water follow after the first combat VFX gate is proven.
- Polished UI.
- Multiplayer crater RPC sync, late-join replay, save/load of crater history, chunk rebuild optimization, and crater VFX/audio polish.
- Teams, scoring, respawn rules, matchmaking browser, final art, audio, replay UI, and dedicated server.

## Handoff Notes

- Keep the Steam bootstrap in `res://scripts/globals/Online.gd`.
- `res://scenes/ui/lobby_start_screen.gd` still emits `start_match_requested` with no arguments. Charlie can call `get_match_setup()` on the lobby instance before hiding it when wiring tank selection into `TankGame`.
- Keep AppID `480` for prototype testing unless a real Steam app ID is explicitly assigned.
- Do not log or persist private tokens, Steam credentials, chat IDs, or unrelated machine-specific secrets.
- Treat the Terrain3D result as a gate: if the addon spike fails, report `No-Go` for crater terrain until an alternative is chosen.
- For v0.2.1, keep crater deformation local. Hand off later network work as event replication of primitive crater dictionaries, not scene-node sync or mesh-buffer sync.
- For v0.2.2, keep projectile effects and deformation host-authoritative: clients may show visual projectile followers, but they apply primitive crater events from the host and compare seed plus crater event fingerprints for manual verification.
