# Roadmap Pengembangan — SRD (MQL5)

> Dokumen perencanaan teknis, backlog fitur, dan panduan evolusi untuk **`SRD_Indi.mq5`** (evolusi lanjutan dari `multi_indicator.mq5`).  
> Terakhir diperbarui: **2026-09** | Status Aktif: **v2.51 (Fase 5.6 Selesai Penuh)**.

---

## 1. Status Rilis & Riwayat Versi (Completed Milestones)

| Versi | Rilis | Status | Deskripsi Singkat |
|---|---|---|---|
| **v1.00** | 2026-09 | ✅ Selesai | Fondasi awal: Deteksi fractal swing, cluster zona S&R, trend panel makro D1/H4/H1 (EMA+ADX+RSI), dashboard warna standalone & read-only. |
| **v1.01** | 2026-09 | ✅ Selesai | Fitur anti-overlap: Auto-clearance toolbar dan panel One-Click Trading MT5 (sadar DPI) serta auto-fit batas layar chart. |
| **v1.02** | 2026-09 | ✅ Selesai | Perbaikan arah penomoran RES: RES 1 = terdekat ke harga running (konsisten dengan SUP 1 = terdekat). |
| **v1.03** | 2026-09 | ✅ Selesai | Perbaikan perhitungan jarak harga (`DiffStr`) sadar digit pair Forex 3/5-digit. |
| **v1.10** | 2026-09 | ✅ Selesai | **Multi-TF S&R Matrix**: Scan serentak 3 Timeframe (M30, H1, H4) dari 1 chart, layout vertikal terpusat (HARGA di tengah, RES 1–3 ke atas, SUP 1–3 ke bawah). |
| **v1.11** | 2026-09 | ✅ Selesai | **Per-Column Rendering**: Memecah label per kolom untuk melompati batasan internal 63 karakter MT5 (`OBJ_LABEL`). Tampilan H4 kini 100% utuh tanpa terpotong di semua monitor & DPI. |
| **v1.20** | 2026-09 | ✅ Selesai | **Fase 1 (Confluence Detector + Instant Load)**: Deteksi otomatis level kembar multi-TF (tanda `★` & warna Emas `clrGold` untuk 3-TF Confluence, tanda `•` & warna Cyan `clrAqua` untuk 2-TF Confluence). Border ganda di chart, serta fallback timer 1 detik di `OnInit()` agar tren langsung tampil instan saat market libur. |
| **v1.30** | 2026-09 | ✅ Selesai | **Fase 2 (Interactive Minimize + Proximity Warning)**: Tombol interaktif `[-]` dan `[+]` di header panel untuk menciutkan/membuka dashboard secara instan, serta fitur Proximity Warning (tanda `►` & warna Kuning menyala `clrYellow` otomatis saat harga sedang mendekati level terdekat). |
| **v1.40** | 2026-09 | ✅ Selesai | **Fase 3 (Quick Stats Bar)**: Baris sub-header di bawah judul panel menampilkan Spread real-time, ADR-14 (rata-rata range harian 14 hari D1 dalam poin), Range Hari Ini sebagai % ADR, dan Sisa poin. Warna peringatan otomatis `clrOrange` jika range > 90% ADR (potensi pasar melambat). |
| **v1.50** | 2026-09 | ✅ Selesai | **Fase 4 (S&D Zone Engine)**: Deteksi otomatis 4 pola Supply & Demand (RBR/DBD/DBR/RBD) di H1 & H4. Filter Fresh/Tested/Consumed, Strength Score (⚡ ATR multiplier), deteksi confluence S&R+S&D (border emas ★), 2 baris baru `[S&D] S|` dan `[S&D] D|` di dashboard, serta kotak zona S&D di chart. |
| **v1.51** | 2026-09 | ✅ Selesai | **Fase 4.1 (S&D Calibration & Diagnostic Fix)**: Kalibrasi threshold ATR agar adaptif terhadap volatilitas Gold, integrasi diagnostic HUD `Comment(dbg)`, relaksasi syarat ImpIn, perbaikan penyelarasan kolom visual S&D di dashboard, serta ekspansi scan history. |
| **v2.00 (SRD)** | 2026-09 | ✅ Selesai | **Rilis Resmi SRD**: Tombol toggle runtime `[S&R]` & `[S&D]` di chart, modul **"LEVEL TERKUAT"** (top-2 RES & top-2 SUP gabungan 3 TF + 1 Supply & 1 Demand S&D terkuat), prefix terisolasi ringkas `SRD_`. |
| **v2.10 (SRD)** | 2026-09 | ✅ Selesai | **Fase 5.1 (Multi-Channel Smart Alert)**: Push notification instan ke MT5 HP (Android/iOS via `SendNotification`), smart filter level kunci (Confluence ★★★, Fresh S&D, Level Terkuat), dan cooldown anti-spam 15 menit. |
| **v2.20 (SRD)** | 2026-09 | ✅ Selesai | **Fase 5.2 (R:R Helper - Opsi A)**: 2 baris proyeksi `SETUP > BUY` & `SELL` di panel otomatis menghitung Entry, SL (Buffer ATR), Target TP (RES/SUP Terkuat), dan Rasio R:R sebelum eksekusi order. |
| **v2.30 (SRD)** | 2026-09 | ✅ Selesai | **Fase 5.3 (FVG Imbalance Confluence - Opsi 2)**: Deteksi 3-candle imbalance pada departure leg S&D, verifikasi unmitigated status, sematkan tag `+FVG` di baris S&D dan SETUP panel, serta visualisasi kotak fisik transparan dashed FVG di chart. |
| **v2.40 (SRD)** | 2026-09 | ✅ Selesai | **Fase 5.4 (Liquidity Sweep / Stop Hunt Reversal - Opsi 1)**: Deteksi candle penembusan zona dengan wick $\ge 0.3 \times \text{ATR}$ yang close kembali ke dalam base, penanda visual `⚡ SWEEP` di chart, serta peringatan instan pada baris status judul dashboard. |
| **v2.50 (SRD)** | 2026-09 | ✅ Selesai | **Fase 5.6a (Kalibrasi R:R Helper — 3 Mode Entry)**: Input `InpRR_EntryMode` dengan 3 pilihan: `Aggressive` (edge 0%), `Equilibrium` (mid 50%), `Conservative` (deep 80%). SL tetap dari batas belakang + buffer ATR. Risk, Reward, bintang ★ (RR≥2.0) dihitung ulang sesuai mode. Label `@mid` / `@deep` tampil di baris SETUP. Tooltip S&D menampilkan risk poin & mode. |
| **v2.51 (SRD)** | 2026-09 | ✅ Selesai | **Fase 5.6b (FVG 50% CE Mitigation)**: Input `InpFVG_MitigationType` dengan 2 pilihan: `FVG_MITIGATE_50PCT_CE` (Consequent Encroachment — **default**, SMC/ICT standar, mitigated saat Low/High retest ≥50% celah) dan `FVG_MITIGATE_FULL_FILL` (100% — hanya mitigated jika celah tertutup penuh). Tooltip kotak FVG menampilkan mode aktif. |

