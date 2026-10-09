# config/

Everything DEMIURGE drops onto the filesystem that isn't source code. `setup-demiurge.sh` installs all of this; the files live here so you can read, diff, and edit them without booting a Pi.

## Two layers, one user-facing surface

DEMIURGE has exactly **one** config file users edit: `~/demiurge/live.conf`. Everything below is the system layer underneath — installed once by `setup-demiurge.sh`, then left alone. The Rust launcher reads `live.conf` and translates it into the internal session graph at runtime; users never see the graph and never edit Rust unless they want to extend the engine itself.

## Subdirectories

### `pipewire/`
- **`demiurge-virtual.conf`** — installed to `/etc/pipewire/pipewire.conf.d/`. Loads two `libpipewire-module-loopback` instances that create `demiurge-sink` (Audio/Sink, `node.linger=true`) and its playback stream `demiurge-sink-output` (`node.passive=true`). This is the virtual audio layer — every program connects here, never to hardware.
- **`demiurge-midi.conf`** — reference only, not installed by setup. Kept in‑tree as a worked example of the PipeWire‑native MIDI graph path we explored before settling on the kernel ALSA seq `Midi Through` bus (which works with every language for free).

### `wireplumber/`
- **`50-demiurge.conf`** — installed to `/etc/wireplumber/wireplumber.conf.d/`. Pins `demiurge-sink` (priority=0 + `node.dont-reconnect`), demotes HDMI so it is never picked as a default, constrains hot-pluggable audio-class devices to the graph rate, ignores Bluetooth. The pinning rule is what keeps the launcher's routing assumptions intact across hot‑plugs.

### `systemd/demiurge.service.d/`
- **`wait-pipewire.conf`** — installed to `/etc/systemd/system/demiurge.service.d/`. Three `ExecStartPre=` steps: (1) block until `pw-link -i` reports `demiurge-sink:playback_FL`, (2) pin the graph rate to 48000, (3) pin the quantum to 128 via `pw-metadata`. Without (1) the launcher races the loopback module and ChucK silently produces no audio; without (2)/(3) WirePlumber's metadata push wins over the static config and the pins never stick. See `gotchas.md` Q7a and Q7c.

### `network/` — connectivity stability pack
See `network/README.md`. Every tool here addresses the Pi as `demiurge.local`, so link stability is a precondition for everything else. Fixes three separate faults that each produced the same "the Pi vanished" symptom: a deleted wifi profile sending the box to a neighbour's subnet, mDNS advertising **both** the wired and wireless addresses so the name resolved to the flaky link while the cable sat idle, and the SoC watchdog hard-resetting the board after an RT audio livelock starved PID 1. Installs a persistent journal (Pi OS ships `Storage=volatile`, so every reboot erased the evidence), NetworkManager defaults including `autoconnect-retries=0`, and `demiurge-netguard` — a 20 s timer plus an NM dispatcher hook that keeps **one link up at a time**: ethernet primary, wifi parked while the cable works, ~6 s failover when it's pulled.

> If you find wifi "mysteriously disconnected" while the cable is in, that is deliberate — see that README.

### `pi5-performance/` — the M8 performance pack
See `pi5-performance/README.md` for the full rationale. Short version: RT limits for `@audio`, PipeWire quantum 128 @ 48 kHz, `performance` CPU governor pinned at boot, a safe Pi 5 overclock (`arm_freq=2800`, `over_voltage_delta=50000`), kernel cmdline additions (`threadirqs usbcore.autosuspend=-1 isolcpus=3` — `nohz_full=3` / `rcu_nocbs=3` are appended too but the stock Raspberry Pi OS kernel rejects both, see that README's "Kernel cmdline reality check"), and a thermal watchdog on a 10‑second timer. All reversible.

## Top‑level files

| File | Installed to | Purpose |
|---|---|---|
| `demiurge.conf.default` | `/boot/firmware/demiurge.conf` (template) | Boot pointer. One line — `launch = <abs path to a live.conf>` — decides which live.conf the launcher reads. Default points at `~/demiurge/live.conf`. |
| `demiurge.service` | `/etc/systemd/system/demiurge.service` | Systemd unit that runs `demiurge-launcher` as user `pi`, with `Restart=on-failure`, RT limits, and `KillMode=mixed` so child engines tear down cleanly on stop. |

## How it fits together

On boot, systemd starts `pipewire.service` → WirePlumber (with `50-demiurge.conf` policy) → the virtual audio layer from `demiurge-virtual.conf` → `demiurge.service` runs (waits for `demiurge-sink:playback_FL`, forces quantum 128) → launcher reads `/boot/firmware/demiurge.conf` → loads `~/demiurge/live.conf` → starts each chain stage under its `demiurge-run-*` wrapper → resolves each program's JACK client name via `pw-link -o` → applies the patch graph → wires MIDI through `Midi Through` (14:0). The M8 pack tightens the kernel and CPU settings underneath all of that so the chain runs at the 128-sample quantum without xruns.
