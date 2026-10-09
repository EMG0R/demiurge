# src/

The code DEMIURGE compiles and installs to `/opt/demiurge/bin/` — everything else on the system is an existing language binary or a config file.

## `demiurge-launcher-rs/` (Rust)

The session launcher and patch‑graph engine. A zero‑dependency Rust crate (stdlib only) — this is the **only** launcher DEMIURGE ships. Installed to `/opt/demiurge/bin/demiurge-launcher` and started at boot by `demiurge.service`.

Build:
```bash
cd src/demiurge-launcher-rs
cargo build --release
sudo install -m 755 target/release/demiurge-launcher /opt/demiurge/bin/demiurge-launcher
```

`setup-demiurge.sh` runs this for you — it bootstraps `rustup` on a fresh Pi and then does the cargo build + install automatically.

Around 460 KB stripped. Cold start is well under 50 ms; steady‑state CPU is <1 %.

What it does, in order:

1. **Reads** `/boot/firmware/demiurge.conf`'s `launch =` line. That line must point at a `live.conf` (or be blank, in which case it falls back to `~/demiurge/live.conf`). `live.conf` is the **only** user-facing config format; there is no raw-audio-file launch path and no classic session format.
2. **Parses** `live.conf` via `src/live.rs` — `link`, `bpm`, one or more `chain =` blocks, and an optional `midi =` sidecar block — then translates it into the internal `Program` / `Edge` graph in `src/config.rs`. The internal graph types exist only so the rest of the launcher has something to operate on; users never see them.
3. **Aggregates** every USB audio class device macOS‑style. Smaller‑channel‑count interfaces go first; successive devices fill `demiurge-sink-output:FL/FR`, then `RL/RR`. HDMI and Bluetooth are ignored. The pass is **idempotent** — it computes the diff against current PipeWire links and applies only what's changed, which is what lets hot‑plug events re‑run it safely.
4. **Launches** each program via `/opt/demiurge/bin/demiurge-run-<lang>` wrappers (csound, chuck, pd, sc, faust, cpp, python, strudel). Wrappers bake in `LD_LIBRARY_PATH=/usr/lib/aarch64-linux-gnu/pipewire-0.3/jack` and `PIPEWIRE_PROPS=node.autoconnect=false node.dont-reconnect=true` so every child plays by the same rules.
5. **Resolves** each program's JACK client by polling `pw-link -o` for known candidate names (10 s deadline).
6. **Links** the patch graph — matching stereo port‑pair patterns (`output_FL/FR`, `output_1/2`, `out_0/1`, `outL/R`, ChucK's literal `outport 0/1` with the space) — and scrubs undeclared auto‑connections to physical hardware (Faust's `faust2jackconsole` auto‑connects to system playback at startup; the scrub pass catches it).
7. **Wires MIDI** — `aconnect "Midi Through":0 "<client>":0` both ways for every program plus `demiurge-midi-connect.sh` for physical controllers.
8. **Listens** for events:
   - A background thread tails `pw-mon` and debounces USB node add/remove into a single `UsbDeviceChange` event per quiet window — triggers a fresh aggregation pass (grow‑only).
   - A child‑watcher thread checks `/proc/<pid>` for each supervised program and posts `ChildExited` on death.
   - A 2 s heartbeat catches any drift the other channels miss.
   Any event that changes live/dead state triggers `graph::apply` + `midi::wire_bus` again. Dead middle stages get rewired (`A→B→C` with B dead becomes `A→C`); resurrection restores the original graph.

**Logs.** Three files, in priority order:

- `journalctl -u demiurge` — the launcher's own decisions (parsing, launch, link/scrub, reconcile, child-exit). Canonical source.
- `~/.demiurge/logs/<id>.log` — per‑program stdout+stderr, truncated on every spawn. When a stage exits silently (csound rtjack errors, ChucK syntax errors, Faust runtime aborts), the *real* error message lives here — the launcher's journal only logs `program 'foo' marked dead`.
- `~/.demiurge/logs/<id>.compile.log` — Faust `faust2jackconsole` and C++ `g++` build output. Only written for `faust` and `cpp` languages, only on rebuild. When a `.dsp` won't come up, this is the file with the diagnostic.

