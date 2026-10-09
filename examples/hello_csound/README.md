# hello_csound: hello nonlinear daylight (Csound)

Csound: D Lydian, two detuned saws -> moogladder -> envelope into a reverbsc tail. Runs Emory's nonlinear daylight sketch.

## UI
One shared page drives all six languages: `web/examples/nonlinear_daylight.html?stage=csound`
(served by demiurge-web at `/examples/nonlinear_daylight.html?stage=csound`). Sliders write through
`POST /api/pool/set`; the page follows the engine's `/pout` echo.

## Params (identical in all six languages, floats 0..1, `"map": "hard"`)
| Pool path | Controls |
|---|---|
| `/nld-csound/density` | note rate, ~0.05 to ~1.2 notes/s (exponential) |
| `/nld-csound/tone` | filter cutoff, ~180 Hz to ~7 kHz (exponential) |
| `/nld-csound/length` | note length, ~0.4 s to ~9 s (exponential) |

Manifest: `params/nld-csound.json` (stage `nld-csound`, port 9000). Copy it to `~/demiurge/params/` and run
this file as the only (first) stage of a `chain =`, so the launcher's stage port is 9000
(`DEMIURGE_PARAM_PORT` overrides). Only one of the six manifests at a time (they share port 9000).

## How the hook is wired
`demiurge_params.udo` via `#include "params/csound/demiurge_params.udo"` (`--env:INCDIR=$DEMIURGE_RESOURCES`, which the launcher passes). `dparam_init "nld-csound", 0`, three `dparam` reads, three `dpout`. `ksmps = 32` (the hook takes one `/p` per k-cycle; keep <= 64). `giDParamPort init 9000` after the include is only the fallback when no `--omacro:DEMIURGE_PARAM_PORT` is passed.

## Run (silent / offline check, no audio device)
```
csound -d -+ignore_csopts=1 -+rtaudio=null -o dac hello_nonlinear_daylight.csd --omacro:DEMIURGE_PARAM_PORT=9000 --omacro:DEMIURGE_POOL_PORT=9102 --env:INCDIR=$DEMIURGE_RESOURCES
```
Automated: `bash testing/stock-check/run.sh --only hello_csound` sends `/p` and requires the `/pout` echo back.
