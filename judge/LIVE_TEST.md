# Live-Test Visual 1 Minggu — SRD_Indi v2.60 (Fase 5)

## Kenapa ini (bukan replay lagi)
Replay membuktikan skor v2.60 benar arahnya tapi avgR judge nyaris tak
bergerak (Fresh +0.031 → +0.040): judge menilai SEMUA level, sedangkan
skor mengubah TAG + TERKUAT + SETUP (display). Kenaikan riil hanya di
live (trader entry yg hijau). Fase ini memvalidasi display + logger.

## Setup (Senin, pasar buka — 27 Sep 2026 Minggu, market tutup)
1. Copy `SRD_Indi.mq5` ke `MQL5/Indicators/`, compile (F7) → `SRD_Indi.ex5`.
2. Attach ke chart **H1 XAUUSD.vxc** (H1 = clock logger, hindari bug TF).
3. Inputs: `InpEnableLogger=true`, `InpRR_RequireFreshFVG=true` (default),
   `InpShowSD_Debug=false` (hemat IO), alert OFF dulu.
4. Biarkan 1 minggu penuh (Senin–Jumat, ~120 snapshot × ≤18 baris).

## Checklist visual harian (±2 menit)
- [ ] Baris SETUP Tested/tanpa-FVG tampil abu `SKIP (butuh Fresh+FVG)`?
- [ ] Baris SETUP Fresh+FVG tetap hijau + tag `+FVG`?
- [ ] TERKUAT S&D menunjuk zona Fresh meski sedikit lebih jauh?
- [ ] `InpRR_RequireFreshFVG=false` → hijau lama kembali (sanity)?
- [ ] File `MQL5/Files/SRD_Indi_signals_YYYYMMDD.csv` tumbuh tiap jam?

## Validasi CSV (akhir minggu)
```powershell
python judge/validate_live.py --signals SRD_Indi_signals_20260929.csv
python judge/judge.py --signals SRD_Indi_signals_20260929.csv --ohlc judge/ohlc_xauusd.csv --out judge/out_live --point XAUUSD.vxc:0.01
```
Lolos jika: header 24 kolom OK, ≤18 baris/snapshot, `version` konsisten,
Fresh+FVG share 1–5%, `sdStatus` hanya Fresh/Tested/None.

## Kriteria sukses / gagal
- SUKSES: SKIP abu muncul + CSV cocok replay (Fresh share≈) → SOP live jalan.
- GAGAL: tak ada SKIP seminggu (pasar tren bersih) → perpanjang 1 minggu.
- GAGAL: CSV kosong/rusak → cek `Experts` log `SRD Logger: gagal buka`, hak tulis Files.