---

## 2. Backlog Fitur Profesional (Next Versions — v2.50+)

Berikut adalah roadmap fitur prioritas untuk peningkatan performa analisis, akurasi institusional, dan kenyamanan visual trader:

```text
                  ┌───────────────────────────────────────────────────────────────┐
                  │                   ROADMAP PENGEMBANGAN SRD                    │
                  └──────────────────────────────┬────────────────────────────────┘
                                                 │
        ┌───────────────┬────────────────┼───────┴────────┬───────────────┬───────────────┐
        │               │                │                │               │               │
 ┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐  ┌────▼────┐    ┌─────▼─────┐
 │  FASE 5.1   │  │  FASE 5.2   │  │  FASE 5.3   │  │  FASE 5.4   │  │ FASE 5.5│    │ FASE 5.6  │
 │ Mobile Push │  │ R:R Helper  │  │ FVG Imbal.  │  │ Liquidity   │  │ Hotkeys │    │ Calibrasi │
 │ & Smart Notif│ │ Auto Proj.  │  │ Confluence  │  │ Sweep Hunt  │  │ & Drag  │    │  RR & FVG │
 ├─────────────┤  ├─────────────┤  ├─────────────┤  ├─────────────┤  ├─────────┤    ├───────────┤
 │• SendNotif()│  │• Entry/SL/TP│  │• 3-Bar Gap  │  │• Wick Sweep │  │• 'R','D'│    │• 3 Entry  │
 │• Filter Lvl │  │• Proyeksi RR│  │• +FVG Tag   │  │• Close Base │  │  'M' key│    │  Modes    │
 │  Terkuat    │  │  di Panel   │  │• Box Chart  │  │• ⚡ SWEEP    │  │• DragUI │    │• 50% CE   │
 └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘    │  Mitigasi │
   ✅ Selesai       ✅ Selesai       ✅ Selesai       ✅ Selesai       ⭐ Prioritas 2 └───────────┘
                                                                                     ✅ Selesai
```

