# Faust

Faust already speaks OSC (`faust2jackconsole -osc`, `-port N`), so there is no library to include. Three pieces:

- `dparam_example.dsp`: conventions. `[osc:/addr 0 1]` = Faust's own alias: it accepts 0..1 and maps it **linearly**
  onto the slider itself. No alias = Faust's default address `/<dsp name>/<label>` in **native units**.
- `faust_manifest.py`: `faust -json` -> pool manifest. Alias -> `address` only; no alias and a non-0..1 range ->
  `native {min,max,curve}` (`[scale:log]` -> `exp`), default normalized to 0..1.
  `./faust_manifest.py dparam_example.dsp --stage mystage --port 9007 -o ~/demiurge/params/mystage.json`
- The pool's `osc` sink does the denormalizing for entries with `native` (`sinks/osc.py denormalize`: lin, or exp with min > 0).
  Exponential ranges must therefore NOT use an alias (aliases are linear).

Faust does not natively send `/pout <path> <val>`. Two-way is the architecture's job: `faust_pool_arch.cpp`
(reference, no audio I/O) polls the zones and sends `/pout`; for a real engine copy that loop into your arch.
Self-test: compiles the example, checks the manifest, builds the arch with g++ (~4 s) and does a real OSC round-trip
(`faust_osc_check.py`); with no g++ / libOSCFaust / liblo it degrades to manifest-only and says so.
Port/host env for the arch: `DEMIURGE_PARAM_PORT`, `DEMIURGE_POOL_HOST`, `DEMIURGE_POOL_PORT`, `DEMIURGE_STAGE`.
