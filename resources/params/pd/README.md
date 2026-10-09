# Pure Data

Put `resources/params/pd` on the path (`-path`, or Demiurge's launcher does it). In ONE patch:

- `[dparam_rx 0 0]`  once: `netreceive -u -b` -> `oscparse` -> shared bus. Arguments `port poolport`; `0 0` means
  "take them from the messages `demiurge-param-port N` / `demiurge-pool-port N`" which the launcher sends with
  `pd -send "demiurge-param-port 9004; demiurge-pool-port 9102"` (Pd has no getenv). Pool port falls back to 9102
  after 1 s if no message arrives.
- `[dparam /stage/cutoff 0.5]`  outlet = 0..1 float (default on load, then every `/p`).
- `[dpout /stage/level]`  inlet float -> `/pout` (only on change).

Gotcha recorded: `oscparse` strips the leading slash of the *address* (`/p` -> `p`) but not of string arguments.
Self-test: `./selftest.sh [ENGINE_PORT POOL_PORT]` (`pd -nogui -nosound -nomidi -noprefs`).
