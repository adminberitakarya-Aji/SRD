# Hasil Fase 3 — Replay Jan 2024 (XAUUSD.vxc, 8740 signals → 5950 trades)

Periode: 2024-01-02 s/d 2024-02-01 (replay_logger.py, engine ≈ v2.51 tanpa S&D/FVG).
Label: LOSE 3044, WIN_TP2 1953, WIN_TP1 731, TIMEOUT 222. Avg R keseluruhan: -0.157.

## Tabel agent × side × rank (hit% = WIN_TP1+WIN_TP2)
agent,side,rank,n,hit%,avgR,PF
H1,RES,1,399,48.9%,-0.133,0.73
H1,RES,2,348,48.6%,+0.012,1.02
H1,RES,3,286,46.2%,+0.029,1.05
H1,SUP,1,396,45.5%,-0.350,0.34
H1,SUP,2,321,38.9%,-0.363,0.38
H1,SUP,3,234,34.2%,-0.351,0.41
H4,RES,1,426,51.2%,-0.082,0.82
H4,RES,2,346,55.2%,+0.269,1.61
H4,RES,3,260,60.8%,+0.576,2.52
H4,SUP,1,423,53.9%,-0.216,0.50
H4,SUP,2,344,35.5%,-0.363,0.38
H4,SUP,3,244,34.0%,-0.352,0.41
M30,RES,1,360,41.7%,-0.236,0.57
M30,RES,2,342,50.0%,+0.006,1.01
M30,RES,3,275,48.7%,+0.002,1.00
M30,SUP,1,383,43.6%,-0.380,0.30
M30,SUP,2,326,30.7%,-0.465,0.25
M30,SUP,3,237,34.2%,-0.346,0.41

## Slice filter
conf=1: n=1196 hit 43.6% avgR -0.080
conf=2: n=2370 hit 44.5% avgR -0.176
conf=3: n=2384 hit 46.5% avgR -0.177
strong=0: n=4456 hit 44.7% avgR -0.141
strong=1: n=1494 hit 46.5% avgR -0.205
agent=H1: n=1984 hit 44.4% avgR -0.190
agent=H4: n=2043 hit 48.9% avgR -0.046
agent=M30: n=1923 hit 41.8% avgR -0.240
rank=1: n=2387 hit 47.7% avgR -0.230
rank=2: n=2027 hit 43.3% avgR -0.145
rank=3: n=1536 hit 43.5% avgR -0.060

## Baca trader (sampel 1 bulan — belum final, butuh 2-3 thn)
1. Januari 2024 = tren naik (harga 1980→2060): semua SUP/support tenggelam,
   semua RES/resistance terbang. Jangan simpulkan dari 1 bulan.
2. H4 RES rank2/3 positif (PF 1.61/2.52) = pola klasik: tembus RES1 lalu
   lari ke RES2/3 searah tren. Entry fade RES1 rugi, breakout ke RES2/3 untung.
3. CONF ★★★ menaikkan hit (43.6→46.5%) tapi avgR tidak ikut — butuh filter arah tren.
4. Next: replay penuh 2023-2026 + tambah S&D/FVG + trendCtx ADX di replay_logger.