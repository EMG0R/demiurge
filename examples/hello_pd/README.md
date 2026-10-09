# hello_pd: hello nonlinear daylight (Pure Data)

Pure Data: a self-playing Lydian voice (two oscillators, line~ envelope, low-pass, delay echo); DSP is turned on by its own loadbang. Runs Emory's nonlinear daylight sketch.

## UI
One shared page drives all six languages: `web/examples/nonlinear_daylight.html?stage=pd`
(served by demiurge-web at `/examples/nonlinear_daylight.html?stage=pd`). Sliders write through
`POST /api/pool/set`; the page follows the engine's `/pout` echo.

## Params (identical in all six languages, floats 0..1, `"map": "hard"`)
| Pool path | Controls |
|---|---|
| `/nld-pd/density` | metro period, ~4 s down to ~0.4 s |
| `/nld-pd/tone` | low-pass cutoff |
| `/nld-pd/length` | envelope length |

Manifest: `params/nld-pd.json` (stage `nld-pd`, port 9000). Copy it to `~/demiurge/params/` and run
this file as the only (first) stage of a `chain =`, so the launcher's stage port is 9000
(`DEMIURGE_PARAM_PORT` overrides). Only one of the six manifests at a time (they share port 9000).

## How the hook is wired
`[dparam_rx 0 0]` once, `[dparam /nld-pd/<name> <default>]` per param (feeds the existing `s nld_*` sends) and `[dpout /nld-pd/<name>]` for the echo. Needs `-path $DEMIURGE_RESOURCES/params/pd` and the launcher's `-send "demiurge-param-port N; demiurge-pool-port M"`, both placed before the patch. Pd prints `canvas: no method for 'used'` once from the abstractions; harmless.

## Run (silent / offline check, no audio device)
```
pd -nogui -nosound -nomidi -noprefs -path $DEMIURGE_RESOURCES/params/pd -send "demiurge-param-port 9000; demiurge-pool-port 9102" hello_nonlinear_daylight.pd
```
Automated: `bash testing/stock-check/run.sh --only hello_pd` sends `/p` and requires the `/pout` echo back.
