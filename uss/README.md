# USS: Unified Synthesis System

A public, curated set of **playable generative instruments** across Csound and ChucK (VCV later), all on **one shared UI**
(`ui/index.html`) with **hard maps** so nobody has to map them. They start with Emory's own pieces, then the Csound classics.
Not patches: patches are NEPTR's Csound presets plus soft maps. USS instruments are hard-mapped, and they run as their own
engine stage; live NEPTR Csound keeps priority.

Exportable: nothing here depends on `demiurge/`. It needs only `resources/params/<lang>/` (the pool hooks) and, for the checks,
`src/demiurge-io` + `testing/stock-check/pool_e2e.py`.

## Layout
```
uss/README.md            this file
uss/ui/index.html        the one UI (phone-first; copy to web/examples/uss.html, open /examples/uss.html?inst=supersaw)
uss/check.sh             per-instrument PASS/FAIL/HANG (also run by testing/stock-check/run.sh as uss_* rows)
uss/rec.ck, wavstat.py   offline recorder (ChucK) and wav analyser used by check.sh
uss/instruments/<name>/  <name>.csd|.ck   the engine (real hooks)
                         params/uss-<name>.json   manifest: 7 params, "map":"hard", hard_maps
                         README.md
```
Instruments: `nonlinear_daylight` (Csound, Emory), `supersaw` (ChucK, Emory), `lockin` (ChucK, NEPTR's synth mode).
Deploy an instrument: copy its `params/uss-<name>.json` to `~/demiurge/params/`, run the engine file as a Demiurge stage whose
program id is `uss-<name>` (the launcher then passes `DEMIURGE_PARAM_PORT` etc.; see `resources/README.md`).

## Structure of an instrument
1. One engine file in Csound or ChucK, built on the pool hook (`#include params/csound/demiurge_params.udo`, or
   `DemiurgeParams.ck`). It listens `/p <path> <0..1>` and answers `/pout` on change, so the UI follows.
2. It is generative on its own: started, it plays. The common params steer it; the instrument's own sound is untouched.
3. One manifest, stage `uss-<name>`, port 9020+ (a fallback; the launcher assigns the real one). Every param is `"map":"hard"`
   and `hard_maps` carries the table below (existing map schema, docs/parameters.md section 11). The pool drops any user map aimed at them.
   Path naming: the registry requires the stage to be the first path segment, so `/uss/<inst>/x` is written `/uss-<inst>/x`.

## Common performance parameters (every instrument, all floats 0..1)
| param | meaning | neutral default |
|---|---|---|
| `/uss-<inst>/density` | how much happens: event rate / gesture probability | 0.5 |
| `/uss-<inst>/tone` | brightness (FM index / filter / filter offset / detune width) | 0.5 |
| `/uss-<inst>/length` | how long things last (note/section length) | 0.5 |
| `/uss-<inst>/space` | room: reverb amount | 0.75 nld, 0 others |
| `/uss-<inst>/intensity` | level | 0.5 |
| `/uss-<inst>/pitch` | pitch of the next triggered note (quantized per instrument) | 0.5 |
| `/uss-<inst>/trig` | gate: 0 to 1 edge fires a note/gesture now | 0 |

Defaults reproduce the original piece exactly (every scale is 1.0 at its default). Meaning per instrument is in each README.

## Hard-map table (identical for every instrument)
| source | param | mode | range |
|---|---|---|---|
| arcade button `/hw/teensy/b1` | `trig` | gate (press 1, release 0) | |
| joystick X `/hw/teensy/jx` | `pitch` | continuous | 0..1 |
| joystick Y `/hw/teensy/jy` | `tone` | continuous | 0..1 |
| LiDAR 1 `/hw/teensy/tof1` | `space` | continuous, hold on dropout | 0..1 |
| LiDAR 2 `/hw/teensy/tof2` | `length` | continuous, hold on dropout | 0..1 |
| FSR 1 `/hw/teensy/fsr1` | `density` | continuous | 0.5..1 (rest = original density, press = busier) |
| DUODECIMUS pedal `/hw/midi/1/29` (ch1 CC29) | `intensity` | continuous | 0.3..1 (heel = quiet) |

Never mapped: **encoders** (e1-e7, eb1-eb7) keep their NEPTR menu roles; FSR 2, joystick click and the other buttons stay free.
`check.sh` fails an instrument whose manifest maps an encoder source.
Arcade button: the hard map makes it the instrument's trigger while a USS instrument is active (`"arcade": "trig"` in the b1 map);
a long hold (`"arcade_hold_s"`) hands it back to the host's own role (e.g. tap tempo). The role logic lives in `demiurge-io`'s `arcade.py`.

## Checks
`bash uss/check.sh [--only <name>]`, or `bash testing/stock-check/run.sh --only uss`. Per instrument: manifest loads in the real
`ParamRegistry` (7 params, all hard, 7 hard_maps, no encoder source, params present in the engine file); offline silent render
(csound `-+rtaudio=null -W`, chuck `--silent` + a WvOut tap) that must compile, be non-silent (RMS > 0.01), peak <= 1.0 and have
under 0.001% full-scale samples; `/p` to `/pout` round trip on all 7 params through the real pool objects. Ports UDP 18300+ only,
no audio device, no JACK/PipeWire, no service touched.

## Known gaps
- The sources `/hw/teensy/<id>` (sensors alias the bare ids; buttons b1-b9/jb are new) and `/hw/midi/1/29` exist in the pool as of
  the NEPTR integration (src/demiurge-io, tests/test_neptr.py) but are unverified on the body until the bench run.
- `demiurge-io` must run with `--midi --midi-port Through --midi-neptr` for the pedal source (the unit in src/demiurge-io does).
- The slot needs a launcher with the pool launch contract (hook + `DEMIURGE_PARAM_PORT`): `demiurge-uss` refuses otherwise.
- Pool ingress is UDP 9102 (9100 belongs to demiurge-clock's `/transport/tap`).
