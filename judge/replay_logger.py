"""Replay logger SRD_Indi murni Python (tanpa MT5) utk Fase 3.
Meniru engine v2.51: fractal swing -> cluster ATR -> touches ->
3 RES/SUP terdekat -> confluence -> TERKUAT -> snapshot 18/jam.
Pakai: py judge/replay_logger.py --ohlc ohlc_xauusd.csv --out signals_replay.csv
"""
import argparse, csv
from collections import defaultdict
from datetime import datetime
MERGE_ATR = 0.30
MINTHICK_ATR = 0.15
CONF_TOL_ATR = 0.25
SCAN = 300
MINTOUCH = 1
LOOK = {30: 4, 60: 4, 240: 3}

def pt(s):
    for f in ("%Y-%m-%d %H:%M:%S", "%Y.%m.%d %H:%M:%S", "%Y.%m.%d %H:%M"):
        try: return datetime.strptime(s.strip(), f)
        except ValueError: pass
    raise ValueError(s)

def atr(bars, i, p=14):
    if i < p: return 0.0
    s = 0.0
    for k in range(i - p + 1, i + 1):
        h, l, pc = bars[k][2], bars[k][3], bars[k - 1][4]
        s += max(h - l, abs(h - pc), abs(l - pc))
    return s / p

def swings(bars, lb, n=300):
    # bars kronologis lama->baru; bar terbaru = index TERAKHIR.
    # Scan n bar terakhir; perlu lb bar kanan utk konfirmasi fractal.
    out = []
    hi = len(bars) - lb - 1
    lo = max(lb, hi - n)
    for i in range(lo, hi + 1):
        h, l = bars[i][2], bars[i][3]
        sh = all(bars[i - k][2] <= h for k in range(1, lb + 1)) and all(bars[i + k][2] < h for k in range(1, lb + 1))
        sl = all(bars[i - k][3] >= l for k in range(1, lb + 1)) and all(bars[i + k][3] > l for k in range(1, lb + 1))
        if sh or sl: out.append((h if sh else l, i))
    return out

def build(bars, upto, tfmin, bid):
    a = atr(bars, upto)
    if a <= 0: return ([], []), 0.0
    lb = LOOK.get(tfmin, 3)
    sw = swings(bars[:upto + 1], lb)
    used = [False] * len(sw)
    zones = []
    for i, (p, bi) in enumerate(sw):
        if used[i]: continue
        used[i] = True
        top = bot = p
        for j in range(i + 1, len(sw)):
            if used[j]: continue
            if abs(sw[j][0] - p) <= MERGE_ATR * a:
                used[j] = True
                top = max(top, sw[j][0]); bot = min(bot, sw[j][0])
        if top - bot < MINTHICK_ATR * a:
            mid = (top + bot) / 2; top = mid + MINTHICK_ATR * a / 2; bot = mid - MINTHICK_ATR * a / 2
        tc = 0; prev = False
        for k in range(max(0, upto - SCAN), upto + 1):
            inn = bars[k][2] >= bot and bars[k][3] <= top
            if inn and not prev: tc += 1
            prev = inn
        if tc < MINTOUCH: continue
        zones.append({"mid": (top + bot) / 2, "t": tc, "sup": bid > (top + bot) / 2})
    sup = sorted([z for z in zones if z["sup"]], key=lambda z: abs(z["mid"] - bid))[:3]
    res = sorted([z for z in zones if not z["sup"]], key=lambda z: abs(z["mid"] - bid))[:3]
    return (sup, res), a
