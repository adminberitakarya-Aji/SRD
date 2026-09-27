# SRD.md

> **Dokumentasi teknis & panduan penggunaan** — `SRD.mq5 v2.51`  
> Indikator **standalone, read-only**: membaca harga, menganalisis struktur Multi-TF S&R + S&D Matrix (M30, H1, H4) + Level Terkuat + Kalkulator R:R Setup + FVG Imbalance Confluence + Detektor Liquidity Sweep + panel tren D1/H4/H1 dalam satu dashboard matriks presisi. **Tidak ada logika trading sama sekali** (tanpa order, lot, SL/TP, magic number) dan **tidak terhubung ke EA mana pun**.

---

## 1. Identitas & Filosofi

| Aspek | Keputusan | Alasan |
|---|---|---|
| **Tipe** | **Indicator** (`OnCalculate`), bukan EA | Hanya membaca pasar & menggambar — indikator = pembaca, EA/trader = pelaku |
| **Kemandirian** | 1 file mandiri, tanpa include kustom | Dapat dipasang di chart broker mana pun tanpa dependensi file eksternal |
| **Read-only** | Hanya membaca harga & membuat chart objects | 100% aman untuk Strategy Tester, live akun, dan tidak mengganggu EA lain |
| **Multi-TF Matrix** | S&R discan serentak 3 TF (default: M30, H1, H4) | Dari 1 chart TF apa saja, trader langsung melihat struktur 3 TF |
| **Runtime Control** | Tombol klik langsung di chart: `[S&R]`, `[S&D]`, `[-]` | Sembunyikan/tampilkan gambar zona seketika tanpa membuka menu properties |
| **Smart Ranking** | Baris `TERKUAT>` otomatis memilih level kunci | Mengeliminasi kebingungan membaca puluhan level di tabel |
| **Stateless Recompute** | Zona S&R & S&D di-rebuild setiap bar baru | Sederhana, bebas bug akumulasi state; perpindahan SUP/RES terjadi otomatis |

**Sebelas pilar dalam satu dashboard SRD:**
1. **Struktur Multi-TF S&R** — Matriks zona (M30, H1, H4): RES 3–1, HARGA tengah, SUP 1–3
2. **Confluence Detector** — Sorot level kembar antar-TF (Emas `★★★` untuk 3-TF / Cyan `★★` untuk 2-TF)
3. **Level Terkuat (Smart Ranking)** — Top-2 RES & Top-2 SUP terkuat serta 1 Supply & 1 Demand terkuat
4. **R:R Helper (Setup Projections)** — Proyeksi otomatis Entry, SL, TP, dan rasio R:R pada baris `SETUP > BUY` & `SELL`
5. **S&D Zone Engine** — Deteksi zona Supply & Demand via pola RBR/DBD/DBR/RBD di H1 & H4
6. **FVG Imbalance Engine (Fase 5.3)** — Deteksi Fair Value Gap departure leg, tag `+FVG` di panel, & kotak transparan dashed FVG di chart
7. **Liquidity Sweep Engine (Fase 5.4)** — Deteksi candle stop hunt / fakeout (`⚡ SWEEP` di chart + tag status real-time di judul panel)
8. **Interactive Controls** — Tombol toggle chart `[S&R]` & `[S&D]` serta minimize `[-]`/`[+]`
9. **Quick Stats Bar** — Spread real-time, ADR-14, Range Hari Ini (%), dan peringatan potensi pasar jenuh (`SLOW`)
10. **Arah & Kekuatan Tren** — EMA 50 slope per TF (D1/H4/H1) + ADX + status RSI OB/OS
11. **Smart Alerts & Mobility** — Alert pop-up terminal PC + MT5 Mobile Push Notification + Cooldown anti-spam

---

## 2. Arsitektur Modul

