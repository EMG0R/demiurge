# COD on Demiurge (Phase 12) -- present but dormant

`install-cod.sh` is Demiurge's hook for the public COD repo (github.com/EMG0R/cod). COD must keep
working standalone on a Pi without Demiurge; COD ships no installer yet, so this is the minimal
Demiurge-side copy step. Anything cod grows an installer for should move there and this shrink to one call.

## What it does
- **Download + stay current.** `~/.local/share/cod-update/` is a DEMIURGE_ROOT-parameterized instance of
  the Demiurge updater (`stage`/`swap`, copied to `~/.local/lib/demiurge-cod/`): `versions/<hash>`, `current`,
  remote `https://github.com/EMG0R/cod.git`. `~/cod` -> `current` (only if `~/cod` doesn't exist; `cod-hub.service`
  expects `%h/cod`). `cod-update.timer` (user, 6 h, Nice 19) = stage + swap + `install-cod.sh --refresh`.
  It only reads GitHub, restarts nothing, and is decoupled from `demiurge-update-*`.
- **Installs cod's files:** `~/.local/bin/claude-persist`, `~/.local/bin/cod`, units `cod-tmux`, `cod-agents`,
  `cod-hub` (user units). Agent rules from cod's README are kept: tmux server owned by `cod-tmux`, no `ExecStop`.
  A drop-in points `CLAUDE_BIN` at `~/.npm-global/bin/claude`.
- **Replaces** the old `setup-script/claude-rc/` and `cod-bus/` copies (removed): one mechanism.

## Dormant state
| thing | state |
|---|---|
| `cod-bus.service` | written, **not enabled**, guard drop-in: skipped unless `~/.cod-bus.conf` has `COD_BUS_URL=` and `COD_BUS_TOKEN=` non-empty. No connection, no retry loop. |
| `cod-hub.service` | written, not enabled (loopback-only anyway) |
| `cod-tmux` / `cod-agents` | written; enabled only if agents are already registered (`~/.claude-persist/*.sid`) and the legacy `claude-rc`/`demiurge-agents` units are absent |
| Tailscale | never `up`, no auth key, no hub URL. `COD_TAILSCALE=install` (bootstrap sets it on FRESH images) installs the package only |
| `~/.cod-bus.conf` | never created, never edited |

## "Tank on" (what the COD app does)
1. Link Device: install/auth Tailscale (`tailscale up ...`).
2. Write `~/.cod-bus.conf` (chmod 600): `COD_BUS_NODE`, `COD_BUS_URL`, `COD_BUS_TOKEN`, `COD_BUS_DELIVER=tmux:<agent>`.
3. `systemctl --user enable --now cod-bus.service` (Start tank on this node: also `cod-hub.service`).
4. First agent: `claude-persist <name>`, then `systemctl --user enable cod-tmux cod-agents`.
Re-running the hook later keeps all of this (enables cod-bus again if the conf is valid; never starts anything).
Leave a tank: delete `~/.cod-bus.conf` and `systemctl --user disable --now cod-bus.service`.

## Test (offline, temp HOME, stubbed systemctl/loginctl/tailscale)
`COD_TEST_REMOTE=/path/to/cod-checkout bash setup-script/cod/test-install-cod.sh` (default remote = GitHub).

## What cod should own (not yet in EMG0R/cod)
An installer (`aquarium/install.sh`, flags `--dormant`), a `cod-bus.service` with the guard built in, Tailscale
helper (`cod tailscale link`), claude path resolution via PATH instead of `/usr/local/bin/claude`,
enable-on-register for `cod-tmux`/`cod-agents`, and `cod tank join|leave` that writes/removes `~/.cod-bus.conf`.
