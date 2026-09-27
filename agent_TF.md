# Blueprint Penilaian Signal SRD — Multi-Agent per TF

> Status: DRAFT diskusi | Acuan: SRD_Indi.mq5 v2.51
> Tujuan: ukur % kebenaran signal SRD per TF secara objektif.

## 1. Latar Belakang
SRD per TF (M30/H1/H4) tampilkan 3 RES + 3 SUP terdekat
(g_resLevel/g_supLevel sort by jarak), ranking TERKUAT
(FindStrongestLevels: confluence lalu totalTouches), S&D+FVG+Sweep.
Masalah: TF mana paling valid? Apakah rank1 vs rank2/3 beda?
Apakah filter (TERKUAT/Fresh/+FVG) yg bikin valid?
Prinsip: terdekat utk entry, terjauh utk exit, terkuat utk filter.

## 2. Arsitektur 2 Lapis
SRD_Indi.ex5 (chart) -> SRD_Logger (MQL5 snapshot per bar baru) -> CSV -> Judge (Python pandas).
Logger: snapshot mentah tanpa menilai. Judge: majukan N bar, tentukan TP/SL duluan.
File: agent_TF.md (ini), logger di SRD_Indi.mq5 Fase Agent-1, judge.py (spec Bab 6).
## 3. Definisi Agent
Tiga agent: agent_M30 (kolom M30, noise tinggi, frek tinggi),
agent_H1 (sweet spot intraday XAUUSD), agent_H4 (win tinggi,
sampel kecil, SL lebar, wajib filter ALIGNED D1/H4).
Setiap agent bawa 6 peluru per snapshot: RES1-3 + SUP1-3.
RES1/SUP1 = pintu depan (entry), RES2/SUP2 = TP1, RES3/SUP3 = TP2.
Hanya yg TERSENTUH dinilai; tak tersentuh = NO_TRADE (bukan LOSE).
Satu kandidat max 1 trade (sentuhan pertama saja).
Tag logic tiap kandidat: touches, confluence 1/2/3 (single/2TF/3TF),
totalTouches, isStrongest 0/1 + rank 1/2, sdOverlap 0/1, hasFVG 0/1,
sdStatus Fresh/Tested/None, sweepAtSignal 0/1, trendCtx D1/H4/H1+ADX,
distATR = |price-bid|/ATR_TF. Bisa slice TF dan slice logic.

## 4. Definisi EVENT ENTRY KEBENARAN
Event: snapshot close bar N (clock H1, usulan), ACTIVE saat High/Low
sentuh price +- toleransi min(0.10*ATR_TF, 15*_Point) dalam expiry.
Entry anti-lookahead: signal close N, entry open N+1 (market, Opsi A v1),
level dari snapshot <=N saja. Opsi B limit di level — diputuskan Q2.
SL ATR per TF (bukan global): BUY sl=level-0.20*ATR_TF,
SELL sl=level+0.20*ATR_TF. TP1=entry+-1R. TP2=level terkuat searah
TF sama (fallback 2R). Biaya: spread_snapshot + slippage 50pt XAUUSD.
Expiry adil dalam jam: M30 24j (48 bar), H1 24j (24 bar), H4 48j (12 bar).
Label Judge: WIN_TP1, WIN_TP2, LOSE (SL duluan; SL&TP 1 bar = LOSE),
TIMEOUT (0R-biaya), NO_TRADE (tak tersentuh, luar statistik).
Metrik: hit-TP1%, avg R, expectancy R, PF, median time-to-TP, MAE/MFE,
sweep_fail%. Min n>=100 per grup sebelum simpulkan.

## 5. Spec Logger (SRD_Indi.mq5 Fase Agent-1, SELESAI — default OFF)
Snapshot tiap bar baru H1 (usulan, sinkron 3 agent) + saat SRD recompute.
Satu baris CSV per kandidat (18 baris/snapshot):
time_utc,symbol,clock_tf,agent_tf,side,rank_jarak,price,touches,
confluence,totalTouches,isStrongest,isStrongestRank,sdOverlap,hasFVG,
sdStatus,sweepAtSignal,trendCtx,bid,ask,spread_pt,atr_tf,distATR,
expiry_hours,version
Anti-curang: tulis price/atr/bid/spread + hasFVG/sdStatus/confluence
SAAT snapshot (FVG bisa mitigated 3 bar kemudian). Sertakan version 2.51.
File: MQL5/Files/SRD_Indi_signals_YYYYMMDD.csv (append).
Aktifkan via input InpEnableLogger=true (default false agar panel hemat IO).
Fungsi: LoggerTrendCtx/LoggerStrongRank/LoggerSDTag/LoggerWriteRow/
LoggerMaybeSnapshot dipanggil di OnCalculate + reset di OnInit.