```
OnCalculate (per tick)
 +-- [bar baru?] --- YES --> UpdateTrends()        : arah/ADX/RSI D1-H4-H1
 |                  +------> RecomputeZones()       : scan swing -> zona -> touches (3 TF)
 |                               +-- BuildNearestListsForTF() : 3 RES & 3 SUP per TF
 |                               +-- CheckConfluence()        : deteksi level kembar antar-TF
 |                               +-- DrawNearestZones()       : gambar rectangle S&R (jika g_showSR ON)
 |                               +-- RecomputeSD()            : S&D engine orchestrator
 |                               |       +-- FindSDZonesForTF()     : scan pola RBR/DBD/DBR/RBD
 |                               |       +-- CheckSDSRConfluence()  : tag overlap S&D + S&R
 |                               |       +-- BuildNearestSD()       : demand & supply terdekat
 |                               |       +-- DrawSDZones()          : gambar kotak S&D (jika g_showSD ON)
 |                               +-- FindStrongestLevels()    : ranking top-2 RES/SUP & S&D terkuat
 +-- UpdateDashboard()      : render panel tabel presisi (ringan, tiap tick)
 |       +-- CalcStats()    : Spread, ADR-14, Range hari ini
 |       +-- FormatLevelCell(): format sel dengan Proximity & Confluence color
 |       +-- ResTag() / SupTag(): format teks ringkas baris TERKUAT
 +-- CheckAlerts()          : alert popup saat harga sentuh zona (opsional)

OnInit       : buat handle EMA/ADX/RSI (3 TF) + ATR S&R (3 TF) + ATR S&D (2 TF)
OnTimer      : fallback update 1 detik saat pasar libur / belum ada tick baru
OnDeinit     : ObjectsDeleteAll(OBJ_PREFIX) + IndicatorRelease semua handle
OnChartEvent : deteksi klik tombol [-]/[+], [S&R], dan [S&D]
```

**Prinsip performa VPS:**  
Proses komputasi berat (scan bar history, clustering fraktal, dan pengenalan pola S&D) hanya dijalankan **1x per pergantian bar baru**. Pemrosesan per tick dibatasi hanya pada pembaruan teks dashboard dan evaluasi jarak harga running.

---

## 3. Layout Dashboard SRD (v2.30)

```text
+------------------------------------------------------------------------+
| SRD | ALIGNED UP                                    [S&R] [S&D] [-]    |
| SPR:12  ADR14:285  Range:193(68%)  Sisa:92.0pt                         |
| D1 : UP (kuat)   ADX 31.2  RSI 58.3                                    |
| H4 : UP (lemah)  ADX 18.4  RSI 71.2 OB!                                |
| H1 : DOWN        ADX 22.0  RSI 44.0                                    |
| TERKUAT> RES1 H4 2435.50(★★★ 40x)   RES2 H1 2428.80(★★ 12x)             |
|          SUP1 H1 2408.00(★★★ 28x)   SUP2 M30 2401.10(★★ 15x)  S:.. D:..|
| SETUP > BUY D:2408.00+FVG (SL:2401.50 TP:2435.50|RR 1:4.2) ★          |
|        SELL S:2435.50     (SL:2442.00 TP:2408.00|RR 1:4.3) ★          |
+------------------------------------------------------------------------+
|           |         M30        |        H1          |        H4        |
+-----------+--------------------+--------------------+------------------+
| RES 3     |  2418.50(+9.9|1x)  |  2424.00(+15.4|1x) | ★2435.00(+26.4|1x)|
| RES 2     |  2414.20(+5.6|2x)  | •2418.90(+10.3|2x) | •2428.50(+19.9|4x)|
| RES 1     | ►2410.50(+1.9|1x)  |  2414.50( +5.9|3x) |  2419.00(+10.4|3x)|
+-----------+--------------------+--------------------+------------------+
|                       HARGA RUNNING : 2408.60                          |
+-----------+--------------------+--------------------+------------------+
| SUP 1     |  2405.10( -3.5|2x) |  2401.15( -7.4|3x) | ★2394.50(-14.1|5x)|
| SUP 2     |  2402.40( -6.2|1x) |  2396.00(-12.6|2x) |  2382.00(-26.6|2x)|
| SUP 3     |  2399.00( -9.6|1x) |  2390.80(-17.8|1x) |  2370.10(-38.5|1x)|
+-----------+--------------------+--------------------+------------------+
|[S&D] S|   - - -              |  2428.80 (RBD⚡2.8x)|★2435.50 (DBD⚡1.9x)+FVG|
|[S&D] D|   - - -              |★2408.00 (RBR⚡2.2x)+FVG| 2401.10 (DBR⚡1.4x) |
+------------------------------------------------------------------------+
```

