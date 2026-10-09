# hello_chuck: hello nonlinear daylight (ChucK)

ChucK: one triangle voice through a low-pass, ADSR and light reverb, walking C Lydian. Runs Emory's nonlinear daylight sketch.

## UI
One shared page drives all six languages: `web/examples/nonlinear_daylight.html?stage=chuck`
(served by demiurge-web at `/examples/nonlinear_daylight.html?stage=chuck`). Sliders write through
`POST /api/pool/set`; the page follows the engine's `/pout` echo.

## Params (identical in all six languages, floats 0..1, `"map": "hard"`)
| Pool path | Controls |
|---|---|
| `/nld-chuck/density` | event rate (gap 8 s down to 0.4 s) |
| `/nld-chuck/tone` | filter cutoff 300 Hz to 5 kHz |
| `/nld-chuck/length` | note length 0.3 s to 4 s |

Manifest: `params/nld-chuck.json` (stage `nld-chuck`, port 9000). Copy it to `~/demiurge/params/` and run
this file as the only (first) stage of a `chain =`, so the launcher's stage port is 9000
(`DEMIURGE_PARAM_PORT` overrides). Only one of the six manifests at a time (they share port 9000).

## How the hook is wired
`DemiurgeParams.ck` is compiled before the patch (the launcher puts it first in argv): `pool.init("nld-chuck", 0)` (port from `DEMIURGE_PARAM_PORT`), `pool.add`, `pool.get`, `pool.out`. A 20 ms shred copies the three values and echoes changes.

## Run (silent / offline check, no audio device)
```
chuck --silent $DEMIURGE_RESOURCES/params/chuck/DemiurgeParams.ck hello_nonlinear_daylight.ck
```
Automated: `bash testing/stock-check/run.sh --only hello_chuck` sends `/p` and requires the `/pout` echo back.
