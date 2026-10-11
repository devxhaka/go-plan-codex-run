# Contoh Plan (hasil tempelan dari ChatGPT Go)

> File ini contoh format plan. Di pemakaian nyata, isi file ini diganti
> dengan plan yang dibuat ChatGPT web (akun Go) setelah me-review project
> lewat MCP bridge. Lalu jalankan: scripts/run-plan.sh plan.md

## Tugas: Tambah endpoint health check

1. Buat file `src/health.py` berisi fungsi `health()` yang return dict
   `{"status": "ok"}`.
2. Daftarkan route `GET /health` di file routing utama (cari file yang
   sudah mendaftarkan route lain, ikuti pola yang sama).
3. Jangan ubah file lain. Jangan install dependency baru.
4. Setelah selesai, ringkas file apa saja yang diubah.
