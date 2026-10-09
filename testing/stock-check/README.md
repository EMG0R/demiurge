# stock-check

Does every language's parameter hook (resources/params/<lang>/) work on a stock Pi? Written to be run over ssh by another
agent: no Claude agent, no USB audio needed (HDMI-only is fine), never opens an audio device, never restarts a service,
uses only UDP ports 19200-19319 (never the real pool's 9102).

## Exact commands

```bash
# 1. get the repo onto the Pi (any path), e.g. from the dev machine:
rsync -a --exclude .git ./resources ./testing user@pi:/tmp/demiurge-check/
# 2. run everything (about 10 s):
ssh user@pi 'bash /tmp/demiurge-check/testing/stock-check/run.sh'
# 3. one language / longer timeout / look at the machine-readable result:
ssh user@pi 'bash /tmp/demiurge-check/testing/stock-check/run.sh --only faust --timeout 40'
ssh user@pi 'cat /tmp/demiurge-check/testing/stock-check/results.tsv'
```
(`--repo DIR` if resources/ and testing/ are not siblings; the hello_* check then looks in `DIR/demiurge/examples`,
`~/demiurge/examples`, `/opt/demiurge/examples`, and only reports PRESENT/MISSING.)

## Reading the result
| Result | Meaning |
|---|---|
| PASS | engine started silent/offline, received `/p` from testpool.py, answered `/pout` |
| FAIL | engine crashed, errored, or never echoed (last log lines are printed) |
| HANG | test exceeded `--timeout` (default 20 s); its whole process group is killed |
| SKIP | engine not installed, or not built yet (Cardinal) -- reason in DETAIL |
| MISSING | a `hello_*` example file is absent (informational, never fails the run) |

Exit status 0 iff no FAIL and no HANG. `results.tsv` columns: `kind name result seconds detail`.

## Needs on the Pi
bash, python3, plus the engines you want checked (csound, chuck, pd, sclang, faust [+ g++, libOSCFaust, liblo-dev for the
real Faust OSC round-trip; without them Faust is checked manifest-only and says so], node). Missing engines SKIP.

## How each test stays silent
Csound `-+rtaudio=null -o dac` (paced, no device) · ChucK `--silent` · Pd `-nosound -nomidi -noprefs` · sclang only
(no scsynth boot, empty config so `startup.scd` is not run) · Faust compiles a console binary with no audio I/O · node.

## hello_* rows (full run, or `--only hello_csound|hello_chuck|hello_pd|hello_sc|hello_faust|hello_strudel|hello_patching`)
Each `hello_<lang>/hello_nonlinear_daylight.*` is started silent with the launcher's argv/env (see `params.rs`) and driven by
`pool_e2e.py`, which uses the real `demiurge_io` objects (`ParamRegistry` + `OscSink` + `Pool`): it writes the three
`/nld-<lang>/{density,tone,length}` params as `/p`, waits for `/pout` on the pool port, and requires `Pool.publish_out` to record them.
Faust goes through the reference arch (needs g++ + libOSCFaust + liblo, else SKIP); Strudel needs `~/demiurge/strudel/node_modules`
(else SKIP). The `hello_patching` row runs `demiurge/examples/hello_patching/check.sh` (seven stages, ports 18400+).
Ports: hello rows use `--port-base` + 40.. (engine) and + 140.. (pool).
