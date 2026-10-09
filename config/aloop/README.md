# DEMIURGE virtual interface (snd-aloop)

Makes the DEMIURGE sync layer **run in real-time even with no audio interface
plugged in** — the stated "demiurge works with no interface" goal. This is the
always-on **fallback clock** (Phase 1 of the multi-interface master-clock
design).

## Why this exists

With no audio device, PipeWire **suspends** the sync-layer loopback nodes
(`pw-top` shows `QUANT 0`, the Dummy-Driver idle). Nothing is clocked, so audio
doesn't actually run in real-time and passthrough/latency can't be exercised.

`snd-aloop` is the ALSA loopback kernel module — a **virtual sound card that
provides a real hardware-style clock with zero physical hardware**. Loaded in
its **default (ACP) profile**, the card can clock the whole graph — but **loading
the module is NOT sufficient on its own**. The aloop must be **LINKED into the
graph** (`demiurge-sink-output → aloop` playback) before it actually drives. With
nothing linked, an idle/blank graph still SUSPENDS.

Proven live 2026-06-22: with `snd-aloop` merely loaded but the sink output left
linked to a suspended fallback (HDMI), the blank graph stayed suspended. The
moment `demiurge-sink-output` was relinked to the aloop, every demiurge node went
fully clocked — `R 256 48000 Running` — and the testing system measured, with NO
interface attached, `passthrough: OK` plus `internal 5.333 ms [measured]` (a REAL
measurement, not the computed fallback). So the always-on clock = aloop **loaded
AND linked** to `demiurge-sink-output`. That is the "trick everything into
thinking it's an interface" mechanism. The launcher's `aggregate.rs` performs this
link automatically when no real interface is present (being implemented).

When a real interface is plugged in, demiurge clocks to that instead and the
aloop just sits idle — it is a *fallback* clock, never in the way. The WirePlumber
rule pins it to the LOWEST driver/session priority so any real interface always
outranks it as the graph driver; the aloop only drives when it is the only
candidate.

### Why NOT `use-acp=false`

An earlier version disabled ACP (`api.alsa.use-acp = false`) to expose the raw
PCMs for a DMA-latency-measurement experiment. That approach was **abandoned**
because it **regressed clocking**: raw PCMs suspend until explicitly driven, so
the graph stopped being clocked at idle — the exact opposite of what the
fallback clock needs. The default ACP profile is what we ship, but note that even
ACP only clocks the graph once `demiurge-sink-output` is **linked** to the aloop;
the profile choice does not remove the link requirement. The old raw-PCM
period-size/period-num tuning is gone for the same reason.

## Files

| file                       | installs to                               | purpose |
| -------------------------- | ----------------------------------------- | ------- |
| `demiurge-aloop.modules`   | `/etc/modules-load.d/demiurge-aloop.conf` | load `snd-aloop` at boot |
| `demiurge-aloop.modprobe`  | `/etc/modprobe.d/demiurge-aloop.conf`     | fixed card index 10, id `DemiurgeLoop`, 2 substreams |
| `90-demiurge-aloop.conf`   | `/etc/wireplumber/wireplumber.conf.d/`    | WirePlumber rule: pin 48 kHz, keep clocking, lowest priority, no auto-default |

## Install (run on the Pi)

```
sudo install -m0644 demiurge-aloop.modules  /etc/modules-load.d/demiurge-aloop.conf
sudo install -m0644 demiurge-aloop.modprobe /etc/modprobe.d/demiurge-aloop.conf
sudo install -m0644 90-demiurge-aloop.conf  /etc/wireplumber/wireplumber.conf.d/90-demiurge-aloop.conf
sudo modprobe snd-aloop index=10 id=DemiurgeLoop pcm_substreams=2   # now, without reboot
```

Loading the module is only half the job: the graph stays suspended until
`demiurge-sink-output` is **linked** to the aloop playback. The launcher's
`aggregate.rs` does this link automatically when no real interface is present
(being implemented). To verify by hand, relink `demiurge-sink-output → aloop`
and confirm the demiurge nodes show `R 256 48000 Running` in `pw-top`.

Never leave this half-applied — fully install all three files (and `modprobe`)
or fully revert. Restart PipeWire/WirePlumber for the rule to take effect.

The card is `hw:10` (`DemiurgeLoop`). In the ACP profile it presents as a normal
playback/capture device whose timer drives the graph; the sync layer needs only
that clock, not a raw out→in loop. This is **sync-mode-only** — in bypass mode
PipeWire is stopped and the rule is dormant.
