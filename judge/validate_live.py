"""Validator CSV logger live SRD_Indi v2.60 (Fase 5 live-test).
Cek: header 24 kolom Bab 5, <=18 baris/snapshot, version tag, tag S&D,
tren, Concertina S&D skor (Fresh+FVG share), dan kesiapan judge.
Pakai: python judge/validate_live.py --signals SRD_Indi_signals_20260928.csv
"""
import argparse, csv
from collections import Counter
COLS = "time_utc,symbol,clock_tf,agent_tf,side,rank_jarak,price,touches,confluence,totalTouches,isStrongest,isStrongestRank,sdOverlap,hasFVG,sdStatus,sweepAtSignal,trendCtx,bid,ask,spread_pt,atr_tf,distATR,expiry_hours,version".split(",")
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--signals", required=True)
    a = ap.parse_args()
    rows = list(csv.DictReader(open(a.signals, encoding="utf-8-sig")))
    print("rows:", len(rows))
    if not rows: print("FAIL: kosong"); return
    hdr = rows[0].keys()
    miss = [c for c in COLS if c not in hdr]
    print("header:", "OK 24 kolom" if not miss else "FAIL kurang %s" % miss)
    by = Counter((r["time_utc"], r["symbol"]) for r in rows)
    mx = max(by.values()); mn = min(by.values())
    print("snapshots:", len(by), "rows/snap max/min:", mx, mn)
    print("CHECK <=18/snap:", "OK" if mx <= 18 else "FAIL (>18)")
    print("version:", Counter(r["version"] for r in rows))
    print("sdStatus:", Counter(r["sdStatus"] for r in rows))
    print("hasFVG:", Counter(r["hasFVG"] for r in rows))
    print("isStrongest:", Counter(r["isStrongest"] for r in rows))
    print("agent:", Counter(r["agent_tf"] for r in rows))
    print("trend sample:", Counter(r["trendCtx"] for r in rows).most_common(3))
    f = [r for r in rows if r["sdStatus"] == "Fresh" and r["hasFVG"] == "1"]
    print("Fresh+FVG share: %d / %d = %.2f%%" % (len(f), len(rows), 100.0*len(f)/len(rows)))
    bad = [r for r in rows if r["sdStatus"] not in ("Fresh", "Tested", "None")]
    print("sdStatus valid:", "OK" if not bad else "FAIL %d" % len(bad))
    print("NEXT: judge.py --signals <ini> --ohlc ohlc.csv --out out_live")
if __name__ == "__main__": main()
