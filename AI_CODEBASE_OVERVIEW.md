# AI Codebase Overview - ViMayer Steam/Local Multiplayer Lobby Template

Purpose: fast context file for future AI agents working on this repo. Read this before editing. It is intentionally compact and implementation-oriented.

Repo location in this workspace:

`E:\Godot_With_Steam\external\vimayer-steam-local-multiplayer-lobby-template`

Workspace-local Godot:

`E:\Godot_With_Steam\tools\godot-4.7`

Launchers:

- `E:\Godot_With_Steam\open-vimayer-template-godot-4.7.cmd`
- `E:\Godot_With_Steam\open-vimayer-template-godot-4.7-safe.cmd`

The `tools/godot-4.7/._sc_` marker intentionally puts Godot in self-contained/portable mode so editor settings are kept beside the downloaded editor instead of `AppData\Roaming\Godot`.

Godot MCP Pro:

- Plugin source copied from `E:\0_Asset Library\Plugins\godot-mcp-pro-v1.13.2`.
- Project plugin path: `addons/godot_mcp`.
- Project MCP config: `.mcp.json`.
- Workspace MCP config: `E:\Godot_With_Steam\.mcp.json`.
- Codex global MCP config: `C:\Users\nkatz\.codex\config.toml`, server name `godot-mcp-pro`.
- Codex config backup before edit: `C:\Users\nkatz\.codex\config.toml.backup-godot-mcp-pro`.
- Project-level Codex/Godot-MCP instructions: `AGENTS.md`.

Current-session note: Codex loads MCP servers at session/project start. If `mcp__godot...` tools are not visible in the active thread, restart/reopen the Codex project/thread after this setup. Godot editor must also be open with this project loaded so the plugin can connect to the Node MCP server.

Upstream:

`https://github.com/ViMayer/Godot-Steam-Local-Multiplayer-Lobby-Template`

Analyzed revision:

`df07966 Update v-1.1.1`

Project identity:

- Godot project name: `Steam/Local Multiplayer Lobby Template`
- Version: `1.1.1`
- Godot feature tag: `4.7`
- Renderer: Forward Plus, Windows rendering driver set to `d3d12`
- Main scene: `scenes/lobby/lobby.tscn`
- Only project autoload: `Online` -> `scripts/globals/Online.gd`
- Steam dev app ID hardcoded in code: `480` (Spacewar)
- Vendored Steam bridge: `addons/godotsteam/` GDExtension with platform binaries.

## Executive Summary

This is a working GodotSteam + `SteamMultiplayerPeer` lobby template wrapped in a 3D first-person controller demo.

The Steam MVP-relevant path is:

`Lobby UI -> Online.host_steam_lobby()/join_steam_lobby() -> Steam lobby discovery -> SteamMultiplayerPeer.create_host/create_client -> Godot MultiplayerAPI/RPC/MultiplayerSpawner`.

Steam lobbies are used for discovery/invites. The actual high-level multiplayer transport is `SteamMultiplayerPeer`, not IP/port. GodotSteam's old P2P packet API is used only for custom invite payloads in the friends UI.

For our cursor MVP, keep:

- `project.godot` Steam/GDExtension config.
- `addons/godotsteam/`.
- `scripts/globals/Online.gd` Steam host/join path.
- `scripts/player_data_resource.gd` as the player identity container, possibly simplified.
- Main menu/lobby ID/invite UI if useful.

For our cursor MVP, replace or remove:

- 3D map and first-person movement.
- `PlayerCharacter` scene and state machine.
- movement modifier addon.
- local ENet path, unless we want a non-Steam test fallback.
- HUD/debug movement UI.

## File Map

Core project files:

- `project.godot`: Godot app config, autoload, display, input, physics/rendering, Steam settings.
- `README.md`: user-facing template description.
- `LICENSE`: project license.

Networking and shared data:

