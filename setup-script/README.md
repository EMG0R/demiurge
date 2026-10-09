# setup-script/

One idempotent installer that turns a fresh Pi OS Lite Bookworm (64‑bit) image into a working DEMIURGE system. Run it on the Pi over SSH:

```bash
cd ~/_______DEMIURGE
./setup-script/setup-demiurge.sh
```

Re‑running is safe — every step checks state before acting. `INSTRUCTIONS.md` at the repo root is the concept‑first companion: it explains *why* each step exists, which silent‑failure modes it prevents, and how to debug when something goes wrong. Read it once before running the script on a machine you care about.

## What each phase does

| Phase | What it installs / configures | Concept |
|---|---|---|
| **1 — Foundation** | apt base: build tools, `alsa-utils`, `sox`, `ffmpeg`, liblo, `curl`. Adds the user to the `audio` group. Bootstraps `rustup` + stable Rust toolchain (minimal profile) so Phase 6 can build the launcher. | Prereqs. Nothing DEMIURGE‑specific yet. |
| **2 — PipeWire** | `pipewire`, `pipewire-alsa`, `pipewire-jack`, `wireplumber`, `pipewire-pulse`. Removes PulseAudio. Enables the user services. | Replaces the entire audio stack. JACK and PulseAudio become thin shims over the PipeWire graph. |
| **3 — Virtual audio layer** | Drops `/etc/pipewire/pipewire.conf.d/demiurge-virtual.conf` — a `libpipewire-module-loopback` pair that creates the `demiurge-sink` Audio/Sink with `node.linger=true`. Installs `config/wireplumber/50-demiurge.conf` to pin `demiurge-sink` with `priority.session=0` + `dont-reconnect=true` so WirePlumber can never route chain outputs around it. | Every program connects to one virtual sink. Hardware hot‑plug is invisible — audio plays into the void when nothing is attached and resumes when something is. |
| **4 — Virtual MIDI layer** | Ensures the `snd-seq-dummy` kernel module is loaded so `Midi Through` (ALSA seq `14:0`) exists. Installs the udev rule + `demiurge-midi-connect.sh` that auto‑merges USB controllers into the shared bus on hot‑plug. | One MIDI pool. Every program reads AND writes `Midi Through`. No per‑program MIDI routing. |
| **5 — Audio languages** | apt + pin‑managed installs: `csound`, `puredata`, `supercollider`, `chuck`, `faust` + `faust2jackconsole`, `strudel-runner.mjs` node deps pinned to `@strudel/*@1.2.0`, Python venv with `mido python-rtmidi python-osc ctcsound numpy`. Installs C++ build deps. | Every major live‑audio language, already wired to the graph. The launcher knows how to start each one. |
| **6 — Launcher + staging** | Builds `demiurge-clock` from `src/demiurge-clock.cpp` (with `-DDEMIURGE_LINK` when `ableton-link-dev` is present) and installs it to `/opt/demiurge/bin/`. Builds the Rust launcher from `src/demiurge-launcher-rs/` (`cargo build --release`) and installs the ~460 KB `demiurge-launcher` binary plus every `src/wrappers/demiurge-run-*` to `/opt/demiurge/bin/`. Rsyncs the `demiurge/` tree to `~/demiurge/` but **never overwrites an existing `~/demiurge/live.conf`** — the user's live config is sacred. Installs the `demiurge.service` unit, its `wait-pipewire.conf` drop-in (ExecStartPre gate that polls for `demiurge-sink:playback_FL` and forces PipeWire's `clock.force-quantum = 128` via `pw-metadata` before the launcher starts), and `cpu-affinity.conf` (pins the launcher and every child it forks to CPU 3, the core reserved by `isolcpus=3`). | The Rust launcher is the brain: event‑driven supervisor, idempotent USB audio aggregation, graceful‑failure graph. `demiurge_clock` is the only extra service because no existing binary provides it. `~/demiurge/` is the workspace. Systemd auto‑starts the session on boot. |
| **7 — M8 performance pack** | RT limits, PipeWire quantum 128 @ 48 kHz, `performance` CPU governor at boot, thermal watchdog, IRQ isolation, audio IRQ-thread RT priority (`demiurge-audio-irq-rt` — derives the interrupt that paces *this* interface at runtime, so USB / I2S HAT / HDMI are treated identically), the vendor-neutral `demiurge-audio-bounce.sh` helper used by the launcher's `ensure_usb_rates_stable()`, removal of the retired `demiurge-usb-irq-rt` + `demiurge-scarlett-*` units, fast-boot service masking. | Turns the Pi into an instrument, not a generic Linux box. All reversible — see `config/pi5-performance/README.md`. |
| **8 — Boot config (overclock + kernel cmdline)** | Interactive/DANGEROUS: prompts for confirmation, then backs up and edits `/boot/firmware/config.txt` (`arm_freq=2800`, `over_voltage_delta=50000`, `gpu_freq=500`, `usb_max_current_enable=1`, etc.) and `/boot/firmware/cmdline.txt` (`threadirqs isolcpus=3 fsck.mode=skip …`; `nohz_full=3 rcu_nocbs=3` are appended too but the stock kernel rejects both), then reboots. Requires the official 5V/5A USB-C PSU and active cooling. Idempotent and re-runnable (`./setup-demiurge.sh 8`); both files are timestamped-backed-up before any edit. | The overclock + `isolcpus` split that makes CPU 3 a dedicated real-time audio core, plus the USB current fix needed to stop under-voltage throttling with a bus-powered interface attached. Because it reboots and can (in theory) make the Pi unbootable if misapplied, it's kept as its own confirm-gated phase rather than folded into Phase 7 or run non-interactively. See `incidents/2026-07-13-psu-verification-resolved.md` for the verified-good measurements. |
| **9 — Web UI (demiurge-web)** | Installs `web/demiurge_web.py` + `web/static/{index.html,app.js,style.css}` to `/opt/demiurge/web/`, plus `config/demiurge-web.service` (User=pi, `CPUAffinity=0-2`, `Nice=10`, deliberately **not** `PartOf=demiurge.service` so the UI survives an audio-side stop). Enables and starts the service. | A stdlib-only Python status daemon + browser mirror of the terminal companion; serves `http://demiurge.local:8080` and writes `~/.demiurge/status` every 2 s. Since Phase 8 ends in a reboot, run this phase separately on a fresh install: `./setup-demiurge.sh 9`. |
| **10 — RNBO** | Adds Cycling '74's apt repo + key (informational candidate check only — nothing installed from it), installs the from-source build toolchain (apt packages + pinned conan 1.66.0 + c++20/libstdc++11 profile), then clones and builds `rnbo.oscquery.runner` **from source** (`setup-script/rnbo-build-runner.sh`, pinned to tag `v1.4.5-9`, on-device compile enabled) and installs the resulting binary to `/opt/rnbo/bin/rnbooscquery`. Installs the runner config, the auto-reload watcher (`--user` service), the gate script, and `rnbo-runner.service` (User=pi placeholder templated the same way as `demiurge.service`/`demiurge-web.service`). Enables the service (fail-closed gated, so `enable --now` condition-skips cleanly when RNBO isn't in use). | RNBO (Cycling '74) support, folded into the standard install. The prebuilt apt package ships on-device compile **disabled**, so this phase does a real from-source compile — expect it to take a while the first time (conan builds libossia/boost/etc. from source too), much faster on re-runs once conan's cache is warm. `config/rnbo/demiurge-rnbo-gate.sh` (an `ExecCondition`) keeps `rnbo-runner.service` down unless `live.conf` has `rnbo = on` or a `*.rnbo` file is in the chain. See `demiurge/docs/rnbo.md` for the full rationale. |

