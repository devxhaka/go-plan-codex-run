@echo off
REM Go-Plan bridge: hentikan MCP server + tunnel (Windows)
taskkill /F /FI "WINDOWTITLE eq bridge-mcp-server*" >nul 2>&1
taskkill /F /FI "WINDOWTITLE eq bridge-tunnel*" >nul 2>&1
echo [bridge] berhenti.
