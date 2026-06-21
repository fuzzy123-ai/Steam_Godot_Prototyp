@echo off
setlocal
set "PROJECT_DIR=%~dp0"
set "WORKSPACE_ROOT=%PROJECT_DIR%..\..\"
set "GODOT_EXE=%WORKSPACE_ROOT%tools\godot-4.7\Godot_v4.7-stable_win64.exe"
if defined GODOT_47_EXE set "GODOT_EXE=%GODOT_47_EXE%"
if not exist "%GODOT_EXE%" if exist "%PROJECT_DIR%tools\godot-4.7\Godot_v4.7-stable_win64.exe" set "GODOT_EXE=%PROJECT_DIR%tools\godot-4.7\Godot_v4.7-stable_win64.exe"
if not exist "%GODOT_EXE%" if exist "%PROJECT_DIR%..\tools\godot-4.7\Godot_v4.7-stable_win64.exe" set "GODOT_EXE=%PROJECT_DIR%..\tools\godot-4.7\Godot_v4.7-stable_win64.exe"
if not exist "%GODOT_EXE%" (
	echo Could not find Godot 4.7.
	echo Expected: %WORKSPACE_ROOT%tools\godot-4.7\Godot_v4.7-stable_win64.exe
	echo Or set GODOT_47_EXE to the full Godot executable path.
	exit /b 1
)
cd /d "%PROJECT_DIR%"
if not exist "%WORKSPACE_ROOT%runtime_logs" mkdir "%WORKSPACE_ROOT%runtime_logs"
"%GODOT_EXE%" --log-file "%WORKSPACE_ROOT%runtime_logs\steam-cursor-mvp-safe.log" --rendering-driver opengl3_angle --rendering-method gl_compatibility --path "%PROJECT_DIR%"
