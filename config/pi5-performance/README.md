# DEMIURGE M8 — Pi 5 performance block

Drop-in performance snippets for Milestone 8 (Max Performance).

> **Day-to-day power / audio / patch control is the `demiurge` terminal
> companion** (Mac-side, over SSH) — see
> [`../../demiurge/docs/companion.md`](../../demiurge/docs/companion.md). This
> directory is the **boot-layer foundation** the companion sits on top of:
> `config.txt*`, cmdline, the performance governor, IRQ/RT isolation and the
> thermal watchdog. These apply at boot regardless.
>
> **Everything here is interface-agnostic.** Nothing in this directory names an
> audio-interface vendor or assumes a bus: the audio IRQ is derived at runtime
> from the cards actually present, so a USB interface (any brand), an I2S HAT
> (any brand), HDMI and an on-SoC codec all get the same treatment.

| File | Install to | Purpose |
|---|---|---|
| `config.txt.snippet` | append to `/boot/firmware/config.txt` | Safe Pi 5 overclock (2800 MHz, +50 mV, active cooling required) — **PSU mode** |
| `config.txt.laptop.snippet` | append to `/boot/firmware/config.txt` **instead of** `config.txt.snippet` | **Laptop / weak-supply** boot block: arm_freq 1500, **no over_voltage**, USB current raised (always — user-locked for Teensy inrush). Boot half of the no-brownout guarantee. |
| `cmdline.txt.additions` | append tokens to `/boot/firmware/cmdline.txt` | `threadirqs`, `usbcore.autosuspend=-1`, `isolcpus=3`. (`nohz_full=3` / `rcu_nocbs=3` are also listed there but the stock Raspberry Pi OS kernel **rejects both** — see "Kernel cmdline reality check" below.) |
| `../systemd/demiurge.service.d/cpu-affinity.conf` | `/etc/systemd/system/demiurge.service.d/` | `CPUAffinity=0-2` + `AllowedCPUs=0-3` — keeps the *launcher and its helpers* off CPU 3 while leaving CPU 3 admissible to the unit's cgroup, so the engine alone can pin itself there via `DEMIURGE_RT_PIN`. Do **not** "simplify" this to `CPUAffinity=3` (a silent no-op — the cgroup cpuset clamps it) or `AllowedCPUs=3` (measured *worse* than no pinning: launcher helpers then preempt the engine). Installed automatically by `setup-demiurge.sh` Phase 6. |
| `demiurge-audio.limits.conf` | `/etc/security/limits.d/` | RT limits for `@audio` group (`rtprio 99`, unlimited memlock, nice -20) |
| `demiurge-pipewire-lowlatency.conf` | `/etc/pipewire/pipewire.conf.d/99-demiurge-lowlatency.conf` | Quantum 128 default / 32 min at 48 kHz. The `wait-pipewire.conf` systemd drop-in also forces `clock.force-quantum = 128` via `pw-metadata` at every `demiurge.service` start. |
| `demiurge-power.sh` | `/usr/local/bin/` | Applies live.conf `power = low\|medium\|high` (+ `cpu_max_mhz`, `cpu_cores`): governor `performance`, min/max freq, cores online. low = 3 cores flat 2000 MHz, medium = all 1500..2400, high = all up to `cpuinfo_max_freq` (the `config.txt.snippet` overclock). Replaces the old cpu-governor unit. |
| `demiurge-power.service` | `/etc/systemd/system/` | Root oneshot, boot, before `demiurge.service`; `demiurge-power <level>` restarts it |
| `demiurge-thermal-watchdog.sh` | `/usr/local/bin/` | Logs `vcgencmd measure_temp` + `get_throttled` with WARN/CRITICAL levels |
| `demiurge-thermal-watchdog.service` | `/etc/systemd/system/` | Oneshot unit fired by the timer |
| `demiurge-thermal-watchdog.timer` | `/etc/systemd/system/` | Every 10 s |
| `demiurge-irq-isolate.sh` | `/usr/local/bin/` | Writes `0-2` into every `/proc/irq/*/smp_affinity_list` so userspace IRQs avoid CPU 3. `isolcpus=3` alone is NOT enough: the kernel's default IRQ affinity is the full mask, so audio/storage/network interrupts still land on CPU 3 and preempt the audio thread mid-block. Each ~30-50us IRQ on CPU 3 during a 2.67 ms quantum causes an xrun that sounds like a click or bitcrush artifact. This script fixes that at boot. It also writes `7` to `/sys/devices/virtual/workqueue/cpumask` so **unbound** kernel workqueues stop placing workers on CPU 3 — hygiene only, see "What is actually on CPU 3" below. |
| `demiurge-irq-isolate.service` | `/etc/systemd/system/` | Runs the IRQ script at boot before `demiurge.service` |
| `demiurge-audio-irq-rt.sh` | `/usr/local/bin/` | Raises the threaded-IRQ handlers **that actually pace audio** to `SCHED_FIFO 85` (default 50; the engine runs at 74). Whichever interrupt wakes the engine each block — a USB host controller, an I2S DMA engine, something else — must outrank the engine and the other FIFO-50 irq threads, or its wake-up jitter eats a meaningful slice of the period budget at 128 frames and below. **The IRQ set is derived at runtime, never hardcoded**: USB host controllers structurally from `/sys/bus/usb/devices/usb*`, sound-card IRQs from sysfs where exposed, and — the general case — whatever IRQ is observed advancing at audio rate while a stream is `RUNNING`. See the script header. |
| `demiurge-audio-irq-rt.service` | `/etc/systemd/system/` | Runs the audio IRQ boost at boot, before `demiurge.service`, then keeps watching for a stream to start so it can derive the pacing IRQ for whatever interface is in use. Never fails. |
| `demiurge-audio-bounce.sh` | `/usr/local/bin/` | On-demand sysfs unbind/bind that makes WirePlumber re-enumerate a hot-pluggable interface whose node negotiated the wrong sample rate. Device set derived from the attached cards (no vendor IDs); silent no-op for permanently-powered cards (I2S HAT, HDMI, loopback). **Script only — no boot unit**; called by the launcher's `ensure_usb_rates_stable()` and by hand. |

