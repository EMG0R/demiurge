# DEMIURGE

DEMIURGE is an audio-first Raspberry Pi OS: a flashable distro layered on
top of Raspberry Pi OS Lite that turns a Pi into a dedicated, low-latency
audio instrument host.

- **PipeWire** owns audio and MIDI routing. Every program connects to one
  virtual sink and one virtual MIDI merge port, so hardware can be hot-plugged
  without reconfiguring anything.
- **Every major audio language ships pre-installed and pre-wired**: Csound,
  Pure Data, SuperCollider, ChucK, Faust, RNBO, Strudel, C++ (JACK), Python.
- **A single live patch file (`live.conf`)** describes the chain. (The Rust
  launcher that hot-reloads it is not part of this export yet.)
- **One global MIDI clock**, with optional Ableton Link, so every language in
  the chain shares tempo for free.
- **A self-updater** that stages new releases in the background and only
  swaps them in at boot. (The web UI is not part of this export yet.)

## Install

On a fresh Raspberry Pi OS Lite (64-bit) install:

```
bash bootstrap.sh
```

See `BOOTSTRAP.md` for what the bootstrap does step by step, `FLASHING.md`
for imaging the SD card itself, and `INSTRUCTIONS.md` for the full reference.
`install.sh` and `setup-script/` hold the individual installers this calls.

## Update

DEMIURGE includes a self-updater in `setup-script/updater/`: a timer checks
a configured git remote, stages a new version under `/demiurge/versions/`
without touching the running system, and swaps it in atomically at the next
boot. It ships disabled. See `UPDATING.md` for how it works and how to turn
it on.

## What this repo is NOT

This is the distro: the installer, the audio chain wrappers and config, and
the updater. It is not any one person's instrument. The owner's personal
instrument configuration, physical node registry, agent personas, memory,
and credentials live in a separate private repository and are never part of
this one.
