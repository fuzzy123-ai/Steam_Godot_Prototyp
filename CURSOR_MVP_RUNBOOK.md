# Steam Cursor MVP Runbook

## Current MVP

Main scene:

`res://scenes/cursor_mvp/cursor_mvp.tscn`

Behavior:

- Starts as an empty UI window with a local cursor preview.
- Shows Steam running state, persona name, and Steam ID when GodotSteam is initialized.
- Host creates a Steam lobby through `Online.host_steam_lobby()`.
- Client joins by numeric Steam lobby ID through `Online.join_steam_lobby(lobby_id)`.
- Transport uses `SteamMultiplayerPeer`, not IP/port.
- Cursor positions are normalized to viewport size and sent at 30 Hz.
- Clients submit cursor state to peer `1`; the host relays cursor state to all peers.
- Cursor labels use registered `PlayerData.display_name`, which is populated from the Steam persona name after Steam initialization.

## Launch

From the workspace root:

`E:\Godot_With_Steam\open-vimayer-template-godot-4.7.cmd`

Project path:

`E:\Godot_With_Steam\external\vimayer-steam-local-multiplayer-lobby-template`

Godot binary:

`E:\Godot_With_Steam\tools\godot-4.7\Godot_v4.7-stable_win64.exe`

## Steam Requirements

- Steam client must be running under the same Windows user that launches Godot.
- `steam_appid.txt` is present with app ID `480` for Spacewar development testing.
- With app ID `480`, Steam presence may appear as Spacewar, not the final game name.
- For a real Steam app name/presence, replace `480` with the real Steam app ID and run an exported/uploaded build through Steam.

## Multiplayer Test Path

1. Start Steam on both test machines/accounts.
2. Open the project and run the main scene on the host.
3. Press `Host Steam Lobby`.
4. Copy the shown lobby ID.
5. Start the project on the client.
6. Paste the lobby ID and press `Join`.
7. Move the mouse in both windows; each peer should see the other peer's cursor and Steam name.

## Verified Locally

These commands passed:

`Godot_v4.7-stable_win64_console.exe --headless --path <project> --check-only --script res://scripts/globals/Online.gd`

`Godot_v4.7-stable_win64_console.exe --headless --path <project> --check-only --script res://scenes/cursor_mvp/cursor_mvp.gd`

`Godot_v4.7-stable_win64_console.exe --headless --path <project> --quit-after 5`

Headless run note:

In the Codex sandbox, the Steam client is not initialized for the sandbox user, so Steam multiplayer is disabled for that automated run. The prototype now handles that state cleanly instead of crashing or spamming GodotSteam errors.