## Backup kit (Mac side)

| Script | What it does |
|---|---|
| `backup-rig.sh` | Pull-only, copy-only. Mirrors the Pi's `~/demiurge/*`, user audio fragments, RAM state and system files into `rig-backup/latest/<host>/`, plus a dated tarball (last 5 kept). Never writes or deletes on the Pi. Exits non-zero only if ssh fails. |
| `restore-rig.sh` | Pushes user files back. Skips existing Pi files unless `--force` (old copy kept as `.pre-restore`). `--dry-run` supported. Never touches `/etc`; prints the sudo commands instead. |

Both read `pi-rig.conf` (override with `PI_USER` / `PI_HOST`). The installer seeds `live.conf`, `sets/`, `presets/`, `state/`, `asound.state` and friends from `rig-backup/latest/<host>/home/demiurge/` when the rig has none. See `rig-backup/README.md`.

## When things go wrong

Every phase echoes `=== Phase N complete ===` on success. If a phase fails, stop there and check `INSTRUCTIONS.md §12` (failure modes F1–F29) — it covers the full diagnostic tree: libjack collisions, DSP‑off Pd silence, `--sched` / Csound scheduling crashes, the Faust hardware auto‑link problem, and how to verify audio with `pw-jack jack_rec` (never `pw-record --target=`, which silently captures the mic).

Phase 8 now applies and reboots for the cmdline.txt/config.txt kernel tokens
automatically (see the phase table above) — the manual snippet files at
`config/pi5-performance/cmdline.txt.additions` and
`config/pi5-performance/config.txt.snippet` are kept only as reference for
what Phase 8 writes, and as a manual fallback if you ever need to reapply
them by hand.

## COD (Phase 12): dormant agent persistence + tank client

Phase 12 runs `setup-script/cod/install-cod.sh`: downloads public `EMG0R/cod`, installs its `claude-persist`, `cod-tmux`/`cod-agents` units and the `cod` client, and keeps the checkout current through `cod-update.timer` (the Demiurge `stage`/`swap` scripts, parameterized by `DEMIURGE_ROOT`; never touches audio). **Dormant:** no tank membership, no Tailscale login, no outbound bus connection until the COD app writes `~/.cod-bus.conf`. Full details, the "tank on" contract and the offline test: `setup-script/cod/README.md`.