- `scripts/globals/Online.gd`: central autoload; owns Steam init, lobby state, SteamMultiplayerPeer, local ENet peer, player registry, invite payload packets.
- `scripts/player_data_resource.gd`: serializable `PlayerData` resource with `multiplayer_id`, `display_name`, `steam_id`, `color`.

Main scene and UI:

- `scenes/lobby/lobby.tscn`: main scene. Contains World3D, MultiplayerSpawner, PlayersContainer, 3D map, InGameUI, MainMenuUI, SteamFriendsList, InvitePopup.
- `scenes/lobby/lobby.gd`: connects UI signals to `Online`, controls host/join/leave, spawns/despawns players.
- `scenes/lobby/main_menu_ui.tscn`: start menu with address/lobby ID input, color picker, host online/local, join, quit.
- `scenes/lobby/main_menu_ui.gd`: emits clean UI intent signals and writes chosen color into `Online.personal_player_data.color`.

Steam friends/invites:

- `scenes/ui/steam_friends_list/steam_friends_list.gd`: enumerates Steam friends via `Steam.getFriendCount()` and creates cards.
- `scenes/ui/steam_friends_list/steam_friend_card/steam_friend_card.gd`: displays avatar/status/name and sends lobby invite payloads.
- `scenes/ui/steam_friends_list/invite_popup/invite_popup.gd`: accepts/rejects custom invite payloads.
- `scenes/ui/steam_friends_list/control_loader/control_loader_effect.gd`: visual loading shimmer.

3D demo player:

- `scenes/player_character/player_character_scene.tscn`: spawned player scene; has `MultiplayerSynchronizer`.
- `scenes/player_character/player_character_script.gd`: authority-gated first-person controller.
- `scenes/player_character/dependencies/camera_script.gd`: local camera/mouse capture/FOV/headbob.
- `scenes/player_character/dependencies/hud/hud_script.gd`: movement/FPS/crosshair HUD.
- `scenes/player_character/dependencies/robot_model/robot_model_script.gd`: remote visual model animation/color sync.
- `scenes/player_character/dependencies/StateMachine/*.gd`: movement state machine.

Vendored/addon content:

- `addons/godotsteam/`: GodotSteam GDExtension binaries and `godotsteam.gdextension`.
- `addons/JehenoAdvancedFirstPersonController(Modified)/`: first-person controller support assets and movement modifier scenes/scripts.

Assets:

- `common/fonts/`, `common/themes/`: fonts/theme.
- `screenshots/`: README images.
- robot model, textures, shaders under `scenes/player_character/dependencies/`.

## Runtime Boot Sequence

1. Godot loads `project.godot`.
2. Autoload `Online` is created before the main scene.
3. `Online._ready()` calls:
   - `_setup_steam_multiplayer()`
   - `_setup_local_multiplayer()`
4. `_setup_steam_multiplayer()`:
   - sets env vars `SteamAppID` and `SteamGameID` to `480`.
   - calls `Steam.steamInit(false, STEAM_APP_ID)`.
   - enables `Steam.allowP2PPacketRelay(true)`.
   - connects `Steam.lobby_created`, `Steam.lobby_joined`, `Steam.join_requested`.
5. `Online._process()` continuously reads custom Steam P2P packets on channel 0 for invite payloads.
6. Main scene `Lobby` starts and connects UI and multiplayer signals.

Important: `Steam.run_callbacks()` is not explicitly called in `Online.gd`. The project config has:

```ini
[steam]
initialization/initialize_on_startup=false
initialization/embed_callbacks=false
```

If callbacks do not fire in practice, first suspect missing `Steam.run_callbacks()` or GodotSteam callback embedding behavior/version differences.

## Main Steam Multiplayer Flow

Host flow:

1. User presses Host Online in `MainMenuUI`.
2. `MainMenuUI.host_online_requested` -> `Lobby._on_host_online_requested()`.
3. `Lobby` awaits `Online.host_steam_lobby()`.
4. `Online.host_steam_lobby()`:
   - guards `is_busy`.
   - creates `SteamMultiplayerPeer`.
   - calls `new_steam_peer.create_host(0)`.
   - calls `Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, MAX_PLAYERS)`.
   - awaits `lobby_hosting_response`.