### Tombol Kontrol Header
* **`[S&R]`**: Toggle ON/OFF kotak zona Support & Resistance di chart. Hijau = Aktif, Abu-abu = Disembunyikan.
* **`[S&D]`**: Toggle ON/OFF kotak zona Supply & Demand di chart. Hijau = Aktif, Abu-abu = Disembunyikan.
* **`[-]` / `[+]`**: Menciutkan panel menjadi 1 baris ringkas saat butuh ruang chart yang lapang, atau mengembalikannya ke tampilan penuh.

> **Catatan:** Mematikan tombol `[S&R]` atau `[S&D]` hanya menyembunyikan gambar kotak di chart candle. Data matriks dan baris S&D di tabel dashboard tetap aktif diperbarui secara real-time.

---

## 4. Modul Level Terkuat (Smart Ranking)

Modul `FindStrongestLevels()` mengumpulkan seluruh level aktif (maksimal 9 Resistance dan 9 Support dari 3 timeframe) kemudian melakukan perankingan:

1. **Resistance & Support**:
   - Prioritas 1: **Confluence multi-TF** (3 TF `★★★` > 2 TF `★★` > 1 TF biasa).
   - Prioritas 2: **Total Touches** gabungan seluruh TF yang berkonfluensi.
   - Hasil: Mengambil 2 level Resistance teratas (`RES1`, `RES2`) dan 2 level Support teratas (`SUP1`, `SUP2`).
2. **Supply & Demand**:
   - Memilih 1 Supply dan 1 Demand terkuat.
   - Prioritas diberikan pada zona yang berimpit dengan level S&R (`srConfl`), lalu yang memiliki jarak terdekat dengan harga running.

---

## 5. S&D Zone Engine — Anatomi & Pola

Zona Supply & Demand dideteksi berdasarkan struktur institusional: **[Leg Masuk / Arrival] $\rightarrow$ [Base Konsolidasi] $\rightarrow$ [Leg Keluar / Departure Impulsive]**.

```text
    DEMAND (Area Beli)                  SUPPLY (Area Jual)

  1) RBR (Rally-Base-Rally)           1) DBD (Drop-Base-Drop)
          ▲                                    │
          │ [Rally]                            ▼ [Drop]
       ┌──┴──┐                              ┌──┴──┐
       │BASE │ (Demand)                     │BASE │ (Supply)
       └──┬──┘                              └──┬──┘
          ▲                                    │
          │ [Rally]                            ▼ [Drop]

  2) DBR (Drop-Base-Rally)            2) RBD (Rally-Base-Drop)
          ▲                                    ▲
          │ [Rally]                            │ [Rally]
       ┌──┴──┐                              ┌──┴──┐
       │BASE │ (Demand Kuat)                │BASE │ (Supply Kuat)
       └──┬──┘                              └──┬──┘
          │                                    │
          ▼ [Drop]                             ▼ [Drop]
```

### Tabel Karakteristik Pola

| Pola | Arah Masuk | Arah Keluar | Tipe Area | Karakteristik Pasar |
|---|---|---|---|---|
| **RBR** | Bullish | Bullish | **Demand** | Penerusan tren naik (*bullish continuation*) |
| **DBD** | Bearish | Bearish | **Supply** | Penerusan tren turun (*bearish continuation*) |
| **DBR** | Bearish | Bullish | **Demand Kuat** | Pembalikan arah tajam dari lembah (*bullish reversal*) |
| **RBD** | Bullish | Bearish | **Supply Kuat** | Pembalikan arah tajam dari puncak (*bearish reversal*) |

