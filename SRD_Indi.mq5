//+------------------------------------------------------------------+
//|                                                          SRD.mq5 |
//|  SRD : Multi-TF S&R Matrix + Confluence + S&D Engine v2.51       |
//|  (rewrite dari multi_indicator.mq5 v1.51)                        |
//|                                                                  |
//|  INDICATOR STANDALONE - READ ONLY - TANPA LOGIKA TRADING.        |
//|  Tidak ada order, magic number, lot, SL/TP, maupun koneksi        |
//|  ke EA manapun. Hanya membaca harga & menggambar.                 |
//|                                                                  |
//|  MODUL:                                                          |
//|   1) S&R Matrix    : multi-TF fractal swing (M30, H1, H4) ->     |
//|                      cluster zona -> SUP 1-3 & RES 1-3           |
//|   2) Confluence    : deteksi level kembar antar-TF (★★★ / ★★)    |
//|   3) Proximity     : peringatan visual harga dekat level (► kuning)|
//|   4) Interactive   : tombol minimize [-]/[+], toggle [S&R]/[S&D] |
//|   5) Trend Panel   : EMA + ADX + RSI per TF (D1/H4/H1)           |
//|   6) Dashboard     : matrix table vertikal presisi + HARGA tengah |
//|   7) Level Terkuat : top-2 RES & top-2 SUP gabungan 3 TF,        |
//|                      + 1 Supply & 1 Demand S&D terkuat           |
//|   8) R:R Helper    : kalkulasi auto Entry, SL, TP & Rasio R:R    |
//|                      pada baris SETUP dashboard (Fase 5.2)       |
//|   9) S&D Engine    : deteksi zona RBR/DBD/DBR/RBD + Fresh filter |
//|  10) FVG Engine    : Fair Value Gap / Imbalance Confluence       |
//|                      (+FVG tag + kotak fisik FVG di chart, F5.3) |
//|  11) Liquidity Swp : Deteksi Stop Hunt / Fakeout candle          |
//|                      ('⚡ SWEEP' di candle + tag status, F5.4)   |
//|  12) Smart Alerts  : notifikasi sentuh zona (Terminal + Mobile    |
//|                      Push MT5 + Cooldown Anti-Spam + Smart Filter)|
//|                                                                  |
//|  Dokumentasi lengkap: SRD.md & roadmap.md                         |
//|                                                                  |
//|  BARU DI v2.61 (Audit Fix — versi CSV logger):                     |
//|   - BUG FIX: kolom `version` di CSV logger sebelumnya hardcode    |
//|     "2.51". Kini memakai #define SRD_VERSION (satu sumber), jadi  |
//|     judge.py/validate_live.py bisa membedakan data antar-rilis.   |
//|     CATATAN: #property version tidak bisa memakai macro, sehingga |
//|     saat rilis berikut ubah KEDUANYA (SRD_VERSION + #property).    |
//|                                                                  |
//|  BARU DI v2.60 (Fase 4.2 — Ranking Kualitas SOP LIVE):              |
//|   - SDZoneScore(): Fresh=1000 + FVG=100 + srConfl=50 + strength    |
//|     - penalti jarak/ATR. BuildNearestSD & FindStrongestLevels      |
//|     kini pilih skor tertinggi (Fresh tak lagi kalah jarak).        |
//|   - S&R Terkuat seri (conf+touches sama) dimenangkan jarak dekat.  |
//|   - CalcRRStrings: InpRR_RequireFreshFVG=true (default) menolak    |
//|     zona Tested/tanpa-FVG jadi baris abu SKIP (bukan hijau).       |
//|                                                                  |
//|  BARU DI v2.52 (Audit Fix — Signal Logger stale-data):           |
//|   - BUG FIX: LoggerMaybeSnapshot() sebelumnya menulis snapshot   |
//|     H1 memakai g_resLevel/g_supLevel/g_strongResTF/g_sdZones/    |
//|     g_trend yang hanya ter-refresh mengikuti cadence bar CHART   |
//|     yang di-attach (needRecompute di OnCalculate). Kalau         |
//|     indikator di-attach di chart H4/M30 (bukan H1), sebagian     |
//|     besar baris CSV per-jam sebenarnya berisi data recompute     |
//|     bar chart TERAKHIR, bukan kondisi riil di jam H1 itu.        |
//|   - FIX: LoggerMaybeSnapshot() sekarang memanggil sendiri        |
//|     UpdateTrends()+RecomputeZones() tepat saat mendeteksi bar H1 |
//|     baru (gerbang existing tetap membatasi ke 1x/jam, jadi tetap |
//|     VPS-safe) -- akurasi CSV logger kini independen dari TF chart|
//|     yang dipakai attach.                                         |
//|                                                                  |
//|  BARU DI v2.51 (Fase 5.6 — bagian FVG Mitigation):              |
//|   - Opsi Mitigasi FVG (`ENUM_FVG_MITIGATION`):                   |
//|     * 50% CE (Consequent Encroachment) [DEFAULT, SMC standar]:   |
//|       FVG dinyatakan mitigated saat Low/High candle retest         |
//|       menyentuh midpoint gap (50% kedalaman celah).               |
//|     * Full Fill (100%): hanya mitigated jika celah tertutup       |
//|       penuh (Low<=gapBottom / High>=gapTop). Perilaku lama.       |
//|     Pilihan via input InpFVG_MitigationType di Properties MT5.    |
//|     Tooltip kotak FVG menampilkan mode aktif [50% CE/Full Fill].  |
//+------------------------------------------------------------------+
#property copyright   "SRD - Multi-TF S&R Matrix, Confluence & S&D Engine"
#property link        ""
#property version     "2.61"
#property description "Multi-TF S&R Matrix (M30,H1,H4) + Confluence + Proximity + Toggle S&R/S&D + Quick Stats + Trend D1/H4/H1"
#property description "Level Terkuat + R:R Helper + S&D Engine + FVG Imbalance + Liquidity Sweep + Smart Alert (Push MT5)"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- Prefix semua objek chart milik indicator ini (untuk cleanup rapi & anti-bentrok dgn indikator lain)
//--- Versi tunggal: dipakai #property version DAN kolom version di CSV logger
#define SRD_VERSION   "2.61"
#define OBJ_PREFIX    "SRD_"
#define NUM_SR_TF     3
#define NUM_SR_LEVELS 3
#define NUM_SD_TF     2   // S&D scan 2 TF: H1 & H4

//--- Enum mode entry R:R Helper — HARUS di atas blok input agar bisa dipakai sebagai tipe input (Fase 5.6)
enum ENUM_RR_ENTRY_MODE
  {
   RR_ENTRY_AGGRESSIVE,   // Aggressive: tepi terluar zona (sentuhan pertama, best-case RR)
   RR_ENTRY_EQUILIBRIUM,  // Equilibrium: titik tengah zona (50%, kalkulasi realistis)
   RR_ENTRY_CONSERVATIVE  // Conservative: penetrasi dalam 80% zona (risk terkecil, missed trade lebih sering)
  };

//--- Enum mode mitigasi FVG — HARUS di atas blok input (Fase 5.6)
enum ENUM_FVG_MITIGATION
  {
   FVG_MITIGATE_50PCT_CE,  // 50% CE (Consequent Encroachment) — direkomendasikan SMC/ICT standar
   FVG_MITIGATE_FULL_FILL  // Full Fill (100%) — mitigated hanya jika celah tertutup penuh
  };

//=== INPUT GROUP: S&R MULTI-TIMEFRAME ENGINE ======================
input group "===== S&R MULTI-TIMEFRAME ENGINE ====="
input ENUM_TIMEFRAMES InpSR_TF1     = PERIOD_M30;   // S&R Timeframe Kolom 1
input ENUM_TIMEFRAMES InpSR_TF2     = PERIOD_H1;    // S&R Timeframe Kolom 2
input ENUM_TIMEFRAMES InpSR_TF3     = PERIOD_H4;    // S&R Timeframe Kolom 3
input int             InpSwingBars  = 0;            // Swing lookback (0 = otomatis per TF)
input int             InpScanBars   = 300;          // Jumlah bar yang discan per TF
input double          InpMergeATRMult = 0.30;       // Gabung swing bila jarak < (x * ATR)
input double          InpZoneMinATR   = 0.15;       // Tebal minimum zona (x ATR)
input int             InpMinTouches   = 1;          // Min sentuhan agar zona valid

//=== INPUT GROUP: CONFLUENCE DETECTOR =============================
input group "===== CONFLUENCE DETECTOR (LEVEL KEMBAR) ====="
input bool   InpEnableConfluence = true;         // Aktifkan sorotan Confluence antar-TF
input double InpConfToleranceATR = 0.25;         // Toleransi jarak antar-TF (x ATR)
input color  InpColorConf3       = clrGold;      // Warna Confluence 3 TF (Super Strong ★★★)
input color  InpColorConf2       = clrAqua;      // Warna Confluence 2 TF (Strong ★★)

//=== INPUT GROUP: PROXIMITY & INTERACTION (FASE 2) ================
input group "===== PROXIMITY & INTERACTION (FASE 2) ====="
input bool   InpProximityWarning = true;         // Peringatan saat harga mendekati level terdekat
input double InpProximityATR     = 0.15;         // Ambang jarak pemicu peringatan (x ATR)
input color  InpColorProximity   = clrYellow;    // Warna peringatan jarak dekat

//=== INPUT GROUP: TREND PANEL =====================================
input group "===== TREND PANEL ====="
input int    InpTrendEMAPeriod = 50;    // EMA period untuk arah tren
input bool   InpUseADX       = true;    // Tampilkan ADX (kekuatan tren)
input int    InpADX_Period   = 14;      // ADX period
input double InpADX_Threshold= 25.0;    // ADX min dianggap tren KUAT (20-25)
input bool   InpUseRSI       = true;    // Tampilkan RSI (warning ekstrem)
input int    InpRSI_Period   = 14;      // RSI period
input double InpRSI_OB       = 70.0;    // RSI Overbought
input double InpRSI_OS       = 30.0;    // RSI Oversold

//=== INPUT GROUP: QUICK STATS BAR (FASE 3) ========================
input group "===== QUICK STATS BAR (SPREAD & ADR) ====="
input bool   InpShowStats     = true;           // Tampilkan baris Quick Stats (Spread & ADR)
input int    InpADR_Period    = 14;             // Periode ADR (jumlah bar D1)
input double InpADR_WarnPct  = 90.0;           // % ADR harian (warn jika range > ini)
input color  InpColorStats   = clrSilver;       // Warna teks Quick Stats normal
input color  InpColorADRWarn = clrOrange;       // Warna peringatan ADR > threshold

//=== INPUT GROUP: DASHBOARD & VISUAL ==============================
input group "===== DASHBOARD & VISUAL ====="
input ENUM_BASE_CORNER InpPanelCorner = CORNER_LEFT_UPPER; // Posisi panel
input int    InpPanelX       = 10;      // Offset X panel (px)
input int    InpPanelY       = 25;      // Offset Y panel (px)
input bool   InpAvoidOCT     = true;    // Geser panel agar tidak menutupi One-Click Trading
input int    InpOCTClearance = 120;     // Tinggi kawasan atas toolbar+OCT (px @96 DPI)
input int    InpFontSize     = 9;       // Ukuran font dashboard
input string InpFont         = "Consolas"; // Font dashboard (monospace diwajibkan untuk matrix)
input color  InpColorBG      = C'18,18,18'; // Warna background panel
input color  InpColorBorder  = clrDimGray;  // Warna border panel & garis pemisah
input color  InpColorText    = clrWhite;    // Teks netral
input color  InpColorHdr     = clrLightSteelBlue; // Header kolom timeframe
input color  InpColorPrice   = clrGold;     // Teks harga running
input color  InpColorTrendUp = clrLimeGreen;// Tren UP
input color  InpColorTrendDn = clrTomato;   // Tren DOWN
input color  InpColorFlat    = clrDarkGray; // Tren FLAT / lemah
input color  InpColorWarn    = clrGold;     // Warning RSI ekstrem (OB/OS)
input color  InpColorResist  = clrTomato;   // Baris RESISTANCE
input color  InpColorSupport = clrLimeGreen;// Baris SUPPORT
input color  InpZoneResFill  = C'80,25,25'; // Isi zona resistance di chart
input color  InpZoneSupFill  = C'20,80,40'; // Isi zona support di chart
input bool   InpShowZones    = true;        // Kondisi AWAL toggle [S&R] saat di-attach (bisa diubah via tombol panel)

//=== INPUT GROUP: S&D ENGINE (FASE 4) =============================
input group "===== S&D ENGINE (SUPPLY & DEMAND) ====="
input bool            InpShowSD          = true;          // Master switch engine S&D (matikan = hemat CPU, tombol toggle nonaktif)
input ENUM_TIMEFRAMES InpSD_TF1          = PERIOD_H1;     // S&D Timeframe 1
input ENUM_TIMEFRAMES InpSD_TF2          = PERIOD_H4;     // S&D Timeframe 2
input int             InpSDScanBars      = 400;           // Jumlah bar yang discan per TF (default 400)
input double          InpImpulseBodyATR  = 1.0;           // Min ukuran impulse leg keluar (x ATR)
input double          InpBaseMaxATR      = 0.8;           // Max lebar candle base (x ATR)
input int             InpBaseMaxCandles  = 5;             // Max jumlah candle dalam base
input bool            InpHideTested      = false;         // Sembunyikan zona Tested (sudah disentuh 1x)
input bool            InpShowSD_Debug    = true;          // Tampilkan HUD diagnostik S&D di chart (Comment())
input bool            InpShowSDZonesInit = true;          // Kondisi AWAL toggle [S&D] saat di-attach (bisa diubah via tombol panel)
input color           InpColorDemandFill = C'20,65,30';   // Fill zona Demand (beli)
input color           InpColorDemandBdr  = clrLimeGreen;  // Border zona Demand
input color           InpColorSupplyFill = C'65,18,18';   // Fill zona Supply (jual)
input color           InpColorSupplyBdr  = clrOrangeRed;  // Border zona Supply
input color           InpColorSDLabel    = clrLightCyan;  // Warna baris S&D di panel
input color           InpColorSDConf     = clrGold;       // Warna S&R+S&D Confluence

//=== INPUT GROUP: RISK:REWARD HELPER (FASE 5.2 + 5.6) ============
input group "===== RISK:REWARD HELPER (FASE 5.2 + 5.6) ====="
input bool              InpShowRR         = true;                   // Tampilkan baris proyeksi R:R Setup di panel
input ENUM_RR_ENTRY_MODE InpRR_EntryMode  = RR_ENTRY_AGGRESSIVE;    // Mode entry: Aggressive(edge 0%), Equilibrium(mid 50%), Conservative(deep 80%)
input double            InpRR_SLBufferATR = 0.20;                   // Buffer SL di luar batas belakang zona (x ATR)

//+------------------------------------------------------------------+
//| INPUT: penegakan kualitas SOP LIVE di R:R Helper (Fase 4.2)      |
//+------------------------------------------------------------------+
input bool InpRR_RequireFreshFVG = true; // SETUP hijau hanya jika zona Fresh+FVG (SOP LIVE); selain itu baris abu SKIP

//=== INPUT GROUP: FVG (FAIR VALUE GAP) CONFLUENCE (FASE 5.3 + 5.6) =
input group "===== FVG (FAIR VALUE GAP) CONFLUENCE (FASE 5.3 + 5.6) ====="
input bool              InpEnableFVG          = true;             // Aktifkan deteksi FVG Imbalance
input bool              InpDrawFVGBoxes       = true;             // Gambar kotak area FVG di chart (Opsi 2)
input double            InpFVG_MinGapATR      = 0.15;             // Ukuran gap minimum untuk FVG valid (x ATR)
input ENUM_FVG_MITIGATION InpFVG_MitigationType = FVG_MITIGATE_50PCT_CE; // Mode mitigasi: 50% CE (SMC standar) atau Full Fill (100%)
input color             InpColorFVGBull       = C'0,140,200';    // Warna border kotak Bullish FVG
input color             InpColorFVGBear       = C'200,50,120';   // Warna border kotak Bearish FVG

//=== INPUT GROUP: LIQUIDITY SWEEP / FAKEOUT (FASE 5.4) ============
input group "===== LIQUIDITY SWEEP / FAKEOUT (FASE 5.4) ====="
input bool   InpEnableSweep       = true;         // Aktifkan deteksi Liquidity Sweep / Fakeout
input double InpSweep_MinWickATR  = 0.30;         // Ukuran jarum tembus minimal (x ATR)
input int    InpSweepScanBars     = 10;           // Jumlah bar terakhir yang dipantau di chart
input color  InpColorSweepBull    = clrLimeGreen; // Warna penanda Bullish Sweep (Support/Demand)
input color  InpColorSweepBear    = clrTomato;    // Warna penanda Bearish Sweep (Resistance/Supply)

//=== INPUT GROUP: SIGNAL LOGGER FOR MULTI-AGENT JUDGE (FASE AGENT-1) ==
input group "===== SIGNAL LOGGER (CSV FOR JUDGE) ====="
input bool   InpEnableLogger   = false;        // Tulis snapshot 18 kandidat ke CSV tiap bar baru H1 (clock kunci agent_TF.md)
input string InpLoggerPrefix   = "SRD_Indi_signals"; // Prefix nama file di MQL5/Files (akhir: _YYYYMMDD.csv)