5. `Steam.lobby_created` -> `Online._on_steam_lobby_created()`.
6. On `Steam.RESULT_OK`:
   - saves `steam_lobby_id`.
   - calls `Steam.setLobbyJoinable(lobby_id, true)`.
   - registers local player data.
   - emits `lobby_hosting_response(SUCCESS)`.
7. `host_steam_lobby()` then:
   - sets `is_host = true`.
   - assigns `multiplayer.multiplayer_peer = new_steam_peer`.
   - emits `joined_lobby`.
8. `Lobby` hides menu and shows in-game UI.

Join flow:

1. User enters lobby ID and presses Join, or Steam emits `join_requested`.
2. `Lobby._on_join_requested(address)` calls `Online.join_steam_lobby(address as int)` unless address is local default.
3. `Online.join_steam_lobby()`:
   - leaves existing lobby if needed.
   - sets `steam_lobby_id`.
   - calls `Steam.joinLobby(lobby_id)`.
   - awaits `lobby_join_response`.
4. `Steam.lobby_joined` -> `Online._on_steam_lobby_join_response()`.
5. Handler:
   - gets host Steam ID via `Steam.getLobbyOwner(lobby_id)`.
   - rejects self-join.
   - creates `SteamMultiplayerPeer`.
   - calls `new_steam_peer.create_client(lobby_owner_id, 0)`.
   - assigns `multiplayer.multiplayer_peer`.
   - defers local player registration.
   - emits `lobby_join_response(SUCCESS)`.
6. `Lobby` hides menu.

Direct-connection interpretation:

- No IP/port is entered for Steam connections.
- Lobby ID / Steam invite is discovery.
- Connection is established against lobby owner's Steam ID through `SteamMultiplayerPeer.create_client(lobby_owner_id, 0)`.
- Steam may connect peer-to-peer or relay internally; the app does not control that.

## Local ENet Flow

Local hosting:

- `Lobby._on_host_local_requested()` -> `Online.host_local_lobby()`.
- Creates `ENetMultiplayerPeer.create_server(8080, MAX_PLAYERS)`.
- Assigns it to `multiplayer.multiplayer_peer`.
- Registers local player.

Local joining:

- Empty/default address maps to `127.0.0.1`.
- `Online.join_local_lobby()` first calls `check_if_host_exists()`.
- `join_address()` creates `ENetMultiplayerPeer.create_client(address, 8080)`.

For Steam-only MVP, this path is optional and can be deleted or hidden.

## Player Registry and Spawn Flow

Data model:

`PlayerData` fields:

- `multiplayer_id`: Godot peer ID.
- `display_name`: Steam persona or local fallback.
- `steam_id`: Steam user ID.
- `color`: chosen color.

Serialization:

- `PlayerData.to_dict()` reflects script variables into a dictionary.
- `PlayerData.from_dict(dict)` creates a new resource and `set()`s each key.
- `PlayerData.apply_data_to_node(data, node)`:
  - names node with multiplayer ID.
  - sets multiplayer authority to that ID.
  - writes `player_data` property if node has it.

Registration RPC:

`Online._register_player_data(player_data_dict)` is:

```gdscript
@rpc("any_peer", "reliable", "call_local")
```

Behavior:

- Converts dict to `PlayerData`.
- Stores by `multiplayer_id`.
- Emits `player_connected`.
- If host/server, forwards new player data to existing peers and sends existing player data to the joining peer.

Spawn:

- `Lobby._setup_multiplayer_spawner()` sets `spawn_function = _add_player`.
- `Online.player_connected` -> `Lobby._on_player_connected()`.
- If `multiplayer.is_server()`, calls `multiplayer_spawner.spawn(player_data.to_dict())`.
- `_add_player(dict)` instantiates `player_scene`, sets name/position, applies `PlayerData`, returns node.

Despawn:

