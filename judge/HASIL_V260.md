# Hasil Replay v2.60 — ukur avgR naiknya skor kualitas

## Jan-2024 (8740 signals, mesin v2.51 vs v2.60, judge sama)
| Slice | v2.51 (zona pertama) | v2.60 (skor tertinggi) |
|---|---|---|
| Fresh trades | n107 avgR +0.031 | n118 avgR +0.040 |
| Tested trades | n416 avgR -0.396 | n405 avgR -0.410 |
| Fresh+FVG | n64 +0.383 (sama — FVG sudah best) | n64 +0.383 |
| strong=1 | n1494 -0.205 | n1511 -0.188 |
| Tag berubah | — | 420 baris (4.8%, dominan isStrongest M30→H1/H4) |

## Jan–Mei 2021 (34.536 signals v2.60, 21.052 trades)
Fresh n295 -0.172 | Tested n2459 -0.177 | FVG n180 -0.217
Fresh+FVG n162 -0.159 (SUP n41 -0.725, RES n121 +0.033)
Baseline -0.20. Conf2 hit 45.1% terbaik.

## Baca trader (JUJUR)
1. Skor v2.60 TIDAK menaikkan avgR secara material (Fresh +0.031→+0.040,
   strong -0.205→-0.188). Kenapa: judge menilai SEMUA 18 level disentuh,
   sedangkan skor v2.60 hanya mengubah TAG + TERKUAT + SETUP (display),
   bukan level yg disentuh. avgR judge = f(level, entry/SL/TP), bukan
   f(tag). Kenaikan riil hanya terasa di LIVE (trader hanya entry yg hijau).
2. Bukti tak langsung: tag berubah 420 baris; Fresh trades +11 (Tested yg
   salah-label kini Fresh). Arah benar, besaran kecil di judge.
3. 2021 Fresh+FVG -0.159 (vs +0.383 Jan-2024): regime, bukan bug skor.
   RES +0.033 vs SUP -0.725 — konsisten HASIL_REGIME (fade sisi struktur).
4. Kesimpulan: v2.60 betul secara desain (SOP ditegakkan di panel), tapi
   JANGAN klaim "avgR judge naik" — klaim yg benar: "panel kini menolak
   Tested/noFVG (abu SKIP), sehingga live hanya eksekusi Fresh+FVG".