---

### Fitur 1: Multi-Channel Smart Alert (MT5 Mobile Push & Smart Filter)
* **Target Versi**: `v2.10`
* **Prioritas**: ⭐⭐⭐⭐⭐ (Sangat Tinggi)
* **Kategori**: *Real-time Alerts & Mobility*
* **Tujuan**: Memungkinkan trader menerima notifikasi instan langsung di smartphone (aplikasi MT5 Android/iOS) saat harga menyentuh zona kunci tanpa harus menatap layar chart PC/VPS terus-menerus.
* **Spesifikasi Teknis**:
  * Integrasikan fungsi native `SendNotification()` bersamaan dengan `Alert()`.
  * **Smart Alert Filter**: Menyediakan opsi filter agar notifikasi ke ponsel hanya terpicu jika:
    1. Harga menyentuh level **Confluence 3-TF (`★★★`)**.
    2. Harga menyentuh zona **Fresh S&D** terdekat.
    3. Harga menyentuh salah satu dari **Level Terkuat** (`g_strongRes` / `g_strongSup`).
  * Mencegah banjir notifikasi (*spam alert*) dengan mekanisme jeda/cooldown per level yang sama (misal 15 menit).

---

### Fitur 2: Otomatisasi Kalkulasi Risk-to-Reward (R:R Helper pada Baris Level Terkuat)
* **Target Versi**: `v2.10`
* **Prioritas**: ⭐⭐⭐⭐ (Tinggi)
* **Kategori**: *Risk Management & Execution Helper*
* **Tujuan**: Memberikan panduan matematis instan mengenai kelayakan rasio untung-rugi (*Risk-to-Reward Ratio*) untuk setiap setup sebelum trader mengeksekusi order.
* **Spesifikasi Teknis**:
  * Memanfaatkan batas presisi zona yang sudah dihitung oleh SRD:
    * **Setup Demand**: Entry = `Top` Base, SL = `Bottom` Base minus buffer ATR ($0.2\times\text{ATR}$), TP = `RES 1` terdekat.
    * **Setup Supply**: Entry = `Bottom` Base, SL = `Top` Base plus buffer ATR ($0.2\times\text{ATR}$), TP = `SUP 1` terdekat.
  * Hitung rasio: $\text{RR} = \frac{|\text{TP} - \text{Entry}|}{|\text{Entry} - \text{SL}|}$.
  * Tampilkan di baris Level Terkuat dashboard atau tooltip chart:  
    `[D:2408.00] SL:2401.50 | TP:2428.00 | RR 1:3.1` (highlight warna Emas jika $\text{RR} \ge 1:2.0$).

---