### Kriteria Deteksi Matematis (v2.00 Adaptif Volatilitas)
- **Impulse keluar (`ImpOut`)**: `|Body Candle| >= InpImpulseBodyATR * ATR` (default: `1.0 * ATR`).
- **Base Konsolidasi**: 1 hingga `InpBaseMaxCandles` (default: 5) candle dengan rentang `High - Low <= InpBaseMaxATR * ATR` (default: `0.8 * ATR`).
- **Arrival (`ImpIn`)**: Membaca arah kedatangan untuk menentukan klasifikasi pola tanpa batas kaku yang memotong pembalikan harga alami.

### 3 Status Siklus Zona
1. **Fresh**: Zona belum pernah tersentuh harga sama sekali sejak terbentuk. Memiliki probabilitas pantulan tertinggi (*unfilled orders* institusi masih utuh).
2. **Tested**: Harga sudah pernah masuk 1 kali ke zona lalu memantul. Sebagian pesanan telah terisi (*partially mitigated*).
3. **Consumed**: Harga menembus melampaui batas zona (close di luar zona). Zona otomatis dibersihkan dari memori dan chart.

---

## 6. Referensi Input Lengkap

### 6.1 S&R Multi-Timeframe Engine
| Parameter | Default | Keterangan |
|---|---|---|
| `InpSR_TF1` | `PERIOD_M30` | Timeframe S&R Kolom 1 |
| `InpSR_TF2` | `PERIOD_H1` | Timeframe S&R Kolom 2 |
| `InpSR_TF3` | `PERIOD_H4` | Timeframe S&R Kolom 3 |
| `InpSwingBars` | `0` (otomatis) | Lookback fractal; auto disesuaikan per TF |
| `InpScanBars` | `300` | Jumlah bar history yang discan per TF |
| `InpMergeATRMult` | `0.30` | Toleransi penggabungan swing jika jarak < (x * ATR) |
| `InpZoneMinATR` | `0.15` | Tebal minimum zona (x * ATR) |
| `InpMinTouches` | `1` | Minimal sentuhan agar zona dianggap valid |

### 6.2 Confluence Detector
| Parameter | Default | Keterangan |
|---|---|---|
| `InpEnableConfluence` | `true` | Aktifkan deteksi level kembar antar-TF |
| `InpConfToleranceATR` | `0.25` | Toleransi selisih jarak antar-TF (x * ATR) |
| `InpColorConf3` | `clrGold` | Warna Confluence 3 TF (`★★★`) |
| `InpColorConf2` | `clrAqua` | Warna Confluence 2 TF (`★★`) |

### 6.3 Proximity & Visual Interaktif
| Parameter | Default | Keterangan |
|---|---|---|
| `InpProximityWarning` | `true` | Peringatan saat harga mendekati level terdekat |
| `InpProximityATR` | `0.15` | Ambang jarak pemicu peringatan (x * ATR) |
| `InpColorProximity` | `clrYellow` | Warna tanda peringatan panah `►` |
| `InpShowZones` | `true` | Kondisi awal toggle tombol `[S&R]` saat di-attach |

### 6.4 Trend Panel
| Parameter | Default | Keterangan |
|---|---|---|
| `InpTrendEMAPeriod` | `50` | Periode EMA untuk penentuan arah tren D1/H4/H1 |
| `InpUseADX` | `true` | Aktifkan modul ADX |
| `InpADX_Period` | `14` | Periode ADX |
| `InpADX_Threshold` | `25.0` | Ambang tren kuat (≥ 25.0) |
| `InpUseRSI` | `true` | Aktifkan modul RSI |
| `InpRSI_Period` | `14` | Periode RSI |
| `InpRSI_OB` / `OS` | `70.0` / `30.0`| Batas Overbought / Oversold |

