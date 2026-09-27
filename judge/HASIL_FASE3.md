# Hasil Fase 3 PENUH — Replay 2023-01 s/d 2024-03 (S&R polos)

Signals 116803 -> trades 73174 (LOSE 37195, WIN_TP2 21801,
WIN_TP1 9355, TIMEOUT 4823), NO_TRADE 43629. Avg R: -0.213.
Engine: replay S&R polos tanpa S&D/FVG (fondasi jujur, fade mentah).

## Tabel agent x side x rank
H1 RES 1: n5214 hit46.2% avgR-0.103 PF0.80
H1 RES 2: n3947 hit46.4% avgR-0.041 PF0.91
H1 RES 3: n2869 hit42.2% avgR-0.096 PF0.79
H1 SUP 1: n5246 hit40.1% avgR-0.398 PF0.37
H1 SUP 2: n3780 hit38.4% avgR-0.286 PF0.46
H1 SUP 3: n2594 hit34.8% avgR-0.297 PF0.44
H4 RES 1: n5642 hit47.5% avgR-0.117 PF0.76
H4 RES 2: n3857 hit44.1% avgR-0.141 PF0.71
H4 RES 3: n2567 hit37.9% avgR-0.181 PF0.64
H4 SUP 1: n5673 hit46.1% avgR-0.209 PF0.59
H4 SUP 2: n3745 hit40.3% avgR-0.239 PF0.56
H4 SUP 3: n2424 hit36.8% avgR-0.281 PF0.50
M30 RES 1: n5182 hit47.6% avgR-0.127 PF0.74
M30 RES 2: n4225 hit47.3% avgR-0.161 PF0.72
M30 RES 3: n3407 hit45.6% avgR-0.086 PF0.82
M30 SUP 1: n5393 hit38.8% avgR-0.383 PF0.34
M30 SUP 2: n4181 hit36.2% avgR-0.376 PF0.35
M30 SUP 3: n3228 hit38.5% avgR-0.291 PF0.45

## Slice filter
conf1: n18472 hit40.4% avgR-0.231
conf2: n28396 hit42.9% avgR-0.202
conf3: n26306 hit43.8% avgR-0.211
strong0: n53648 hit41.9% avgR-0.217
strong1: n19526 hit44.4% avgR-0.201
agent H1: n23650 hit41.9% avgR-0.208
agent H4: n23908 hit43.4% avgR-0.185
agent M30: n25616 hit42.4% avgR-0.242
rank1: n32350 hit44.4% avgR-0.222
rank2: n23735 hit42.2% avgR-0.208
rank3: n17089 hit39.7% avgR-0.200

## Avg R per bulan
2023-01 4571 -0.205 | 2023-02 4944 -0.113 | 2023-03 5272 -0.123
2023-04 5100 -0.220 | 2023-05 5786 -0.215 | 2023-06 5811 -0.145
2023-07 5562 -0.177 | 2023-08 5579 -0.206 | 2023-09 5224 -0.276
2023-10 4898 -0.263 | 2023-11 4525 -0.252 | 2023-12 4048 -0.328
2024-01 5939 -0.156 | 2024-02 5604 -0.360 | 2024-03 311 parsial

## Baca trader (fondasi JUJUR)
1. Semua avgR negatif: fade mentah kalah di tren naik 1830->2200.
   SUP lawan tren hancur (-0.3 s/d -0.4R). Bukan vonis SRD.
2. Ranking TF: H4 (-0.185) > H1 (-0.208) > M30 (-0.242). Sesuai hipotesa.
3. Conf3 naikkan hit 40.4->43.8% tapi avgR tetap merah: perlu filter arah.
4. H4 RES rank2/3 hijau Jan-2024 ternyata artefak 1 bulan (full-run merah).
5. OHLC broker hanya s/d 2024-03; n per grup ribuan, syarat n>=100 terpenuhi.

## Next: tambah S&D + FVG + trendCtx ke replay, replay ulang,
slice Fresh+FVG+ALIGNED. Regenerasi lokal (di-ignore git).
