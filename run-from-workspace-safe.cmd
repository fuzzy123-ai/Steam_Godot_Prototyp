@echo off
setlocal
set "PROJECT_DIR=%~dp0."
set "WORKSPACE_ROOT=%PROJECT_DIR%\..\.."
set "LOG_DIR=%PROJECT_DIR%\runtime_logs"
set "GODOT_RUNNER=%GODOT_EXE%"
if defined GODOT_47_EXE set "GODOT_RUNNER=%GODOT_47_EXE%"
if not defined GODOT_RUNNER set "GODOT_RUNNER=%WORKSPACE_ROOT%\tools\godot-4.7\Godot_v4.7-stable_win64.exe"
if not exist "%GODOT_RUNNER%" if exist "%PROJECT_DIR%\tools\godot-4.7\Godot_v4.7-stable_win64.exe" set "GODOT_RUNNER=%PROJECT_DIR%\tools\godot-4.7\Godot_v4.7-stable_win64.exe"
if not exist "%GODOT_RUNNER%" if exist "%PROJECT_DIR%\..\tools\godot-4.7\Godot_v4.7-stable_win64.exe" set "GODOT_RUNNER=%PROJECT_DIR%\..\tools\godot-4.7\Godot_v4.7-stable_win64.exe"
if not exist "%GODOT_RUNNER%" (
	echo Could not find Godot 4.7.
	echo Set GODOT_EXE or GODOT_47_EXE to the full Godot executable path.
	exit /b 1
)
cd /d "%PROJECT_DIR%"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>nul
if not exist "%LOG_DIR%" set "LOG_DIR=%TEMP%\Steam_Godot_Prototyp_logs"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>nul
if not exist "%LOG_DIR%" (
	echo Could not create runtime log directory.
	exit /b 1
)
"%GODOT_RUNNER%" --log-file "%LOG_DIR%\steam-cursor-mvp-safe.log" --rendering-driver opengl3_angle --rendering-method gl_compatibility --path "%PROJECT_DIR%" %*
