# hello_faust: hello nonlinear daylight (Faust)

Faust: one triangle voice with a soft octave through a low-pass, C Lydian. Runs Emory's nonlinear daylight sketch.

## UI
One shared page drives all six languages: `web/examples/nonlinear_daylight.html?stage=faust`
(served by demiurge-web at `/examples/nonlinear_daylight.html?stage=faust`). Sliders write through
`POST /api/pool/set`; the page follows the engine's `/pout` echo.

## Params (identical in all six languages, floats 0..1, `"map": "hard"`)
| Pool path | Controls |
|---|---|
| `/nld-faust/density` | time between notes, ~12 s down to 0.6 s |
| `/nld-faust/tone` | low-pass cutoff 300 to 6000 Hz |
| `/nld-faust/length` | note release 0.8 to 10 s |

Manifest: `params/nld-faust.json` (stage `nld-faust`, port 9000). Copy it to `~/demiurge/params/` and run
this file as the only (first) stage of a `chain =`, so the launcher's stage port is 9000
(`DEMIURGE_PARAM_PORT` overrides). Only one of the six manifests at a time (they share port 9000).

## How the hook is wired
No library: `declare name "nld"` makes Faust's OSC root `/nld`, so the pool's osc sink (manifest `"address": "/nld/<name>"`) writes straight to the sliders. Build with `faust2jackconsole -midi -osc` (the launcher adds `-osc` when a manifest for the stage exists). A stock Faust binary cannot report `/pout`; the echo comes from `resources/params/faust/faust_pool_arch.cpp` (reference arch, no audio I/O), which testing uses.

## Run (silent / offline check, no audio device)
```
faust2jackconsole -midi -osc hello_nonlinear_daylight.dsp && ./hello_nonlinear_daylight -port 9000
```
Automated: `bash testing/stock-check/run.sh --only hello_faust` sends `/p` and requires the `/pout` echo back.