- `multiplayer.peer_disconnected` -> `Online._handle_peer_disconnection()` and `Lobby._remove_peer()`.
- `Online.player_disconnected` -> `Lobby._on_player_disconnected()`.
- Matching player node is queued for deletion.

Potential issue:

- `Online._on_steam_lobby_created()` calls `_register_player_data(personal_player_data.to_dict())` twice. This is probably redundant. It is mostly harmless because `_register_player_data` ignores already registered IDs.

## Steam Friends and Invite Payloads

The friends UI does not create the main game connection. It helps invite/join.

Friend list:

- `SteamFriendsList._load_friends()` calls:
  - `Steam.getFriendCount()`
  - `Steam.getFriendByIndex(i, Steam.FRIEND_FLAG_IMMEDIATE)`
  - `SteamFriendCard.create_player_card(steam_id)`

Friend card:

- Reads persona name/state/avatar:
  - `Steam.getFriendPersonaName()`
  - `Steam.getFriendPersonaState()`
  - `Steam.getPlayerAvatar()`
- Invite button disabled if friend already appears in `Online.players`.

Invite send:

- `SteamFriendCard._invite_to_lobby()`:
  - creates `Online.DataPayload.create_steam_invite_payload(lobby_id, steam_id)`.
  - calls `payload.send()`.

Payload send:

- `Online._send_steam_data_payload()`:
  - sends custom packet: `Steam.sendP2PPacket(target_steam_id, payload.packet_data, ...)`.
  - also calls `Steam.inviteUserToLobby(lobby_id, target_steam_id)`.

Payload receive:

- `Online._process_steam_p2p_packets()` checks `Steam.getAvailableP2PPacketSize(0)`.
- `Steam.readP2PPacket(packet_size, 0)` -> `bytes_to_var(packet["data"])`.
- `_handle_incoming_packet()` recognizes `header == "DATA_PAYLOAD"`.
- `_handle_payload_received()` emits `steam_lobby_invite_received(lobby_id, sender_id)`.
- `LobbyInvitePopup` presents accept/close and calls `Online.join_steam_lobby(request_lobby_id)`.

For cursor MVP:

- Keep this if we want in-game friend invite.
- It is not required for lobby-ID join.
- It is separate from `SteamMultiplayerPeer`.

## Scene Structure

Main scene: `scenes/lobby/lobby.tscn`

Key nodes:

- `Lobby` root with script `lobby.gd`.
- `World3D/MultiplayerSpawner`
- `World3D/PlayersContainer`
- `World3D/Map`: large 3D demo environment.
- `CanvasLayer/UI/InGameUI`: visible during lobby/game.
- `CanvasLayer/UI/InGameUI/Panel/SteamFriendsList`
- `CanvasLayer/UI/InGameUI/Panel/.../ExitLobbyButton`
- `CanvasLayer/UI/InGameUI/Panel/.../LobbyInfoButton`
- `CanvasLayer/UI/MainMenuUI`
- `CanvasLayer/UI/InvitePopup`

Main menu scene:

- `MainMenuUI` root with exported refs:
  - `address_input`
  - `color_picker`
  - `main_container`
  - `color_picker_label`
- Emits abstract signals; does not directly create network peers.

Player scene:

- `PlayerCharacter` root `CharacterBody3D`, script `player_character_script.gd`.
- `MultiplayerSynchronizer` replicates:
  - root `position`
  - `CameraHolder:rotation`
  - `CameraHolder:position`
  - animation player fields
  - `CharacterModel:position`
  - `PlayerNick/NickLabel:text`
- `CameraHolder`/`Camera` only active for local authority.
- `StateMachine` controls movement.
- `RobotModel` displays remote body and syncs mesh color/animation.

## Authority Model

Authority is peer-ID based.

- Server/host has peer ID 1.
- Player node names are the peer ID string.
- `PlayerData.apply_data_to_node()` calls `set_multiplayer_authority(id)`.
- `PlayerCharacter` early returns if not authority for local movement/physics.
- Remote movement/animation comes through `MultiplayerSynchronizer` and explicit RPCs.