## `demiurge-clock.cpp` (C++ ALSA seq daemon)

The global clock source. Built once on the Pi and installed to `/opt/demiurge/bin/demiurge-clock`:

```bash
# Standalone (no network sync)
g++ -O2 -o demiurge-clock src/demiurge-clock.cpp -lasound -lpthread

# With Ableton Link (requires ableton-link-dev from apt)
sudo apt install -y ableton-link-dev
g++ -std=c++17 -O2 -DDEMIURGE_LINK -o demiurge-clock src/demiurge-clock.cpp -lasound -lpthread

sudo install -m 0755 demiurge-clock /opt/demiurge/bin/demiurge-clock
```

`setup-demiurge.sh` does the build + install automatically and defaults to building with Link support.

What it does:

- Opens an ALSA seq client named `demiurge_clock` with one input port and one output port. Subscribes both ways to `Midi Through` (`14:0`) at startup.
- Emits MIDI realtime `0xF8` at 24 PPQN using `clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME)` — absolute‑deadline sleep that prevents drift.
- Broadcasts BPM once per beat on **`ch16 CC119`** (0..127 → 40..240 BPM). Every downstream program reads this to tempo‑lock.
- Listens for **`ch16 CC118`** (BPM steer) and **`ch16 CC117`** (transport: ≥64 → start, <64 → stop).
- Emits `0xFA` / `0xFC` on transport state changes.
- **Ableton Link (optional).** When `link = on` is set in `/boot/firmware/demiurge.conf` and the binary was built with `-DDEMIURGE_LINK`, the daemon joins an Ableton Link session. Link tempo and transport propagate into `g_bpm` / `g_playing` on every tick; `CC118` / `CC117` writes commit back into Link so network peers (Ableton Live, Max/MSP, iOS/Android music apps, hardware boxes) stay tied to the DEMIURGE session. The usual `0xF8` / `CC119` / `0xFA` / `0xFC` broadcasts still fan out to every language on the MIDI bus — Link just wraps the whole thing in an outer authority.

The read/write split (CC119 broadcast vs CC118 steer) means the daemon never has to filter its own echo — there's no feedback loop to debug.

See `demiurge/docs/clock.md` for the full protocol reference and per‑language reader snippets.

## `wrappers/` (language launch wrappers)

One wrapper script per language — `demiurge-run-csound`, `demiurge-run-chuck`, `demiurge-run-pd`, `demiurge-run-sc`, `demiurge-run-faust`, `demiurge-run-cpp`, `demiurge-run-python`, `demiurge-run-strudel`. Each one sources `demiurge-env.sh` (which sets `LD_LIBRARY_PATH`, `PIPEWIRE_PROPS`, `QT_QPA_PLATFORM=offscreen`, and the default latency) and `exec`s the language runtime with the right flags. The launcher never embeds language CLI knowledge — if you need to tweak Csound's options or Faust's binary path resolution, edit the corresponding wrapper.

Install to `/opt/demiurge/bin/` with the same name:

```bash
sudo install -m 755 src/wrappers/demiurge-env.sh /opt/demiurge/bin/demiurge-env.sh
for w in src/wrappers/demiurge-run-*; do
    sudo install -m 755 "$w" "/opt/demiurge/bin/$(basename $w)"
done
```

## Why these and nothing else

Everything else DEMIURGE needs already exists as an installed binary (csound, pd, sclang, chuck, faust compilers, node, python). The launcher is the glue; the clock is the one service no existing binary provides; the wrappers are the per‑language boilerplate nobody wants to maintain twice. The rest is config.
