# Cardinal (VCV Rack fork) -> the pool

Status: **not built yet**, so nothing here is tested. `selftest.sh` reports SKIP.

Cardinal has no script layer, so there is no "library to include". **Everything below about Cardinal's module names is from memory and unverified.** Two paths, in order of preference:

1. **Built-in OSC.** Cardinal ships the `Cardinal` plugin's *Host Parameters* module (host/plugin automation
   parameters, exposed over the standalone's OSC/remote-control port) and an OSC-capable remote module.
   Point its OSC input at `DEMIURGE_PARAM_PORT` and add a manifest (below) whose `address` entries are
   the module's parameter addresses. The pool's `osc` sink does the 0..1 -> native step from `native`.
   Reporting back (`/pout`) needs an OSC-out module aimed at `DEMIURGE_POOL_HOST:DEMIURGE_POOL_PORT`
   sending `/pout <path> <val>`; if the module cannot format a string argument, skip two-way for Cardinal.
2. **MIDI-CC bridge (always works).** Declare params with `"midi": {"ch": N, "cc": M}` in the manifest;
   the pool's `midi` sink writes CC to Midi Through, and Cardinal's MIDI-CC module maps CC -> knob.
   Remember: ch16 CC104-119 (clock) and ch1 CC29 are reserved and never emitted.

Manifest (hand-written, `~/demiurge/params/cardinal.json`; stage `cardinal`):

```json
{ "stage": "cardinal", "port": 9008, "version": 1,
  "params": [
    {"path": "/cardinal/cutoff", "label": "Cutoff", "default": 0.5, "midi": {"ch": 3, "cc": 20}},
    {"path": "/cardinal/drive",  "label": "Drive",  "default": 0.2, "address": "/param/1", "map": "soft"} ] }
```

Open items before this can be marked verified: build Cardinal on the Pi, confirm the OSC module names and
the address scheme, then replace `selftest.sh` with a real round-trip against `../testpool.py`.
