# config/network/ — connectivity stability pack

The operational files (guard script, systemd units, NetworkManager/polkit
drop-ins) live in this directory and are installed by
`setup-script/setup-demiurge.sh` — do not move them, the install script
references this directory by path.

**Full reference doc, history, and troubleshooting: [`demiurge/docs/wifi.md`](../../demiurge/docs/wifi.md).**