## Requirements before enabling

- **PSU**: official 5V / 5A USB-C. A 3A phone charger will brown out at load.
- **Cooling**: official Pi 5 Active Cooler or equivalent. No heatsink = no overclock.
- **Thermal watchdog enabled** before raising `arm_freq`, so you have a log the first time something gets hot.

## Enable order

```bash
# 1) install governor + watchdog first (these are safety infrastructure)
sudo install -m 0755 demiurge-power.sh             /usr/local/bin/
sudo install -m 0755 demiurge-thermal-watchdog.sh  /usr/local/bin/
sudo install -m 0644 demiurge-power.service              /etc/systemd/system/
sudo install -m 0644 demiurge-thermal-watchdog.service   /etc/systemd/system/
sudo install -m 0644 demiurge-thermal-watchdog.timer     /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now demiurge-power.service
sudo systemctl enable --now demiurge-thermal-watchdog.timer

# 1b) IRQ isolation — required for xrun-free audio at quantum = 128
sudo install -m 0755 demiurge-irq-isolate.sh      /usr/local/bin/
sudo install -m 0644 demiurge-irq-isolate.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now demiurge-irq-isolate.service

# 1c) audio IRQ-thread RT priority — wake-up jitter floor at 64/128 frames
sudo install -m 0755 demiurge-audio-irq-rt.sh      /usr/local/bin/
sudo install -m 0644 demiurge-audio-irq-rt.service /etc/systemd/system/
sudo install -m 0755 demiurge-audio-bounce.sh      /usr/local/bin/
sudo systemctl daemon-reload
sudo systemctl enable --now demiurge-audio-irq-rt.service

# 2) RT limits (takes effect at next login)
sudo install -m 0644 demiurge-audio.limits.conf /etc/security/limits.d/demiurge-audio.conf

# 3) PipeWire low-latency config
sudo install -m 0644 demiurge-pipewire-lowlatency.conf /etc/pipewire/pipewire.conf.d/99-demiurge-lowlatency.conf
systemctl --user restart pipewire wireplumber

# 4) FINALLY — the overclock + cmdline. These need a reboot. Do them LAST.
#    Append config.txt.snippet to /boot/firmware/config.txt manually.
#    Append cmdline.txt.additions tokens to /boot/firmware/cmdline.txt manually.
sudo reboot
```

## Verifying after reboot