### 6.5 Quick Stats Bar
| Parameter | Default | Keterangan |
|---|---|---|
| `InpShowStats` | `true` | Tampilkan baris Spread & ADR |
| `InpADR_Period` | `14` | Periode rata-rata range harian ADR (D1) |
| `InpADR_WarnPct` | `90.0` | Batas % ADR untuk memunculkan warning potensi pasar jenuh |
| `InpColorStats` | `clrSilver` | Warna teks normal stats |
| `InpColorADRWarn`| `clrOrange` | Warna peringatan jika range harian melampaui batas |

### 6.6 S&D Engine
| Parameter | Default | Keterangan |
|---|---|---|
| `InpShowSD` | `true` | Master switch modul S&D (matikan jika ingin hemat CPU) |
| `InpSD_TF1` | `PERIOD_H1` | Timeframe 1 pemindaian S&D |
| `InpSD_TF2` | `PERIOD_H4` | Timeframe 2 pemindaian S&D |
| `InpSDScanBars` | `400` | Jumlah bar yang discan per TF S&D |
| `InpImpulseBodyATR`| `1.0` | Minimal besar candle impulse keluar (x * ATR) |
| `InpBaseMaxATR` | `0.8` | Maksimal rentang candle base (x * ATR) |
| `InpBaseMaxCandles`| `5` | Maksimal jumlah candle pembentuk base |
| `InpHideTested` | `false` | Sembunyikan zona yang sudah berstatus Tested |
| `InpShowSD_Debug`| `true` | Tampilkan HUD diagnostik transparan di pojok chart |
| `InpShowSDZonesInit`| `true` | Kondisi awal toggle tombol `[S&D]` saat di-attach |
| `InpColorDemandFill`| `C'20,65,30'` | Warna fill area Demand di chart |
| `InpColorDemandBdr` | `clrLimeGreen` | Warna border area Demand |
| `InpColorSupplyFill`| `C'65,18,18'` | Warna fill area Supply di chart |
| `InpColorSupplyBdr` | `clrOrangeRed` | Warna border area Supply |

### 6.7 Dashboard & Visual Layout
| Parameter | Default | Keterangan |
|---|---|---|
| `InpPanelCorner` | `CORNER_LEFT_UPPER` | Posisi penempatan panel |
| `InpPanelX` / `Y` | `10` / `25` | Koordinat offset panel (px) |
| `InpAvoidOCT` | `true` | Auto-geser menghindari One-Click Trading MT5 |
| `InpOCTClearance` | `120` | Tinggi kawasan atas toolbar + OCT (px @96 DPI) |
| `InpFontSize` | `9` | Ukuran font dashboard |
| `InpFont` | `"Consolas"` | Jenis font (wajib monospace) |
| `InpColorBG` | `C'18,18,18'` | Warna latar belakang panel |
| `InpColorBorder` | `clrDimGray` | Warna border panel & garis pemisah |

### 6.7 Risk:Reward Helper (Fase 5.2 + Fase 5.6a v2.50)
| Parameter | Default | Keterangan |
|---|---|---|
| `InpShowRR` | `true` | Tampilkan baris proyeksi R:R Setup di dashboard |
| `InpRR_EntryMode` | `RR_ENTRY_AGGRESSIVE` | Mode entry Fase 5.6a: Aggressive edge 0% (tanpa label) / Equilibrium mid 50% (`@mid`) / Conservative deep 80% (`@deep`); dihitung via `CalcEntryFromZone()` |
| `InpRR_SLBufferATR` | `0.20` | Buffer jarak SL di luar batas zona base (x ATR) |

