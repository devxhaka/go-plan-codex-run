#!/usr/bin/env python3
"""
Go-Plan / Codex-Run — MCP server (read-only, multi-repo).

Mengekspos SATU ATAU BEBERAPA folder project ke ChatGPT web (akun Go)
lewat tunnel, supaya ChatGPT bisa baca project untuk bikin plan, tanpa
bisa mengubah apa pun. Eksekusi tetap dilakukan Codex (akun Plus)
secara lokal.

Format path memakai alias repo: "nama-repo/path/ke/file".
Contoh: "frontend/src/app.ts", "backend/src/index.ts".
list_files("") tanpa path menampilkan daftar repo yang tersedia.

Keamanan:
- Hanya melayani path di dalam root yang terdaftar (env, wajib, absolut).
- Menolak path traversal (.., symlink keluar, absolute path di luar root).
- Hanya bind ke 127.0.0.1 — yang mengekspos ke internet hanyalah
  Cloudflare Quick Tunnel yang dijalankan script start-*. Pilihan ada di user.
- Tools read-only: tidak ada tulis/hapus/shell.

Env:
  PROJECT_ROOTS (diutamakan) daftar root dipisah os.pathsep
              (":" di Linux, ";" di Windows).
              Format tiap entri: /path/ke/repo  atau  alias=/path/ke/repo
              Contoh Linux:   /home/u/frontend-arsha:/home/u/backend-arsha
              Contoh Windows: fe=C:\\proj\\fe;be=C:\\proj\\be
  PROJECT_ROOT  (fallback) satu root saja, untuk kompatibilitas lama.
  BRIDGE_PORT   (opsional, default 8765)
"""

import os
import re
import sys
from pathlib import Path

import uvicorn
from mcp.server.mcpserver import MCPServer
from mcp.server.transport_security import TransportSecuritySettings
from starlette.applications import Starlette
from starlette.responses import JSONResponse
from starlette.routing import Mount, Route

# ---------------------------------------------------------------- config

MAX_READ_BYTES = 1_000_000      # 1 MB per read_file
MAX_SEARCH_RESULTS = 50
EXCLUDE_DIRS = {".git", "node_modules", "__pycache__", ".venv", "venv",
                "dist", "build", ".next", "target", ".idea", ".vscode"}


def _parse_roots() -> dict[str, Path]:
    raw = os.environ.get("PROJECT_ROOTS", "") or os.environ.get("PROJECT_ROOT", "")
    if not raw.strip():
        sys.exit(
            "ERROR: isi PROJECT_ROOTS dengan daftar absolute path folder project "
            f"(dipisah '{os.pathsep}'). Contoh: /a/frontend:/a/backend "
            "atau alias eksplisit: fe=/a/frontend;be=/a/backend"
        )
    roots: dict[str, Path] = {}
    for entry in raw.split(os.pathsep):
        entry = entry.strip().strip('"').strip("'")
        if not entry:
            continue
        if "=" in entry:
            alias, p = entry.split("=", 1)
            alias = alias.strip()
        else:
            alias, p = "", entry
        rp = Path(p.strip()).expanduser()
        if not rp.is_absolute():
            sys.exit(f"ERROR: path harus absolut: {entry}")
        rp = rp.resolve()
        if not rp.is_dir():
            sys.exit(f"ERROR: bukan folder: {entry}")
        alias = alias or rp.name
        if alias in roots:
            sys.exit(f"ERROR: alias duplikat '{alias}' — pakai format nama=/path untuk membedakan.")
        if "/" in alias or "\\" in alias:
            sys.exit(f"ERROR: alias tidak boleh mengandung slash: {alias}")
        roots[alias] = rp
    if not roots:
        sys.exit("ERROR: tidak ada root valid.")
    return roots


ROOTS = _parse_roots()

PORT = int(os.environ.get("BRIDGE_PORT", "8765"))
HOST = "127.0.0.1"  # jangan diubah: hanya tunnel yang boleh mengekspos

mcp = MCPServer("go-plan-bridge")


# ---------------------------------------------------------------- helpers

class _NeedRepoList(Exception):
    """path kosong -> pemanggil harus menampilkan daftar repo."""


def _resolve(rel: str) -> tuple[str, Path, str]:
    """Kembalikan (alias, path_absolut, path_tampil). rel kosong -> raise _NeedRepoList."""
    rel = (rel or "").replace("\\", "/").strip().lstrip("/")
    if not rel:
        raise _NeedRepoList()
    alias, _, rest = rel.partition("/")
    if alias not in ROOTS:
        raise ValueError(
            f"Repo '{alias}' tidak dikenal. Repo tersedia: {', '.join(sorted(ROOTS))}. "
            "Format path: nama-repo/path/ke/file"
        )
    root = ROOTS[alias]
    p = (root / rest).resolve() if rest else root
    try:
        p.relative_to(root)
    except ValueError:
        raise ValueError(f"Path di luar repo '{alias}': {rel!r}")
    return alias, p, f"{alias}/{rest}" if rest else alias


def _repo_list_text() -> str:
    lines = ["Repo tersedia (pakai format 'nama-repo/path/ke/file'):"]
    for alias in sorted(ROOTS):
        lines.append(f"- {alias}  ({ROOTS[alias]})")
    return "\n".join(lines)


def _fmt_size(n: int) -> str:
    for unit in ("B", "KB", "MB"):
        if n < 1024 or unit == "MB":
            return f"{n:.0f}{unit}"
        n /= 1024
    return f"{n:.0f}GB"