### Fitur 3: FVG (Fair Value Gap / Imbalance) Confluence Detector (Opsi 2)
* **Status**: ✅ **SELESAI (Rilis di `v2.30`)**
* **Prioritas**: ⭐⭐⭐⭐ (Tinggi)
* **Kategori**: *Smart Money Concepts (SMC) & Institutional Price Action*
* **Tujuan**: Memperkuat validasi zona S&D dengan mendeteksi adanya celah ketidakseimbangan harga 3-candle (*imbalance*) yang ditinggalkan oleh lonjakan institusi pada departure leg.
* **Implementasi Teknis Selesai**:
  * **Deteksi Departure Leg**: Evaluasi 3-candle imbalance saat harga meninggalkan base (`c3_low > c1_high` untuk Bullish FVG Demand, `c1_low > c3_high` untuk Bearish FVG Supply) dengan threshold gap $\ge \text{InpFVG\_MinGapATR} \times \text{ATR}$.
  * **Verifikasi Mitigasi**: Memeriksa seluruh candle subsequent hingga harga running (`bid`). Jika celah belum tertutup penuh, status ditetapkan sebagai **UNMITIGATED**.
  * **Hirarki Panel Dashboard**:
    * Tag **`+FVG`** disematkan di kolom `[S&D] S|` dan `[S&D] D|` (contoh: `★ 2408.00 RBR(⚡1.8x)+FVG`).
    * Baris proyeksi `SETUP > BUY` & `SELL` otomatis menampilkan `D:2408.00+FVG` dan `S:2415.00+FVG` dengan panjang baris dijaga ketat $\le 61$ karakter (aman di bawah limit 63 karakter MT5).
  * **Visual Chart (Opsi 2)**:
    * Menggambar kotak fisik terpisah bertransparansi dengan garis putus-putus (*dashed rectangle*) tepat pada celah harga FVG (`SRD_FVG_*`).
    * Border kotak S&D utama diberi warna aksen terang (`clrAqua` / `clrHotPink` / `InpColorSDConf`) dengan ketebalan 2px jika memiliki FVG.
    * Tooltip box chart menampilkan detail rentang Gap dan status `⚡ UNMITIGATED FVG`.
    * Otomatis terhapus bersamaan dengan toggle S&D atau mitigasi.
  * **Smart Alerts & Priority**: S&D terkuat memprioritaskan zona dengan confluence FVG, dan alert push MT5 menyertakan tag `[+FVG]`.

---

### Fitur 4: Deteksi Liquidity Sweep / Fakeout (Stop Hunt Reversal - Opsi 1)
* **Status**: ✅ **SELESAI (Rilis di `v2.40`)**
* **Prioritas**: ⭐⭐⭐ (Menengah)
* **Kategori**: *Market Manipulation & False Breakout Filter*
* **Tujuan**: Menangkap fenomena institusional saat harga sengaja menembus level Support/Resistance/S&D sejenak hanya untuk mengambil likuiditas stoploss (*stop hunt*), lalu berbalik arah dengan cepat.
* **Implementasi Teknis Selesai**:
  * **Algoritma Rejection Wick**: Memeriksa penembusan level S&R (3 TF) dan zona S&D (H1/H4) pada candle bar 1 s/d `InpSweepScanBars`:
    * *Bearish Sweep (Resistance/Supply)*: `High > Level` dengan jarum tembus $\ge \text{InpSweep\_MinWickATR} \times \text{ATR}$ (default $0.3\times\text{ATR}$), namun candle `Close <= Level`.
    * *Bullish Sweep (Support/Demand)*: `Low < Level` dengan jarum tembus $\ge \text{InpSweep\_MinWickATR} \times \text{ATR}$, namun candle `Close >= Level`.
  * **Visual Chart**: Menandai objek teks `⚡ SWEEP` (`SRD_SWEEP_*`) dengan warna hijau (`InpColorSweepBull`) di bawah jarum Low atau warna merah (`InpColorSweepBear`) di atas jarum High, lengkap dengan tooltip detail ukuran wick (dalam poin) dan level yang ditembus.
  * **Status Dashboard (Opsi 1)**: Memunculkan tag peringatan real-time pada baris judul panel:
    * Contoh: `SRD | ALIGNED UP | ⚡ SWEEP BUY H1` (mode penuh) dan `SRD | MIXED | ⚡ SWEEP SELL M30 | BID: 2412.30` (mode minimized), panjang string tetap $\le 49$ karakter.
  * **VPS-Safe**: Komputasi pemindaian berjalan stateless 1x per bar baru di akhir `RecomputeZones()`.

---

