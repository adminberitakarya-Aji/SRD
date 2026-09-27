"""Replay logger SRD_Indi murni Python (tanpa MT5) utk Fase 3.
Meniru engine v2.60: fractal swing -> cluster ATR -> touches ->
3 RES/SUP terdekat -> confluence -> TERKUAT (seri=jarak dekat) ->
S&D skor kualitas (Fresh1000+FVG100+srConfl50+strength-jarak) ->
snapshot 18/jam. Pakai: py judge/replay_logger.py --ohlc ohlc.csv --out signals.csv
"""
import argparse, csv
from collections import defaultdict
from datetime import datetime
MERGE_ATR = 0.30
MINTHICK_ATR = 0.15
CONF_TOL_ATR = 0.25
FVG_MIN_ATR = 0.15
IMPULSE_ATR = 1.0
BASEMAX_ATR = 0.8
BASEMAX_N = 5
SD_SCAN = 400
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

def ema_series(closes, period):
    k = 2.0 / (period + 1.0)
    n = len(closes)
    out = [None] * n
    if n < period: return out
    s = sum(closes[:period]) / period
    out[period - 1] = s
    for i in range(period, n):
        s = closes[i] * k + s * (1 - k)
        out[i] = s
    return out

def trend_ctx_idx(e50, cl, ud1, uh4, uhh):
    # Index sudah diselaraskan ke bar <= ht per TF. O(1) per snapshot.
    def one(e, closes, upto):
        if e is None or closes is None: return ("FL", 0.0)
        if upto is None or upto >= len(e) or upto >= len(closes): return ("FL", 0.0)
        if upto < 4: return ("FL", 0.0)
        e1, e3 = e[upto - 1], e[upto - 3]
        if e1 is None or e3 is None: return ("FL", 0.0)
        slope = e1 - e3
        c = closes[upto - 1]
        d = "UP" if (c > e1 and slope > 0) else ("DN" if (c < e1 and slope < 0) else "FL")
        chg = 0.0
        a0 = max(1, upto - 13)
        for i in range(a0, upto + 1): chg += abs(closes[i] - closes[i - 1])
        net = abs(closes[upto] - closes[max(0, upto - 14)])
        adx = round(100.0 * net / chg, 0) if chg > 0 else 0.0
        return (d, adx)
    d_d1, _ = one(e50.get("D1"), cl.get("D1"), ud1) if e50.get("D1") else ("NA", 0.0)
    d_h4, ax = one(e50.get("H4"), cl.get("H4"), uh4) if e50.get("H4") else ("FL", 0.0)
    d_h1, _ = one(e50.get("H1"), cl.get("H1"), uhh) if e50.get("H1") else ("FL", 0.0)
    return "D1_%s/H4_%s/H1_%s|ADX%.0f" % (d_d1, d_h4, d_h1, ax)

def trend_ctx(d1, h4, h1, upto_h1, e50_d1=None, e50_h4=None, e50_h1=None,
              cl_d1=None, cl_h4=None, cl_h1=None):
    # EMA50 dihitung SEKALI di main (bukan per snapshot) -> O(1) per snapshot.
    def one(e, closes, upto):
        if e is None or closes is None: return ("FL", 0.0)
        if upto is None or upto >= len(e) or upto >= len(closes): return ("FL", 0.0)
        if upto < 4: return ("FL", 0.0)
        e1, e3 = e[upto - 1], e[upto - 3]
        if e1 is None or e3 is None: return ("FL", 0.0)
        slope = e1 - e3
        c = closes[upto - 1]
        d = "UP" if (c > e1 and slope > 0) else ("DN" if (c < e1 and slope < 0) else "FL")
        chg = 0.0
        a0 = max(1, upto - 13)
        for i in range(a0, upto + 1): chg += abs(closes[i] - closes[i - 1])
        net = abs(closes[upto] - closes[max(0, upto - 14)])
        adx = round(100.0 * net / chg, 0) if chg > 0 else 0.0
        return (d, adx)
    u_d1 = min(upto_h1 * 24, len(e50_d1) - 1) if e50_d1 else 0
    u_h4 = min(upto_h1 * 4, len(e50_h4) - 1) if e50_h4 else 0
    d_d1, _ = one(e50_d1, cl_d1, u_d1) if e50_d1 else ("NA", 0.0)
    d_h4, ax = one(e50_h4, cl_h4, u_h4) if e50_h4 else ("FL", 0.0)
    d_h1, _ = one(e50_h1, cl_h1, upto_h1) if e50_h1 else ("FL", 0.0)
    return "D1_%s/H4_%s/H1_%s|ADX%.0f" % (d_d1, d_h4, d_h1, ax)

def sd_score(z, bid, a):
    # Cermin SDZoneScore() v2.60: Fresh=1000 + FVG=100 + srConfl=50
    # + strength - penalti jarak/ATR. srConfl dihitung on-the-fly
    # terhadap level S&R snapshot (butuh lv + tol) — lihat pemakaian.
    s = 0.0
    if z["st"] == "Fresh": s += 1000.0
    if z["fvg"]: s += 100.0
    if z.get("srConfl"): s += 50.0
    s += z.get("str", 0.0)
    if a > 0:
        s -= abs(z["mid"] - bid) / a
    return s