```bash
vcgencmd measure_clock arm          # should report ~2.8 GHz under load
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor    # performance
cat /sys/devices/system/cpu/isolated                          # 3
journalctl -u demiurge-thermal-watchdog -f                    # live temps
ulimit -r                                                     # 99
pw-metadata -n settings 0 clock.force-quantum                 # 128
taskset -p $(systemctl show demiurge.service -p MainPID --value) | awk '{print $NF}'   # 8 (= CPU 3 only)
cat /proc/irq/default_smp_affinity                            # 7 (= CPUs 0-2, IRQs avoid CPU 3)
ps -eLo rtprio,cls,comm | awk '$1==85'                        # the pacing irq thread(s) for THIS interface
journalctl -u demiurge-audio-irq-rt                           # which IRQ it derived, and why
grep . /proc/irq/*/smp_affinity_list | grep -v '^.*:3$' | wc -l  # should match most IRQs; pinned ones skip
```

## Kernel cmdline reality check

Measured on stock Raspberry Pi OS (Pi 5, `dmesg`), 2026-08-10:

| Token | Actually applied? | Evidence |
|---|---|---|
| `threadirqs` | **yes** | `irq/N-*` threads exist in `ps` |
| `usbcore.autosuspend=-1` | **yes** | — |
| `isolcpus=3` | **yes** | `cat /sys/devices/system/cpu/isolated` → `3` |
| `nohz_full=3` | **NO — rejected** | `Housekeeping: nohz unsupported. Build with CONFIG_NO_HZ_FULL`; `/sys/devices/system/cpu/nohz_full` does not exist |
| `rcu_nocbs=3` | **NO — rejected** | `Unknown kernel command line parameters "… nohz_full=3 rcu_nocbs=3", will be passed to user space` |

The last two are inert on this kernel and are kept on the cmdline only for
forward compatibility with a custom kernel built with `CONFIG_NO_HZ_FULL`.
Do not describe the isolation as "isolcpus + nohz_full + rcu_nocbs" — the
working isolation is `isolcpus=3` + the per-process pin (`DEMIURGE_RT_PIN`)
+ `demiurge-irq-isolate.sh` + the `performance` governor.

## What is actually on CPU 3

Audited 2026-08-11 with the engine live. **Conclusion: CPU 3 is already clean.
There is no non-audio workload left to evict.** Recorded here so nobody spends
another evening rediscovering it.

**Nothing non-audio ever lands on CPU 3.** 300 samples of `ps -eLo psr,tid,comm`
over 90 s found exactly six userspace threads on CPU 3, all of them the audio
path: 3 × `demiurge-csound`, 2 × `pw-csound6`, and PipeWire's `data-loop.0`.
`neptr-ui`, `demiurge-touch`, `demiurge-web`, `demiurge-monitor`, `wireplumber`
and the PipeWire main loop appeared **zero** times. This holds even though
`neptr-ui`, `demiurge-touch` and `demiurge-monitor` have an unrestricted
`0-3` affinity mask — `isolcpus=3` is carrying them on its own.

> `data-loop.0` living on CPU 3 is correct — it is the engine's own PipeWire
> data loop. Pinning it *off* CPU 3 was tried and measured **worse**. Leave it.

**No device IRQ fires on CPU 3.** Every counted device interrupt in
`/proc/interrupts` (eth0, i2c, spi, xhci, mmc0/1, v3d, hvs, `ads7846` touch,
vc4 crtc, `dw_axi_dmac`) shows its entire count on CPU 0. `demiurge-irq-isolate.sh`
is doing its job. A few IRQs still *report* an `0-3` affinity mask
(`pwr_button`, the two `107d5082*.i2c`, the `hvs` trio) but their CPU 3 columns
are all zero.

**What remains on CPU 3 is kernel bookkeeping that cannot preempt the engine.**
Measured over 60 s via `/proc/<tid>/schedstat`:

| Thread | Class | On-CPU per 60 s | % of CPU 3 |
|---|---|---|---|
| `ksoftirqd/3` | SCHED_OTHER | 36.4 ms | 0.061 % |
| `kworker/3:1-events` | SCHED_OTHER | 0.80 ms | 0.0013 % |
| `ktimers/3` | FIFO 1 | 0.54 ms | 0.0009 % |
| `kworker/3:1H`, `3:2H`, `3:2` | SCHED_OTHER | 0 ns | idle |
| **total** | | **≈ 37.7 ms** | **≈ 0.063 %** |