### Fitur 5: Hotkeys Keyboard & Draggable Panel (Penyempurnaan Ergonomi UX)
* **Target Versi**: `v2.60`
* **Prioritas**: ⭐⭐⭐ (Menengah)
* **Kategori**: *User Experience & Chart Cleanliness*
* **Tujuan**: Mempercepat alur kerja analisis trader aktif tanpa perlu mengarahkan kursor mouse ke tombol dashboard setiap saat.
* **Spesifikasi Teknis**:
  * Event listener `CHARTEVENT_KEYDOWN` di `OnChartEvent()`:
    * Tekan tombol **`R`**: Toggle ON/OFF visual kotak zona Support & Resistance.
    * Tekan tombol **`D`**: Toggle ON/OFF visual kotak zona Supply & Demand.
    * Tekan tombol **`M`**: Toggle Minimize / Expand panel `[-]` / `[+]`.
  * **Draggable Panel**: Panel dashboard dapat diklik pada area header dan digeser (*drag and drop*) bebas ke posisi mana pun di chart untuk menghindari area candlestick yang sedang dianalisis.

---

### Fitur 6: Kalibrasi Realistis R:R Helper & Mitigasi FVG 50% CE (SMC Standards)
* **Target Versi**: `v2.50–v2.51`
* **Status**: ✅ **SELESAI PENUH (Rilis di `v2.50` + `v2.51`)**
* **Prioritas**: ⭐⭐⭐⭐⭐ (Sangat Tinggi / Kritis — sudah dikerjakan)
* **Kategori**: *Risk Precision & SMC Institutional Logic*
* **Latar Belakang & Masalah**:
  1. **R:R Helper Bias Agresif**: Saat ini entry dihitung dari tepi terluar zona (`dz.top` untuk Demand, `sz.bottom` untuk Supply). Ini adalah skenario *best-case* tertipis risk-nya, sehingga RR dan bintang `★` (RR $\ge 2.0$) tampil terlalu optimis dibanding eksekusi riil trader yang menunggu retest lebih dalam (50% / base).
  2. **Mitigasi FVG Terlalu Longgar (Full-Fill)**: Pengujian mitigasi FVG saat ini mensyaratkan *full gap fill* (100% tertutup jarum). Akibatnya, tag `+FVG` dan kotak unmitigated bertahan terlalu lama padahal harga sudah merespons *Consequent Encroachment* (50% level gap) khas SMC/ICT.
* **Spesifikasi Solusi Teknis**:
  1. **Mode Entry S&D Terkalibrasi (`ENUM_RR_ENTRY_MODE`)**:
     * `RR_ENTRY_AGGRESSIVE` (Edge / 0%): Tepi terluar (`dz.top` / `sz.bottom`) — *default saat ini*.
     * `RR_ENTRY_EQUILIBRIUM` (Mid / 50%): Titik tengah zona `(top + bottom) / 2` — kalkulasi seimbang & realistis.
     * `RR_ENTRY_CONSERVATIVE` (Deep / 80%): Penetrasi dalam ke dasar zona (80% kedalaman) — risk minimal, potensi missed trade tinggi.
     * Formula dinamis SL tetap menjaga buffer ATR dari batas belakang base, namun besaran Risk (`|Entry - SL|`) dan Reward (`|TP - Entry|`) serta kelayakan bintang `★` dihitung akurat sesuai pilihan trader.
  2. **Opsi Mitigasi FVG (`ENUM_FVG_MITIGATION`)**:
     * `FVG_MITIGATE_50PCT_CE` (**Recommended SMC**): Menganggap FVG sudah mitigated jika candle retest menyentuh $\ge 50\%$ dari tinggi gap (Consequent Encroachment).
     * `FVG_MITIGATE_FULL_FILL` (100%): Hanya mitigated jika seluruh celah tertutup penuh.
     * Memperbarui kalkulasi `HasUnmitigatedFVG()` dan rendering visual kotak FVG di chart secara instan.
* **Implementasi Selesai di Kode (SRD.mq5 v2.51)**:
  * ENUM_RR_ENTRY_MODE + input InpRR_EntryMode (Aggressive/Equilibrium/Conservative) via fungsi CalcEntryFromZone() + label @mid/@deep di CalcRRStrings().
  * ENUM_FVG_MITIGATION + input InpFVG_MitigationType (50pct CE default) via threshold mitThreshold midpoint vs full-fill di FindSDZonesForTF() Bullish & Bearish.

---

## 3. Matriks Rencana Implementasi

