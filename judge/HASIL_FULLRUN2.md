# Hasil Full-Run 2 (Jan–Agu 2021 + mesin betul, 62.127 signals)

OHLC: 113.291 bar (M30 68.388 via chunked retry, H1 34.559, H4 8.864, D1 1.480).
Replay berhenti Agu-2021 (8 bulan, bukan 2021-2026 — H1 broker berlubang
pasca Agu-2021 di akun ini; perlu sumber data lain utk 2022-2026).
Trades: 37.858 (LOSE 18.725, TP2 11.831, TP1 4.414, TO 2.888).

## Slice kunci (8 bulan 2021, pasar sideways 1680-1830)
Fresh: n643 avgR -0.027 | Tested: n5046 avgR -0.120
FVG: n404 avgR -0.093 | Fresh+FVG: n383 avgR -0.055
Overlap: n5689 avgR -0.110 | Baseline: -0.196
Conf 2/3: hit 44.2/43.8% (vs conf1 39.8%) — konfirmasi arah benar.
H1 (-0.164) > H4 (-0.213) > M30 (-0.210) di sideways (kebalikan tren!).

## Baca trader (JUJUR: edge Jan-2024 TIDAK bertahan di 2021)
1. Fresh+FVG -0.055 di 2021 vs +0.383 di Jan-2024. Regime matters:
   Jan-2024 tren naik (FVG breakout searah), 2021 sideways chop
   (FVG fade kena whipsaw). Filter SAMA, hasil BEDA per regime.
2. Tapi ranking filter TETAP: Fresh > Tested, FVG > non-FVG, conf2/3 > conf1
   di KEDUA periode. Arah benar, besaran regime-dependent.
3. Pelajaran: SOP live WAJIB filter regime (ADX/trendCtx) — bukan Fresh+FVG
   mentah. Next: slice per trendCtx + nunggu data 2022-2026.
4. Replay berhenti Agu-2021 = bug data (H1 gap), bukan selesai. Next:
   perbaiki export (skip gap) atau pakai sumber OHLC lain.