def sd_zones(bars, upto, bid, a):
    # Tiru FindSDZonesForTF: ImpOut impulse + base<=5 + ImpIn, Fresh/Tested,
    # buang Consumed, plus FVG 3-candle 50% CE di departure leg.
    # Index: bars kronologis lama->baru; bar terbaru = index TERAKHIR.
    # Counterpart MQL5 i+x = bars[upto-x].
    out = []
    if a <= 0: return out
    lim = min(SD_SCAN, upto - BASEMAX_N - 3)
    if lim < 5: return out
    n = upto + 1
    lows = [b[3] for b in bars[:n]]
    highs = [b[2] for b in bars[:n]]
    closes = [b[4] for b in bars[:n]]
    opens = [b[1] for b in bars[:n]]
    for i in range(1, lim):
        oi = upto - i
        if oi < BASEMAX_N + 2 or oi >= n: continue
        o, c = opens[oi], closes[oi]
        body = abs(c - o)
        if body < IMPULSE_ATR * a: continue
        outBull = c > o
        for bLen in range(1, BASEMAX_N + 1):
            # MQL5 series: i+1 = LEBIH LAMA. Kronologis: base di KIRI (lama)
            # dari ImpOut, ImpIn 1 bar lebih lama lagi dari base.
            be = oi - 1
            bs = oi - bLen
            if bs < 0: continue
            if bs - 1 < 0: continue
            bh = max(highs[k] for k in range(bs, be + 1))
            bl = min(lows[k] for k in range(bs, be + 1))
            if bh - bl > BASEMAX_ATR * a: continue
            io, ic = opens[bs - 1], closes[bs - 1]
            inBull = ic >= io
            dem = (inBull and outBull) or ((not inBull) and outBull)
            sup = ((not inBull) and (not outBull)) or (inBull and (not outBull))
            isDem = dem and not sup
            if not dem and not sup: continue
            zT, zB = bh, bl
            st = "Fresh"
            # MQL5 c2=1..i-1 = bar LEBIH BARU dari ImpOut (kanan di kronologis).
            # + filter harga running (bid di luar zona = consumed).
            if isDem and bid < zB: st = "Consumed"
            elif (not isDem) and bid > zT: st = "Consumed"
            else:
                for kk in range(oi + 1, n):
                    if highs[kk] >= zB and lows[kk] <= zT:
                        cl = closes[kk]
                        if isDem and cl < zB - a * 0.1: st = "Consumed"; break
                        if (not isDem) and cl > zT + a * 0.1: st = "Consumed"; break
                        if st == "Fresh": st = "Tested"
            if st == "Consumed": continue
            fvg = 0
            mg = FVG_MIN_ATR * a
            gap = None
            # MQL5 series: bar 0 = TERBARU. Kronologis: oi kecil = lama.
            # i+1 (MQL5) = 1 bar LEBIH LAMA = oi-1 kronologis.
            # i-1 (MQL5) = 1 bar LEBIH BARU = oi+1 kronologis.
            # Pola A demand: c1=high(oi-1), c3=low(oi+1); gap jika c3-c1>=mg.
            # Pola B demand: c1=high(oi-2), c3=low(oi); fvgBar=oi-1.
            # Mitigasi: candle LEBIH BARU dari evalBar = oi+1..n-1 + bid.
            fvgBar = None
            if isDem:
                c1h = highs[oi - 1] if oi - 1 >= 0 else -1
                c3l = lows[oi + 1] if oi + 1 < n else -1
                if c1h > 0 and c3l > 0 and c3l - c1h >= mg:
                    gap = (c1h, c3l); fvgBar = oi
                if gap is None and oi - 2 >= 0:
                    c1h = highs[oi - 2]; c3l = lows[oi]
                    if c3l - c1h >= mg: gap = (c1h, c3l); fvgBar = oi - 1
                if gap:
                    mid = (gap[0] + gap[1]) * 0.5
                    mit = bid <= mid
                    if not mit:
                        eb = (fvgBar + 1) if fvgBar is not None else oi + 1
                        for kk in range(eb, n):
                            if lows[kk] <= mid: mit = True; break
                    if not mit: fvg = 1
            else:
                c1l = lows[oi - 1] if oi - 1 >= 0 else -1
                c3h = highs[oi + 1] if oi + 1 < n else -1
                if c1l > 0 and c3h > 0 and c1l - c3h >= mg: gap = (c3h, c1l); fvgBar = oi
                if gap is None and oi - 2 >= 0:
                    c1l = lows[oi - 2]; c3h = highs[oi]
                    if c1l - c3h >= mg: gap = (c3h, c1l); fvgBar = oi - 1
                if gap:
                    mid = (gap[0] + gap[1]) * 0.5
                    mit = bid >= mid
                    if not mit:
                        eb = (fvgBar + 1) if fvgBar is not None else oi + 1
                        for kk in range(eb, n):
                            if highs[kk] >= mid: mit = True; break
                    if not mit: fvg = 1
            # Strength = body ImpOut dalam ATR (cermin MQL5 strength).
            impBody = abs(c - o)
            impStr = (impBody / a) if a > 0 else 0.0
            out.append({"mid": (zT + zB) / 2, "st": st, "fvg": fvg,
                        "dem": bool(isDem), "oi": oi, "age": n - 1 - oi,
                        "zt": zT, "zb": zB, "str": impStr,
                        "srConfl": False})
            break
        if len(out) >= 40: break
    return out
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
    e50 = {n: ema_series([b[4] for b in syms[n]], 50) for n in syms}
    e50["D1"] = ema_series([b[4] for b in data.get("D1", [])], 50)
    cl = {n: [b[4] for b in syms[n]] for n in syms}
    cl["D1"] = [b[4] for b in data.get("D1", [])]
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
            # Potong bars per TF s/d ui agar masa depan tak bocor (S&R + S&D).
            cutSR = {}
            for name, tm, exp in tfs:
                bars = syms[name]
                ui = bisect.bisect_right(tlist[name], ht) - 1
                cutSR[name] = (bars[:ui + 1], ui)
            lv = {}; aa = {}
            for name, tm, exp in tfs:
                bars, ui = cutSR[name]
                if ui < 20: lv[name] = ([], []); aa[name] = 0.0; continue
                (sup, res), at = build(bars, len(bars) - 1, tm, bid)
                lv[name] = (sup, res); aa[name] = at if at > 0 else 1.0
            flat = []
            for name, tm, exp in tfs:
                sup, res = lv[name]
                for k, z in enumerate(sup): flat.append((name, "SUP", k, z, exp))
                for k, z in enumerate(res): flat.append((name, "RES", k, z, exp))
            # S&D SEKALI per snapshot dari bars yg sudah dipotong.
            sdCache = {}
            for sdn in ("H1", "H4"):
                bars, ui2 = cutSR[sdn]
                if ui2 < 20: sdCache[sdn] = []; continue
                a2 = atr(bars, len(bars) - 1)
                sdCache[sdn] = sd_zones(bars, len(bars) - 1, bid, a2) if a2 > 0 else []
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
                        z["dist"] = abs(z["mid"] - bid)
            # v2.60: S&R Terkuat seri (conf+touches sama) dimenangkan jarak
            # dekat (cermin FindStrongestLevels). Dulu urutan TF mentah.
            sres = sorted([x for x in flat if x[1] == "RES"],
                          key=lambda x: (-x[3]["conf"], -x[3]["totalT"], x[3].get("dist", 1e9)))[:2]
            ssup = sorted([x for x in flat if x[1] == "SUP"],
                          key=lambda x: (-x[3]["conf"], -x[3]["totalT"], x[3].get("dist", 1e9)))[:2]
            strong = set((n, s, k) for n, s, k, z, e in (sres + ssup))
            srank = {}
            for i, (n, s, k, z, e) in enumerate(sres): srank[(n, s, k)] = 1 if i == 0 else 2
            for i, (n, s, k, z, e) in enumerate(ssup):
                if (n, s, k) not in srank: srank[(n, s, k)] = 1 if i == 0 else 2
            for name, side, k, z, exp in flat:
                at = aa[name]
                tol = max(CONF_TOL_ATR * at, 0.15)
                # v2.60: tag = zona skor-TERTINGGI yg overlap (cermin
                # BuildNearestSD+FindStrongestLevels). Dulu zona PERTAMA yg
                # overlap (bias Tested dekat) — Fresh jauh tak pernah menang.
                best = None
                bestSc = -1e18
                bestA = 1.0
                for sdn in ("H1", "H4"):
                    bars2, _ = cutSR[sdn]
                    a2 = atr(bars2, len(bars2) - 1)
                    for zn in sdCache[sdn]:
                        if abs(zn["mid"] - z["mid"]) > tol: continue
                        zn["srConfl"] = True
                        sc = sd_score(zn, bid, a2 if a2 > 0 else at)
                        if sc > bestSc:
                            bestSc = sc; best = zn; bestA = a2
                sdO, fvg, sdS = 0, 0, "None"
                if best is not None:
                    sdO = 1
                    if best["fvg"]: fvg = 1
                    sdS = best["st"]
                uhh = bisect.bisect_right(tlist["H1"], ht) - 1
                ud1 = bisect.bisect_right([b[0] for b in data.get("D1", [])], ht) - 1 if data.get("D1") else 0
                uh4 = bisect.bisect_right(tlist["H4"], ht) - 1
                tc = trend_ctx_idx(e50, cl, ud1, uh4, uhh)
                w.writerow([ht.strftime("%Y-%m-%d %H:%M:%S"), a.symbol, "H1", name, side, k + 1, round(z["mid"], 2), z["t"], z["conf"], z["totalT"], 1 if (name, side, k) in strong else 0, srank.get((name, side, k), 0), sdO, fvg, sdS, 0, tc, round(bid, 2), round(ask, 2), 32, round(at, 2), round(abs(z["mid"] - bid) / at, 3) if at else 0, exp, "2.60-replay"])
                rows += 1
    print("replay rows=%d -> %s" % (rows, a.out))

if __name__ == "__main__": main()

