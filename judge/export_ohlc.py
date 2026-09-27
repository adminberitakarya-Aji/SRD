"""Export OHLC M30/H1/H4 XAUUSD dari terminal MT5 lokal ke CSV judge.
Butuh MT5 terbuka + login broker dgn history XAUUSD 2022-2024.
Pakai: py judge/export_ohlc.py --symbol XAUUSD --out judge/ohlc_xauusd.csv [--years 3]
Keluar kolom: time_utc,symbol,timeframe,open,high,low,close (UTC server MT5).
"""
import argparse
from datetime import datetime, timedelta
import MetaTrader5 as mt5

TFMAP = {"M30": mt5.TIMEFRAME_M30, "H1": mt5.TIMEFRAME_H1,
         "H4": mt5.TIMEFRAME_H4}

def main():
    ap = argparse.ArgumentParser(description="Export OHLC MT5")
    ap.add_argument("--symbol", default="XAUUSD")
    ap.add_argument("--out", default="judge/ohlc_xauusd.csv")
    ap.add_argument("--years", type=int, default=3)
    a = ap.parse_args()
    if not mt5.initialize():
        raise SystemExit("mt5.initialize gagal: %s" % (mt5.last_error(),))
    end = datetime.now() + timedelta(days=1)
    start = datetime(end.year - a.years, 1, 1)
    n = 0
    with open(a.out, "w", encoding="utf-8") as f:
        f.write("time_utc,symbol,timeframe,open,high,low,close\n")
        for tf, code in TFMAP.items():
            rates = mt5.copy_rates_range(a.symbol, code, start, end)
            if rates is None:
                print("WARN %s %s: %s" % (a.symbol, tf, mt5.last_error()))
                continue
            for r in rates:
                t = datetime.fromtimestamp(int(r["time"]))
                f.write("%s,%s,%s,%s,%s,%s,%s\n" % (
                    t.strftime("%Y-%m-%d %H:%M:%S"), a.symbol, tf,
                    r["open"], r["high"], r["low"], r["close"]))
                n += 1
            print("%s %s: %d bar" % (a.symbol, tf, len(rates)))
    mt5.shutdown()
    print("total=%d -> %s" % (n, a.out))

if __name__ == "__main__": main()
