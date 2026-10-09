# Strudel / node

`dparams.mjs`: dependency-free (`node:dgram`). `init({stage, port})`, `add(path, dflt)`, `get(path)`, `out(path, v)`.
Strudel patterns are JS evaluated by a host process; expose the reader and use it inside patterns:

```js
import { init, add, get } from './dparams.mjs';
init({ stage: 'strudel' }); add('/strudel/cutoff', 0.5);
globalThis.dp = get;                      // then in a pattern:  s("bd*4").lpf(dp('/strudel/cutoff') * 8000)
```
`get` is a Map read: call it per evaluation/cycle (or wrap in `signal(() => dp(...))`).
A browser-only Strudel REPL has no UDP; the node host owns the socket and forwards.
Self-test: `./selftest.sh [ENGINE_PORT POOL_PORT]`.