For cursor MVP:

- Use same authority model.
- Local client sends cursor state from its authority.
- Host can relay or each client can RPC to all; prefer host relay for simpler trust/debug.

## Signals

`Online` signals:

- `joined_lobby`
- `connection_failed`
- `steam_lobby_invite_received(lobby_id, sender_id)`
- `lobby_hosting_response(error_code)`
- `lobby_join_response(error_code)`
- `player_connected(player_data)`
- `player_disconnected(player_data)`
- `server_disconnected`

UI signals:

- `MainMenuUI.host_online_requested`
- `MainMenuUI.host_local_requested`
- `MainMenuUI.join_requested(address)`
- `MainMenuUI.quit_requested`
- `SteamFriendCard.loaded`
- `LobbyInvitePopup.request_handled`

Godot multiplayer signals connected:

- `multiplayer.connected_to_server`
- `multiplayer.peer_disconnected`
- `multiplayer.connection_failed`
- `multiplayer.server_disconnected`

Steam signals connected:

- `Steam.lobby_created`
- `Steam.lobby_joined`
- `Steam.join_requested`
- `Steam.avatar_loaded` per friend card.

## MVP Cursor Game Plan

Target: empty window, all players see all live mouse positions and Steam names.

Current implemented status:

- Main scene is `res://scenes/cursor_mvp/cursor_mvp.tscn`.
- Cursor MVP script is `res://scenes/cursor_mvp/cursor_mvp.gd`.
- Steam development app ID file exists at `steam_appid.txt` with app ID `480`.
- `project.godot` now points `run/main_scene` at the cursor MVP.
- `Online.gd` still owns Steam lobby host/join and player registry.
- `Online._process()` now calls `Steam.run_callbacks()` when Steam is initialized.
- `Online.gd` and `PlayerData` were made robust against fresh Godot 4.7 script-class/import ordering by avoiding fragile compile-time self/extension type references.
- Steam calls are guarded so headless/sandbox runs without an initialized Steam client start cleanly.
- Cursor positions are normalized to viewport size and sent at 30 Hz.
- Clients submit cursor state to server peer `1`; host relays cursor state to all peers.
- Cursor labels use `PlayerData.display_name`, populated from Steam persona after Steam init.
- Run/test instructions live in `CURSOR_MVP_RUNBOOK.md`.

Validated locally:

- `Online.gd` passes `--check-only`.
- `cursor_mvp.gd` passes `--check-only`.
- Main scene starts headless for 5 seconds.
- The Codex sandbox cannot initialize the Steam client for its sandbox user; this is expected and now reported as a clean disabled-Steam state.

Recommended minimal implementation on top of this template:

1. Keep `Online.gd` host/join/player registry.
2. Replace `player_scene` with a lightweight `CursorPlayer` or avoid `MultiplayerSpawner` entirely and render cursors from a UI manager keyed by peer ID.
3. Add `scenes/cursor/cursor_layer.tscn` + `cursor_layer.gd`:
   - listens to `Online.player_connected` / `player_disconnected`.
   - creates/removes UI cursor nodes.
   - shows `PlayerData.display_name`.
4. Add RPC path:
   - local peer samples `get_viewport().get_mouse_position()`.
   - sends normalized position `Vector2(x / viewport_width, y / viewport_height)` to host at fixed tick rate.
   - host stores and broadcasts cursor positions.
   - all clients render denormalized positions.
5. Use unreliable ordered or unreliable RPC for mouse positions. Use reliable only for join/identity.
6. Keep lobby ID display and Steam friend invites for testing.
7. Hide/remove local ENet buttons for Steam-focused MVP.

Potential cursor RPC shape:

```gdscript
@rpc("any_peer", "unreliable")
func submit_cursor_position(norm_pos: Vector2) -> void:
    if not multiplayer.is_server():
        return
    var sender := multiplayer.get_remote_sender_id()
    broadcast_cursor_position.rpc(sender, norm_pos)

@rpc("authority", "unreliable", "call_local")
func broadcast_cursor_position(peer_id: int, norm_pos: Vector2) -> void:
    cursor_positions[peer_id] = norm_pos
```

