@echo off
setlocal
set "PROJECT_DIR=%~dp0"
set "WORKSPACE_ROOT=%PROJECT_DIR%..\..\"
set "GODOT_EXE=%WORKSPACE_ROOT%tools\godot-4.7\Godot_v4.7-stable_win64_console.exe"
if defined GODOT_47_CONSOLE_EXE set "GODOT_EXE=%GODOT_47_CONSOLE_EXE%"
if not exist "%GODOT_EXE%" if exist "%PROJECT_DIR%tools\godot-4.7\Godot_v4.7-stable_win64_console.exe" set "GODOT_EXE=%PROJECT_DIR%tools\godot-4.7\Godot_v4.7-stable_win64_console.exe"
if not exist "%GODOT_EXE%" if exist "%PROJECT_DIR%..\tools\godot-4.7\Godot_v4.7-stable_win64_console.exe" set "GODOT_EXE=%PROJECT_DIR%..\tools\godot-4.7\Godot_v4.7-stable_win64_console.exe"
if not exist "%GODOT_EXE%" (
	echo Could not find Godot 4.7 console executable.
	echo Expected: %WORKSPACE_ROOT%tools\godot-4.7\Godot_v4.7-stable_win64_console.exe
	echo Or set GODOT_47_CONSOLE_EXE to the full Godot console executable path.
	exit /b 1
)
cd /d "%PROJECT_DIR%"
if not exist "%WORKSPACE_ROOT%runtime_logs" mkdir "%WORKSPACE_ROOT%runtime_logs"
"%GODOT_EXE%" --log-file "%WORKSPACE_ROOT%runtime_logs\steam-cursor-mvp-console.log" --path "%PROJECT_DIR%"
