# Go-Plan / Codex-Run

Paket tools supaya langganan **ChatGPT Go** dan **ChatGPT Plus** kepakai
bareng secara efisien:

- **ChatGPT Go (web)** → jadi "perencana": baca project lewat MCP bridge,
  bikin plan implementasi (markdown).
- **Codex (akun Plus, CLI lokal)** → jadi "eksekutor": jalanin plan tersebut
  di komputer/VPS.

Idenya: eksplorasi konteks yang berat (baca banyak file, review arsitektur)
dikerjakan di ChatGPT web, sedangkan Codex hanya menerima plan yang sudah
fokus — jadi sesi Codex lebih pendek dan jarang mengulang.

> **Jujur dulu:** tidak ada jaminan penghematan kuota/token. ChatGPT web
> juga memakai jatah akun, dan "hemat" di sini artinya sesi Codex lebih
> fokus (sedikit iterasi), bukan token gratis. Jangan percaya klaim
> "token savings" tanpa mengukur sendiri.

## Isi paket

```
go-plan-codex-run/
├── README.md                 (file ini)
├── plan-contoh.md            (contoh format plan)
├── mcp_server/
│   ├── server.py             (MCP server read-only, 3 tools)
│   └── requirements.txt
└── scripts/
    ├── start-linux.sh        (Linux: server + tunnel)
    ├── stop-linux.sh
    ├── start-windows.cmd     (Windows: server + tunnel)
    ├── stop-windows.cmd
    ├── run-plan.sh           (Linux: codex exec)
    ├── run-plan.cmd          (Windows wrapper)
    └── run-plan.ps1          (Windows: codex exec)
```

## Syarat

| Kebutuhan | Keterangan |
|---|---|
| Python 3.10+ | untuk MCP server (Windows & Linux) |
| `cloudflared` | untuk Quick Tunnel. Download di situs Cloudflare |
| Codex CLI | `npm i -g @openai/codex`, lalu `codex login` dengan **akun Plus** |
| Akun ChatGPT Go | untuk planning di web |
| Node.js 20+ | hanya untuk install Codex CLI |

## Cara pakai (ringkas)

### 1. Planning — ChatGPT Go

**Linux (VPS):**
```bash
cd go-plan-codex-run
chmod +x scripts/*.sh
# satu repo:
scripts/start-linux.sh /absolute/path/ke/project
# DUA repo sekaligus (mis. frontend + backend arshacash):
scripts/start-linux.sh /absolute/path/frontend-arsha /absolute/path/backend-arsha
# atau dengan alias sendiri:
scripts/start-linux.sh "fe=/absolute/path/frontend-arsha:be=/absolute/path/backend-arsha"
```

**Windows:**
```cmd
cd go-plan-codex-run
scripts\start-windows.cmd C:\path\ke\project
REM dua repo sekaligus:
scripts\start-windows.cmd C:\path\frontend-arsha C:\path\backend-arsha
```

Tanpa alias eksplisit, nama repo diambil dari nama foldernya
(mis. `frontend-arsha`, `backend-arsha`).

Script akan menampilkan URL seperti:
```
https://acak-xyz.trycloudflare.com/mcp/sse
```

Tempel URL itu ke ChatGPT web (akun **Go**) sebagai custom MCP connector
(Settings → Connectors → tambah MCP server). Path memakai format
`nama-repo/path/ke/file`, mis. `frontend-arsha/src/app.ts`.
`list_files` tanpa path menampilkan daftar repo. Lalu chat, contoh:

> "Review kedua repo ini (frontend-arsha dan backend-arsha). Saya mau
> tambah fitur X yang menyentuh keduanya. Pelajari struktur kodenya
> lewat tools yang tersedia, lalu buatkan plan implementasi langkah
> per langkah dalam format markdown, pisahkan per repo. Jangan ubah
> apa pun, hanya plan."

**PENTING — keamanan:**
- Bridge hanya boleh menunjuk **SATU folder project**, bukan `C:\`, `/`,
  atau home folder.
- Tools-nya read-only (list/baca/cari). Tidak ada tulis, hapus, atau shell.
- Tunnel membuat folder project bisa diakses dari internet selama aktif.
  Matikan (`stop-*`) setelah selesai. Jangan dipakai untuk project berisi
  secret/API key.
- Test dulu di folder project dummy/non-sensitif.

### 2. Eksekusi — Codex (Plus)

Copy plan dari ChatGPT web ke file, mis. `plan.md`, lalu:

**Linux:**
```bash
scripts/run-plan.sh plan.md
# dengan opsi codex, mis. full-auto:
scripts/run-plan.sh plan.md --full-auto
```

**Windows:**
```cmd
scripts\run-plan.cmd plan.md
```

Codex akan mengerjakan plan tersebut di folder project. Review hasilnya
(`git diff`) sebelum lanjut.

### 3. Selesai

```bash
scripts/stop-linux.sh        # Linux
scripts\stop-windows.cmd     # Windows
```

## Tips hemat (yang beneran ngaruh)

1. **Satu sesi bridge untuk repo yang berkaitan.** Frontend + backend
   arshacash bisa dibuka bareng dalam satu sesi (lihat cara multi-repo
   di atas) supaya plan-nya konsisten antar repo.
2. **Plan spesifik.** Minta ChatGPT Go menulis plan yang konkret
   (nama file, fungsi, langkah berurutan, pisahkan per repo) — plan
   generik bikin Codex menebak-nebak dan iterasi sia-sia.
3. **Minta diff kecil.** Di plan, tegaskan "ubah sesedikit mungkin,
   jangan refactor yang tidak diminta".
4. **Review plan sebelum eksekusi.** Revisi plan di web itu murah;
   revisi hasil eksekusi Codex itu mahal.
5. **Satu chat = satu fitur** di sisi ChatGPT web, biar konteks tidak
   membengkak.

## Batasan yang perlu diketahui

- Sisi planning **semi-manual**: copy-paste plan dari web ke file.
  ChatGPT Go tidak punya API resmi, jadi tidak bisa full otomatis.
- URL tunnel berubah setiap start ulang — update connector di ChatGPT web.
- Script tunnel belum dites di semua jaringan (beberapa jaringan kantor
  memblokir Quick Tunnel).
- `codex exec` butuh login akun Plus yang valid di mesin tersebut.

## Lisensi

MIT — pakai dan modifikasi bebas, risiko tanggung sendiri.