The engine runs **SCHED_FIFO 74**. Every thread above is SCHED_OTHER or FIFO 1,
i.e. strictly *below* it, so none of them can preempt a block mid-DSP — they
only get the core while the engine sleeps between blocks. The one exception is
`migration/3` (FIFO 99), which only runs to service a migration request.

**Therefore evicting the CPU 3 kworkers is not a latency fix**, and the
workqueue cpumask write in `demiurge-irq-isolate.sh` should not be credited
with one. It is a guard against *future* unbound work, nothing more. Note also
that per-CPU worker pools (`kworker/3:0`, `kworker/3:1`, `kworker/3:0H`,
`kworker/3:1H-kblockd`) are bound to CPU 3 by construction and **cannot** be
moved by any sysfs knob — they will still show up in `ps` afterwards. Anyone
claiming a "clean sweep" of CPU 3 kworkers has misread the output.

**Cores 0-2 are not contended**, so there is nothing to gain from hand-spreading
the UI / touch / web daemons across them: measured 6 % / 6 % / 5 % busy over
20 s with the UI running. Deliberate distribution was considered and rejected
as premature — revisit only if a core actually saturates.

**Residual, not fixable from userspace:** the `arch_timer` tick still fires on
CPU 3 (33 M counts) and RCU callbacks are still processed there in softirq
(3.66 M). Both would be addressed by `nohz_full=3` / `rcu_nocbs=3` — which this
kernel **rejects** (see "Kernel cmdline reality check"). Fixing them requires a
custom kernel with `CONFIG_NO_HZ_FULL`; at 0.063 % total overhead that is not
currently worth it.

## Back-out

If anything misbehaves: comment out the `arm_freq` / `over_voltage_delta` lines
in `config.txt` and reboot. The Pi will return to stock 2400 MHz immediately.

## Power modes & the laptop brownout

Power level (**low / medium / high**) is driven from the `demiurge` companion
(keys `l`/`m`/`h`, or the `lowdemiurge` / `mediumdemiurge` / `highdemiurge`
commands), which sets the cpufreq governor + ceiling + online cores over SSH at
runtime — see [`../../demiurge/docs/companion.md`](../../demiurge/docs/companion.md).
This README covers the **boot layer** those modes sit on.

### Brownout guarantee (powered FROM a MacBook USB-C port)

A laptop USB-C *host* port gives 5V / ~15W — **not** the Pi 5's 5V/5A/25W PD
contract. Undervolt trips around ~4.65–4.8V at the connector, so your margin is
~0.3V and the **transient** (cores ramping in lockstep with over-voltage) is what
sags the rail and browns out audio. A reactive governor can't help — it reacts
*after* the sag. So the guarantee is a **static low ceiling + no over-voltage**,
which is two halves:

1. **Runtime half** — `low` power (companion `l` / `lowdemiurge`) pins the cores
   *flat* at the lowest OPP (min=max), so they never ramp → no di/dt spike, and
   keeps only 2 cores online.
2. **Boot half** — append `config.txt.laptop.snippet` **instead of**
   `config.txt.snippet`: `arm_freq=1500`, **over_voltage_delta removed**,
   `usb_max_current_enable` left at default. over_voltage is boot-only, so without
   this half the guarantee is *reduced, not met*.

The config can't fix the electrical part: short/thick USB-C cable, a bulk-cap /
power-bank passthrough on 5V, and ideally power the Pi from its own PSU with
data-only to the laptop. Prove it holds — the undervolt bit must stay `0x0`
under a full-load test:

```bash
vcgencmd get_throttled                       # want throttled=0x0
journalctl -u demiurge-thermal-watchdog -f   # watch undervolt_* during a load test
cat /sys/devices/system/cpu/online           # laptop → 0,3 (cpu0 + audio core)
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_{min,max}_freq   # equal = pinned flat
```

## Audio on/off

Start/stop the whole audio system from the companion (`s` / `x`) or the `~/.zshrc`
aliases `redem` (restart) / `stodem` (stop). See
[`../../demiurge/docs/companion.md`](../../demiurge/docs/companion.md).

### Switching PSU ↔ laptop

- **PSU / performance:** `config.txt.snippet` block in `config.txt`, companion
  `h` (`highdemiurge`), reboot.
- **Laptop / weak supply:** swap to `config.txt.laptop.snippet`, companion `l`
  (`lowdemiurge`), reboot.
