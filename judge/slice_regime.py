# Slice regime dari trendCtx (temp)
"""Bukti hipotesa regime: ALIGNED vs MIXED x Fresh/FVG.
Filter: ADX0 (EMA belum matang, awal replay) dibuang dari analisa regime.
Arah trade vs regime: RES=SELL (cocok DN), SUP=BUY (cocok UP)."""
import csv
from collections import Counter, defaultdict

tr = [x for x in csv.DictReader(open("D:/SRD/judge/out_full2/trades.csv"))
      if not x["trend"].endswith("ADX0")]
print("trades (tanpa ADX0):", len(tr))


def regime(t):
    p = t.split("|")[0].split("/")
    ds = [x.split("_")[1] for x in p]
    if ds[0] == ds[1] == ds[2] and ds[0] in ("UP", "DN"):
        return "ALIGNED_" + ds[0]
    if ds[1] == ds[2] and ds[1] in ("UP", "DN"):
        return "H4H1_" + ds[1]
    return "MIXED"


def adx(t):
    try:
        return int(t.split("ADX")[1])
    except (IndexError, ValueError):
        return 0


def cocok(x):
    r = regime(x["trend"])
    if x["side"] == "RES":
        return r in ("ALIGNED_DN", "H4H1_DN")
    return r in ("ALIGNED_UP", "H4H1_UP")


groups = defaultdict(list)
for x in tr:
    r = regime(x["trend"])
    ax = adx(x["trend"])
    groups[(r, "ADXge25" if ax >= 25 else "ADXlt25")].append(float(x["r"]))
    groups[(r, "ALL")].append(float(x["r"]))

print("== regime x ADX (semua, tanpa ADX0) ==")
for k in sorted(groups):
    v = groups[k]
    print("  %s %s: n=%d avgR=%.3f" % (k[0], k[1], len(v), sum(v) / len(v)))

print("== searah vs lawan tren (semua) ==")
for name, f in (("SEARAH", cocok), ("LAWAN", lambda x: not cocok(x))):
    v = [float(x["r"]) for x in tr if f(x)]
    print("  %s: n=%d avgR=%.3f" % (name, len(v), sum(v) / len(v)))

print("== Fresh+FVG x searah/lawan ==")
for name, f in (("SEARAH", cocok), ("LAWAN", lambda x: not cocok(x))):
    v = [float(x["r"]) for x in tr
         if x["sdS"] == "Fresh" and x["fvg"] == "1" and f(x)]
    print("  Fresh+FVG %s: n=%d avgR=%.3f" % (name, len(v), sum(v) / len(v) if v else 0))

print("== Fresh x searah/lawan ==")
for name, f in (("SEARAH", cocok), ("LAWAN", lambda x: not cocok(x))):
    v = [float(x["r"]) for x in tr if x["sdS"] == "Fresh" and f(x)]
    print("  Fresh %s: n=%d avgR=%.3f" % (name, len(v), sum(v) / len(v) if v else 0))
