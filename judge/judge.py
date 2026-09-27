"""SRD Multi-Agent Judge v1 — Fase 2 (agent_TF.md Bab 6).
Kunci: clock H1, entry market open N+1, TP2 level TF sama fallback 2R,
expiry 24/24/48 jam. CSV: SRD_Indi_signals_YYYYMMDD.csv (24 kolom).
Pakai: py judge.py --signals signals.csv --ohlc ohlc_h1.csv --out out
OHLC: time_utc,symbol,timeframe,open,high,low,close.
"""
import argparse, csv, os
from collections import defaultdict
from datetime import datetime, timedelta
SL_BUFFER_ATR = 0.20
TOUCH_TOL_ATR = 0.10
TOUCH_TOL_MIN_PT = 15
COST_PT = 50.0
PT_FALLBACK = 0.01

def pt(s):
    s = s.strip()
    for f in ("%Y.%m.%d %H:%M:%S", "%Y.%m.%d %H:%M",
              "%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M"):
        try: return datetime.strptime(s, f)
        except ValueError: pass
    raise ValueError("waktu: %s" % s)

def load_signals(path):
    rows = []
    with open(path, newline="", encoding="utf-8-sig") as f:
        rd = csv.DictReader(f)
        for r in rd:
            try:
                rows.append({"t": pt(r["time_utc"]), "symbol": r["symbol"],
                    "agent": r["agent_tf"], "side": r["side"],
                    "rank": int(r["rank_jarak"]), "price": float(r["price"]),
                    "touches": int(float(r["touches"])),
                    "conf": int(float(r["confluence"])),
                    "totalT": int(float(r["totalTouches"])),
                    "strong": int(float(r["isStrongest"])),
                    "strongRank": int(float(r["isStrongestRank"])),
                    "sdO": int(float(r["sdOverlap"])),
                    "fvg": int(float(r["hasFVG"])), "sdS": r["sdStatus"],
                    "sweep": int(float(r["sweepAtSignal"])),
                    "trend": r["trendCtx"], "bid": float(r["bid"]),
                    "ask": float(r["ask"]), "spread": float(r["spread_pt"]),
                    "atr": float(r["atr_tf"]), "distATR": float(r["distATR"]),
                    "expiryH": int(float(r["expiry_hours"]))})
            except (ValueError, KeyError): continue
    rows.sort(key=lambda x: x["t"])
    return rows

def load_ohlc(path):
    bars = defaultdict(list)
    with open(path, newline="", encoding="utf-8-sig") as f:
        rd = csv.DictReader(f)
        for r in rd:
            try:
                tc = r["time_utc"] if "time_utc" in r else r["time"]
                bars[(r["symbol"], r.get("timeframe", "H1"))].append(
                    {"t": pt(tc), "o": float(r["open"]),
                     "h": float(r["high"]), "l": float(r["low"]),
                     "c": float(r["close"])})
            except (ValueError, KeyError): continue
    for k in bars: bars[k].sort(key=lambda x: x["t"])
    return bars

def idx_after(bars, t):
    lo, hi = 0, len(bars)
    while lo < hi:
        m = (lo + hi) // 2
        if bars[m]["t"] <= t: lo = m + 1
        else: hi = m
    return lo

def mk(s, eT, xT, e, sl, tp1, tp2, label, r):
    d = dict(s)
    xs = xT.strftime("%Y-%m-%d %H:%M:%S") if hasattr(xT, "strftime") else str(xT)
    d.update(entry_t=eT.strftime("%Y-%m-%d %H:%M:%S"), exit_t=xs,
             entry=round(e, 5), sl=round(sl, 5), tp1=round(tp1, 5),
             tp2=round(tp2, 5), label=label, r=round(r, 3))
    return d

def judge(signals, ohlc, pmap):
    trades = []
    bySnap = defaultdict(list)
    for c in signals:
        bySnap[(c["t"], c["symbol"], c["agent"])].append(c)
    for s in signals:
        key = (s["symbol"], "H1")
        bars = ohlc.get(key)
        if not bars:
            bars = next((v for k, v in ohlc.items()
                         if k[0].split(".")[0] == s["symbol"].split(".")[0]), None)
        if not bars: continue
        i0 = idx_after(bars, s["t"])
        if i0 >= len(bars): continue
        point = pmap.get(s["symbol"], PT_FALLBACK)
        tol = max(TOUCH_TOL_ATR * s["atr"], TOUCH_TOL_MIN_PT * point)
        end = s["t"] + timedelta(hours=s["expiryH"])
        isBuy = (s["side"] == "SUP")
        cost = (s["spread"] + COST_PT) * point
        touched, entry = False, None
        for i in range(i0, len(bars)):
            b = bars[i]
            if b["t"] > end: break
            if entry is None:
                hit = (abs(b["h"] - s["price"]) <= tol or
                       abs(b["l"] - s["price"]) <= tol or
                       (b["l"] <= s["price"] <= b["h"]))
                if not hit: continue
                touched = True
                ni = i + 1
                if ni >= len(bars): break
                e = bars[ni]["o"] + (cost if isBuy else 0.0)
                buf = SL_BUFFER_ATR * s["atr"]
                sl = (s["price"] - buf - cost) if isBuy else (s["price"] + buf + cost)
                risk = (e - sl) if isBuy else (sl - e)
                if risk <= 0: break
                tp1 = (e + risk) if isBuy else (e - risk)
                tp2 = None
                for c in bySnap.get((s["t"], s["symbol"], s["agent"]), []):
                    if c["side"] != ("RES" if isBuy else "SUP"): continue
                    if c["price"] == s["price"]: continue
                    px = c["price"]
                    if (isBuy and px > e) or ((not isBuy) and px < e):
                        if tp2 is None or abs(px - e) < abs(tp2 - e): tp2 = px
                if tp2 is None: tp2 = (e + 2 * risk) if isBuy else (e - 2 * risk)
                entry = (e, sl, risk, tp1, tp2, bars[ni]["t"])
            else:
                e, sl, risk, tp1, tp2, eT = entry
                slH = (b["l"] <= sl) if isBuy else (b["h"] >= sl)
                t1H = (b["h"] >= tp1) if isBuy else (b["l"] <= tp1)
                t2H = (b["h"] >= tp2) if isBuy else (b["l"] <= tp2)
                if slH and t1H: t1H = False
                if slH:
                    trades.append(mk(s, eT, b["t"], e, sl, tp1, tp2, "LOSE", -1.0))
                    entry = "done"; break
                if t2H:
                    trades.append(mk(s, eT, b["t"], e, sl, tp1, tp2, "WIN_TP2", abs(tp2 - e) / risk))
                    entry = "done"; break
                if t1H:
                    trades.append(mk(s, eT, b["t"], e, sl, tp1, tp2, "WIN_TP1", 1.0))
                    entry = "done"; break
        if entry is None and not touched: continue
        if entry is not None and entry != "done":
            e, sl, risk, tp1, tp2, eT = entry
            trades.append(mk(s, eT, end, e, sl, tp1, tp2, "TIMEOUT", -cost / max(risk, 1e-9)))
    return trades
