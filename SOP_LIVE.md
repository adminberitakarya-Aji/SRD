# SOP LIVE SRD — 1 Halaman (hasil backtest multi-agent)

> Berlaku: XAUUSD, SRD_Indi v2.51. Aturan kunci Q1–Q4 tetap.
> Bukti: Jan-2024 Fresh+FVG +0.38R/70% (n64); 2021 RES Fresh+FVG +0.24 (n178).

## 1. Syarat entry (SEMUA harus YA, kalau 1 TIDAK = SKIP)
1. Level dari snapshot H1 terakhir (jangan entry dari level basi).
2. `sdStatus = Fresh` (BUANG Tested/Consumed — Tested -0.40R).
3. `hasFVG = 1` (Fresh tanpa FVG -0.49R — FVG adalah filternya).
4. Sisi ikut struktur: DN → hanya SELL di RES; UP → hanya BUY di SUP.
5. Regime bukan MIXED (MIXED -0.25R, terburuk). ALIGNED/H4H1 saja.
6. Confluence 2/3 diutamakan (hit 44% vs 40% single). Single boleh
   hanya jika 1–5 terpenuhi semua + jarak dekat (distATR kecil).

## 2. Eksekusi (kunci Q2/Q3)
- Entry: market open bar H1 berikutnya (Opsi A). Jangan limit di tengah.
- SL: level ± 0.20×ATR_TF + spread + 50pt slippage.
- TP1: 1R (wajib partial). TP2: level terkuat searah TF sama (fallback 2R).
- Expiry: M30/H1 24 jam, H4 48 jam. Lewat = tutup/timeout, jangan hold.
- SL & TP satu bar = LOSE (konservatif, sesuai judge).

## 3. Filter TF (pilih sesuai gaya)
- Intraday: H1 utama (-0.16 sideways, sweet spot).
- Tren kuat: H4 (ranking H4>H1>H4 saat tren; SL lebar, target jauh).
- M30: hanya presisi entry, jangan hold (noise -0.21 s/d -0.24).
- Rank: utamakan RES1/SUP1 (hit 43-44%); rank2/3 untuk TP, bukan entry.

## 4. Money management
- Risiko 0.5–1R per trade. Fresh+FVG jarang (2-3% signals) — jangan overlot.
- Max 1 trade per level (sentuhan pertama saja). Sentuhan ulang = skip.
- Daily stop: 2 LOSE beruntun = stop. MIXED seharian = libur.

## 5. Validasi berjalan (wajib)
- Hidupkan `InpEnableLogger=true` di live/demo 1 minggu.
- Running `judge.py` mingguan; edge batal jika Fresh+FVG < 0R dalam
  100 trades terakhir → kembali demo.
- ADX MT5 asli > aproksimasi replay — percaya panel live, bukan ADX replay.
