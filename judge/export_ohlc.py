"""Export OHLC M30/H1/H4/D1 XAUUSD dari terminal MT5 lokal ke CSV judge.
Pakai: py judge/export_ohlc.py --symbol XAUUSD --out judge/ohlc_xauusd.csv [--years 5]
Keluar: time_utc,symbol,timeframe,open,high,low,close.
M30 rawan Invalid params utk range jauh -> fallback per-chunk 6 bulan.
"""
import argparse
from datetime import datetime, timedelta
import MetaTrader5 as mt5

TFMAP = {"M30": mt5.TIMEFRAME_M30, "H1": mt5.TIMEFRAME_H1,
         "H4": mt5.TIMEFRAME_H4, "D1": mt5.TIMEFRAME_D1}

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
    seen = set()
    with open(a.out, "w", encoding="utf-8") as f:
        f.write("time_utc,symbol,timeframe,open,high,low,close\n")
        for tf, code in TFMAP.items():
            rates = None
            try:
                rates = mt5.copy_rates_range(a.symbol, code, start, end)
            except Exception as e:
                print("EXC %s %s: %s" % (a.symbol, tf, e))
            if rates is None or len(rates) == 0:
                print("RETRY %s %s per-chunk 6 bulan" % (a.symbol, tf))
                rates = chunked(a.symbol, code, start, end)
            if rates is None or len(rates) == 0:
                print("SKIP %s %s" % (a.symbol, tf))
                continue
            for r in rates:
                t = datetime.fromtimestamp(int(r["time"]))
                key = (tf, int(r["time"]))
                if key in seen:
                    continue
                seen.add(key)
                f.write("%s,%s,%s,%s,%s,%s,%s\n" % (
                    t.strftime("%Y-%m-%d %H:%M:%S"), a.symbol, tf,
                    r["open"], r["high"], r["low"], r["close"]))
                n += 1
            print("%s %s: %d bar" % (a.symbol, tf, len(rates)))
    mt5.shutdown()
    print("total=%d -> %s" % (n, a.out))


def chunked(symbol, code, start, end):
    import calendar
    out = []
    cur = datetime(start.year, start.month, 1)
    while cur < end:
        nm = cur.month + 6
        ny = cur.year + (nm - 1) // 12
        nm = (nm - 1) % 12 + 1
        nxt = datetime(ny, nm, 1)
        try:
            r = mt5.copy_rates_range(symbol, code, cur, min(nxt, end))
        except Exception as e:
            print("EXC chunk %s: %s" % (cur, e))
            r = None
        if r is not None and len(r) > 0:
            out.extend(r)
        cur = nxt
    if not out:
        return None
    import numpy as np
    arr = np.array(out)
    arr = arr[np.argsort(arr["time"])]
    _, idx = np.unique(arr["time"], return_index=True)
    return arr[np.sort(idx)]

if __name__ == "__main__": main()
