@echo off
REM Wrapper: scripts\run-plan.cmd plan.md [opsi-codex...]
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-plan.ps1" %*
