#!/usr/bin/env bash
# Clone (if needed) and build Magic Lantern for the Canon EOS 80D (fw 1.0.3).
# Produces: $WORKROOT/magiclantern_simplified/platform/80D.103/build/
#             autoexec.bin, magiclantern.zip
set -euo pipefail

WORKROOT="${WORKROOT:-/home/user/src}"
ML_REPO="${ML_REPO:-https://github.com/reticulatedpines/magiclantern_simplified.git}"
ML_DIR="$WORKROOT/magiclantern_simplified"
PLATFORM="80D.103"

mkdir -p "$WORKROOT"
if [ ! -d "$ML_DIR/.git" ]; then
    echo ">> cloning Magic Lantern ..."
    git clone "$ML_REPO" "$ML_DIR"
fi

cd "$ML_DIR/platform/$PLATFORM"
echo ">> building ML for $PLATFORM ..."
make -j"$(nproc)"

echo
echo ">> build artifacts:"
ls -la build/autoexec.bin build/magiclantern.zip