# ---------------------------------------------------------------- tools

@mcp.tool(description=(
    "List isi direktori. Path memakai format 'nama-repo/path'. "
    "Path kosong = tampilkan daftar repo. Hanya baca."
))
def list_files(path: str = "") -> str:
    try:
        alias, d, shown = _resolve(path)
    except _NeedRepoList:
        return _repo_list_text()
    except ValueError as e:
        return f"Ditolak: {e}"
    if not d.is_dir():
        return f"Bukan direktori: {shown!r}"
    lines = []
    for child in sorted(d.iterdir(), key=lambda c: (c.is_file(), c.name.lower())):
        rel = f"{alias}/{child.relative_to(ROOTS[alias]).as_posix()}"
        if child.is_dir():
            lines.append(f"[dir]  {rel}/")
        else:
            lines.append(f"[file] {rel} ({_fmt_size(child.stat().st_size)})")
    body = "\n".join(lines) if lines else "(kosong)"
    return f"Isi {shown}:\n{body}"


@mcp.tool(description=(
    "Baca isi file teks (dengan paging). Path format 'nama-repo/path/ke/file'. "
    "File binary / >1MB ditolak. Hanya baca."
))
def read_file(path: str, offset: int = 1, limit: int = 200) -> str:
    try:
        _, f, shown = _resolve(path)
    except _NeedRepoList:
        return "Tentukan file, format: nama-repo/path/ke/file"
    except ValueError as e:
        return f"Ditolak: {e}"
    if not f.is_file():
        return f"Bukan file: {shown!r}"
    if f.stat().st_size > MAX_READ_BYTES:
        return f"File terlalu besar (>1MB): {shown!r}"
    try:
        text = f.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return f"File binary / bukan UTF-8: {shown!r}"
    offset = max(offset, 1)
    limit = max(limit, 1)
    all_lines = text.splitlines()
    total = len(all_lines)
    chunk = all_lines[offset - 1: offset - 1 + limit]
    numbered = "\n".join(f"{i + offset:6d} | {ln}" for i, ln in enumerate(chunk))
    tail = (f"\n... ({total} baris total, {len(chunk)} ditampilkan)"
            if offset - 1 + limit < total else f"\n({total} baris total)")
    return f"{shown}:\n{numbered}{tail}"


@mcp.tool(description=(
    "Cari teks (regex) di file-file project. Path format 'nama-repo/subfolder' "
    "atau kosong = cari di SEMUA repo. Folder .git/node_modules/dll dilewati. "
    "Maks 50 hasil."
))
def search_files(pattern: str, path: str = "") -> str:
    try:
        rx = re.compile(pattern)
    except re.error as e:
        return f"Regex tidak valid: {e}"
    try:
        targets = [(_resolve(path)[0], _resolve(path)[1])] if path.strip() else [
            (alias, root) for alias, root in ROOTS.items()
        ]
    except _NeedRepoList:
        targets = [(alias, root) for alias, root in ROOTS.items()]
    except ValueError as e:
        return f"Ditolak: {e}"
    hits: list[str] = []
    for alias, base in targets:
        root = ROOTS[alias]
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS]
            for fn in filenames:
                fp = Path(dirpath) / fn
                try:
                    if fp.stat().st_size > MAX_READ_BYTES:
                        continue
                    text = fp.read_text(encoding="utf-8", errors="strict")
                except (OSError, UnicodeDecodeError, ValueError):
                    continue
                for i, line in enumerate(text.splitlines(), 1):
                    if rx.search(line):
                        rel = f"{alias}/{fp.relative_to(root).as_posix()}"
                        hits.append(f"{rel}:{i}: {line.strip()[:200]}")
                        if len(hits) >= MAX_SEARCH_RESULTS:
                            break
                if len(hits) >= MAX_SEARCH_RESULTS:
                    break
            if len(hits) >= MAX_SEARCH_RESULTS:
                break
        if len(hits) >= MAX_SEARCH_RESULTS:
            break
    body = "\n".join(hits) if hits else "(tidak ada hasil)"
    note = f"\n... dibatasi {MAX_SEARCH_RESULTS} hasil" if len(hits) >= MAX_SEARCH_RESULTS else ""
    scope = path.strip() or "semua repo"
    return f"Hasil pencarian {pattern!r} ({scope}):\n{body}{note}"


# ---------------------------------------------------------------- app

async def health(request):
    return JSONResponse({
        "ok": True,
        "roots": {alias: str(p) for alias, p in ROOTS.items()},
        "tools": ["list_files", "read_file", "search_files"],
    })


def make_app() -> Starlette:
    from contextlib import asynccontextmanager

    @asynccontextmanager
    async def lifespan(app):
        async with mcp.session_manager.run():
            yield

    return Starlette(
        routes=[
            Mount("/mcp", app=mcp.streamable_http_app(
                stateless_http=True,
                transport_security=TransportSecuritySettings(enable_dns_rebinding_protection=False),
            )),
            Route("/health", endpoint=health),
        ],
        lifespan=lifespan,
    )


if __name__ == "__main__":
    print("[bridge] roots:", flush=True)
    for alias in sorted(ROOTS):
        print(f"[bridge]   {alias} -> {ROOTS[alias]}", flush=True)
    print(f"[bridge] listen http://{HOST}:{PORT} (MCP SSE di /mcp, health di /health)", flush=True)
    uvicorn.run(make_app(), host=HOST, port=PORT, log_level="warning")