### 6.8 FVG (Fair Value Gap) Confluence Engine (Fase 5.3 + Fase 5.6b v2.51)
| Parameter | Default | Keterangan |
|---|---|---|
| `InpEnableFVG` | `true` | Aktifkan deteksi 3-candle imbalance pada departure leg S&D |
| `InpDrawFVGBoxes` | `true` | Gambar kotak fisik area FVG (transparan dashed) di chart (Opsi 2) |
| `InpFVG_MinGapATR` | `0.15` | Ukuran gap minimum untuk validasi FVG (x ATR) |
| `InpFVG_MitigationType` | `FVG_MITIGATE_50PCT_CE` | Mode mitigasi Fase 5.6b: 50% CE midpoint SMC standar vs Full Fill 100%; threshold `mitThreshold` di `FindSDZonesForTF()` |
| `InpColorFVGBull` | `C'0,140,200'` | Warna border kotak Bullish FVG (Demand) di chart |
| `InpColorFVGBear` | `C'200,50,120'`| Warna border kotak Bearish FVG (Supply) di chart |

### 6.9 Liquidity Sweep Engine (Fase 5.4)
| Parameter | Default | Keterangan |
|---|---|---|
| `InpEnableSweep` | `true` | Aktifkan deteksi candle jarum stop hunt / fakeout |
| `InpSweep_MinWickATR` | `0.30` | Ukuran jarum tembus minimal (x ATR) agar valid sebagai sweep |
| `InpSweepScanBars` | `10` | Jumlah bar terakhir yang dipantau di chart candle (1..20) |
| `InpColorSweepBull` | `clrLimeGreen` | Warna penanda Bullish Sweep (Support/Demand) |
| `InpColorSweepBear` | `clrTomato` | Warna penanda Bearish Sweep (Resistance/Supply) |

### 6.10 Alert & Smart Notifications (Fase 5.1)
| Parameter | Default | Keterangan |
|---|---|---|
| `InpAlertTouch` | `false` | Master Switch modul alert saat harga menyentuh zona |
| `InpAlertTerminal` | `true` | Alert suara & pop-up dialog di terminal MT5 PC |
| `InpAlertMobile` | `false` | Push notification ke smartphone (MT5 Android/iOS via `SendNotification`) |
| `InpAlertOnlyStrongest`| `true` | Smart Filter: Hanya picu alert untuk Level Terkuat / Confluence ★★★ / Fresh S&D / +FVG |
| `InpAlertSR` | `true` | Aktifkan deteksi alert untuk zona Support & Resistance |
| `InpAlertSD` | `true` | Aktifkan deteksi alert untuk zona Supply & Demand |
| `InpAlertCooldownMins` | `15` | Waktu jeda (cooldown anti-spam) sebelum level yang sama bisa memicu alert lagi |

---

## 7. Prefix & Manajemen Objek Chart

Semua objek chart yang digambar menggunakan prefix `#define OBJ_PREFIX "SRD_"` untuk menjamin pembersihan 100% tuntas saat indikator di-*remove* (`OnDeinit`):

| Objek | Tipe MT5 | Fungsi |
|---|---|---|
| `SRD_PANEL_BG` | `OBJ_RECTANGLE_LABEL` | Background latar dashboard |
| `SRD_BTN_MIN` | `OBJ_BUTTON` | Tombol minimize/expand `[-]` / `[+]` |
| `SRD_BTN_SR` | `OBJ_BUTTON` | Tombol toggle runtime zona S&R |
| `SRD_BTN_SD` | `OBJ_BUTTON` | Tombol toggle runtime zona S&D |
| `SRD_T_*` | `OBJ_LABEL` | Semua teks dan sel matriks tabel |
| `SRD_T_RR_BUY` | `OBJ_LABEL` | Baris proyeksi kalkulasi R:R Setup BUY |
| `SRD_T_RR_SELL` | `OBJ_LABEL` | Baris proyeksi kalkulasi R:R Setup SELL |
| `SRD_Z_*` | `OBJ_RECTANGLE` | Kotak area Support & Resistance di chart |
| `SRD_SD_*` | `OBJ_RECTANGLE` | Kotak area Supply & Demand di chart |
| `SRD_FVG_*` | `OBJ_RECTANGLE` | Kotak fisik celah Fair Value Gap transparan dashed di chart (Opsi 2) |
| `SRD_SWEEP_*` | `OBJ_TEXT` | Penanda teks/icon `⚡ SWEEP` di ujung jarum candle chart (Fase 5.4) |

