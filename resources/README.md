# resources/ : how any language joins the parameter pool

Contract: `docs/parameters.md` (every parameter is a float 0..1; §11 = hard/soft + two-way). This tree holds one
tiny hook per language, each with a README and a `selftest.sh`. Demiurge points every engine at it with
`DEMIURGE_RESOURCES=<repo or /opt/demiurge>/resources` (hooks live in `$DEMIURGE_RESOURCES/params/<lang>/`).

## The whole protocol (so any language can hand-roll it in 20 lines)
| Direction | Message (OSC over UDP, loopback) | Meaning |
|---|---|---|
| pool -> engine | `/p <path:string> <val:float>` to the engine's `port` | set parameter (0..1) |
| engine -> pool | `/pout <path:string> <val:float>` to `DEMIURGE_POOL_HOST:PORT` (127.0.0.1:9102) | "my value is now this"; echoed to the UI, never sent back to the engine |

Path = `/<stage>/<name>`, lowercase. Declare it in the stage manifest `~/demiurge/params/<stage>.json`
(`stage`, `port`, `params[]` with `path`, `label`, `default`, `address`, optional `native`, optional `"map":"hard"`).
Unknown paths are ignored; values are clamped to 0..1.

## Env vars Demiurge sets for every engine
| Var | Meaning | Default |
|---|---|---|
| `DEMIURGE_PARAM_PORT` | UDP port this engine listens on (its manifest `port`) | per stage |
| `DEMIURGE_POOL_HOST` | where `/pout` goes | `127.0.0.1` |
| `DEMIURGE_POOL_PORT` | where `/pout` goes | `9102` |
| `DEMIURGE_STAGE` | this engine's stage name | |
| `DEMIURGE_RESOURCES` | this directory | |

Csound and Pd cannot read env: the launcher turns them into `--omacro:` flags / `pd -send` messages (see their READMEs).

## Per language
| Lang | Hook | Receive | Report |
|---|---|---|---|
| Csound | `params/csound/demiurge_params.udo` | `kv dparam "/p/a", dflt` | `dpout "/p/a", kv` |
| ChucK | `params/chuck/DemiurgeParams.ck` | `p.get(path)` | `p.out(path, v)` |
| Pd | `params/pd/dparam.pd`, `dpout.pd`, `dparam_rx.pd` | `[dparam /p/a 0.5]` | `[dpout /p/a]` |
| SuperCollider | `params/supercollider/DemiurgeParams.scd` | `~dparam.(path, dflt)` | `~dpout.(path, v)` |
| Faust | `params/faust/` (built-in OSC + manifest generator) | OSC alias / default address | arch loop |
| Strudel (node) | `params/strudel/dparams.mjs` | `get(path)` | `out(path, v)` |
| Cardinal | `params/cardinal/README.md` (not built yet) | | |

`params/testpool.py` is a pure-python fake pool (records `/pout`, sends `/p`); self-tests and
`testing/stock-check/run.sh` use it on ports 19000-19999 only, never the real 9102. Every self-test runs the engine
silent/offline (null audio backend or no server) and never opens an audio device.
