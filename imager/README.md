# Installing DEMIURGE with Raspberry Pi Imager

The image is the primary install path. The first-boot installer (`bootstrap.sh`)
remains supported for building a node from a plain Raspberry Pi OS card.

## One-time step: point Imager at this repository

1. Open Raspberry Pi Imager.
2. **Choose OS** → scroll to the bottom → **Use custom repository**.
3. Paste:

       https://raw.githubusercontent.com/EMG0R/demiurge/main/imager/os-list.json

4. DEMIURGE OS now appears in the OS list. Pick it, choose your card, write.

Imager verifies the download against the checksum in that file, so a corrupted
or truncated download fails loudly instead of producing a card that half-boots.

## Verifying the image yourself

Every release publishes `.sha256` files next to the image. Checking by hand:

    sha256sum -c demiurge-<date>.img.xz.sha256

## What you get

A node that boots, brings up the audio stack, and can self-update
(`setup-script/updater/`). It has no identity of its own until you give it one:
see `MD/device.template.md`.

## What is NOT in the image

No credentials, no SSH host keys (regenerated on first boot, so no two nodes
share an identity), no wifi configuration, no author's personal instrument,
node registry or memory. Every published image is audited for those before
release — see the seal and audit steps in `FLASHING.md`.

## Fields a release must fill in `os-list.json`

| field | what it is |
|---|---|
| `url` | the GitHub Release asset URL for the `.img.xz` |
| `image_download_size` | size in bytes of the **compressed** `.img.xz` |
| `extract_size` | size in bytes of the **uncompressed** `.img` |
| `extract_sha256` | sha256 of the **uncompressed** `.img` |
| `release_date` | `YYYY-MM-DD` |

`extract_size` and `extract_sha256` are the two that get mistyped, and Imager
fails unhelpfully when they are wrong. They describe the file *after*
decompression, not the download.
