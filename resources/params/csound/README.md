# Csound

```csound
#include "demiurge_params.udo"          ; path via DEMIURGE_RESOURCES/params/csound (-I or absolute)
instr 1
  dparam_init "mystage", 9005           ; once, i-time. iport 0 -> macro / giDParamPort
  kcut dparam "/mystage/cutoff", 0.5    ; k-rate 0..1, updated by the pool's /p
  dpout "/mystage/level", klevel        ; /pout to the pool whenever klevel changes
endin
```
Port/host come from macros because Csound has no `getenv` opcode: Demiurge's launcher passes
`--omacro:DEMIURGE_PARAM_PORT=N --omacro:DEMIURGE_POOL_HOST=... --omacro:DEMIURGE_POOL_PORT=...`
from the env vars. By hand: add those flags yourself, or pass `iport` / set `giDParamPort`.
- `DEMIURGE_POOL_HOST` is pasted into the orchestra as source, so the value needs its own double quotes:
  `'--omacro:DEMIURGE_POOL_HOST="10.0.0.2"'` (single quotes outside in a shell). The default is already quoted.
- Order: set `giDParamPort` / `giDParamPool` **after** the `#include` (the .udo does `giDParamPort init 0`; Csound cannot
  keep a pre-set global). `dparam_init` reads it at i-time, so this always works. `#define DEMIURGE_PARAM_PORT #N#`
  is the opposite: before the include.

Notes (all found the hard way, see the comments in the .udo):
- One receiver instrument `DParamRx` (started by `dparam_init`) owns the only `OSClisten`; each `dparam`
  reads a slot of a shared table. Several `OSClisten`s on one handle do not all get the message.
- One `/p` message is handled per k-cycle: use **ksmps <= 64**.
- `dpout` calls `OSCsend` every k-cycle with the `changed` trigger (it fires on a *rise*, so it must not sit in an `if`).
- Unknown `/p` paths are ignored; values are clamped to 0..1.
- Existing NEPTR rig keeps its own `/p <int id>` on 7770 (`expr_targets.json`); this file is for new stages.

Self-test: `./selftest.sh [ENGINE_PORT POOL_PORT]` (uses `-+rtaudio=null -o dac`: real-time pacing, opens no audio device).
