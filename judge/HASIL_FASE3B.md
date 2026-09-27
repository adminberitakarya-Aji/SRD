# Hasil Fase 3B — Replay + S&D/FVG/TrendCtx (Jan 2024, 8740 signals)

Engine: replay_logger v2 (S&R + S&D Tested/Fresh + FVG 50%CE + trend EMA50).
FVG hidup: 195 signals (2.2%). Overlap S&D: 496 signals, semua Tested, 0 Fresh.
Judge: 5950 trades (sama dgn run S&R polos — level S&R tidak berubah).

## Slice edge SRD (Jan 2024)
overlap S&D: n349 avgR -0.252 (vs noOverlap n5601 avgR -0.151)
fvg=1: n139 avgR -0.274
overlap+strong: n102 avgR -0.319
trend 2/3 searah: n5216 avgR -0.159
up-aligned D1_UP/H4_UP: n1434 | dn-aligned: n0 (Jan-2024 tren naik)

## Baca trader (1 bulan — diagnosis, bukan vonis)
1. Overlap/FVG MERAH di bulan ini karena semua zona Tested (bekas),
   0 Fresh. Tested = sisa order tipis = wajar kalah di tren naik.
2. FVG 50%CE bekerja (195 unmitigated terdeteksi), tapi menempel di zona
   Tested sehingga tidak mengangkat avgR.
3. TrendCtx EMA50 aproksimasi curiga: D1_UP/H4_DN campur terbanyak,
   dn-aligned NOL di bulan naik-turun — mapping index D1/H4 vs H1
   kemungkinan miring 1 bar. Perlu validasi vs panel MT5 live.
4. Next: full-run + perbaiki trend index + kejar Fresh (bukan Tested).