Need verify exact Godot 4.7 RPC authority semantics before final code.

## Known Risks / Cleanup Notes

Steam callbacks:

- `Steam.run_callbacks()` is not visible in project scripts.
- If GodotSteam does not embed callbacks automatically with current config, lobbies/invites may stall.
- First debug step: add `Steam.run_callbacks()` in `Online._process()` before `_process_steam_p2p_packets()`.

Steam init:

- `Steam.steamInit(false, STEAM_APP_ID)` assumes GodotSteam signature for this version.
- Project also sets `[steam] initialization/app_id=0`, so code controls app ID.

Hardcoded Spacewar:

- `STEAM_APP_ID = 480` is correct for development but must be changed for real Steam app.

Host-only spawning:

- `Lobby._on_player_connected()` only spawns on `multiplayer.is_server()`.
- This is normal for authoritative spawner use.

Player data:

- `PlayerData.to_dict()` uses reflection over script variables.
- Good for extensibility, but less explicit. For MVP, explicit dict may be easier to audit.

Join input overload:

- Main menu uses one field for both local IP and Steam lobby ID.
- Empty/default `127.0.0.1` means local ENet; any other value is cast to int lobby ID.
- For Steam-only MVP, use a dedicated "Lobby ID" field or remove local path.

Custom invite payload:

- DataPayload setters convert values to strings in packet data. Type restoration is manual.
- Fine for lobby ID invite, not suitable as general game-state protocol.

3D controller complexity:

- Large movement state machine, camera, HUD, robot model, and map are unrelated to cursor MVP.
- Avoid modifying these unless preserving the 3D demo.

Possible typo:

- `move_left_action` default string is `"play_char_move_left_ation"` (missing `c` in action). Runtime registration may hide this.

## Recommended Read Order For Future Agents

1. `AI_CODEBASE_OVERVIEW.md`
2. `scripts/globals/Online.gd`
3. `scenes/lobby/lobby.gd`
4. `scripts/player_data_resource.gd`
5. `scenes/lobby/main_menu_ui.gd`
6. `scenes/ui/steam_friends_list/steam_friend_card/steam_friend_card.gd`
7. `scenes/ui/steam_friends_list/invite_popup/invite_popup.gd`
8. Only then inspect `player_character` if working on 3D movement.

## Search Cheat Sheet

Find Steam connection code:

`rg "SteamMultiplayerPeer|create_host|create_client|createLobby|joinLobby|lobby_joined|lobby_created" scripts scenes`

Find player registration/spawn:

`rg "_register_player_data|player_connected|MultiplayerSpawner|spawn\\(" scripts scenes`

Find invite path:

`rg "DataPayload|sendP2PPacket|readP2PPacket|inviteUserToLobby|steam_lobby_invite_received" scripts scenes`

Find authority/RPC:

`rg "@rpc|set_multiplayer_authority|is_multiplayer_authority|MultiplayerSynchronizer" scripts scenes`

Find UI host/join:

`rg "host_online_requested|join_requested|host_steam_lobby|join_steam_lobby" scenes scripts`

## Editing Guidance

For Steam cursor MVP:

- Do not rewrite Steam bootstrap unless it fails.
- Prefer adding a new small cursor scene/script and swapping the main scene content.
- Keep `Online` as the single network authority until there is a reason to split.
- Keep reliable RPCs for identity/join only.
- Use normalized cursor positions so window sizes can differ.
- Document any change to Steam callback handling explicitly.

For project hygiene:

- Avoid touching `addons/godotsteam/` binaries.
- Avoid editing vendored first-person controller unless deleting/replacing the 3D demo.
- If removing local ENet, remove UI affordances and code path together.
- If changing `PlayerData`, keep `to_dict()`/`from_dict()` compatibility or update `_register_player_data()` and spawner calls in the same change.