## 6. Spec Judge (Python Fase 2, SELESAI — judge/judge.py)
Input CSV + OHLC M30/H1/H4. Output tabel per (agent_tf,side,rank_jarak)
+ slice filter. Analisis wajib: (1) TF mana valid, (2) rank mana valid,
(3) filter apa menaikkan validitas, (4) mode entry optimal Agg/Mid/Deep
via MAE tanpa re-logging (simulasi CalcEntryFromZone).

## 7. Jebakan SRD
Repaint: hanya snapshot <=N utk trade N+1. FVG 50CE vs FullFill:
snapshot-locked (log mitMode juga). Confluence drift OK dinilai saat
snapshot. Spread XAUUSD wajib. H4 butuh 2-3 thn data utk n>=100.

## 8. Open Issues
Q1 Clock: KUNCI H1 tetap (sinkron 3 agent). Q2 Entry: KUNCI Opsi A
market open N+1 (pasti dapat barang, ukur arah pantulan). Q3 TP2:
KUNCI Opsi A level searah TF sama (fallback 2R bila kosong).
Q4 Expiry: KUNCI 24j M30 / 24j H1 / 48j H4.

## 9. Next Step
Fase 5 live-test: setup SIAP (judge/LIVE_TEST.md + validate_live.py).
Hari ini Minggu market tutup — attach Senin, validasi akhir minggu.
4 Buat judge.py Bab 6 running 2 thn. 5 Keputusan live: TF+filter+mode entry.

## 10. Roadmap Step-by-Step (kunci: Q1=H1, 3 agent tetap)
Fase 0 Kunci Aturan: SELESAI (Q1 H1, Q2 market N+1, Q3 TP2 level, Q4 24/24/48).
0.1 Kunci Q2 entry (usul market open N+1 v1).
0.2 Kunci Q3 TP2 (usul level TF sama, fallback 2R).
0.3 Kunci Q4 expiry: KUNCI 24/24/48 jam (M30 24j, H1 24j, H4 48j).
0.4 Kunci simbol/periode (usul XAUUSD 2022-2024 spread real).
Gate: Q1-Q4 kunci, lanjut Fase 1.

Fase 1 Logger: SELESAI (tulis CSV di dalam SRD_Indi, Opsi A).
1.1 Buat indikator logger: handle ATR M30/H1/H4 + baca
g_resLevel/g_supLevel 3x3 + TERKUAT + hasFVG/sdStatus + sweep + trend.
1.2 Trigger snapshot tiap bar baru H1 (clock kunci), tulis 18 baris CSV
format Bab 5 ke MQL5/Files/SRD_signals_YYYYMMDD.csv (append).
1.3 Snapshot-locked: price/atr/bid/spread/confluence/FVG saat snapshot.
1.4 Uji 1 minggu live/demo: cek 18 baris/jam, kolom lengkap, version 2.51.
Gate: CSV 1 minggu valid, lanjut Fase 2.

Fase 2 Judge v1: SELESAI (judge.py + contoh lolos uji).
2.1 Load CSV + OHLC M30/H1/H4 (MT5 export / paket MetaTrader5).
2.2 Event sentuh +- toleransi dalam expiry 24/24/48 jam, max 1 trade/kandidat.
2.3 Entry open N+1, SL 0.20*ATR_TF, TP1 1R, TP2 level/fallback 2R,
biaya spread+50pt, label WIN_TP1/WIN_TP2/LOSE/TIMEOUT/NO_TRADE.
2.4 Output tabel (agent_tf,side,rank) + metrik hit-TP1 avgR expectancy PF
MAE/MFE time-to-TP sweep_fail. Min n>=100.
Gate: running 2 thn XAUUSD keluar tabel 3x6, lanjut Fase 3.

Fase 3 Analisis Slice: SELESAI full-run 116803 signals (fondasi S&R polos).
3.1 Slice TF: M30 vs H1 vs H4 (expiry jam sama).
3.2 Slice rank: RES1/SUP1 vs RES2/3 per TF.
3.3 Slice filter: conf 3 vs 2 vs 1, TERKUAT, Fresh+FVG, sweep, trend ALIGNED.
3.4 Simulasi mode entry Agg/Mid/Deep via MAE (tanpa re-logging).
Gate: tahu TF+filter+mode terbaik, lanjut Fase 4.

Fase 4 Keputusan Live: SELESAI (SOP_LIVE.md). Aturan: Fresh+FVG saja,
sisi ikut struktur (DN=SELL RES, UP=BUY SUP), MIXED skip, conf 2/3 utama.
4.1 Tetapkan TF+filter yg dipakai live + default Inp* SRD yg perlu direvisi.
4.2 Tulis SOP 1 halaman dari hasil (entry/SL/TP/expiry per TF).
4.3 (Opsional) Revisi SRD.mq5 bila perlu + update SRD.md/roadmap.md.
