# Demiurge updater (skeleton) — SHIPPED DISABLED

!!! DO NOT ENABLE ON A LIVE AUDIO Pi (NEPTR / TWINK NEPTR in performance). !!!
Nothing here is installed or enabled by `install.sh` or `setup-demiurge.sh`.
Layout migration (`/demiurge/current` symlink) is not done yet; until it is, every
script refuses to act.

Model (bathtub §5), SYNC bucket:
- `stage` (timer, 6 h): `ls-remote` EMGOR's remote; if newer, shallow-clone into
  `/demiurge/versions/<hash>` under Nice=19, idle IO, core 0, 25% CPU. Verifies, then
  sets `/demiurge/next`. Never touches `current`.
- `swap` (boot, before demiurge.service): flips `current` to `next` with one atomic
  symlink rename; old one becomes `previous`.
- `revert`: flips back and pauses updates (`/demiurge/local/NO_SWAP`).
- `/demiurge/local` (LOCAL bucket) is outside versions and symlinked into each one.

Enable (one command, a non-live Pi only):

    sudo CONFIRM_NOT_LIVE_AUDIO=yes bash setup-script/updater/enable.sh

Then put `DEMIURGE_REMOTE=<public EMGOR repo url>` in `/demiurge/local/updater.conf`.
Disable: `sudo systemctl disable --now demiurge-update-stage.timer demiurge-update-swap.service`.

Untested on a Pi (syntax-checked only). Big audio files (git-lfs/rsync) not handled yet.

## Self-update + per-release apply
After a successful flip, `swap` runs `current/setup-script/updater/post-swap.sh` (root, 60 s timeout,
failure never undoes the swap). It (a) reinstalls changed updater scripts/units into `/opt/demiurge/bin`
and `/etc/systemd/system`, (b) writes `/demiurge/local/apply-pending`. `demiurge-apply.service`
(After user@/network-online, never touches audio units) then runs `setup-script/apply-user.sh` as the rig
user (`DEMIURGE_USER` in `local/updater.conf` or `local/device.md`, else the lingering user) and clears
the marker on success. apply-user.sh currently re-runs `cod/install-cod.sh` (dormant COD).

### One-time bootstrap for a node whose installed swap.sh predates post-swap
After the first stage of a release containing these files, once `/demiurge/current` has the new tree:

    sudo CONFIRM_NOT_LIVE_AUDIO=yes bash /demiurge/current/setup-script/updater/enable.sh

It installs the new swap/apply scripts + units and sets `apply-pending`; the next boot applies. (Run it
only when audio is not live; it starts nothing.) Afterwards updates are fully self-maintaining.

Test (offline): `bash setup-script/updater/test-post-swap.sh`.