def summarize(trades):
    g = defaultdict(list)
    for t in trades: g[(t["agent"], t["side"], t["rank"])].append(t)
    out = []
    for k in sorted(g):
        ts = g[k]; n = len(ts)
        w = sum(1 for x in ts if x["label"].startswith("WIN"))
        w1 = sum(1 for x in ts if x["label"] == "WIN_TP1")
        w2 = sum(1 for x in ts if x["label"] == "WIN_TP2")
        lo = sum(1 for x in ts if x["label"] == "LOSE")
        to = sum(1 for x in ts if x["label"] == "TIMEOUT")
        avgR = sum(x["r"] for x in ts) / n
        wp = [x["r"] for x in ts if x["r"] > 0]
        lp = [-x["r"] for x in ts if x["r"] <= 0]
        pf = (sum(wp) / sum(lp)) if lp and sum(lp) > 0 else 0.0
        out.append({"agent": k[0], "side": k[1], "rank": k[2], "n": n,
            "hit_pct": round(100.0 * w / n, 1), "win_tp1": w1,
            "win_tp2": w2, "lose": lo, "timeout": to,
            "avg_R": round(avgR, 3), "expectancy_R": round(avgR, 3),
            "profit_factor": round(pf, 2)})
    return out

def sfilter(trades, fn):
    g = defaultdict(list)
    for t in trades: g[fn(t)].append(t)
    out = []
    for k in sorted(g, key=str):
        ts = g[k]; n = len(ts)
        w = sum(1 for x in ts if x["label"].startswith("WIN"))
        out.append({"filter": k, "n": n,
            "hit_pct": round(100.0 * w / n, 1),
            "avg_R": round(sum(x["r"] for x in ts) / n, 3)})
    return out

def wcsv(path, rows, fields):
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        w.writeheader(); w.writerows(rows)

def main():
    ap = argparse.ArgumentParser(description="SRD judge v1")
    ap.add_argument("--signals", required=True)
    ap.add_argument("--ohlc", required=True)
    ap.add_argument("--out", default="judge/out")
    ap.add_argument("--point", default="")
    a = ap.parse_args()
    pmap = {}
    if a.point:
        for kv in a.point.split(","):
            if ":" in kv:
                k, v = kv.split(":", 1); pmap[k.strip()] = float(v)
    sig = load_signals(a.signals); ohl = load_ohlc(a.ohlc)
    tr = judge(sig, ohl, pmap)
    os.makedirs(a.out, exist_ok=True)
    tf = ["t", "symbol", "agent", "side", "rank", "price", "touches",
          "conf", "totalT", "strong", "strongRank", "sdO", "fvg",
          "sdS", "sweep", "trend", "bid", "ask", "spread", "atr",
          "distATR", "expiryH", "entry_t", "exit_t", "entry", "sl",
          "tp1", "tp2", "label", "r"]
    for t in tr: t["t"] = t["t"].strftime("%Y-%m-%d %H:%M:%S")
    wcsv(os.path.join(a.out, "trades.csv"), tr, tf)
    sm = summarize(tr)
    wcsv(os.path.join(a.out, "summary_agent.csv"), sm,
         ["agent", "side", "rank", "n", "hit_pct", "win_tp1",
          "win_tp2", "lose", "timeout", "avg_R", "expectancy_R",
          "profit_factor"])
    fl = []
    fl += sfilter(tr, lambda x: "conf=%d" % x["conf"])
    fl += sfilter(tr, lambda x: "strong=%d" % x["strong"])
    fl += sfilter(tr, lambda x: "fvg=%d" % x["fvg"])
    fl += sfilter(tr, lambda x: "agent=%s" % x["agent"])
    fl += sfilter(tr, lambda x: "rank=%d" % x["rank"])
    wcsv(os.path.join(a.out, "summary_filter.csv"), fl,
         ["filter", "n", "hit_pct", "avg_R"])
    print("signals=%d trades=%d no_trade=%d" % (len(sig), len(tr), max(len(sig) - len(tr), 0)))
    print("out: %s" % a.out)
    for s in sm:
        print("%(agent)s %(side)s rank%(rank)d n=%(n)d hit=%(hit_pct)s%% avgR=%(avg_R)s PF=%(profit_factor)s" % s)
    if len(tr) < 100: print("WARN: n<100 — butuh 2-3 thn data H4.")

if __name__ == "__main__": main()

