@echo off
setlocal
cd /d "%~dp0"
if not exist "%~dp0..\..\runtime_logs" mkdir "%~dp0..\..\runtime_logs"
"%~dp0..\..\tools\godot-4.7\Godot_v4.7-stable_win64_console.exe" --log-file "%~dp0..\..\runtime_logs\steam-cursor-mvp-console.log" --path "%~dp0"