//=== INPUT GROUP: ALERT & SMART NOTIFICATIONS =====================
input group "===== ALERT & SMART NOTIFICATIONS (FASE 5.1) ====="
input bool   InpAlertTouch         = false;         // Master Switch Alert saat harga menyentuh zona
input bool   InpAlertTerminal      = true;          // Alert pop-up suara di terminal MT5 PC
input bool   InpAlertMobile        = false;         // Push notification ke aplikasi MT5 HP (Android/iOS)
input bool   InpAlertOnlyStrongest = true;          // Smart Filter: Hanya alert level TERKUAT / Confluence ★★★ / Fresh S&D
input bool   InpAlertSR            = true;          // Alert untuk zona S&R (Support & Resistance)
input bool   InpAlertSD            = true;          // Alert untuk zona S&D (Supply & Demand)
input int    InpAlertCooldownMins  = 15;            // Cooldown anti-spam per zona yang sama (menit)

//+------------------------------------------------------------------+
//| STRUKTUR DATA & GLOBAL STATE                                     |
//+------------------------------------------------------------------+
struct SRZone
  {
   double   top;        // batas atas zona
   double   bottom;     // batas bawah zona
   double   mid;        // titik tengah zona
   int      touches;    // jumlah peristiwa sentuhan
   bool     isSupport;  // true=SUPPORT, false=RESISTANCE
   datetime born;       // waktu swing tertua
  };

struct SRLevel
  {
   double   price;        // harga mid level
   int      touches;      // jumlah sentuhan
   bool     valid;        // apakah level ini ada/terisi
   int      confluence;   // 1=normal (1 TF), 2=confluence 2 TF (★★), 3=confluence 3 TF (★★★)
   int      totalTouches; // total sentuhan gabungan semua TF yang confluence
  };

struct TFZoneList
  {
   SRZone   zones[];
  };

struct TrendInfo
  {
   int      dir;        // 1=UP, -1=DOWN, 0=FLAT
   bool     strong;     // ADX >= threshold
   bool     rsiOB;      // RSI overbought
   bool     rsiOS;      // RSI oversold
   double   adx;
   double   rsi;
   double   slope;      // ema[1] - ema[3]
  };

//--- Enum pola S&D
enum ENUM_SD_PATTERN { SD_RBR, SD_DBD, SD_DBR, SD_RBD };

//--- Status zona S&D: Fresh / Tested / Consumed
enum ENUM_SD_STATUS { SD_FRESH, SD_TESTED, SD_CONSUMED };

struct SDZone
  {
   double          top;        // batas atas zona (High tertinggi base)
   double          bottom;     // batas bawah zona (Low terendah base)
   double          mid;        // titik tengah zona
   bool            isDemand;   // true=Demand (beli), false=Supply (jual)
   ENUM_SD_PATTERN pattern;    // RBR / DBD / DBR / RBD
   ENUM_SD_STATUS  status;     // Fresh / Tested / Consumed
   double          strength;   // ukuran impulse leg keluar (dalam ATR)
   datetime        born;       // waktu terbentuknya zona (bar base)
   bool            srConfl;    // true = bertepatan dengan level S&R
   bool            hasFVG;     // true = memiliki unmitigated FVG di departure leg
   double          fvgTop;     // batas atas gap FVG
   double          fvgBottom;  // batas bawah gap FVG
   datetime        fvgBorn;    // waktu terbentuknya bar FVG
  };

struct SDTFZoneList
  {
   SDZone   zones[];
  };

//--- State Trend Panel (D1, H4, H1)
TrendInfo        g_trend[3];
int              hEma[3], hAdx[3], hRsi[3];
ENUM_TIMEFRAMES  g_tf[3]     = {PERIOD_D1, PERIOD_H4, PERIOD_H1};
string           g_tfName[3] = {"D1", "H4", "H1"};

//--- State S&R Matrix (M30, H1, H4)
ENUM_TIMEFRAMES  g_srTF[NUM_SR_TF];
string           g_srTFName[NUM_SR_TF];
int              hSR_ATR[NUM_SR_TF];
TFZoneList       g_zones_tf[NUM_SR_TF];

//--- Matriks Level RES & SUP: [tfIdx][levelIdx]
SRLevel          g_resLevel[NUM_SR_TF][NUM_SR_LEVELS];
SRLevel          g_supLevel[NUM_SR_TF][NUM_SR_LEVELS];

//--- State S&D Engine (H1, H4)
ENUM_TIMEFRAMES  g_sdTF[NUM_SD_TF];
string           g_sdTFName[NUM_SD_TF];
int              hSD_ATR[NUM_SD_TF];
SDTFZoneList     g_sdZones[NUM_SD_TF];       // semua zona S&D per TF
SDZone           g_sdNearest[NUM_SD_TF][2];  // [tfIdx][0=demand terdekat, 1=supply terdekat]
bool             g_sdNearestValid[NUM_SD_TF][2];

//--- Level Terkuat (gabungan 3 TF S&R + 1 Supply/Demand S&D terkuat)
int    g_strongResTF[2]  = {-1,-1}, g_strongResLvl[2] = {-1,-1};
int    g_strongSupTF[2]  = {-1,-1}, g_strongSupLvl[2] = {-1,-1};
int    g_strongSDSupplyTF = -1, g_strongSDDemandTF = -1;

//--- State toggle tampilan chart (runtime, via tombol panel) ---
bool             g_showSR         = true;  // toggle gambar zona S&R di chart
bool             g_showSD         = true;  // toggle gambar zona S&D di chart

//--- State riwayat alert untuk mekanisme cooldown anti-spam ---
struct AlertHistory
  {
   string   key;
   datetime lastTime;
  };
AlertHistory     g_alertHistory[];

datetime         g_lastBarTime    = 0;
bool             g_timerActive    = false;
int              g_timerCount     = 0;
bool             g_panelCollapsed = false; // State tombol minimize [-] / [+]

//--- State Signal Logger (Fase Agent-1: snapshot per bar baru H1) ---
datetime         g_logLastH1Bar   = 0;   // bar H1 terakhir yg sudah di-snapshot
bool             g_logHeaderDone  = false; // header CSV ditulis sekali per attach
string           g_logFileName    = "";  // nama file hari ini (rotasi harian)

//--- State Liquidity Sweep (Fase 5.4) ---
int              g_lastSweepDir   = 0;   // 1 = Bullish Sweep, -1 = Bearish Sweep, 0 = None
string           g_lastSweepTF    = "";  // Timeframe kejadian sweep terbaru
datetime         g_lastSweepTime  = 0;   // Bar time kejadian sweep terbaru

//+------------------------------------------------------------------+
//| UTILITAS FORMAT TEKS: Helper agar kolom super presisi & rata     |
//+------------------------------------------------------------------+
string CenterText(const string txt, const int width)
  {
   int len = StringLen(txt);
   if(len >= width)
      return(StringSubstr(txt, 0, width));
   int leftPad = (width - len) / 2;
   int rightPad = width - len - leftPad;
   string res = "";
   for(int i = 0; i < leftPad; i++) res += " ";
   res += txt;
   for(int i = 0; i < rightPad; i++) res += " ";
   return(res);
  }

string FormatLevelCell(const SRLevel &lvl, const double bid, const double refATR, color &cellColor, const bool isRes)
  {
   if(!lvl.valid)
     {
      cellColor = InpColorBorder;
      return("       - - -        ");
     }

   string pStr  = DoubleToString(lvl.price, _Digits);
   double diff  = lvl.price - bid;
   string dSign = (diff >= 0 ? "+" : "-");
   string dVal  = DoubleToString(MathAbs(diff), _Digits);
   string tStr  = IntegerToString(lvl.touches) + "x";

   // Cek apakah harga sedang sangat dekat (Proximity Warning)
   double proxDist = MathMax(InpProximityATR * refATR, 10 * _Point);
   bool isNear = (InpProximityWarning && MathAbs(diff) <= proxDist);

   // Tentukan warna berdasarkan status Proximity atau Confluence
   if(isNear)
      cellColor = InpColorProximity; // Kuning menyala (Peringatan jarak dekat!)
   else if(InpEnableConfluence && lvl.confluence >= 3)
      cellColor = InpColorConf3; // Emas (★★★)
   else if(InpEnableConfluence && lvl.confluence == 2)
      cellColor = InpColorConf2; // Cyan (★★)
   else
      cellColor = isRes ? InpColorResist : InpColorSupport;

   string mark = " ";
   if(isNear)
      mark = "►";
   else if(InpEnableConfluence)
     {
      if(lvl.confluence >= 3) mark = "★";
      else if(lvl.confluence == 2) mark = "•";
     }

   return StringFormat("%s%s (%s%s|%s)", mark, pStr, dSign, dVal, tStr);
  }

string TFToString(const ENUM_TIMEFRAMES tf)
  {
   switch(tf)
     {
      case PERIOD_M1:  return("M1");
      case PERIOD_M5:  return("M5");
      case PERIOD_M15: return("M15");
      case PERIOD_M30: return("M30");
      case PERIOD_H1:  return("H1");
      case PERIOD_H4:  return("H4");
      case PERIOD_D1:  return("D1");
      case PERIOD_W1:  return("W1");
      case PERIOD_MN1: return("MN");
      default:         return(StringSubstr(EnumToString(tf), 7));
     }
  }

//+------------------------------------------------------------------+
//| UTILITAS: lookback fractal otomatis sesuai TF                    |
//+------------------------------------------------------------------+
int AutoSwingBars(const ENUM_TIMEFRAMES tf)
  {
   switch(tf)
     {
      case PERIOD_M1:
      case PERIOD_M5:
      case PERIOD_M15: return(5);
      case PERIOD_M30:
      case PERIOD_H1:  return(4);
      default:         return(3);
     }
  }

//+------------------------------------------------------------------+
//| UTILITAS: ATR per TF (fallback aman)                             |
//+------------------------------------------------------------------+
double GetATR(const int handle)
  {
   double a[];
   ArraySetAsSeries(a, true);
   if(handle != INVALID_HANDLE && CopyBuffer(handle, 0, 0, 2, a) >= 2 && a[1] > 0)
      return(a[1]);
   return(100 * _Point);
  }

//+------------------------------------------------------------------+
//| UTILITAS: buat/update label teks dashboard                       |
//+------------------------------------------------------------------+
void SetLabel(const string name, const int x, const int y, const string text,
              const color clr, const int fontSize, const string font)
  {
   string full = OBJ_PREFIX + name;
   if(ObjectFind(0, full) < 0)
     {
      ObjectCreate(0, full, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, full, OBJPROP_CORNER, InpPanelCorner);
      ObjectSetInteger(0, full, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, full, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, full, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, full, OBJPROP_BACK, false);
     }
   ObjectSetInteger(0, full, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, full, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, full, OBJPROP_TEXT, text);
   ObjectSetInteger(0, full, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, full, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, full, OBJPROP_FONT, font);
  }

//+------------------------------------------------------------------+
//| UTILITAS: buat/update tombol (minimize maupun toggle S&R/S&D)   |
//+------------------------------------------------------------------+
void SetButton(const string name, const int x, const int y, const int w, const int h,
               const string text, const color clrText, const color clrBG)
  {
   string full = OBJ_PREFIX + name;
   if(ObjectFind(0, full) < 0)
     {
      ObjectCreate(0, full, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, full, OBJPROP_CORNER, InpPanelCorner);
      ObjectSetInteger(0, full, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, full, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, full, OBJPROP_BACK, false);
     }
   ObjectSetInteger(0, full, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, full, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, full, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, full, OBJPROP_YSIZE, h);
   ObjectSetString(0, full, OBJPROP_TEXT, text);
   ObjectSetInteger(0, full, OBJPROP_COLOR, clrText);
   ObjectSetInteger(0, full, OBJPROP_BGCOLOR, clrBG);
   ObjectSetInteger(0, full, OBJPROP_BORDER_COLOR, InpColorBorder);
   ObjectSetInteger(0, full, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, full, OBJPROP_FONT, InpFont);
   ObjectSetInteger(0, full, OBJPROP_STATE, false);
  }

//+------------------------------------------------------------------+
//| UTILITAS: buat/update background panel                           |
//+------------------------------------------------------------------+
void SetPanel(const int x, const int y, const int w, const int h)
  {
   string full = OBJ_PREFIX + "PANEL_BG";
   if(ObjectFind(0, full) < 0)
     {
      ObjectCreate(0, full, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, full, OBJPROP_CORNER, InpPanelCorner);
      ObjectSetInteger(0, full, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, full, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, full, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, full, OBJPROP_BACK, false);
     }
   ObjectSetInteger(0, full, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, full, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, full, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, full, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, full, OBJPROP_BGCOLOR, InpColorBG);
   ObjectSetInteger(0, full, OBJPROP_COLOR, InpColorBorder);
  }

//+------------------------------------------------------------------+
//| S&R ENGINE: deteksi swing high/low (fractal N-bar) per TF        |
//+------------------------------------------------------------------+
int FindSwings(const ENUM_TIMEFRAMES tf, const int lookback,
               double &prices[], bool &isHigh[], datetime &times[])
  {
   int available = Bars(_Symbol, tf);
   int maxBars   = MathMin(InpScanBars, available - lookback - 2);
   if(maxBars < lookback * 2 + 2)
      return(0);

   ArrayResize(prices, maxBars);
   ArrayResize(isHigh, maxBars);
   ArrayResize(times,  maxBars);

   int count = 0;
   for(int i = lookback + 1; i <= maxBars; i++)
     {
      double h = iHigh(_Symbol, tf, i);
      double l = iLow(_Symbol, tf, i);
      bool sh = true, sl = true;

      for(int k = 1; k <= lookback && (sh || sl); k++)
        {
         if(sh && (iHigh(_Symbol, tf, i + k) >= h || iHigh(_Symbol, tf, i - k) > h))
            sh = false;
         if(sl && (iLow(_Symbol, tf, i + k) <= l || iLow(_Symbol, tf, i - k) < l))
            sl = false;
        }

      if(sh || sl)
        {
         prices[count] = (sh ? h : l);
         isHigh[count] = sh;
         times[count]  = iTime(_Symbol, tf, i);
         count++;
        }
     }

   ArrayResize(prices, count);
   ArrayResize(isHigh, count);
   ArrayResize(times,  count);
   return(count);
  }

//+------------------------------------------------------------------+
//| S&R ENGINE: hitung jumlah sentuhan zona per TF                   |
//+------------------------------------------------------------------+
int CountTouches(const ENUM_TIMEFRAMES tf, const double top, const double bottom, const int maxBars)
  {
   int touches = 0;
   bool prevIn = false;
   int available = Bars(_Symbol, tf);
   int limit = MathMin(maxBars, available - 1);
   for(int i = 1; i <= limit; i++)
     {
      double h = iHigh(_Symbol, tf, i);
      double l = iLow(_Symbol, tf, i);
      bool in  = (h >= bottom && l <= top);
      if(in && !prevIn)
         touches++;
      prevIn = in;
     }
   return(touches);
  }

//+------------------------------------------------------------------+
//| S&R ENGINE: pilih 3 RES & 3 SUP terdekat per TF                  |
//| levelIdx: 0=Level 1 (terdekat), 1=Level 2, 2=Level 3 (terjauh)   |
//+------------------------------------------------------------------+
void BuildNearestListsForTF(const int tfIdx, const double refPrice)
  {
   for(int k = 0; k < NUM_SR_LEVELS; k++)
     {
      g_resLevel[tfIdx][k].valid        = false;
      g_resLevel[tfIdx][k].confluence   = 1;
      g_resLevel[tfIdx][k].totalTouches = 0;

      g_supLevel[tfIdx][k].valid        = false;
      g_supLevel[tfIdx][k].confluence   = 1;
      g_supLevel[tfIdx][k].totalTouches = 0;
     }

   int totalZones = ArraySize(g_zones_tf[tfIdx].zones);
   if(totalZones <= 0)
      return;

   double supPrices[]; int supTouches[]; double supDists[];
   double resPrices[]; int resTouches[]; double resDists[];

   for(int z = 0; z < totalZones; z++)
     {
      double mid = g_zones_tf[tfIdx].zones[z].mid;
      double d   = MathAbs(mid - refPrice);
      if(g_zones_tf[tfIdx].zones[z].isSupport)
        {
         int s = ArraySize(supPrices);
         ArrayResize(supPrices, s + 1);
         ArrayResize(supTouches, s + 1);
         ArrayResize(supDists, s + 1);
         supPrices[s]  = mid;
         supTouches[s] = g_zones_tf[tfIdx].zones[z].touches;
         supDists[s]   = d;
        }
      else
        {
         int s = ArraySize(resPrices);
         ArrayResize(resPrices, s + 1);
         ArrayResize(resTouches, s + 1);
         ArrayResize(resDists, s + 1);
         resPrices[s]  = mid;
         resTouches[s] = g_zones_tf[tfIdx].zones[z].touches;
         resDists[s]   = d;
        }
     }

   // Sort Support ascending by distance (terdekat dulu)
   int numSup = ArraySize(supPrices);
   for(int a = 0; a < numSup - 1; a++)
     {
      int best = a;
      for(int b = a + 1; b < numSup; b++)
         if(supDists[b] < supDists[best])
            best = b;
      if(best != a)
        {
         double tp = supPrices[a];  supPrices[a]  = supPrices[best];  supPrices[best]  = tp;
         int tt    = supTouches[a]; supTouches[a] = supTouches[best]; supTouches[best] = tt;
         double td = supDists[a];   supDists[a]   = supDists[best];   supDists[best]   = td;
        }
     }

   for(int k = 0; k < NUM_SR_LEVELS; k++)
     {
      if(k < numSup)
        {
         g_supLevel[tfIdx][k].price        = supPrices[k];
         g_supLevel[tfIdx][k].touches      = supTouches[k];
         g_supLevel[tfIdx][k].valid        = true;
         g_supLevel[tfIdx][k].confluence   = 1;
         g_supLevel[tfIdx][k].totalTouches = supTouches[k];
        }
     }

   // Sort Resistance ascending by distance (terdekat dulu)
   int numRes = ArraySize(resPrices);
   for(int a = 0; a < numRes - 1; a++)
     {
      int best = a;
      for(int b = a + 1; b < numRes; b++)
         if(resDists[b] < resDists[best])
            best = b;
      if(best != a)
        {
         double tp = resPrices[a];  resPrices[a]  = resPrices[best];  resPrices[best]  = tp;
         int tt    = resTouches[a]; resTouches[a] = resTouches[best]; resTouches[best] = tt;
         double td = resDists[a];   resDists[a]   = resDists[best];   resDists[best]   = td;
        }
     }

   for(int k = 0; k < NUM_SR_LEVELS; k++)
     {
      if(k < numRes)
        {
         g_resLevel[tfIdx][k].price        = resPrices[k];
         g_resLevel[tfIdx][k].touches      = resTouches[k];
         g_resLevel[tfIdx][k].valid        = true;
         g_resLevel[tfIdx][k].confluence   = 1;
         g_resLevel[tfIdx][k].totalTouches = resTouches[k];
        }
     }
  }

