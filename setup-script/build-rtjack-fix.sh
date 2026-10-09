#!/bin/bash
# build-rtjack-fix.sh — rebuild csound 6.18 librtjack.so with the long-port-name
# stack-overflow fix. InOut/rtjack.c listDevices/listDevicesM copy full JACK port
# names into a 64-byte stack buffer via strNcpy(port, name, strlen+1); pipewire-jack
# port names (e.g. the Focusrite Scarlett's) exceed 63 chars -> *** stack smashing
# detected *** on every JACK open. Caps the copy at sizeof(port). No sudo (build only).
set -euo pipefail
TAG=6.18.1
B=/tmp/rtbuild; rm -rf "$B"; mkdir -p "$B/dev"; cd "$B"
apt-get download libcsound64-dev
dpkg-deb -x libcsound64-dev_*.deb "$B/dev"
gh=https://raw.githubusercontent.com/csound/csound/refs/tags/$TAG
curl -fsSL "$gh/InOut/rtjack.c"      -o rtjack.c
curl -fsSL "$gh/InOut/alphanumcmp.c" -o alphanumcmp.c
curl -fsSL "$gh/InOut/alphanumcmp.h" -o alphanumcmp.h
curl -fsSL "$gh/H/cs_jack.h"         -o cs_jack.h
sed -i 's#strNcpy(port, portNames\[i\], n+1);#strNcpy(port, portNames[i], sizeof(port)); /* DEMIURGE: cap to buf size (pipewire names can exceed 63 chars) */#' rtjack.c
gcc -shared -fPIC -O2 -DUSE_DOUBLE -I"$B/dev/usr/include/csound" -I"$B" \
    rtjack.c alphanumcmp.c -ljack -lpthread -o "$B/librtjack.so"
echo "built: $B/librtjack.so"
