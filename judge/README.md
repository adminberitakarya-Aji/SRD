# Judge — penilai signal multi-agent SRD (Fase 2)

## Cara pakai
```powershell
py judge/judge.py --signals signals.csv --ohlc ohlc_h1.csv --out judge/out --point XAUUSD:0.01
```
- `--signals`: CSV logger `SRD_Indi_signals_YYYYMMDD.csv` (24 kolom Bab 5 agent_TF.md).
- `--ohlc`: `time_utc,symbol,timeframe,open,high,low,close` (cukup H1 untuk v1).
- `--point`: point per simbol untuk toleransi & biaya (default 0.01).

## Aturan kunci (agent_TF.md Bab 4)
Clock H1, event sentuh +- max(0.10 ATR, 15 point), entry market open N+1,
SL level +- 0.20 ATR + biaya spread+50pt, TP1 1R, TP2 level TF sama fallback 2R,
expiry 24j M30/H1 48j H4, SL&TP sebatang = LOSE, min n>=100.

## Output
- `trades.csv` — 1 baris per trade + label WIN_TP1/WIN_TP2/LOSE/TIMEOUT.
- `summary_agent.csv` — per (agent,side,rank): n, hit%, avgR, expectancy, PF.
- `summary_filter.csv` — slice conf/strong/fvg/agent/rank.
- Contoh input: `signals_example.csv`, `ohlc_example.csv`.
