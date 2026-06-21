@echo off
setlocal
cd /d "%~dp0"
if not exist "%~dp0..\..\runtime_logs" mkdir "%~dp0..\..\runtime_logs"
"%~dp0..\..\tools\godot-4.7\Godot_v4.7-stable_win64.exe" --log-file "%~dp0..\..\runtime_logs\steam-cursor-mvp-safe.log" --rendering-driver opengl3_angle --rendering-method gl_compatibility --path "%~dp0"
