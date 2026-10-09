# ChucK

```chuck
DemiurgeParams p;                       // chuck DemiurgeParams.ck yourpatch.ck
p.init("mystage", 0);                   // 0 -> DEMIURGE_PARAM_PORT
p.add("/mystage/cutoff", 0.5);
p.get("/mystage/cutoff") => float c;    // 0..1
p.out("/mystage/level", 0.3);           // /pout to the pool
```
`init` starts one listener shred (`OscIn`, address `/p, s f`); only paths declared with `add` are stored,
values clamped to 0..1. `out` uses one `OscOut` aimed at `DEMIURGE_POOL_HOST`/`DEMIURGE_POOL_PORT` (127.0.0.1/9102).
Self-test: `./selftest.sh [ENGINE_PORT POOL_PORT]` (`chuck --silent`: no audio device).