| Fase | Target Fitur | Estimasi Kompleksitas | Kompatibilitas VPS |
|---|---|---|---|
| **Fase 1 (v1.20)** | • Confluence Detector (`★★★`)<br>• Instant Load Init (`OnInit`) | Ringan | Sangat Ringan (tanpa beban loop baru) |
| **Fase 2 (v1.30)** | • Tombol Minimize `[-]` / `[+]`<br>• Proximity Warning | Ringan–Sedang | 100% Event-driven (hanya aktif saat di-klik) |
| **Fase 3 (v1.40)** | • Header Quick Stats (Spread & ADR) | Sangat Ringan | Sangat Hemat Sumber Daya |
| **Fase 4 (v1.50)** | • S&D Zone Engine (RBR/DBD/DBR/RBD)<br>• Fresh/Tested/Consumed Filter<br>• Strength Score (⚡ ATR Multiplier)<br>• Confluence S&R+S&D Tag<br>• S&D Panel Rows + Chart Boxes | Sedang–Berat | Aman VPS (1× per bar, no tick loop) |
| **Fase 4.1 (v1.51)** | • Live Diagnostic HUD `Comment(dbg)`<br>• Adaptive Threshold Tuning (1.0 ATR / 0.8 Base)<br>• Scan History Expansion (400 Bars)<br>• Relaxation of Arrival Leg (ImpIn)<br>• Dashboard Column Alignment Fix (M30/H1/H4) | Ringan–Sedang | 100% Aman VPS (Optimasi filter, tanpa penambahan loop berat) |
| **Fase 5 (v2.00 - SRD)** | • Runtime Toggle `[S&R]` & `[S&D]` Buttons<br>• Baris LEVEL TERKUAT (Top-2 RES/SUP + 1 S&D)<br>• Rebranding & Prefix `SRD_` | Ringan–Sedang | 100% Aman VPS (Event-driven visual toggle, no extra loop) |
| **Fase 5.1 (v2.10)** | • Multi-Channel Smart Alert (`SendNotification`)<br>• Filter Alert Level Terkuat & Fresh S&D<br>• Cooldown Anti-Spam 15 Menit | Ringan | ✅ Selesai (100% Ringan, Event-driven) |
| **Fase 5.2 (v2.20)** | • R:R Helper (Kalkulasi Auto Entry/SL/TP & Rasio RR)<br>• Tampilan Baris SETUP di Panel & Tooltip Chart | Ringan | ✅ Selesai (100% Ringan, Aritmatika Presisi) |
| **Fase 5.3 (v2.30)** | • FVG (Fair Value Gap) Imbalance Detector<br>• Tag `+FVG` Confluence S&D & Box Chart Dashed | Sedang | ✅ Selesai (100% Ringan, Evaluasi Departure) |
| **Fase 5.4 (v2.40)** | • Deteksi Liquidity Sweep / Fakeout<br>• Penanda Grafis `⚡ SWEEP` di Chart & Tag Dashboard | Ringan–Sedang | ✅ Selesai (100% Ringan, Evaluasi Wick Jarum) |
| **Fase 5.6 (v2.50–2.51)** | • **Kalibrasi Realistis R:R Helper** (Edge 0% / Mid 50% / Deep 80%)<br>• **FVG 50% CE Mitigation** (Consequent Encroachment vs Full-Fill) | Ringan–Sedang | ✅ **Selesai Penuh (v2.50 + v2.51)** |
| **Fase 5.5 (v2.60)** | • Hotkeys Keyboard (`R`, `D`, `M`)<br>• Draggable Panel (Click & Drag Header) | Ringan–Sedang | ⭐ Prioritas 2 (100% Event-driven) |

---

## 4. Prinsip Arsitektur yang Wajib Dijaga

1. **Tetap Read-Only**: Indikator tidak boleh mengeksekusi order, tanpa magic number, tanpa lot sizing, agar aman dipadukan dengan EA apa pun.
2. **Performa VPS**: Seluruh kalkulasi berat (scan bar dan clustering) tetap dibatasi hanya berjalan 1x per bar baru.
3. **Batas Karakter MT5**: Setiap label string baru tidak boleh melebihi batas 63 karakter agar tidak terpotong oleh engine rendering MetaTrader.
4. **Isolasi Objek**: Semua objek chart wajib mempertahankan prefix `SRD_` agar pembersihan chart (`OnDeinit`) tetap bersih 100%.
