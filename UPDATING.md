# Updating DEMIURGE

The self-updater lives in `setup-script/updater/`. It ships **disabled** —
nothing in `install.sh` or `setup-script/setup-demiurge.sh` enables it, and
every one of its scripts refuses to act until you explicitly turn it on.

## How it works

Three scripts, all guarded to never restart audio or act on a live rig:

- **`demiurge-update-stage.sh`** — runs on a timer (every 6 hours, low
  priority: `Nice=19`, idle I/O, pinned to core 0, 25% CPU quota). It checks
  the configured git remote with `git ls-remote`; if there's a newer commit
  on the branch, it shallow-clones it into `/demiurge/versions/<hash>/`,
  verifies the clone has the files a real DEMIURGE tree needs
  (`setup-script/setup-demiurge.sh`, `demiurge/live.conf`, `MD/DEMIURGE.md`)
  and that every shell script in it parses (`bash -n`), then points
  `/demiurge/next` at it. It never touches `/demiurge/current` and never
  restarts anything.
- **`demiurge-update-swap.sh`** — runs once at boot, before `demiurge.service`
  starts. If something is staged in `/demiurge/next`, it atomically flips the
  `/demiurge/current` symlink to point at it (the old version becomes
  `/demiurge/previous`). This is the only script that changes what the
  running system will use, and it only ever runs before boot, never while
  the instrument is live.
- **`demiurge-update-revert.sh`** — flips `current` back to `previous` and
  drops a `/demiurge/local/NO_SWAP` flag so the bad version isn't re-applied
  on the next boot. Takes effect at the next boot/service start; does not
  restart audio itself.

A `/demiurge/local/` directory (outside the versioned tree) holds node-local
config — including `updater.conf`, where you set the remote — and is
symlinked into whichever version is current, so local settings survive
updates.

## Enabling it

Not for a live performance rig. On a non-live Pi:

```
sudo CONFIRM_NOT_LIVE_AUDIO=yes bash setup-script/updater/enable.sh
```

This installs the three scripts to `/opt/demiurge/bin/`, installs the
systemd units, and enables `demiurge-update-swap.service` and
`demiurge-update-stage.timer` (enable only — nothing is started
immediately). Then set your remote:

```
echo 'DEMIURGE_REMOTE=https://github.com/EMG0R/demiurge.git' | sudo tee -a /demiurge/local/updater.conf
```

To disable:

```
sudo systemctl disable --now demiurge-update-stage.timer demiurge-update-swap.service
```

Note the updater units are also gated on `/demiurge/current` already being a
symlink (the versioned-tree layout). If your install predates that layout,
the units will see the `ConditionPathExists`/script guard fail and simply do
nothing until it's migrated.
