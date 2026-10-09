# SuperCollider

```supercollider
"DemiurgeParams.scd".loadRelative;
~dparamInit.("mystage", 0);                    // 0 -> DEMIURGE_PARAM_PORT
~cut = ~dparam.("/mystage/cutoff", 0.5);       // Bus if the server is running, else a Function (.value)
~dparamVal.("/mystage/cutoff");                // latest 0..1, always valid
~dpout.("/mystage/level", 0.3);                // /pout to the pool
```
Receive uses `thisProcess.openUDPPort(port)` + `OSCdef(..., '/p', recvPort: port)`, so it works with no server
booted. Self-test runs `sclang -D` with an empty config (skips `startup.scd`) and never boots scsynth.
Self-test: `./selftest.sh [ENGINE_PORT POOL_PORT]`.