def main():
    import argparse, bisect
    ap = argparse.ArgumentParser()
    ap.add_argument("--ohlc", required=True)
    ap.add_argument("--symbol", default="XAUUSD.vxc")
    ap.add_argument("--out", default="judge/signals_replay.csv")
    ap.add_argument("--from-date", default="")
    ap.add_argument("--to-date", default="")
    ap.add_argument("--step", type=int, default=1)
    a = ap.parse_args()
    data = defaultdict(list)
    with open(a.ohlc, encoding="utf-8-sig") as f:
        for r in csv.DictReader(f):
            if r["symbol"] != a.symbol: continue
            data[r["timeframe"]].append((pt(r["time_utc"]), float(r["open"]), float(r["high"]), float(r["low"]), float(r["close"])))
    for k in data: data[k].sort()
    h1 = data.get("H1", [])
    syms = {"M30": data.get("M30", []), "H1": h1, "H4": data.get("H4", [])}
    tlist = {n: [b[0] for b in syms[n]] for n in syms}
    tfs = [("M30", 30, 24), ("H1", 60, 24), ("H4", 240, 48)]
    d0 = pt(a.from_date) if a.from_date else None
    d1 = pt(a.to_date) if a.to_date else None
    rows = 0
    with open(a.out, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow("time_utc,symbol,clock_tf,agent_tf,side,rank_jarak,price,touches,confluence,totalTouches,isStrongest,isStrongestRank,sdOverlap,hasFVG,sdStatus,sweepAtSignal,trendCtx,bid,ask,spread_pt,atr_tf,distATR,expiry_hours,version".split(","))
        for hi in range(14, len(h1), max(a.step, 1)):
            ht, ho, hh, hl, hc = h1[hi]
            if d0 and ht < d0: continue
            if d1 and ht > d1: break
            bid = ask = hc
            lv = {}; aa = {}
            for name, tm, exp in tfs:
                bars = syms[name]
                ui = bisect.bisect_right(tlist[name], ht) - 1
                if ui < 20: lv[name] = ([], []); aa[name] = 0.0; continue
                (sup, res), at = build(bars, ui, tm, bid)
                lv[name] = (sup, res); aa[name] = at if at > 0 else 1.0
            flat = []
            for name, tm, exp in tfs:
                sup, res = lv[name]
                for k, z in enumerate(sup): flat.append((name, "SUP", k, z, exp))
                for k, z in enumerate(res): flat.append((name, "RES", k, z, exp))
            for name, tm, exp in tfs:
                sup, res = lv[name]
                for side, arr in (("SUP", sup), ("RES", res)):
                    for z in arr:
                        c, tt = 1, z["t"]
                        for n2, _, _ in tfs:
                            if n2 == name: continue
                            s2, r2 = lv[n2]
                            arr2 = s2 if side == "SUP" else r2
                            for z2 in arr2:
                                if abs(z2["mid"] - z["mid"]) <= CONF_TOL_ATR * aa[name]:
                                    c += 1; tt += z2["t"]; break
                        z["conf"] = c; z["totalT"] = tt
            sres = sorted([x for x in flat if x[1] == "RES"], key=lambda x: (-x[3]["conf"], -x[3]["totalT"]))[:2]
            ssup = sorted([x for x in flat if x[1] == "SUP"], key=lambda x: (-x[3]["conf"], -x[3]["totalT"]))[:2]
            strong = set((n, s, k) for n, s, k, z, e in (sres + ssup))
            srank = {}
            for i, (n, s, k, z, e) in enumerate(sres): srank[(n, s, k)] = 1 if i == 0 else 2
            for i, (n, s, k, z, e) in enumerate(ssup):
                if (n, s, k) not in srank: srank[(n, s, k)] = 1 if i == 0 else 2
            for name, side, k, z, exp in flat:
                at = aa[name]
                w.writerow([ht.strftime("%Y-%m-%d %H:%M:%S"), a.symbol, "H1", name, side, k + 1, round(z["mid"], 2), z["t"], z["conf"], z["totalT"], 1 if (name, side, k) in strong else 0, srank.get((name, side, k), 0), 0, 0, "None", 0, "H1_FLAT|ADX0", round(bid, 2), round(ask, 2), 32, round(at, 2), round(abs(z["mid"] - bid) / at, 3) if at else 0, exp, "2.51-replay"])
                rows += 1
    print("replay rows=%d -> %s" % (rows, a.out))

if __name__ == "__main__": main()

