@echo off
REM Go-Plan bridge: jalankan MCP server + Cloudflare Quick Tunnel (Windows)
REM Pakai: scripts\start-windows.cmd C:\path\repo1 [C:\path\repo2 ...]
REM   atau: scripts\start-windows.cmd "fe=C:\path\fe;be=C:\path\be"
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "SERVER_DIR=%SCRIPT_DIR%..\mcp_server"
set "TUNNEL_LOG=%SCRIPT_DIR%..\.tunnel.log"
set "SERVER_LOG=%SCRIPT_DIR%..\.server.log"

set "ROOTS="
:parse_args
if "%~1"=="" goto args_done
set "P=%~1"
set "CHK=%P%"
echo "%CHK%" | find "=" >nul && for /f "tokens=2 delims==" %%x in ("%CHK%") do set "CHK=%%x"
if not exist "%CHK%\" (
  echo ERROR: bukan folder: %~1
  exit /b 1
)
echo "%CHK%" | findstr /r /c:"^[\"']*[A-Za-z]:\\[\"']*$" >nul && (
  echo ERROR: terlalu luas - pilih folder project, bukan drive root: %~1
  exit /b 1
)
if defined ROOTS ( set "ROOTS=!ROOTS!;%~1" ) else ( set "ROOTS=%~1" )
shift
goto parse_args
:args_done

if "%ROOTS%"=="" (
  if not "%PROJECT_ROOTS%"=="" (
    set "ROOTS=%PROJECT_ROOTS%"
  ) else if not "%PROJECT_ROOT%"=="" (
    set "ROOTS=%PROJECT_ROOT%"
  ) else (
    echo Pakai: %~nx0 C:\path\repo1 [C:\path\repo2 ...]
    exit /b 1
  )
)

if "%BRIDGE_PORT%"=="" set "BRIDGE_PORT=8765"

where py >nul 2>&1 || where python >nul 2>&1 || (
  echo ERROR: Python tidak ketemu. Install Python 3.10+ dari python.org
  exit /b 1
)
where cloudflared >nul 2>&1 || (
  echo ERROR: cloudflared tidak ketemu.
  echo Install: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/
  exit /b 1
)

if not exist "%SERVER_DIR%\.venv\Scripts\python.exe" (
  echo [bridge] bikin venv + install requirements...
  py -3 -m venv "%SERVER_DIR%\.venv" 2>nul || python -m venv "%SERVER_DIR%\.venv"
  "%SERVER_DIR%\.venv\Scripts\python.exe" -m pip install -q -r "%SERVER_DIR%\requirements.txt"
)

REM hentikan sesi lama
call "%SCRIPT_DIR%stop-windows.cmd" >nul 2>&1

echo [bridge] start MCP server...
start "bridge-mcp-server" /min cmd /c "set PROJECT_ROOTS=%ROOTS% && set BRIDGE_PORT=%BRIDGE_PORT% && ""%SERVER_DIR%\.venv\Scripts\python.exe"" ""%SERVER_DIR%\server.py"" > ""%SERVER_LOG%"" 2>&1"

echo [bridge] start cloudflared Quick Tunnel...
start "bridge-tunnel" /min cmd /c "cloudflared tunnel --url http://127.0.0.1:%BRIDGE_PORT% > ""%TUNNEL_LOG%"" 2>&1"

echo [bridge] nunggu URL tunnel...
set "URL="
for /l %%i in (1,1,30) do (
  if "!URL!"=="" (
    for /f "delims=" %%u in ('powershell -NoProfile -Command "(Select-String -Path '%TUNNEL_LOG%' -Pattern 'https://[a-zA-Z0-9.-]+\.trycloudflare\.com' ^| Select-Object -First 1).Matches.Value" 2^>nul') do set "URL=%%u"
    if "!URL!"=="" timeout /t 2 /nobreak >nul
  )
)

if "%URL%"=="" (
  echo ERROR: URL tunnel tidak ketemu. Cek: %TUNNEL_LOG%
  exit /b 1
)

echo.
echo ==============================================
echo  Bridge AKTIF
echo  Tempel URL ini ke ChatGPT web ^(akun Go^)
echo  sebagai custom MCP connector:
echo.
echo    %URL%/mcp/sse
echo.
echo  Untuk berhenti: scripts\stop-windows.cmd
echo ==============================================