//+------------------------------------------------------------------+
//| CONFLUENCE ENGINE: Deteksi level kembar antar-TF (M30, H1, H4)   |
//+------------------------------------------------------------------+
void CheckConfluence(const double atr)
  {
   if(!InpEnableConfluence)
      return;

   double tol = MathMax(InpConfToleranceATR * atr, 15 * _Point);

   // 1. Cek Confluence untuk RESISTANCE
   for(int t1 = 0; t1 < NUM_SR_TF; t1++)
     {
      for(int k1 = 0; k1 < NUM_SR_LEVELS; k1++)
        {
         if(!g_resLevel[t1][k1].valid)
            continue;

         int matchCount = 1;
         int totalT = g_resLevel[t1][k1].touches;
         double refP = g_resLevel[t1][k1].price;

         for(int t2 = 0; t2 < NUM_SR_TF; t2++)
           {
            if(t2 == t1)
               continue;

            for(int k2 = 0; k2 < NUM_SR_LEVELS; k2++)
              {
               if(!g_resLevel[t2][k2].valid)
                  continue;

               if(MathAbs(g_resLevel[t2][k2].price - refP) <= tol)
                 {
                  matchCount++;
                  totalT += g_resLevel[t2][k2].touches;
                  break; // Cukup 1 kecocokan per TF lain
                 }
              }
           }
         g_resLevel[t1][k1].confluence   = matchCount;
         g_resLevel[t1][k1].totalTouches = totalT;
        }
     }

   // 2. Cek Confluence untuk SUPPORT
   for(int t1 = 0; t1 < NUM_SR_TF; t1++)
     {
      for(int k1 = 0; k1 < NUM_SR_LEVELS; k1++)
        {
         if(!g_supLevel[t1][k1].valid)
            continue;

         int matchCount = 1;
         int totalT = g_supLevel[t1][k1].touches;
         double refP = g_supLevel[t1][k1].price;

         for(int t2 = 0; t2 < NUM_SR_TF; t2++)
           {
            if(t2 == t1)
               continue;

            for(int k2 = 0; k2 < NUM_SR_LEVELS; k2++)
              {
               if(!g_supLevel[t2][k2].valid)
                  continue;

               if(MathAbs(g_supLevel[t2][k2].price - refP) <= tol)
                 {
                  matchCount++;
                  totalT += g_supLevel[t2][k2].touches;
                  break;
                 }
              }
           }
         g_supLevel[t1][k1].confluence   = matchCount;
         g_supLevel[t1][k1].totalTouches = totalT;
        }
     }
  }

//+------------------------------------------------------------------+
//| S&R ENGINE: recompute per timeframe                              |
//+------------------------------------------------------------------+
void RecomputeZonesForTF(const int tfIdx, const double bid)
  {
   ENUM_TIMEFRAMES tf = g_srTF[tfIdx];
   double atr = GetATR(hSR_ATR[tfIdx]);
   if(atr <= 0)
      return;

   double mergeDist = InpMergeATRMult * atr;
   double minThick  = InpZoneMinATR * atr;
   int    lookback  = (InpSwingBars > 0) ? InpSwingBars : AutoSwingBars(tf);

   double   prices[];
   bool     isHigh[];
   datetime times[];
   int n = FindSwings(tf, lookback, prices, isHigh, times);
   if(n <= 0)
     {
      ArrayResize(g_zones_tf[tfIdx].zones, 0);
      for(int k = 0; k < NUM_SR_LEVELS; k++)
        {
         g_resLevel[tfIdx][k].valid = false;
         g_supLevel[tfIdx][k].valid = false;
        }
      return;
     }

   bool used[];
   ArrayResize(used, n);
   ArrayInitialize(used, false);

   ArrayResize(g_zones_tf[tfIdx].zones, 0);
   double closeCur = iClose(_Symbol, tf, 1);
   if(closeCur <= 0)
      closeCur = bid;

   for(int i = 0; i < n; i++)
     {
      if(used[i])
         continue;
      used[i] = true;

      double   top  = prices[i];
      double   bot  = prices[i];
      datetime born = times[i];

      for(int j = i + 1; j < n; j++)
        {
         if(used[j])
            continue;
         if(MathAbs(prices[j] - prices[i]) <= mergeDist)
           {
            used[j] = true;
            if(prices[j] > top)  top  = prices[j];
            if(prices[j] < bot)  bot  = prices[j];
            if(times[j]  < born) born = times[j];
           }
        }

      if(top - bot < minThick)
        {
         double mid0 = (top + bot) / 2.0;
         top = mid0 + minThick / 2.0;
         bot = mid0 - minThick / 2.0;
        }

      int touches = CountTouches(tf, top, bot, InpScanBars);
      if(touches < InpMinTouches)
         continue;

      int sz = ArraySize(g_zones_tf[tfIdx].zones);
      ArrayResize(g_zones_tf[tfIdx].zones, sz + 1);
      g_zones_tf[tfIdx].zones[sz].top       = top;
      g_zones_tf[tfIdx].zones[sz].bottom    = bot;
      g_zones_tf[tfIdx].zones[sz].mid       = (top + bot) / 2.0;
      g_zones_tf[tfIdx].zones[sz].touches   = touches;
      g_zones_tf[tfIdx].zones[sz].born      = born;
      g_zones_tf[tfIdx].zones[sz].isSupport = (bid > g_zones_tf[tfIdx].zones[sz].mid);
     }

   BuildNearestListsForTF(tfIdx, bid);
  }

//+------------------------------------------------------------------+
//| VISUAL: gambar satu zona S&R (rectangle)                         |
//+------------------------------------------------------------------+
void DrawZone(const int tfIdx, SRZone &z)
  {
   string name = OBJ_PREFIX + "Z_" + g_srTFName[tfIdx] + "_" + DoubleToString(z.mid, _Digits);
   datetime t2 = TimeCurrent() + PeriodSeconds(_Period) * 25;

   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, z.born, z.bottom, t2, z.top);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
     }

   // Periksa apakah level ini memiliki status Confluence
   int conf = 1;
   int totT = z.touches;
   for(int k = 0; k < NUM_SR_LEVELS; k++)
     {
      if(z.isSupport && g_supLevel[tfIdx][k].valid && MathAbs(g_supLevel[tfIdx][k].price - z.mid) < _Point)
        {
         conf = g_supLevel[tfIdx][k].confluence;
         totT = g_supLevel[tfIdx][k].totalTouches;
         break;
        }
      else if(!z.isSupport && g_resLevel[tfIdx][k].valid && MathAbs(g_resLevel[tfIdx][k].price - z.mid) < _Point)
        {
         conf = g_resLevel[tfIdx][k].confluence;
         totT = g_resLevel[tfIdx][k].totalTouches;
         break;
        }
     }

   color fill = z.isSupport ? InpZoneSupFill : InpZoneResFill;
   color line = z.isSupport ? InpColorSupport : InpColorResist;
   int lineWidth = 1;

   if(InpEnableConfluence && conf >= 3)
     {
      line = InpColorConf3; // Border Emas untuk Triple Confluence (★★★)
      lineWidth = 2;
     }
   else if(InpEnableConfluence && conf == 2)
     {
      line = InpColorConf2; // Border Cyan untuk Double Confluence (★★)
      lineWidth = 2;
     }

   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, fill);
   ObjectSetInteger(0, name, OBJPROP_COLOR, line);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, lineWidth);

   string confTag = "";
   if(conf >= 3)
      confTag = StringFormat(" [★★★ 3-TF CONFLUENCE - %dx Total]", totT);
   else if(conf == 2)
      confTag = StringFormat(" [★★ 2-TF CONFLUENCE - %dx Total]", totT);

   string tip = StringFormat("[%s] %s (%dx touches)%s",
                             g_srTFName[tfIdx], (z.isSupport ? "SUPPORT" : "RESISTANCE"),
                             z.touches, confTag);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tip);

   ObjectMove(0, name, 0, z.born, z.bottom);
   ObjectMove(0, name, 1, t2, z.top);
  }