---

## 8. Riwayat Versi (Changelog)

| Versi | Rilis | Ringkasan Pembaruan |
|---|---|---|
| **v1.00 - v1.03** | 2026-09 | Fondasi S&R fractal, anti-overlap OCT, digit rounding, penomoran RES terdekat. |
| **v1.10 - v1.11** | 2026-09 | Multi-TF S&R Matrix 3 kolom (M30, H1, H4), per-column rendering batas 63 karakter. |
| **v1.20** | 2026-09 | Confluence Detector level kembar (`★★★`/`★★`), fallback timer `OnInit()` instant load. |
| **v1.30** | 2026-09 | Tombol minimize `[-]`/`[+]`, Proximity Warning panah kuning `►`. |
| **v1.40** | 2026-09 | Quick Stats Bar (Spread, ADR-14, Range Hari Ini %, peringatan `SLOW`). |
| **v1.50 - v1.51** | 2026-09 | S&D Zone Engine (RBR/DBD/DBR/RBD), tuning adaptif Gold (1.0 ATR / 0.8 Base), HUD debug `Comment()`. |
| **v2.00 (SRD)** | 2026-09 | **Rilis Resmi SRD**: Tombol toggle runtime `[S&R]` & `[S&D]`, 2 baris baru **"LEVEL TERKUAT"** (Top-2 RES/SUP + 1 S&D), prefix ringkas `SRD_`. |
| **v2.10 (SRD)** | 2026-09 | **Fase 5.1 (Multi-Channel Smart Alert)**: Dukungan push notification ke smartphone (MT5 mobile Android/iOS), Smart Filter level kunci/Fresh S&D, dan Cooldown anti-spam 15 menit. |
| **v2.20 (SRD)** | 2026-09 | **Fase 5.2 (R:R Helper - Opsi A)**: 2 baris proyeksi `SETUP > BUY` dan `SELL` di panel menghitung Entry, SL (Buffer ATR), Target TP (RES/SUP Terkuat), dan Rasio R:R + Tooltip chart. |
| **v2.30 (SRD)** | 2026-09 | **Fase 5.3 (FVG Imbalance Confluence - Opsi 2)**: Deteksi 3-candle imbalance pada departure leg S&D, verifikasi unmitigated status, tag `+FVG` pada baris S&D dan SETUP panel (panjang $\le 61$ chars), kotak fisik FVG di chart (`SRD_FVG_*`), dan integrasi ranking level terkuat. |
| **v2.40 (SRD)** | 2026-09 | **Fase 5.4 (Liquidity Sweep / Stop Hunt Reversal - Opsi 1)**: Deteksi candle penembusan zona dengan wick $\ge 0.3 \times \text{ATR}$ yang close kembali ke dalam base, penanda visual `⚡ SWEEP` di chart candle (`SRD_SWEEP_*`), serta peringatan instan pada baris status judul dashboard (`⚡ SWEEP BUY/SELL [TF]`). |
| **v2.50 (SRD)** | 2026-09 | **Fase 5.6a (Kalibrasi R:R Helper)**: `ENUM_RR_ENTRY_MODE` + `InpRR_EntryMode` Aggressive/Equilibrium/Conservative via `CalcEntryFromZone()`; label `@mid`/`@deep` di `CalcRRStrings()`; SL tetap buffer ATR. |
| **v2.51 (SRD)** | 2026-09 | **Fase 5.6b (FVG 50% CE Mitigation)**: `ENUM_FVG_MITIGATION` + `InpFVG_MitigationType` 50% CE (default SMC) vs Full Fill; `mitThreshold` midpoint di `FindSDZonesForTF()` Bullish & Bearish. |