//+------------------------------------------------------------------+
//| VISUAL: gambar zona terdekat dari semua TF                       |
//+------------------------------------------------------------------+
void DrawNearestZones()
  {
   ObjectsDeleteAll(0, OBJ_PREFIX + "Z_");
   for(int t = 0; t < NUM_SR_TF; t++)
     {
      // Gambar SUP terdekat
      for(int k = 0; k < NUM_SR_LEVELS; k++)
        {
         if(g_supLevel[t][k].valid)
           {
            double mid = g_supLevel[t][k].price;
            for(int z = 0; z < ArraySize(g_zones_tf[t].zones); z++)
              {
               if(g_zones_tf[t].zones[z].isSupport && MathAbs(g_zones_tf[t].zones[z].mid - mid) < _Point)
                 {
                  DrawZone(t, g_zones_tf[t].zones[z]);
                  break;
                 }
              }
           }
        }
      // Gambar RES terdekat
      for(int k = 0; k < NUM_SR_LEVELS; k++)
        {
         if(g_resLevel[t][k].valid)
           {
            double mid = g_resLevel[t][k].price;
            for(int z = 0; z < ArraySize(g_zones_tf[t].zones); z++)
              {
               if(!g_zones_tf[t].zones[z].isSupport && MathAbs(g_zones_tf[t].zones[z].mid - mid) < _Point)
                 {
                  DrawZone(t, g_zones_tf[t].zones[z]);
                  break;
                 }
              }
           }
        }
     }
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| TREND ENGINE: update arah tren D1/H4/H1                          |
//+------------------------------------------------------------------+
void UpdateTrends()
  {
   for(int i = 0; i < 3; i++)
     {
      g_trend[i].dir    = 0;
      g_trend[i].strong = false;
      g_trend[i].rsiOB  = false;
      g_trend[i].rsiOS  = false;
      g_trend[i].adx    = 0.0;
      g_trend[i].rsi    = 0.0;
      g_trend[i].slope  = 0.0;

      double ema[];
      ArraySetAsSeries(ema, true);
      if(CopyBuffer(hEma[i], 0, 0, 4, ema) < 4)
         continue;

      double closeTF = iClose(_Symbol, g_tf[i], 1);
      double slope   = ema[1] - ema[3];
      g_trend[i].slope = slope;

      if(closeTF > ema[1] && slope > 0)
         g_trend[i].dir = 1;
      else if(closeTF < ema[1] && slope < 0)
         g_trend[i].dir = -1;

      if(InpUseADX && hAdx[i] != INVALID_HANDLE)
        {
         double adx[];
         ArraySetAsSeries(adx, true);
         if(CopyBuffer(hAdx[i], 0, 0, 2, adx) >= 2)
           {
            g_trend[i].adx    = adx[1];
            g_trend[i].strong = (adx[1] >= InpADX_Threshold);
           }
        }

      if(InpUseRSI && hRsi[i] != INVALID_HANDLE)
        {
         double rsi[];
         ArraySetAsSeries(rsi, true);
         if(CopyBuffer(hRsi[i], 0, 0, 2, rsi) >= 2)
           {
            g_trend[i].rsi   = rsi[1];
            g_trend[i].rsiOB = (rsi[1] >= InpRSI_OB);
            g_trend[i].rsiOS = (rsi[1] <= InpRSI_OS);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| DASHBOARD: helper simbol & teks tren                             |
//+------------------------------------------------------------------+
string ArrowOf(TrendInfo &t)
  {
   if(t.dir > 0)
      return(t.strong ? "▲" : "△");
   if(t.dir < 0)
      return(t.strong ? "▼" : "▽");
   return("◆");
  }

string DirText(TrendInfo &t)
  {
   if(t.dir > 0)
      return("UP");
   if(t.dir < 0)
      return("DOWN");
   return("FLAT");
  }

//+------------------------------------------------------------------+
//| UTILITAS: posisi panel aman (anti overlap + auto-fit)            |
//+------------------------------------------------------------------+
void FitPanelPosition(int &x, int &y, const int w, const int h)
  {
   double dpi = (double)TerminalInfoInteger(TERMINAL_SCREEN_DPI);
   if(dpi <= 0.0)
      dpi = 96.0;

   if(InpAvoidOCT && InpPanelCorner == CORNER_LEFT_UPPER)
     {
      int clearance = (int)MathRound(InpOCTClearance * dpi / 96.0);
      if(y < clearance)
         y = clearance;
     }

   long chW = 0, chH = 0;
   if(ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0, chW) && chW > 0)
     {
      int maxX = (int)chW - w;
      if(x > maxX)
         x = (maxX > 0) ? maxX : 0;
     }
   if(ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0, chH) && chH > 0)
     {
      int maxY = (int)chH - h;
      if(y > maxY)
         y = (maxY > 0) ? maxY : 0;
     }
  }

//+------------------------------------------------------------------+
//| S&D ENGINE: helper nama pola & status                            |
//+------------------------------------------------------------------+
string SDPatternName(ENUM_SD_PATTERN p)
  {
   switch(p)
     {
      case SD_RBR: return("RBR");
      case SD_DBD: return("DBD");
      case SD_DBR: return("DBR");
      case SD_RBD: return("RBD");
     }
   return("???");
  }

string SDStatusName(ENUM_SD_STATUS s)
  {
   if(s == SD_FRESH)    return("fresh");
   if(s == SD_TESTED)   return("tested");
   return("consumed");
  }

//+------------------------------------------------------------------+
//| S&D ENGINE: apakah candle adalah impulsive leg?                  |
//| Return true jika |body| >= InpImpulseBodyATR * atr               |
//+------------------------------------------------------------------+
bool IsImpulse(const ENUM_TIMEFRAMES tf, const int bar, const double atr,
               bool &isBull)
  {
   double o = iOpen(_Symbol, tf, bar);
   double c = iClose(_Symbol, tf, bar);
   double body = MathAbs(c - o);
   if(body < InpImpulseBodyATR * atr)
      return(false);
   isBull = (c > o);
   return(true);
  }

//+------------------------------------------------------------------+
//| S&D ENGINE: scan zona per TF                                     |
//| Pola: [ImpIn] -> [Base 1..5 candle] -> [ImpOut]                  |
//+------------------------------------------------------------------+
void FindSDZonesForTF(const int tfIdx, const double bid)
  {
   ArrayResize(g_sdZones[tfIdx].zones, 0);

   ENUM_TIMEFRAMES tf  = g_sdTF[tfIdx];
   double atr = GetATR(hSD_ATR[tfIdx]);
   if(atr <= 0) return;

   int avail = Bars(_Symbol, tf);
   int limit = MathMin(InpSDScanBars, avail - InpBaseMaxCandles - 3);
   if(limit < 5) return;

   double baseMaxRange = InpBaseMaxATR * atr;

   // Scan dari bar terkini ke bar terlama (index naik = semakin lama)
   // Cari pola: bar[i+N+1] = ImpIn, bar[i+1..i+N] = Base, bar[i] = ImpOut
   for(int i = 1; i <= limit - InpBaseMaxCandles - 2; i++)
     {
      bool impOutBull;
      if(!IsImpulse(tf, i, atr, impOutBull))
         continue; // bar[i] harus impulse keluar

      // Cari base: bar[i+1] sampai bar[i+InpBaseMaxCandles]
      for(int bLen = 1; bLen <= InpBaseMaxCandles; bLen++)
        {
         int baseStart = i + 1;       // bar paling kini dari base
         int baseEnd   = i + bLen;    // bar paling lama dari base

         if(baseEnd + 1 >= limit)
            continue;

         // Hitung range base
         double baseHigh = -1, baseLow = DBL_MAX;
         for(int b = baseStart; b <= baseEnd; b++)
           {
            double h = iHigh(_Symbol, tf, b);
            double l = iLow(_Symbol, tf, b);
            if(h > baseHigh) baseHigh = h;
            if(l < baseLow)  baseLow  = l;
           }
         if(baseHigh - baseLow > baseMaxRange)
            continue; // base terlalu lebar, bukan konsolidasi

         // Cek ImpIn (candle kedatangan ke base) di bar[baseEnd+1]
         int impInBar = baseEnd + 1;
         if(impInBar >= limit) continue;

         // Arah kedatangan harga: cukup tentukan bull/bear
         double impInO = iOpen(_Symbol, tf, impInBar);
         double impInC = iClose(_Symbol, tf, impInBar);
         bool impInBull = (impInC >= impInO);

         // Tentukan pola berdasarkan arah ImpIn dan ImpOut
         ENUM_SD_PATTERN pat;
         bool isDemand;
         if(impInBull && impOutBull)
           { pat = SD_RBR; isDemand = true;  }   // Rally-Base-Rally
         else if(!impInBull && !impOutBull)
           { pat = SD_DBD; isDemand = false; }   // Drop-Base-Drop
         else if(!impInBull && impOutBull)
           { pat = SD_DBR; isDemand = true;  }   // Drop-Base-Rally
         else
           { pat = SD_RBD; isDemand = false; }   // Rally-Base-Drop

         // Strength = ukuran ImpOut leg dalam ATR
         double impOutBody = MathAbs(iClose(_Symbol, tf, i) - iOpen(_Symbol, tf, i));
         double strength   = (atr > 0) ? (impOutBody / atr) : 0.0;

         // Tentukan status zona: Fresh / Tested / Consumed
         double zTop = baseHigh;
         double zBot = baseLow;
         ENUM_SD_STATUS status = SD_FRESH;

         // Cek apakah harga sudah pernah kembali ke zona ini (bar 1..i-1 = setelah zona terbentuk)
         for(int c2 = 1; c2 < i; c2++)
           {
            double h2 = iHigh(_Symbol, tf, c2);
            double l2 = iLow(_Symbol, tf, c2);
            if(h2 >= zBot && l2 <= zTop)
              {
               // Jika close di dalam atau menembus zona: Consumed
               double cl2 = iClose(_Symbol, tf, c2);
               if(isDemand && cl2 < zBot - atr * 0.1)
                 { status = SD_CONSUMED; break; }
               if(!isDemand && cl2 > zTop + atr * 0.1)
                 { status = SD_CONSUMED; break; }
               if(status == SD_FRESH) status = SD_TESTED;
              }
           }

         // Lewati zona Consumed
         if(status == SD_CONSUMED) continue;
         // Lewati Tested jika user minta sembunyikan
         if(status == SD_TESTED && InpHideTested) continue;

         // Lewati zona yang sudah tertembus harga running
         if(isDemand  && bid < zBot) continue; // harga di bawah demand = consumed
         if(!isDemand && bid > zTop) continue; // harga di atas supply = consumed

         // Simpan zona
         int sz = ArraySize(g_sdZones[tfIdx].zones);
         ArrayResize(g_sdZones[tfIdx].zones, sz + 1);
         g_sdZones[tfIdx].zones[sz].top      = zTop;
         g_sdZones[tfIdx].zones[sz].bottom   = zBot;
         g_sdZones[tfIdx].zones[sz].mid      = (zTop + zBot) / 2.0;
         g_sdZones[tfIdx].zones[sz].isDemand = isDemand;
         g_sdZones[tfIdx].zones[sz].pattern  = pat;
         g_sdZones[tfIdx].zones[sz].status   = status;
         g_sdZones[tfIdx].zones[sz].strength = strength;
         g_sdZones[tfIdx].zones[sz].born     = iTime(_Symbol, tf, baseEnd);
         g_sdZones[tfIdx].zones[sz].srConfl  = false;
         g_sdZones[tfIdx].zones[sz].hasFVG    = false;
         g_sdZones[tfIdx].zones[sz].fvgTop    = 0.0;
         g_sdZones[tfIdx].zones[sz].fvgBottom = 0.0;
         g_sdZones[tfIdx].zones[sz].fvgBorn   = 0;

         //--- FVG ENGINE (Fase 5.3): Deteksi 3-candle imbalance pada departure leg
         if(InpEnableFVG && atr > 0)
           {
            double minGap = InpFVG_MinGapATR * atr;
            double gapTop = 0, gapBottom = 0;
            int fvgBar = -1, evalBar = -1;
            bool fvgFound = false;

            if(isDemand) // Bullish FVG (Demand)
              {
               // Pola A: bar i adalah candle 2 (impulse), candle 1 = i+1, candle 3 = i-1
               if(i >= 1)
                 {
                  double c1_h = iHigh(_Symbol, tf, i + 1);
                  double c3_l = iLow(_Symbol, tf, i - 1);
                  if(c3_l - c1_h >= minGap)
                    {
                     gapBottom = c1_h; gapTop = c3_l; fvgBar = i; evalBar = MathMax(0, i - 1);
                     fvgFound = true;
                    }
                 }
               // Pola B: bar i adalah candle 3, candle 1 = i+2, candle 2 = i+1
               if(!fvgFound && i + 2 < limit)
                 {
                  double c1_h = iHigh(_Symbol, tf, i + 2);
                  double c3_l = iLow(_Symbol, tf, i);
                  if(c3_l - c1_h >= minGap)
                    {
                     gapBottom = c1_h; gapTop = c3_l; fvgBar = i + 1; evalBar = i;
                     fvgFound = true;
                    }
                 }

               // Cek status mitigasi Bullish FVG
               // Threshold bergantung pada InpFVG_MitigationType:
               //   50% CE : mitigated jika Low candle sesudahnya <= midpoint gap (Consequent Encroachment)
               //   Full Fill: mitigated jika Low candle sesudahnya <= gapBottom (menutup celah penuh)
               if(fvgFound)
                 {
                  double mitThreshold = (InpFVG_MitigationType == FVG_MITIGATE_50PCT_CE)
                                        ? ((gapTop + gapBottom) * 0.5)  // 50% CE midpoint
                                        : gapBottom;                    // 100% full fill

                  bool mitigated = (bid <= mitThreshold);
                  if(!mitigated && evalBar > 1)
                    {
                     for(int c = evalBar - 1; c >= 1; c--)
                       {
                        if(iLow(_Symbol, tf, c) <= mitThreshold)
                          { mitigated = true; break; }
                       }
                    }
                  if(!mitigated)
                    {
                     g_sdZones[tfIdx].zones[sz].hasFVG    = true;
                     g_sdZones[tfIdx].zones[sz].fvgTop    = gapTop;
                     g_sdZones[tfIdx].zones[sz].fvgBottom = gapBottom;
                     g_sdZones[tfIdx].zones[sz].fvgBorn   = iTime(_Symbol, tf, fvgBar);
                    }
                 }
              }
            else // Bearish FVG (Supply)
              {
               // Pola A: bar i adalah candle 2 (impulse), candle 1 = i+1, candle 3 = i-1
               if(i >= 1)
                 {
                  double c1_l = iLow(_Symbol, tf, i + 1);
                  double c3_h = iHigh(_Symbol, tf, i - 1);
                  if(c1_l - c3_h >= minGap)
                    {
                     gapTop = c1_l; gapBottom = c3_h; fvgBar = i; evalBar = MathMax(0, i - 1);
                     fvgFound = true;
                    }
                 }
               // Pola B: bar i adalah candle 3, candle 1 = i+2, candle 2 = i+1
               if(!fvgFound && i + 2 < limit)
                 {
                  double c1_l = iLow(_Symbol, tf, i + 2);
                  double c3_h = iHigh(_Symbol, tf, i);
                  if(c1_l - c3_h >= minGap)
                    {
                     gapTop = c1_l; gapBottom = c3_h; fvgBar = i + 1; evalBar = i;
                     fvgFound = true;
                    }
                 }

               // Cek status mitigasi Bearish FVG
               // Threshold bergantung pada InpFVG_MitigationType:
               //   50% CE : mitigated jika High candle sesudahnya >= midpoint gap (Consequent Encroachment)
               //   Full Fill: mitigated jika High candle sesudahnya >= gapTop (menutup celah penuh)
               if(fvgFound)
                 {
                  double mitThreshold = (InpFVG_MitigationType == FVG_MITIGATE_50PCT_CE)
                                        ? ((gapTop + gapBottom) * 0.5)  // 50% CE midpoint
                                        : gapTop;                       // 100% full fill

                  bool mitigated = (bid >= mitThreshold);
                  if(!mitigated && evalBar > 1)
                    {
                     for(int c = evalBar - 1; c >= 1; c--)
                       {
                        if(iHigh(_Symbol, tf, c) >= mitThreshold)
                          { mitigated = true; break; }
                       }
                    }
                  if(!mitigated)
                    {
                     g_sdZones[tfIdx].zones[sz].hasFVG    = true;
                     g_sdZones[tfIdx].zones[sz].fvgTop    = gapTop;
                     g_sdZones[tfIdx].zones[sz].fvgBottom = gapBottom;
                     g_sdZones[tfIdx].zones[sz].fvgBorn   = iTime(_Symbol, tf, fvgBar);
                    }
                 }
              }
           }
         break; // satu base length sudah cukup, lanjut ke bar berikutnya
        }
     }
  }

//+------------------------------------------------------------------+
//| S&D ENGINE: tandai confluence S&D + S&R                          |
//+------------------------------------------------------------------+
void CheckSDSRConfluence(const int sdTFIdx, const double atr)
  {
   double tol = MathMax(InpConfToleranceATR * atr, 15 * _Point);
   int sz = ArraySize(g_sdZones[sdTFIdx].zones);

   for(int z = 0; z < sz; z++)
     {
      double mid = g_sdZones[sdTFIdx].zones[z].mid;
      bool conflFound = false;

      for(int t = 0; t < NUM_SR_TF && !conflFound; t++)
        {
         for(int k = 0; k < NUM_SR_LEVELS; k++)
           {
            if((g_resLevel[t][k].valid && MathAbs(g_resLevel[t][k].price - mid) <= tol) ||
               (g_supLevel[t][k].valid && MathAbs(g_supLevel[t][k].price - mid) <= tol))
              {
               g_sdZones[sdTFIdx].zones[z].srConfl = true;
               conflFound = true;
               break;
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| QUALITY SCORE S&D (Fase 4.1): Fresh(1000) > Tested(0) + FVG(100)  |
//| + srConfl(50) + strength(ATR) - penalti jarak (per ATR).          |
//| Skor >1000 = Fresh, <1000 = Tested/Consumed. Dipakai BuildNearest |
//| & FindStrongest agar zona Tested tak kalahkan Fresh yg dekat.     |
//+------------------------------------------------------------------+
double SDZoneScore(const SDZone &z, const double bid, const double atr)
  {
   double s = 0.0;
   if(z.status == SD_FRESH) s += 1000.0;
   if(z.hasFVG)  s += 100.0;
   if(z.srConfl) s += 50.0;
   s += z.strength; // impulse leg dalam ATR (biasanya 1-5)
   if(atr > 0)
      s -= MathAbs(z.mid - bid) / atr; // penalti jarak per ATR
   return(s);
  }

//+------------------------------------------------------------------+
//| S&D ENGINE: pilih zona demand & supply terdekat per TF            |
//| Ranking kualitas: Fresh dulu, lalu FVG, lalu srConfl, lalu jarak. |
//| (Dulu murni jarak -> Tested menempel harga kalahkan Fresh jauh.)  |
//+------------------------------------------------------------------+
void BuildNearestSD(const int tfIdx, const double bid)
  {
   g_sdNearestValid[tfIdx][0] = false; // demand
   g_sdNearestValid[tfIdx][1] = false; // supply

   double atr = GetATR(hSD_ATR[tfIdx]);
   double bestDemandScore = -DBL_MAX;
   double bestSupplyScore = -DBL_MAX;
   int    bestDemandIdx  = -1;
   int    bestSupplyIdx  = -1;

   int sz = ArraySize(g_sdZones[tfIdx].zones);
   for(int z = 0; z < sz; z++)
     {
      double sc = SDZoneScore(g_sdZones[tfIdx].zones[z], bid, atr);
      if(g_sdZones[tfIdx].zones[z].isDemand)
        {
         if(sc > bestDemandScore)
           { bestDemandScore = sc; bestDemandIdx = z; }
        }
      else
        {
         if(sc > bestSupplyScore)
           { bestSupplyScore = sc; bestSupplyIdx = z; }
        }
     }

   if(bestDemandIdx >= 0)
     {
      g_sdNearest[tfIdx][0]      = g_sdZones[tfIdx].zones[bestDemandIdx];
      g_sdNearestValid[tfIdx][0] = true;
     }
   if(bestSupplyIdx >= 0)
     {
      g_sdNearest[tfIdx][1]      = g_sdZones[tfIdx].zones[bestSupplyIdx];
      g_sdNearestValid[tfIdx][1] = true;
     }
  }

//+------------------------------------------------------------------+
//| FVG ENGINE: gambar kotak fisik area Fair Value Gap di chart      |
//| (Opsi 2: Kotak transparan dashed rectangle langsung di grafik)  |
//+------------------------------------------------------------------+
void DrawFVGBoxes()
  {
   ObjectsDeleteAll(0, OBJ_PREFIX + "FVG_");

   if(!InpEnableFVG || !InpDrawFVGBoxes || !g_showSD)
      return;

   for(int t = 0; t < NUM_SD_TF; t++)
     {
      int sz = ArraySize(g_sdZones[t].zones);
      for(int z = 0; z < sz; z++)
        {
         SDZone zone = g_sdZones[t].zones[z];
         if(!zone.hasFVG) continue;

         string name = OBJ_PREFIX + "FVG_" + g_sdTFName[t] + "_"
                       + (zone.isDemand ? "BULL_" : "BEAR_")
                       + DoubleToString(zone.fvgBottom, _Digits);

         datetime t2 = TimeCurrent() + PeriodSeconds(_Period) * 25;

         if(ObjectFind(0, name) < 0)
           {
            ObjectCreate(0, name, OBJ_RECTANGLE, 0, zone.fvgBorn, zone.fvgBottom, t2, zone.fvgTop);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
            ObjectSetInteger(0, name, OBJPROP_BACK,       true);
            ObjectSetInteger(0, name, OBJPROP_FILL,       true);
           }

         color boxClr = zone.isDemand ? InpColorFVGBull : InpColorFVGBear;
         color bgClr  = zone.isDemand ? C'15,40,60'     : C'60,18,35';

         ObjectSetInteger(0, name, OBJPROP_COLOR,   boxClr);
         ObjectSetInteger(0, name, OBJPROP_STYLE,   STYLE_DASH);
         ObjectSetInteger(0, name, OBJPROP_WIDTH,   1);
         ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgClr);

         string fvgMitMode = (InpFVG_MitigationType == FVG_MITIGATE_50PCT_CE) ? "50% CE" : "Full Fill";
         string fvgTip = StringFormat("[%s] %s FVG (IMBALANCE)\nGap: %s - %s\nStatus: UNMITIGATED [%s]",
                                      g_sdTFName[t],
                                      zone.isDemand ? "BULLISH" : "BEARISH",
                                      DoubleToString(zone.fvgBottom, _Digits),
                                      DoubleToString(zone.fvgTop, _Digits),
                                      fvgMitMode);
         ObjectSetString(0, name, OBJPROP_TOOLTIP, fvgTip);

         ObjectMove(0, name, 0, zone.fvgBorn, zone.fvgBottom);
         ObjectMove(0, name, 1, t2,           zone.fvgTop);
        }
     }
  }

//+------------------------------------------------------------------+
//| VISUAL: gambar semua zona S&D di chart                           |
//+------------------------------------------------------------------+
void DrawSDZones()
  {
   // Hapus kotak S&D lama
   ObjectsDeleteAll(0, OBJ_PREFIX + "SD_");

   // Gambar kotak FVG (Opsi 2)
   DrawFVGBoxes();

   for(int t = 0; t < NUM_SD_TF; t++)
     {
      int sz = ArraySize(g_sdZones[t].zones);
      for(int z = 0; z < sz; z++)
        {
         SDZone zone = g_sdZones[t].zones[z];

         // Nama objek unik
         string name = OBJ_PREFIX + "SD_" + g_sdTFName[t] + "_"
                       + SDPatternName(zone.pattern) + "_"
                       + DoubleToString(zone.mid, _Digits);

         datetime t2 = TimeCurrent() + PeriodSeconds(_Period) * 30;

         if(ObjectFind(0, name) < 0)
           {
            ObjectCreate(0, name, OBJ_RECTANGLE, 0, zone.born, zone.bottom, t2, zone.top);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
            ObjectSetInteger(0, name, OBJPROP_BACK,       true);
            ObjectSetInteger(0, name, OBJPROP_FILL,       true);
           }

         // Warna fill & border berdasarkan Demand/Supply dan status
         color fillClr   = zone.isDemand ? InpColorDemandFill : InpColorSupplyFill;
         color borderClr = zone.isDemand ? InpColorDemandBdr  : InpColorSupplyBdr;
         int   lineW     = 1;

         // Confluence S&R+S&D → border Emas & lebih tebal
         if(zone.srConfl)
           { borderClr = InpColorSDConf; lineW = 2; }
         else if(zone.hasFVG)
           { borderClr = zone.isDemand ? InpColorFVGBull : InpColorFVGBear; lineW = 2; }

         // Tested → fill redup (50% opacity via darker color mix)
         if(zone.status == SD_TESTED)
           {
            fillClr = zone.isDemand ? C'15,45,20' : C'45,12,12';
           }

         ObjectSetInteger(0, name, OBJPROP_BGCOLOR, fillClr);
         ObjectSetInteger(0, name, OBJPROP_COLOR,   borderClr);
         ObjectSetInteger(0, name, OBJPROP_WIDTH,   lineW);

         // Tooltip informatif
         string confTag = zone.srConfl ? (" | " + ShortToString(0x2605) + " S&R+S&D CONFLUENCE") : "";
         string fvgTag  = zone.hasFVG  ? (" | " + ShortToString(0x26A1) + " UNMITIGATED FVG") : "";
         string tip = StringFormat("[%s] %s - %s | %s | Strength: %.1fx ATR%s%s",
                                   g_sdTFName[t],
                                   zone.isDemand ? "DEMAND" : "SUPPLY",
                                   SDPatternName(zone.pattern),
                                   SDStatusName(zone.status),
                                   zone.strength,
                                   confTag,
                                   fvgTag);
         if(zone.hasFVG)
           {
            tip += StringFormat("\n[FVG Imbalance] Gap: %s - %s (Unmitigated)",
                                DoubleToString(zone.fvgBottom, _Digits),
                                DoubleToString(zone.fvgTop, _Digits));
           }
         if(InpShowRR)
           {
            double refATR  = GetATR(hSR_ATR[1]);
            double buffer  = InpRR_SLBufferATR * refATR;
            double entryP  = CalcEntryFromZone(zone, zone.isDemand);
            double slP     = zone.isDemand ? (zone.bottom - buffer) : (zone.top + buffer);
            double riskP   = MathAbs(entryP - slP);
            string modeStr;
            switch(InpRR_EntryMode)
              {
               case RR_ENTRY_EQUILIBRIUM:  modeStr = "mid 50%";  break;
               case RR_ENTRY_CONSERVATIVE: modeStr = "deep 80%"; break;
               default:                    modeStr = "edge 0%";  break;
              }
            tip += StringFormat("\n[R:R Setup] Entry: %s | SL: %s | Risk: %.0f pt (%s)",
                                DoubleToString(entryP, _Digits),
                                DoubleToString(slP, _Digits),
                                riskP / _Point,
                                modeStr);
           }
         ObjectSetString(0, name, OBJPROP_TOOLTIP, tip);

         // Update koordinat waktu
         ObjectMove(0, name, 0, zone.born, zone.bottom);
         ObjectMove(0, name, 1, t2,        zone.top);
        }
     }
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| LIQUIDITY SWEEP ENGINE (Fase 5.4): deteksi candle jarum stop hunt|
//| (Wick >= InpSweep_MinWickATR yang menembus level lalu close balik)|
//+------------------------------------------------------------------+
void DetectLiquiditySweeps()
  {
   ObjectsDeleteAll(0, OBJ_PREFIX + "SWEEP_");

   if(!InpEnableSweep)
     {
      g_lastSweepDir = 0;
      return;
     }

   double refATR = GetATR(hSR_ATR[1]); // ATR H1 sebagai acuan
   if(refATR <= 0) return;

   double minWick = InpSweep_MinWickATR * refATR;
   int scanBars   = MathMin(InpSweepScanBars, Bars(_Symbol, _Period) - 2);
   if(scanBars < 1) return;

   g_lastSweepDir = 0;
   g_lastSweepTF  = "";

   for(int b = 1; b <= scanBars; b++)
     {
      double h = iHigh(_Symbol, _Period, b);
      double l = iLow(_Symbol, _Period, b);
      double c = iClose(_Symbol, _Period, b);
      datetime t = iTime(_Symbol, _Period, b);

      bool bullSweep = false;
      bool bearSweep = false;
      double sweepWick = 0.0;
      string levelDesc = "";

      // 1. Cek terhadap level Resistance & Support (S&R Matrix)
      for(int tIdx = 0; tIdx < NUM_SR_TF && !bullSweep && !bearSweep; tIdx++)
        {
         for(int k = 0; k < NUM_SR_LEVELS; k++)
           {
            // Resistance: candle menembus ke atas lalu ditutup kembali di bawah level
            if(g_resLevel[tIdx][k].valid)
              {
               double rP = g_resLevel[tIdx][k].price;
               if(h > rP && (h - rP) >= minWick && c <= rP)
                 {
                  bearSweep = true;
                  sweepWick = (h - rP);
                  levelDesc = StringFormat("RES %s (%.2f)", g_srTFName[tIdx], rP);
                  break;
                 }
              }
            // Support: candle menembus ke bawah lalu ditutup kembali di atas level
            if(g_supLevel[tIdx][k].valid)
              {
               double sP = g_supLevel[tIdx][k].price;
               if(l < sP && (sP - l) >= minWick && c >= sP)
                 {
                  bullSweep = true;
                  sweepWick = (sP - l);
                  levelDesc = StringFormat("SUP %s (%.2f)", g_srTFName[tIdx], sP);
                  break;
                 }
              }
           }
        }

      // 2. Cek terhadap zona Supply & Demand (jika belum kena di S&R)
      if(InpShowSD && !bullSweep && !bearSweep)
        {
         for(int tIdx = 0; tIdx < NUM_SD_TF && !bullSweep && !bearSweep; tIdx++)
           {
            int nZ = ArraySize(g_sdZones[tIdx].zones);
            for(int z = 0; z < nZ; z++)
              {
               SDZone zone = g_sdZones[tIdx].zones[z];
               if(zone.isDemand)
                 {
                  // Demand sweep: Low tembus bottom lalu close kembali di dalam base
                  if(l < zone.bottom && (zone.bottom - l) >= minWick && c >= zone.bottom)
                    {
                     bullSweep = true;
                     sweepWick = (zone.bottom - l);
                     levelDesc = StringFormat("DEMAND %s (%.2f)", g_sdTFName[tIdx], zone.mid);
                     break;
                    }
                 }
               else
                 {
                  // Supply sweep: High tembus top lalu close kembali di dalam base
                  if(h > zone.top && (h - zone.top) >= minWick && c <= zone.top)
                    {
                     bearSweep = true;
                     sweepWick = (h - zone.top);
                     levelDesc = StringFormat("SUPPLY %s (%.2f)", g_sdTFName[tIdx], zone.mid);
                     break;
                    }
                 }
              }
           }
        }

      // Gambar penanda grafis di chart jika terjadi sweep
      if(bullSweep)
        {
         string name = OBJ_PREFIX + "SWEEP_BULL_" + IntegerToString(t);
         double yP = l - 0.15 * refATR;
         if(ObjectFind(0, name) < 0)
            ObjectCreate(0, name, OBJ_TEXT, 0, t, yP);

         ObjectSetString(0, name, OBJPROP_TEXT, ShortToString(0x26A1) + " SWEEP");
         ObjectSetInteger(0, name, OBJPROP_COLOR, InpColorSweepBull);
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpFontSize - 1);
         ObjectSetString(0, name, OBJPROP_FONT, InpFont);
         ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_TOP);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);

         string tip = StringFormat("[%s] BULLISH LIQUIDITY SWEEP\nLevel: %s\nLow: %s | Close: %s\nWick: %.1f pt",
                                   _Symbol, levelDesc, DoubleToString(l, _Digits),
                                   DoubleToString(c, _Digits), sweepWick / _Point);
         ObjectSetString(0, name, OBJPROP_TOOLTIP, tip);

         if(b <= 2 && g_lastSweepDir == 0)
           {
            g_lastSweepDir  = 1;
            g_lastSweepTF   = StringSubstr(EnumToString(_Period), 7);
            g_lastSweepTime = t;
           }
        }
      else if(bearSweep)
        {
         string name = OBJ_PREFIX + "SWEEP_BEAR_" + IntegerToString(t);
         double yP = h + 0.15 * refATR;
         if(ObjectFind(0, name) < 0)
            ObjectCreate(0, name, OBJ_TEXT, 0, t, yP);

         ObjectSetString(0, name, OBJPROP_TEXT, ShortToString(0x26A1) + " SWEEP");
         ObjectSetInteger(0, name, OBJPROP_COLOR, InpColorSweepBear);
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpFontSize - 1);
         ObjectSetString(0, name, OBJPROP_FONT, InpFont);
         ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);

         string tip = StringFormat("[%s] BEARISH LIQUIDITY SWEEP\nLevel: %s\nHigh: %s | Close: %s\nWick: %.1f pt",
                                   _Symbol, levelDesc, DoubleToString(h, _Digits),
                                   DoubleToString(c, _Digits), sweepWick / _Point);
         ObjectSetString(0, name, OBJPROP_TOOLTIP, tip);

         if(b <= 2 && g_lastSweepDir == 0)
           {
            g_lastSweepDir  = -1;
            g_lastSweepTF   = StringSubstr(EnumToString(_Period), 7);
            g_lastSweepTime = t;
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| LEVEL TERKUAT: ranking top-2 RES & top-2 SUP gabungan 3 TF S&R,  |
//| plus 1 Supply & 1 Demand S&D terkuat (H1/H4). Ranking:           |
//|  - S&R  : confluence dulu (3TF > 2TF > 1TF), lalu totalTouches,  |
//|           lalu jarak terdekat (pemecah seri, anti level jauh).   |
//|  - S&D  : Fresh dulu (skor 1000+), lalu FVG(100)+srConfl(50)+    |
//|           strength, minus penalti jarak (via SDZoneScore).       |
//+------------------------------------------------------------------+
void FindStrongestLevels()
  {
   double bidQ = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double refATRQ = GetATR(hSR_ATR[1]);
   // --- Kumpulkan semua RES/SUP valid dari 3 TF jadi 1 daftar flat ---
   int resTF[9], resLvl[9], resConf[9], resTouch[9]; double resDist[9]; int nRes = 0;
   int supTF[9], supLvl[9], supConf[9], supTouch[9]; double supDist[9]; int nSup = 0;

   for(int t = 0; t < NUM_SR_TF; t++)
      for(int k = 0; k < NUM_SR_LEVELS; k++)
        {
         if(g_resLevel[t][k].valid)
           {
            resTF[nRes] = t; resLvl[nRes] = k;
            resConf[nRes] = g_resLevel[t][k].confluence; resTouch[nRes] = g_resLevel[t][k].totalTouches;
            resDist[nRes] = MathAbs(g_resLevel[t][k].price - bidQ);
            nRes++;
           }
         if(g_supLevel[t][k].valid)
           {
            supTF[nSup] = t; supLvl[nSup] = k;
            supConf[nSup] = g_supLevel[t][k].confluence; supTouch[nSup] = g_supLevel[t][k].totalTouches;
            supDist[nSup] = MathAbs(g_supLevel[t][k].price - bidQ);
            nSup++;
           }
        }

   // --- Sort RES descending by (confluence, totalTouches), seri -> jarak terdekat ---
   // (Dulu seri confluence+touches dimenangkan urutan TF mentah -> level jauh bisa #1.)
   for(int a = 0; a < nRes - 1; a++)
     {
      int best = a;
      for(int b = a + 1; b < nRes; b++)
         if(resConf[b] > resConf[best] ||
            (resConf[b] == resConf[best] && resTouch[b] > resTouch[best]) ||
            (resConf[b] == resConf[best] && resTouch[b] == resTouch[best] && resDist[b] < resDist[best]))
            best = b;
      if(best != a)
        {
         int t1 = resTF[a], l1 = resLvl[a], c1 = resConf[a], tt1 = resTouch[a]; double d1 = resDist[a];
         resTF[a] = resTF[best]; resLvl[a] = resLvl[best]; resConf[a] = resConf[best]; resTouch[a] = resTouch[best]; resDist[a] = resDist[best];
         resTF[best] = t1; resLvl[best] = l1; resConf[best] = c1; resTouch[best] = tt1; resDist[best] = d1;
        }
     }
   g_strongResTF[0] = (nRes > 0) ? resTF[0] : -1;  g_strongResLvl[0] = (nRes > 0) ? resLvl[0] : -1;
   g_strongResTF[1] = (nRes > 1) ? resTF[1] : -1;  g_strongResLvl[1] = (nRes > 1) ? resLvl[1] : -1;

   // --- Sort SUP dengan cara yang sama (seri -> jarak terdekat) ---
   for(int a = 0; a < nSup - 1; a++)
     {
      int best = a;
      for(int b = a + 1; b < nSup; b++)
         if(supConf[b] > supConf[best] ||
            (supConf[b] == supConf[best] && supTouch[b] > supTouch[best]) ||
            (supConf[b] == supConf[best] && supTouch[b] == supTouch[best] && supDist[b] < supDist[best]))
            best = b;
      if(best != a)
        {
         int t1 = supTF[a], l1 = supLvl[a], c1 = supConf[a], tt1 = supTouch[a]; double d1 = supDist[a];
         supTF[a] = supTF[best]; supLvl[a] = supLvl[best]; supConf[a] = supConf[best]; supTouch[a] = supTouch[best]; supDist[a] = supDist[best];
         supTF[best] = t1; supLvl[best] = l1; supConf[best] = c1; supTouch[best] = tt1; supDist[best] = d1;
        }
     }
   g_strongSupTF[0] = (nSup > 0) ? supTF[0] : -1;  g_strongSupLvl[0] = (nSup > 0) ? supLvl[0] : -1;
   g_strongSupTF[1] = (nSup > 1) ? supTF[1] : -1;  g_strongSupLvl[1] = (nSup > 1) ? supLvl[1] : -1;

   // --- S&D: 1 Supply + 1 Demand terkuat via SKOR KUALITAS (bukan jarak mentah) ---
   // Fresh(1000) selalu kalahkan Tested; FVG(100) > srConfl(50) > strength > jarak.
   // g_sdNearest[*] kini sudah berisi zona skor-tertinggi per TF (BuildNearestSD),
   // jadi pilih antar-TF tinggal bandingkan skornya (bukan rantai if jarak).
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   g_strongSDSupplyTF = -1; g_strongSDDemandTF = -1;
   double bestSupplyScore = -DBL_MAX, bestDemandScore = -DBL_MAX;
   for(int t = 0; t < NUM_SD_TF; t++)
     {
      double atrT = GetATR(hSD_ATR[t]);
      if(g_sdNearestValid[t][1]) // supply
        {
         double sc = SDZoneScore(g_sdNearest[t][1], bid, atrT);
         if(g_strongSDSupplyTF < 0 || sc > bestSupplyScore)
           { bestSupplyScore = sc; g_strongSDSupplyTF = t; }
        }
      if(g_sdNearestValid[t][0]) // demand
        {
         double sc = SDZoneScore(g_sdNearest[t][0], bid, atrT);
         if(g_strongSDDemandTF < 0 || sc > bestDemandScore)
           { bestDemandScore = sc; g_strongSDDemandTF = t; }
        }
     }
  }

//+------------------------------------------------------------------+
//| DASHBOARD: format 1 tag level terkuat (RES/SUP) untuk baris      |
//+------------------------------------------------------------------+
string ResTag(const int idx)
  {
   if(g_strongResTF[idx] < 0) return("");
   SRLevel r = g_resLevel[g_strongResTF[idx]][g_strongResLvl[idx]];
   string star = (r.confluence >= 3 ? "★★★" : (r.confluence == 2 ? "★★" : ""));
   return StringFormat("RES%d %s %s(%s%dx)", idx + 1, g_srTFName[g_strongResTF[idx]],
                       DoubleToString(r.price, _Digits), star, r.totalTouches);
  }

string SupTag(const int idx)
  {
   if(g_strongSupTF[idx] < 0) return("");
   SRLevel s = g_supLevel[g_strongSupTF[idx]][g_strongSupLvl[idx]];
   string star = (s.confluence >= 3 ? "★★★" : (s.confluence == 2 ? "★★" : ""));
   return StringFormat("SUP%d %s %s(%s%dx)", idx + 1, g_srTFName[g_strongSupTF[idx]],
                       DoubleToString(s.price, _Digits), star, s.totalTouches);
  }

//+------------------------------------------------------------------+
//| S&D ENGINE: orchestrator recompute semua TF                      |
//| Catatan: kalkulasi & data dashboard tetap jalan walau tombol     |
//| [S&D] di-toggle OFF -- toggle cuma menyembunyikan rectangle di   |
//| chart (g_showSD), bukan mematikan enginenya (itu InpShowSD).     |
//+------------------------------------------------------------------+
void RecomputeSD()
  {
   if(!InpShowSD)
     {
      if(InpShowSD_Debug) Comment("");
      return;
     }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr = GetATR(hSR_ATR[1]); // pakai ATR H1 sebagai referensi

   string dbg = "";
   for(int t = 0; t < NUM_SD_TF; t++)
     {
      double tfAtr = GetATR(hSD_ATR[t]);
      FindSDZonesForTF(t, bid);
      if(InpShowSD_Debug)
        {
         dbg += StringFormat("%s | ATR=%.2f | ImpTh=%.2f | BaseTh=%.2f | zona lolos=%d\n",
                g_sdTFName[t], tfAtr, tfAtr * InpImpulseBodyATR, tfAtr * InpBaseMaxATR,
                ArraySize(g_sdZones[t].zones));
        }
      if(InpEnableConfluence)
         CheckSDSRConfluence(t, atr);
      BuildNearestSD(t, bid);
     }

   if(InpShowSD_Debug)
      Comment(dbg);
   else
      Comment("");

   if(g_showSD)
      DrawSDZones();
   else
     {
      ObjectsDeleteAll(0, OBJ_PREFIX + "SD_");
      ObjectsDeleteAll(0, OBJ_PREFIX + "FVG_");
     }
  }

//+------------------------------------------------------------------+
//| STATS ENGINE: hitung Spread, ADR-14, & Range Hari Ini            |
//+------------------------------------------------------------------+
struct StatsInfo
  {
   int    spread;      // Spread saat ini (dalam point)
   double adr;         // Average Daily Range 14 hari (dalam point)
   double todayRange;  // Range hari ini High-Low (dalam point)
   double pctToday;    // Persentase range hari ini vs ADR (%)
   double remaining;   // Sisa poin ADR yang belum ditempuh hari ini
  };

StatsInfo CalcStats()
  {
   StatsInfo s;
   s.spread     = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   s.adr        = 0.0;
   s.todayRange = 0.0;
   s.pctToday   = 0.0;
   s.remaining  = 0.0;

   // ADR-14: rata-rata range (H-L) 14 bar D1 terakhir (bar 1..14 = bar closed)
   int period = MathMax(InpADR_Period, 1);
   int avail  = Bars(_Symbol, PERIOD_D1);
   if(avail > period + 1)
     {
      double sumRange = 0.0;
      for(int i = 1; i <= period; i++)
         sumRange += iHigh(_Symbol, PERIOD_D1, i) - iLow(_Symbol, PERIOD_D1, i);
      s.adr = sumRange / period;
     }

   // Range hari ini = High D1 bar 0 (bar berjalan) - Low D1 bar 0
   double todH = iHigh(_Symbol, PERIOD_D1, 0);
   double todL = iLow(_Symbol, PERIOD_D1, 0);
   if(todH > 0 && todL > 0 && todH > todL)
      s.todayRange = todH - todL;

   // Persentase & sisa
   if(s.adr > 0)
     {
      s.pctToday  = (s.todayRange / s.adr) * 100.0;
      s.remaining = MathMax(s.adr - s.todayRange, 0.0);
     }

   return(s);
  }

//+------------------------------------------------------------------+
//| SIGNAL LOGGER: snapshot 18 kandidat (3 TF x RES/SUP 1-3) ke CSV  |
//| Clock kunci H1 (agent_TF.md Bab 4-5). Snapshot-locked anti-curang.|
//+------------------------------------------------------------------+
string LoggerTrendCtx()
  {
   string s = "";
   for(int i = 0; i < 3; i++)
     {
      string d = (g_trend[i].dir > 0 ? "UP" : (g_trend[i].dir < 0 ? "DN" : "FL"));
      s += g_tfName[i] + "_" + d;
      if(i < 2) s += "/";
     }
   s += "|ADX" + DoubleToString(g_trend[1].adx, 0);
   return(s);
  }

int LoggerStrongRank(const int tfIdx, const int lvlIdx, const bool isRes)
  {
   for(int r = 0; r < 2; r++)
     {
      if(isRes)
        {
         if(g_strongResTF[r] == tfIdx && g_strongResLvl[r] == lvlIdx) return(r + 1);
        }
      else
        {
         if(g_strongSupTF[r] == tfIdx && g_strongSupLvl[r] == lvlIdx) return(r + 1);
        }
     }
   return(0);
  }

void LoggerSDTag(const double mid, const double tol, int &sdOverlap, int &hasFVG, string &sdStatus)
  {
   sdOverlap = 0; hasFVG = 0; sdStatus = "None";
   for(int t = 0; t < NUM_SD_TF && sdOverlap == 0; t++)
     {
      int sz = ArraySize(g_sdZones[t].zones);
      for(int z = 0; z < sz; z++)
        {
         if(MathAbs(g_sdZones[t].zones[z].mid - mid) <= tol)
           {
            sdOverlap = 1;
            if(g_sdZones[t].zones[z].hasFVG) hasFVG = 1;
            sdStatus = (g_sdZones[t].zones[z].status == SD_FRESH ? "Fresh" : "Tested");
            break;
           }
        }
     }
  }

void LoggerWriteRow(const int f, const datetime sigTime, const string agentTF,
                    const string side, const int rank, const SRLevel &lvl,
                    const double atrTF, const double bid, const double ask,
                    const long spreadPt, const string trendCtx, const int sweepFlag,
                    const int expiryH)
  {
   if(!lvl.valid) return;
   double distATR = (atrTF > 0 ? MathAbs(lvl.price - bid) / atrTF : 0.0);
   int tfIdx = -1;
   for(int t = 0; t < NUM_SR_TF; t++)
      if(g_srTFName[t] == agentTF) { tfIdx = t; break; }
   bool isRes = (side == "RES");
   int sRank = LoggerStrongRank(tfIdx, rank - 1, isRes);
   int isStrong = (sRank > 0 ? 1 : 0);
   double tol = MathMax(InpConfToleranceATR * atrTF, 15 * _Point);
   int sdO = 0, fvg = 0; string sdS = "None";
   LoggerSDTag(lvl.price, tol, sdO, fvg, sdS);
   string line = StringFormat("%s,%s,H1,%s,%s,%d,%.5f,%d,%d,%d,%d,%d,%d,%d,%s,%d,%s,%.5f,%.5f,%d,%.5f,%.3f,%d,%s",
      TimeToString(sigTime, TIME_DATE | TIME_SECONDS), _Symbol, agentTF, side, rank,
      lvl.price, lvl.touches, lvl.confluence, lvl.totalTouches,
      isStrong, sRank, sdO, fvg, sdS, sweepFlag, trendCtx,
      bid, ask, spreadPt, atrTF, distATR, expiryH, SRD_VERSION);
   FileWriteString(f, line + "\n");
  }

void LoggerMaybeSnapshot()
  {
   if(!InpEnableLogger) return;
   datetime h1Bar = iTime(_Symbol, PERIOD_H1, 0);
   if(h1Bar == 0 || h1Bar == g_logLastH1Bar) return;
   g_logLastH1Bar = h1Bar;

   // FIX (audit): jangan andalkan cadence recompute chart yang di-attach (needRecompute
   // di OnCalculate cuma jalan per bar CHART, bisa H4/M30/dll). Logger berjalan dengan
   // jamnya sendiri (per bar H1), jadi paksa refresh data di sini juga -- supaya g_resLevel/
   // g_supLevel/g_strongResTF/g_sdZones/g_trend yang ditulis ke CSV selalu representasi
   // H1 bar INI, bukan sisa recompute bar chart sebelumnya (yang bisa berjam-jam lalu kalau
   // chart di-attach di H4). Gerbang di atas (h1Bar == g_logLastH1Bar) sudah membatasi ini
   // ke maksimal 1x per jam, jadi tetap sejalan dengan prinsip VPS-safe "1x per bar".
   UpdateTrends();
   RecomputeZones();

   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   string fname = StringFormat("%s_%04d%02d%02d.csv", InpLoggerPrefix, dt.year, dt.mon, dt.day);
   bool needHeader = (!g_logHeaderDone || g_logFileName != fname);
   g_logFileName = fname;

   int f = FileOpen(fname, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(f == INVALID_HANDLE) { Print("SRD Logger: gagal buka ", fname, " err=", GetLastError()); return; }
   FileSeek(f, 0, SEEK_END);
   if(needHeader && FileSize(f) == 0)
     {
      FileWriteString(f, "time_utc,symbol,clock_tf,agent_tf,side,rank_jarak,price,touches,confluence,totalTouches,isStrongest,isStrongestRank,sdOverlap,hasFVG,sdStatus,sweepAtSignal,trendCtx,bid,ask,spread_pt,atr_tf,distATR,expiry_hours,version\n");
      g_logHeaderDone = true;
     }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   long spreadPt = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   string trendCtx = LoggerTrendCtx();
   int sweepFlag = 0;
   if(g_lastSweepTime > 0 && (TimeCurrent() - g_lastSweepTime) <= 2 * PeriodSeconds(PERIOD_H1))
      sweepFlag = 1;

   for(int t = 0; t < NUM_SR_TF; t++)
     {
      double atrTF = GetATR(hSR_ATR[t]);
      int expiryH = (g_srTF[t] == PERIOD_H4 ? 48 : 24);
      for(int k = 0; k < NUM_SR_LEVELS; k++)
        {
         LoggerWriteRow(f, h1Bar, g_srTFName[t], "RES", k + 1, g_resLevel[t][k],
                        atrTF, bid, ask, spreadPt, trendCtx, sweepFlag, expiryH);
         LoggerWriteRow(f, h1Bar, g_srTFName[t], "SUP", k + 1, g_supLevel[t][k],
                        atrTF, bid, ask, spreadPt, trendCtx, sweepFlag, expiryH);
        }
     }
   FileClose(f);
  }

//+------------------------------------------------------------------+
//| S&R ENGINE: recompute semua TF + cek Confluence + S&D + Terkuat |
//+------------------------------------------------------------------+
void RecomputeZones()
  {
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   for(int t = 0; t < NUM_SR_TF; t++)
      RecomputeZonesForTF(t, bid);

   // Deteksi Confluence antar 3 timeframe (M30, H1, H4)
   double refATR = GetATR(hSR_ATR[1]);
   CheckConfluence(refATR);

   // Gambar zona S&R di chart hanya kalau toggle [S&R] aktif (data matrix tetap dihitung)
   if(g_showSR)
      DrawNearestZones();
   else
      ObjectsDeleteAll(0, OBJ_PREFIX + "Z_");

   // S&D Engine: scan pola impulse-base-impulse + gambar zona (gated oleh InpShowSD & g_showSD)
   RecomputeSD();

   // Ranking level terkuat (top-2 RES/SUP gabungan 3 TF + 1 Supply/Demand S&D terkuat)
   FindStrongestLevels();

   // Deteksi Liquidity Sweep / Fakeout di chart (Fase 5.4)
   DetectLiquiditySweeps();
  }

//+------------------------------------------------------------------+
//| RR_ENTRY_CALC: hitung entry berdasarkan mode (Fase 5.6)          |
//|  Demand BUY : entry di antara dz.bottom (dasar) dan dz.top (tepi)|
//|  Supply SELL: entry di antara sz.top (dasar) dan sz.bottom (tepi)|
//+------------------------------------------------------------------+
double CalcEntryFromZone(const SDZone &z, bool isDemand)
  {
   switch(InpRR_EntryMode)
     {
      case RR_ENTRY_AGGRESSIVE:   // 0%  — tepi terluar (sentuhan pertama)
         return isDemand ? z.top : z.bottom;

      case RR_ENTRY_EQUILIBRIUM:  // 50% — titik tengah zona
         return (z.top + z.bottom) * 0.5;

      case RR_ENTRY_CONSERVATIVE: // 80% — penetrasi dalam menuju dasar
         // Demand: mulai dari top, gerak ke bawah 80% kedalaman zona
         // Supply: mulai dari bottom, gerak ke atas 80% kedalaman zona
         if(isDemand)
            return z.top - 0.80 * (z.top - z.bottom);
         else
            return z.bottom + 0.80 * (z.top - z.bottom);
     }
   return isDemand ? z.top : z.bottom; // fallback
  }

//+------------------------------------------------------------------+
//| R:R HELPER: format baris proyeksi Risk:Reward untuk Setup Terkuat|
//| (Fase 5.2 + 5.6: mendukung 3 mode entry)                        |
//+------------------------------------------------------------------+
void CalcRRStrings(string &buyTxt, string &sellTxt, color &buyClr, color &sellClr)
  {
   double refATR = GetATR(hSR_ATR[1]); // ATR H1 sebagai acuan buffer
   double buffer = InpRR_SLBufferATR * refATR;

   // Label mode entry untuk ditampilkan di baris SETUP
   string modeLabel = "";
   switch(InpRR_EntryMode)
     {
      case RR_ENTRY_EQUILIBRIUM:  modeLabel = "@mid ";  break;
      case RR_ENTRY_CONSERVATIVE: modeLabel = "@deep "; break;
      default:                    modeLabel = "";        break; // AGGRESSIVE: tanpa label (default saat ini)
     }

   //--- 1. Proyeksi Setup BUY (dari Demand Terkuat menuju RES Terkuat)
   //        SOP LIVE: zona Tested/tanpa-FVG DITOLAK jadi baris abu SKIP (bukan hijau).
   if(g_strongSDDemandTF >= 0 && g_sdNearestValid[g_strongSDDemandTF][0])
     {
      SDZone dz    = g_sdNearest[g_strongSDDemandTF][0];
      bool dzOK = (!InpRR_RequireFreshFVG) ||
                  (dz.status == SD_FRESH && dz.hasFVG);
      if(!dzOK)
        {
         buyTxt = StringFormat("SETUP > BUY SKIP (butuh Fresh+FVG, zona %s%s)",
                               (dz.status == SD_FRESH ? "Fresh" : "Tested"),
                               (dz.hasFVG ? "+FVG" : "-noFVG"));
         buyClr = clrDimGray;
        }
      else
        {
      double entry = CalcEntryFromZone(dz, true);   // entry sesuai mode
      double sl    = dz.bottom - buffer;             // SL tetap dari dasar zona (batas belakang)
      double risk  = entry - sl;
      string fvgTag = dz.hasFVG ? "+FVG" : "";

      // Target TP: RES terkuat (prioritas g_strongResTF[0], jika di atas entry)
      double tp = 0;
      if(g_strongResTF[0] >= 0 && g_strongResLvl[0] >= 0)
        {
         double candidateTP = g_resLevel[g_strongResTF[0]][g_strongResLvl[0]].price;
         if(candidateTP > entry)
            tp = candidateTP;
        }

      if(tp <= entry && g_strongResTF[1] >= 0 && g_strongResLvl[1] >= 0)
        {
         double candidateTP2 = g_resLevel[g_strongResTF[1]][g_strongResLvl[1]].price;
         if(candidateTP2 > entry)
            tp = candidateTP2;
        }

      if(tp > entry && risk > 0)
        {
         double reward = tp - entry;
         double rr     = reward / risk;
         string star   = (rr >= 2.0) ? " ★" : "";
         buyTxt = StringFormat("SETUP > BUY %sD:%s%s (SL:%s TP:%s|RR 1:%.1f)%s",
                               modeLabel,
                               DoubleToString(entry, _Digits),
                               fvgTag,
                               DoubleToString(sl, _Digits),
                               DoubleToString(tp, _Digits),
                               rr, star);
         buyClr = (rr >= 2.0) ? clrLimeGreen : clrLightGreen;
        }
      else
        {
         buyTxt = StringFormat("SETUP > BUY %sD:%s%s (SL:%s|Target RES nihil)",
                               modeLabel,
                               DoubleToString(entry, _Digits),
                               fvgTag,
                               DoubleToString(sl, _Digits));
         buyClr = clrDarkSeaGreen;
        }
        } // end dzOK (Fresh+FVG) — penegakan SOP LIVE
     }
   else
     {
      buyTxt = "SETUP > BUY D:       - - -        ";
      buyClr = clrDimGray;
     }

   //--- 2. Proyeksi Setup SELL (dari Supply Terkuat menuju SUP Terkuat)
   //        SOP LIVE: sama seperti BUY — tolak Tested/tanpa-FVG jadi SKIP abu.
   if(g_strongSDSupplyTF >= 0 && g_sdNearestValid[g_strongSDSupplyTF][1])
     {
      SDZone sz    = g_sdNearest[g_strongSDSupplyTF][1];
      bool szOK = (!InpRR_RequireFreshFVG) ||
                  (sz.status == SD_FRESH && sz.hasFVG);
      if(!szOK)
        {
         sellTxt = StringFormat("       SELL SKIP (butuh Fresh+FVG, zona %s%s)",
                                (sz.status == SD_FRESH ? "Fresh" : "Tested"),
                                (sz.hasFVG ? "+FVG" : "-noFVG"));
         sellClr = clrDimGray;
        }
      else
        {
      double entry = CalcEntryFromZone(sz, false);  // entry sesuai mode
      double sl    = sz.top + buffer;               // SL tetap dari batas atas zona (batas belakang)
      double risk  = sl - entry;
      string fvgTag = sz.hasFVG ? "+FVG" : "";

      // Target TP: SUP terkuat (prioritas g_strongSupTF[0], jika di bawah entry)
      double tp = 0;
      if(g_strongSupTF[0] >= 0 && g_strongSupLvl[0] >= 0)
        {
         double candidateTP = g_supLevel[g_strongSupTF[0]][g_strongSupLvl[0]].price;
         if(candidateTP < entry)
            tp = candidateTP;
        }

      if(tp <= 0 && g_strongSupTF[1] >= 0 && g_strongSupLvl[1] >= 0)
        {
         double candidateTP2 = g_supLevel[g_strongSupTF[1]][g_strongSupLvl[1]].price;
         if(candidateTP2 < entry)
            tp = candidateTP2;
        }

      if(tp > 0 && tp < entry && risk > 0)
        {
         double reward = entry - tp;
         double rr     = reward / risk;
         string star   = (rr >= 2.0) ? " ★" : "";
         sellTxt = StringFormat("       SELL %sS:%s%s (SL:%s TP:%s|RR 1:%.1f)%s",
                                modeLabel,
                                DoubleToString(entry, _Digits),
                                fvgTag,
                                DoubleToString(sl, _Digits),
                                DoubleToString(tp, _Digits),
                                rr, star);
         sellClr = (rr >= 2.0) ? clrTomato : clrSalmon;
        }
      else
        {
         sellTxt = StringFormat("       SELL %sS:%s%s (SL:%s|Target SUP nihil)",
                                modeLabel,
                                DoubleToString(entry, _Digits),
                                fvgTag,
                                DoubleToString(sl, _Digits));
         sellClr = clrIndianRed;
        }
        } // end szOK (Fresh+FVG) — penegakan SOP LIVE
     }
   else
     {
      sellTxt = "       SELL S:       - - -        ";
      sellClr = clrDimGray;
     }
  }

//+------------------------------------------------------------------+
//| DASHBOARD: render panel matriks super presisi                    |
//+------------------------------------------------------------------+
void UpdateDashboard()
  {
   double dpi = (double)TerminalInfoInteger(TERMINAL_SCREEN_DPI);
   if(dpi <= 0.0)
      dpi = 96.0;
   double dpiScale = dpi / 96.0;

   int lh   = (int)MathRound((InpFontSize + 8) * dpiScale);
   // rows: 17 base + 1 stats + 2 baris "TERKUAT" + 2 baris R:R (opsi A) + 2 S&D rows
   int sdRows = (InpShowSD ? 2 : 0);
   int rrRows = (InpShowRR && InpShowSD) ? 2 : 0;
   int rows   = (InpShowStats ? 18 : 17) + sdRows + 2 + rrRows;
   int h      = rows * lh + (int)MathRound(16 * dpiScale);

   // Kolom koordinat X berbasis DPI
   int x0 = (int)MathRound(10 * dpiScale);   // Kolom label (RES 1-3, SUP 1-3)
   int x1 = (int)MathRound(80 * dpiScale);   // Kolom 1 (M30)
   int x2 = (int)MathRound(272 * dpiScale);  // Kolom 2 (H1)
   int x3 = (int)MathRound(464 * dpiScale);  // Kolom 3 (H4)
   int w  = (int)MathRound(670 * dpiScale);  // Lebar total panel background

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Tentukan status tren
   string tag    = "MIXED";
   color  tagClr = InpColorText;
   if(g_trend[0].dir > 0 && g_trend[1].dir > 0 && g_trend[2].dir > 0)
     {
      tag    = "ALIGNED UP";
      tagClr = InpColorTrendUp;
     }
   else if(g_trend[0].dir < 0 && g_trend[1].dir < 0 && g_trend[2].dir < 0)
     {
      tag    = "ALIGNED DOWN";
      tagClr = InpColorTrendDn;
     }

   // Tag status Liquidity Sweep (Fase 5.4 - Opsi 1)
   string sweepTag = "";
   if(g_lastSweepDir > 0)
      sweepTag = " | " + ShortToString(0x26A1) + " SWEEP BUY " + g_lastSweepTF;
   else if(g_lastSweepDir < 0)
      sweepTag = " | " + ShortToString(0x26A1) + " SWEEP SELL " + g_lastSweepTF;

   int x = InpPanelX;
   int y = InpPanelY;

   // Ukuran & posisi tombol (dipakai di kedua mode: collapsed & expanded)
   int minBtnW = (int)MathRound(22 * dpiScale);
   int minBtnH = (int)MathRound(20 * dpiScale);
   int togBtnW = (int)MathRound(38 * dpiScale);
   int btnGap  = (int)MathRound(4  * dpiScale);

   //--- MODE COLLAPSED (MINIMIZED)
   if(g_panelCollapsed)
     {
      int collW = (int)MathRound(430 * dpiScale);
      int collH = (int)MathRound(32 * dpiScale);
      FitPanelPosition(x, y, collW, collH);

      SetPanel(x, y, collW, collH);

      // Tombol [+] untuk expand
      SetButton("BTN_MIN", x + collW - (int)MathRound(28 * dpiScale), y + (int)MathRound(6 * dpiScale),
                minBtnW, minBtnH, "+", clrWhite, C'45,45,45');

      // Teks ringkas 1 baris
      string collTitle = StringFormat("SRD | %s%s | BID: %s", tag, sweepTag, DoubleToString(bid, _Digits));
      SetLabel("T_TITLE", x + x0, y + (int)MathRound(8 * dpiScale), collTitle, tagClr, InpFontSize, InpFont);

      // Hapus tombol toggle S&R/S&D & semua label tabel matrix agar chart bersih saat minimize
      ObjectDelete(0, OBJ_PREFIX + "BTN_SR");
      ObjectDelete(0, OBJ_PREFIX + "BTN_SD");

      for(int i = 0; i < 3; i++)
         ObjectDelete(0, OBJ_PREFIX + "T_TRD" + IntegerToString(i));

      ObjectDelete(0, OBJ_PREFIX + "T_STRONG_RES");
      ObjectDelete(0, OBJ_PREFIX + "T_STRONG_SUP");
      ObjectDelete(0, OBJ_PREFIX + "T_RR_BUY");
      ObjectDelete(0, OBJ_PREFIX + "T_RR_SELL");
      ObjectDelete(0, OBJ_PREFIX + "T_SEP1");
      ObjectDelete(0, OBJ_PREFIX + "T_HDR_L");
      ObjectDelete(0, OBJ_PREFIX + "T_HDR_0");
      ObjectDelete(0, OBJ_PREFIX + "T_HDR_1");
      ObjectDelete(0, OBJ_PREFIX + "T_HDR_2");
      ObjectDelete(0, OBJ_PREFIX + "T_SEP2");

      for(int k = 1; k <= NUM_SR_LEVELS; k++)
        {
         string s = IntegerToString(k);
         ObjectDelete(0, OBJ_PREFIX + "T_RES_L"  + s);
         ObjectDelete(0, OBJ_PREFIX + "T_RES_C0" + s);
         ObjectDelete(0, OBJ_PREFIX + "T_RES_C1" + s);
         ObjectDelete(0, OBJ_PREFIX + "T_RES_C2" + s);
         ObjectDelete(0, OBJ_PREFIX + "T_SUP_L"  + s);
         ObjectDelete(0, OBJ_PREFIX + "T_SUP_C0" + s);
         ObjectDelete(0, OBJ_PREFIX + "T_SUP_C1" + s);
         ObjectDelete(0, OBJ_PREFIX + "T_SUP_C2" + s);
        }

       ObjectDelete(0, OBJ_PREFIX + "T_STATS");
       ObjectDelete(0, OBJ_PREFIX + "T_SEP3");
       ObjectDelete(0, OBJ_PREFIX + "T_PRICE");
       ObjectDelete(0, OBJ_PREFIX + "T_SEP4");
       ObjectDelete(0, OBJ_PREFIX + "T_SD_SUP_L");
       ObjectDelete(0, OBJ_PREFIX + "T_SD_SUP_0");
       ObjectDelete(0, OBJ_PREFIX + "T_SD_SUP_1");
       ObjectDelete(0, OBJ_PREFIX + "T_SD_SUP_2");
       ObjectDelete(0, OBJ_PREFIX + "T_SD_RES_L");
       ObjectDelete(0, OBJ_PREFIX + "T_SD_RES_0");
       ObjectDelete(0, OBJ_PREFIX + "T_SD_RES_1");
       ObjectDelete(0, OBJ_PREFIX + "T_SD_RES_2");
       ObjectDelete(0, OBJ_PREFIX + "T_SEP5");

      ChartRedraw();
      return;
     }

   //--- MODE EXPANDED (FULL MATRIX)
   FitPanelPosition(x, y, w, h);
   SetPanel(x, y, w, h);

   // Tombol [-] untuk collapse (paling kanan)
   int minBtnX = x + w - minBtnW - (int)MathRound(6 * dpiScale);
   int btnY    = y + (int)MathRound(5 * dpiScale);
   SetButton("BTN_MIN", minBtnX, btnY, minBtnW, minBtnH, "-", clrWhite, C'45,45,45');

   // Tombol toggle [S&D] & [S&R], di kiri tombol minimize -- hijau=ON, abu=OFF
   int sdBtnX = minBtnX - btnGap - togBtnW;
   int srBtnX = sdBtnX  - btnGap - togBtnW;
   SetButton("BTN_SD", sdBtnX, btnY, togBtnW, minBtnH, "S&D",
             g_showSD ? clrWhite : clrSilver, g_showSD ? C'30,90,40' : C'45,45,45');
   SetButton("BTN_SR", srBtnX, btnY, togBtnW, minBtnH, "S&R",
             g_showSR ? clrWhite : clrSilver, g_showSR ? C'30,90,40' : C'45,45,45');

   int row = 0;

   //--- 1. Judul + status alignment multi-TF
   SetLabel("T_TITLE", x + x0, y + 6 + row * lh, "SRD | " + tag + sweepTag, tagClr, InpFontSize, InpFont);
   row++;

   //--- 1b. Quick Stats Bar (Spread & ADR)
   if(InpShowStats)
     {
      StatsInfo st = CalcStats();
      color statsClr = (st.pctToday >= InpADR_WarnPct) ? InpColorADRWarn : InpColorStats;

      string statsText;
      if(st.adr > 0)
        {
         // Format ADR & remaining dalam satuan point agar ringkas
         string adrStr  = DoubleToString(st.adr / _Point, 0);
         string todStr  = DoubleToString(st.todayRange / _Point, 0);
         string remStr  = DoubleToString(st.remaining / _Point, 1);
         string pctStr  = DoubleToString(st.pctToday, 0);
         string warnTag = (st.pctToday >= InpADR_WarnPct) ? " ⚠ SLOW" : "";
         statsText = StringFormat("SPR:%d  ADR14:%s  Range:%s(%s%%)  Sisa:%spt%s",
                                  st.spread, adrStr, todStr, pctStr, remStr, warnTag);
        }
      else
         statsText = StringFormat("SPR:%d  ADR: (data D1 tidak cukup)", st.spread);

      SetLabel("T_STATS", x + x0, y + 6 + row * lh, statsText, statsClr, InpFontSize - 1, InpFont);
      row++;
     }
   else
      ObjectDelete(0, OBJ_PREFIX + "T_STATS");

   //--- 2. Tiga baris tren (D1, H4, H1)
   for(int i = 0; i < 3; i++)
     {
      TrendInfo t = g_trend[i];
      string txt = StringFormat("%-2s : %s %-4s", g_tfName[i], ArrowOf(t), DirText(t));
      if(InpUseADX)
         txt += StringFormat("  ADX %4.1f", t.adx);
      if(InpUseRSI)
         txt += StringFormat("  RSI %4.1f", t.rsi);
      if(InpUseRSI && (t.rsiOB || t.rsiOS))
         txt += (t.rsiOB ? " OB!" : " OS!");

      color clr = (t.dir > 0) ? InpColorTrendUp : ((t.dir < 0) ? InpColorTrendDn : InpColorFlat);
      if(InpUseRSI && (t.rsiOB || t.rsiOS))
         clr = InpColorWarn;

      SetLabel("T_TRD" + IntegerToString(i), x + x0, y + 6 + row * lh, txt, clr, InpFontSize, InpFont);
      row++;
     }

   //--- 2b. LEVEL TERKUAT: top-2 RES (baris 1) & top-2 SUP + S&D (baris 2)
   //        Hirarki: RES di atas (posisi spasial di atas harga), SUP di bawah;
   //        dalam tiap baris urut rank kekuatan (bukan urut TF).
   string strongResTxt = "TERKUAT> " + ResTag(0);
   if(g_strongResTF[1] >= 0) strongResTxt += "   " + ResTag(1);
   SetLabel("T_STRONG_RES", x + x0, y + 6 + row * lh, strongResTxt, InpColorResist, InpFontSize, InpFont);
   row++;

   string strongSupTxt = "         " + SupTag(0);
   if(g_strongSupTF[1] >= 0) strongSupTxt += "   " + SupTag(1);
   if(InpShowSD)
     {
      if(g_strongSDSupplyTF >= 0)
         strongSupTxt += "   S:" + DoubleToString(g_sdNearest[g_strongSDSupplyTF][1].mid, _Digits);
      if(g_strongSDDemandTF >= 0)
         strongSupTxt += "  D:" + DoubleToString(g_sdNearest[g_strongSDDemandTF][0].mid, _Digits);
     }
   SetLabel("T_STRONG_SUP", x + x0, y + 6 + row * lh, strongSupTxt, InpColorSupport, InpFontSize, InpFont);
   row++;

   //--- 2c. SETUP R:R PROJECTION (Fase 5.2 - Opsi A):
   //        Kalkulasi otomatis Entry, SL, TP (RES/SUP Terkuat), dan Rasio R:R
   if(InpShowRR && InpShowSD)
     {
      string rrBuyTxt, rrSellTxt;
      color  rrBuyClr, rrSellClr;
      CalcRRStrings(rrBuyTxt, rrSellTxt, rrBuyClr, rrSellClr);
      SetLabel("T_RR_BUY",  x + x0, y + 6 + row * lh, rrBuyTxt,  rrBuyClr,  InpFontSize, InpFont);
      row++;
      SetLabel("T_RR_SELL", x + x0, y + 6 + row * lh, rrSellTxt, rrSellClr, InpFontSize, InpFont);
      row++;
     }
   else
     {
      ObjectDelete(0, OBJ_PREFIX + "T_RR_BUY");
      ObjectDelete(0, OBJ_PREFIX + "T_RR_SELL");
     }

   // Garis pemisah (60 karakter, aman di bawah batas 63 karakter MT5)
   string sepLine = "------------------------------------------------------------";

   //--- 3. Separator atas tabel
   SetLabel("T_SEP1", x + x0, y + 6 + row * lh, sepLine, InpColorBorder, InpFontSize, InpFont);
   row++;

   //--- 4. Header Kolom Timeframe (M30, H1, H4) per kolom terpisah
   SetLabel("T_HDR_L", x + x0, y + 6 + row * lh, "       |", InpColorHdr, InpFontSize, InpFont);
   SetLabel("T_HDR_0", x + x1, y + 6 + row * lh, CenterText(g_srTFName[0], 21), InpColorHdr, InpFontSize, InpFont);
   SetLabel("T_HDR_1", x + x2, y + 6 + row * lh, "|" + CenterText(g_srTFName[1], 21), InpColorHdr, InpFontSize, InpFont);
   SetLabel("T_HDR_2", x + x3, y + 6 + row * lh, "|" + CenterText(g_srTFName[2], 21), InpColorHdr, InpFontSize, InpFont);
   row++;

   SetLabel("T_SEP2", x + x0, y + 6 + row * lh, sepLine, InpColorBorder, InpFontSize, InpFont);
   row++;

   double refATR = GetATR(hSR_ATR[1]); // ATR H1 untuk acuan Proximity

   //--- 5. Tiga baris RESISTANCE (RES 3 terjauh -> RES 1 terdekat di atas harga)
   for(int k = NUM_SR_LEVELS - 1; k >= 0; k--)
     {
      int resNum = k + 1;
      string sNum = IntegerToString(resNum);
      color clr0, clr1, clr2;
      string c0 = FormatLevelCell(g_resLevel[0][k], bid, refATR, clr0, true);
      string c1 = FormatLevelCell(g_resLevel[1][k], bid, refATR, clr1, true);
      string c2 = FormatLevelCell(g_resLevel[2][k], bid, refATR, clr2, true);

      SetLabel("T_RES_L"  + sNum, x + x0, y + 6 + row * lh, StringFormat(" RES %d |", resNum), InpColorResist, InpFontSize, InpFont);
      SetLabel("T_RES_C0" + sNum, x + x1, y + 6 + row * lh, " " + c0, clr0, InpFontSize, InpFont);
      SetLabel("T_RES_C1" + sNum, x + x2, y + 6 + row * lh, "| " + c1, clr1, InpFontSize, InpFont);
      SetLabel("T_RES_C2" + sNum, x + x3, y + 6 + row * lh, "| " + c2, clr2, InpFontSize, InpFont);
      row++;
     }

   //--- 6. Separator & Baris HARGA RUNNING di tengah
   SetLabel("T_SEP3", x + x0, y + 6 + row * lh, sepLine, InpColorBorder, InpFontSize, InpFont);
   row++;

   string priceText = StringFormat("HARGA RUNNING : %s", DoubleToString(bid, _Digits));
   SetLabel("T_PRICE", x + (int)MathRound(180 * dpiScale), y + 6 + row * lh, priceText, InpColorPrice, InpFontSize, InpFont);
   row++;

   SetLabel("T_SEP4", x + x0, y + 6 + row * lh, sepLine, InpColorBorder, InpFontSize, InpFont);
   row++;

   //--- 7. Tiga baris SUPPORT (SUP 1 terdekat di bawah harga -> SUP 3 terjauh)
   for(int k = 0; k < NUM_SR_LEVELS; k++)
     {
      int supNum = k + 1;
      string sNum = IntegerToString(supNum);
      color clr0, clr1, clr2;
      string c0 = FormatLevelCell(g_supLevel[0][k], bid, refATR, clr0, false);
      string c1 = FormatLevelCell(g_supLevel[1][k], bid, refATR, clr1, false);
      string c2 = FormatLevelCell(g_supLevel[2][k], bid, refATR, clr2, false);

      SetLabel("T_SUP_L"  + sNum, x + x0, y + 6 + row * lh, StringFormat(" SUP %d |", supNum), InpColorSupport, InpFontSize, InpFont);
      SetLabel("T_SUP_C0" + sNum, x + x1, y + 6 + row * lh, " " + c0, clr0, InpFontSize, InpFont);
      SetLabel("T_SUP_C1" + sNum, x + x2, y + 6 + row * lh, "| " + c1, clr1, InpFontSize, InpFont);
      SetLabel("T_SUP_C2" + sNum, x + x3, y + 6 + row * lh, "| " + c2, clr2, InpFontSize, InpFont);
      row++;
     }

   //--- 8. Baris S&D Zone (SUPPLY & DEMAND) — 2 baris jika engine aktif
   if(InpShowSD)
     {
      // Format helper: "TFName: Price (PATTERN ⚡Sx) [★]" atau "       - - -        "
      // Kolom M30 (x1) = placeholder ("- - -"), Kolom H1 (x2) = t=0, Kolom H4 (x3) = t=1
      // Baris 0 = Supply terdekat (di atas harga), Baris 1 = Demand terdekat (di bawah harga)

      // Baris SUPPLY S&D
      string sdResL0 = "       - - -        ", sdResL1 = "       - - -        ";
      color  sdRClr0 = InpColorBorder, sdRClr1 = InpColorBorder;
      for(int t = 0; t < NUM_SD_TF; t++)
        {
         if(g_sdNearestValid[t][1]) // [1] = supply
           {
            SDZone z = g_sdNearest[t][1];
            color c  = z.srConfl ? InpColorSDConf : InpColorSDLabel;
            string confMark = z.srConfl ? (ShortToString(0x2605) + " ") : " ";
            string fvgTag   = z.hasFVG ? "+FVG" : "";
            string cell = StringFormat("%s%s %s(%s%.1fx)%s",
                          confMark, DoubleToString(z.mid, _Digits),
                          SDPatternName(z.pattern), ShortToString(0x26A1), z.strength, fvgTag);
            if(t == 0) { sdResL0 = cell; sdRClr0 = c; }
            else       { sdResL1 = cell; sdRClr1 = c; }
           }
        }
      SetLabel("T_SD_RES_L", x + x0,  y + 6 + row * lh, "[S&D] S|", InpColorSupplyBdr, InpFontSize, InpFont);
      SetLabel("T_SD_RES_0", x + x1,  y + 6 + row * lh, "        - - -       ", InpColorBorder, InpFontSize - 1, InpFont);
      SetLabel("T_SD_RES_1", x + x2,  y + 6 + row * lh, "| " + sdResL0, sdRClr0, InpFontSize - 1, InpFont);
      SetLabel("T_SD_RES_2", x + x3,  y + 6 + row * lh, "| " + sdResL1, sdRClr1, InpFontSize - 1, InpFont);
      row++;

      // Baris DEMAND S&D
      string sdSupL0 = "       - - -        ", sdSupL1 = "       - - -        ";
      color  sdDClr0 = InpColorBorder, sdDClr1 = InpColorBorder;
      for(int t = 0; t < NUM_SD_TF; t++)
        {
         if(g_sdNearestValid[t][0]) // [0] = demand
           {
            SDZone z = g_sdNearest[t][0];
            color c  = z.srConfl ? InpColorSDConf : InpColorSDLabel;
            string confMark = z.srConfl ? (ShortToString(0x2605) + " ") : " ";
            string fvgTag   = z.hasFVG ? "+FVG" : "";
            string cell = StringFormat("%s%s %s(%s%.1fx)%s",
                          confMark, DoubleToString(z.mid, _Digits),
                          SDPatternName(z.pattern), ShortToString(0x26A1), z.strength, fvgTag);
            if(t == 0) { sdSupL0 = cell; sdDClr0 = c; }
            else       { sdSupL1 = cell; sdDClr1 = c; }
           }
        }
      SetLabel("T_SD_SUP_L", x + x0,  y + 6 + row * lh, "[S&D] D|", InpColorDemandBdr, InpFontSize, InpFont);
      SetLabel("T_SD_SUP_0", x + x1,  y + 6 + row * lh, "        - - -       ", InpColorBorder, InpFontSize - 1, InpFont);
      SetLabel("T_SD_SUP_1", x + x2,  y + 6 + row * lh, "| " + sdSupL0, sdDClr0, InpFontSize - 1, InpFont);
      SetLabel("T_SD_SUP_2", x + x3,  y + 6 + row * lh, "| " + sdSupL1, sdDClr1, InpFontSize - 1, InpFont);
      row++;
     }
   else
     {
      ObjectDelete(0, OBJ_PREFIX + "T_SD_SUP_L"); ObjectDelete(0, OBJ_PREFIX + "T_SD_SUP_0");
      ObjectDelete(0, OBJ_PREFIX + "T_SD_SUP_1"); ObjectDelete(0, OBJ_PREFIX + "T_SD_SUP_2");
      ObjectDelete(0, OBJ_PREFIX + "T_SD_RES_L"); ObjectDelete(0, OBJ_PREFIX + "T_SD_RES_0");
      ObjectDelete(0, OBJ_PREFIX + "T_SD_RES_1"); ObjectDelete(0, OBJ_PREFIX + "T_SD_RES_2");
     }

   //--- 9. Separator penutup bawah
   SetLabel("T_SEP5", x + x0, y + 6 + row * lh, sepLine, InpColorBorder, InpFontSize, InpFont);
   row++;

   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| EVENT HANDLER: Klik tombol minimize [-]/[+] & toggle [S&R]/[S&D] |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      if(sparam == OBJ_PREFIX + "BTN_MIN")
        {
         g_panelCollapsed = !g_panelCollapsed;
         UpdateDashboard();
         ChartRedraw();
        }
      else if(sparam == OBJ_PREFIX + "BTN_SR")
        {
         g_showSR = !g_showSR;
         if(g_showSR) DrawNearestZones();
         else         ObjectsDeleteAll(0, OBJ_PREFIX + "Z_");
         UpdateDashboard();
         ChartRedraw();
        }
      else if(sparam == OBJ_PREFIX + "BTN_SD")
        {
         g_showSD = !g_showSD;
         if(g_showSD) DrawSDZones();
         else
           {
            ObjectsDeleteAll(0, OBJ_PREFIX + "SD_");
            ObjectsDeleteAll(0, OBJ_PREFIX + "FVG_");
           }
         UpdateDashboard();
         ChartRedraw();
        }
     }
  }

//+------------------------------------------------------------------+
//| ALERT: notifikasi sekali per zona saat harga masuk zona          |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| ALERT ENGINE: helper cooldown & push notification multi-channel  |
//+------------------------------------------------------------------+
bool CanTriggerAlert(const string key, const int cooldownMins)
  {
   datetime now = TimeCurrent();
   int total = ArraySize(g_alertHistory);

   for(int i = 0; i < total; i++)
     {
      if(g_alertHistory[i].key == key)
        {
         if(now - g_alertHistory[i].lastTime < cooldownMins * 60)
            return(false); // Masih dalam masa cooldown

         g_alertHistory[i].lastTime = now;
         return(true);
        }
     }

   // Belum pernah terpicu, masukkan ke riwayat
   ArrayResize(g_alertHistory, total + 1);
   g_alertHistory[total].key = key;
   g_alertHistory[total].lastTime = now;

   // Bersihkan riwayat lama jika sudah > 50 entri untuk hemat memori
   if(total > 50)
     {
      int newSize = 0;
      for(int i = 0; i < ArraySize(g_alertHistory); i++)
        {
         if(now - g_alertHistory[i].lastTime < 7200) // simpan < 2 jam
           {
            g_alertHistory[newSize] = g_alertHistory[i];
            newSize++;
           }
        }
      ArrayResize(g_alertHistory, newSize);
     }

   return(true);
  }

void FireAlert(const string msg)
  {
   Print(msg);

   if(InpAlertTerminal)
      Alert(msg);

   if(InpAlertMobile)
     {
      if(!SendNotification(msg))
        {
         Print("SRD: Push notification gagal terkirim (cek MetaQuotes ID di Tools->Options->Notifications). Error: ", GetLastError());
        }
     }
  }

//+------------------------------------------------------------------+
//| ALERT ENGINE: deteksi sentuhan level S&R / S&D + smart filter    |
//+------------------------------------------------------------------+
void CheckAlerts()
  {
   if(!InpAlertTouch || (!InpAlertTerminal && !InpAlertMobile))
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   //--- 1. Cek Zona S&R
   if(InpAlertSR)
     {
      for(int t = 0; t < NUM_SR_TF; t++)
        {
         int nZones = ArraySize(g_zones_tf[t].zones);
         for(int i = 0; i < nZones; i++)
           {
            SRZone z = g_zones_tf[t].zones[i];
            if(bid >= z.bottom && bid <= z.top)
              {
               // Cari confluence & total touches untuk level ini
               int conf = 1;
               int totT = z.touches;
               for(int k = 0; k < NUM_SR_LEVELS; k++)
                 {
                  if(z.isSupport && g_supLevel[t][k].valid && MathAbs(g_supLevel[t][k].price - z.mid) < _Point)
                    {
                     conf = g_supLevel[t][k].confluence;
                     totT = g_supLevel[t][k].totalTouches;
                     break;
                    }
                  else if(!z.isSupport && g_resLevel[t][k].valid && MathAbs(g_resLevel[t][k].price - z.mid) < _Point)
                    {
                     conf = g_resLevel[t][k].confluence;
                     totT = g_resLevel[t][k].totalTouches;
                     break;
                    }
                 }

               // Cek apakah termasuk Level Terkuat
               bool isStrongest = false;
               if(z.isSupport)
                 {
                  for(int s = 0; s < 2; s++)
                     if(g_strongSupTF[s] == t && g_strongSupLvl[s] >= 0 &&
                        MathAbs(g_supLevel[t][g_strongSupLvl[s]].price - z.mid) < _Point)
                        isStrongest = true;
                 }
               else
                 {
                  for(int r = 0; r < 2; r++)
                     if(g_strongResTF[r] == t && g_strongResLvl[r] >= 0 &&
                        MathAbs(g_resLevel[t][g_strongResLvl[r]].price - z.mid) < _Point)
                        isStrongest = true;
                 }

               // Smart Filter: jika aktif, hanya picu jika Confluence >= 3 atau Level Terkuat
               if(InpAlertOnlyStrongest && !isStrongest && conf < 3)
                  continue;

               string key = "SR_" + g_srTFName[t] + "_" + (z.isSupport ? "SUP_" : "RES_") + DoubleToString(z.mid, _Digits);
               if(CanTriggerAlert(key, InpAlertCooldownMins))
                 {
                  string side      = z.isSupport ? "SUPPORT" : "RESISTANCE";
                  string starTag   = (conf >= 3 ? " ★★★" : (conf == 2 ? " ★★" : ""));
                  string strongTag = isStrongest ? " [TERKUAT]" : "";
                  string msg       = StringFormat("SRD [%s]: [%s] Harga sentuh %s @ %s (%dx%s)%s",
                                                  _Symbol, g_srTFName[t], side,
                                                  DoubleToString(z.mid, _Digits), totT, starTag, strongTag);
                  FireAlert(msg);
                 }
              }
           }
        }
     }

   //--- 2. Cek Zona S&D (Supply & Demand)
   if(InpAlertSD && InpShowSD)
     {
      for(int t = 0; t < NUM_SD_TF; t++)
        {
         int nSD = ArraySize(g_sdZones[t].zones);
         for(int i = 0; i < nSD; i++)
           {
            SDZone sdz = g_sdZones[t].zones[i];
            if(sdz.status == SD_CONSUMED)
               continue;

            if(bid >= sdz.bottom && bid <= sdz.top)
              {
               // Cek apakah ini salah satu dari S&D Terkuat
               bool isStrongestSD = false;
               if(sdz.isDemand && g_strongSDDemandTF == t && g_sdNearestValid[t][0] &&
                  MathAbs(g_sdNearest[t][0].mid - sdz.mid) < _Point)
                  isStrongestSD = true;
               else if(!sdz.isDemand && g_strongSDSupplyTF == t && g_sdNearestValid[t][1] &&
                  MathAbs(g_sdNearest[t][1].mid - sdz.mid) < _Point)
                  isStrongestSD = true;

               // Smart Filter: jika aktif, hanya picu jika Fresh DAN (Terkuat atau Confluence S&R+S&D atau memiliki FVG atau Strength >= 2.0)
               if(InpAlertOnlyStrongest)
                 {
                  if(sdz.status != SD_FRESH)
                     continue;
                  if(!isStrongestSD && !sdz.srConfl && !sdz.hasFVG && sdz.strength < 2.0)
                     continue;
                 }

               string key = "SD_" + g_sdTFName[t] + "_" + (sdz.isDemand ? "DEM_" : "SUP_") + DoubleToString(sdz.mid, _Digits);
               if(CanTriggerAlert(key, InpAlertCooldownMins))
                 {
                  string typeStr   = sdz.isDemand ? "DEMAND" : "SUPPLY";
                  string patStr    = (sdz.pattern == SD_RBR ? "RBR" : (sdz.pattern == SD_DBD ? "DBD" : (sdz.pattern == SD_DBR ? "DBR" : "RBD")));
                  string statStr   = (sdz.status == SD_FRESH ? "Fresh" : "Tested");
                  string conflTag    = sdz.srConfl ? " ★S&R+S&D" : "";
                  string fvgAlertTag = sdz.hasFVG ? " [+FVG]" : "";
                  string strongTag   = isStrongestSD ? " [TERKUAT]" : "";
                  string msg         = StringFormat("SRD [%s]: [%s] Harga sentuh %s %s @ %s (%s ⚡%.1fx%s%s)%s",
                                                    _Symbol, g_sdTFName[t], typeStr, patStr,
                                                    DoubleToString(sdz.mid, _Digits), statStr, sdz.strength, conflTag, fvgAlertTag, strongTag);
                  FireAlert(msg);
                 }
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| INIT: buat semua handle indikator & inisialisasi instan          |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Inisialisasi state toggle chart dari input (bisa diubah lagi via tombol panel saat runtime)
   g_showSR = InpShowZones;
   g_showSD = InpShowSDZonesInit;

   // Inisialisasi daftar timeframe S&R
   g_srTF[0] = InpSR_TF1;
   g_srTF[1] = InpSR_TF2;
   g_srTF[2] = InpSR_TF3;

   for(int t = 0; t < NUM_SR_TF; t++)
      g_srTFName[t] = TFToString(g_srTF[t]);

   // Inisialisasi daftar timeframe S&D
   g_sdTF[0] = InpSD_TF1;
   g_sdTF[1] = InpSD_TF2;
   for(int t = 0; t < NUM_SD_TF; t++)
     {
      g_sdTFName[t] = TFToString(g_sdTF[t]);
      g_sdNearestValid[t][0] = false;
      g_sdNearestValid[t][1] = false;
     }

   // Handle trend (D1, H4, H1)
   for(int i = 0; i < 3; i++)
     {
      hEma[i] = iMA(_Symbol, g_tf[i], InpTrendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(hEma[i] == INVALID_HANDLE)
        {
         Print("SRD: gagal membuat handle EMA ", g_tfName[i]);
         return(INIT_FAILED);
        }
      hAdx[i] = InpUseADX ? iADX(_Symbol, g_tf[i], InpADX_Period) : INVALID_HANDLE;
      hRsi[i] = InpUseRSI ? iRSI(_Symbol, g_tf[i], InpRSI_Period, PRICE_CLOSE) : INVALID_HANDLE;
     }

   // Handle ATR untuk 3 TF S&R Matrix
   for(int t = 0; t < NUM_SR_TF; t++)
     {
      hSR_ATR[t] = iATR(_Symbol, g_srTF[t], 14);
      if(hSR_ATR[t] == INVALID_HANDLE)
        {
         Print("SRD: gagal membuat handle ATR untuk ", g_srTFName[t]);
         return(INIT_FAILED);
        }
     }

   // Handle ATR untuk 2 TF S&D Engine
   for(int t = 0; t < NUM_SD_TF; t++)
     {
      hSD_ATR[t] = iATR(_Symbol, g_sdTF[t], 14);
      if(hSD_ATR[t] == INVALID_HANDLE)
        {
         Print("SRD: gagal membuat handle ATR S&D untuk ", g_sdTFName[t]);
         return(INIT_FAILED);
        }
     }

   // Bersihkan chart dari label-label lama
   ObjectsDeleteAll(0, OBJ_PREFIX);

   IndicatorSetString(INDICATOR_SHORTNAME, "SRD (S&R + S&D + Confluence)");
   g_lastBarTime    = 0;
   g_logLastH1Bar   = 0; // logger mulai fresh tiap attach
   g_logHeaderDone  = false;
   g_logFileName    = "";
   ArrayFree(g_alertHistory);
   g_panelCollapsed = false;

   // Eksekusi kalkulasi instan di awal (tidak perlu menunggu tick pertama)
   UpdateTrends();
   RecomputeZones();
   UpdateDashboard();

   // Fallback timer 1 detik untuk mengunduh history multi-TF jika pasar libur/tanpa tick
   EventSetTimer(1);
   g_timerActive = true;
   g_timerCount  = 0;

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| DEINIT: bersihkan semua objek & handle                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Comment("");

   if(g_timerActive)
     {
      EventKillTimer();
      g_timerActive = false;
     }

   ObjectsDeleteAll(0, OBJ_PREFIX);
   ChartRedraw();
   ArrayFree(g_alertHistory);

   for(int t = 0; t < NUM_SR_TF; t++)
     {
      if(hSR_ATR[t] != INVALID_HANDLE)
         IndicatorRelease(hSR_ATR[t]);
     }
   for(int t = 0; t < NUM_SD_TF; t++)
     {
      if(hSD_ATR[t] != INVALID_HANDLE)
         IndicatorRelease(hSD_ATR[t]);
     }
   for(int i = 0; i < 3; i++)
     {
      if(hEma[i] != INVALID_HANDLE)
         IndicatorRelease(hEma[i]);
      if(hAdx[i] != INVALID_HANDLE)
         IndicatorRelease(hAdx[i]);
      if(hRsi[i] != INVALID_HANDLE)
         IndicatorRelease(hRsi[i]);
     }
  }

//+------------------------------------------------------------------+
//| TIMER: fallback update saat pasar tanpa tick                     |
//+------------------------------------------------------------------+
void OnTimer()
  {
   g_timerCount++;

   UpdateTrends();
   RecomputeZones();
   UpdateDashboard();

   // Cek apakah data multi-TF sudah lengkap
   bool ready = true;
   if(g_trend[0].adx == 0.0 || g_trend[1].adx == 0.0)
      ready = false;

   for(int t = 0; t < NUM_SR_TF; t++)
     {
      if(!g_resLevel[t][0].valid && !g_supLevel[t][0].valid)
        {
         ready = false;
         break;
        }
     }

   // Jika data sudah lengkap terisi atau sudah mencoba 10 detik, matikan timer
   if(ready || g_timerCount >= 10)
     {
      EventKillTimer();
      g_timerActive = false;
     }
  }

//+------------------------------------------------------------------+
//| MAIN: recompute per bar baru / saat data MTF belum terisi        |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(rates_total < 60)
      return(prev_calculated);

   datetime curBar = time[rates_total - 1];

   //--- Cek apakah data multi-TF sudah siap atau masih ada yang kosong
   bool needRecompute = false;
   if(curBar != g_lastBarTime)
     {
      needRecompute = true;
     }
   else
     {
      // Retry jika indikator baru di-attach dan MT5 belum selesai mengunduh data TF lain
      if(g_trend[0].adx == 0.0 || g_trend[1].adx == 0.0)
         needRecompute = true;

      for(int t = 0; t < NUM_SR_TF; t++)
        {
         if(!g_resLevel[t][0].valid && !g_supLevel[t][0].valid)
           {
            needRecompute = true;
            break;
           }
        }
     }

   if(needRecompute)
     {
      g_lastBarTime = curBar;
      UpdateTrends();     // arah tren D1/H4/H1
      RecomputeZones();   // scan ulang S&R matrix + confluence + S&D + level terkuat
     }

   UpdateDashboard();
   CheckAlerts();
   LoggerMaybeSnapshot(); // Fase Agent-1: snapshot CSV per bar baru H1 (gated InpEnableLogger)

   return(rates_total);
  }
//+------------------------------------------------------------------+