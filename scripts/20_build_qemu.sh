#!/usr/bin/env bash
# Clone and build qemu-eos (ML's patched QEMU) with 80D support.
#
# Works around three things that break a vanilla build today:
#   1. qemu-eos submodules point at git.qemu.org, which is dead (HTTP 405).
#      -> repoint the 6 required submodules at gitlab.com/qemu-project mirrors
#         and check out the pinned commits.
#   2. QEMU 4.2.1 + modern GCC trips a -Werror configure probe -> --disable-werror
#   3. make re-runs the submodule fetch -> --disable-git-update, and seed the
#      .git-submodule-status baseline for exactly the 4 build submodules.
set -euo pipefail

WORKROOT="${WORKROOT:-/home/user/src}"
QEMU_REPO="${QEMU_REPO:-https://github.com/reticulatedpines/qemu-eos.git}"
QEMU_BRANCH="${QEMU_BRANCH:-qemu-eos-v4.2.1}"
QEMU_DIR="$WORKROOT/qemu-eos"
BUILD_DIR="$WORKROOT/qemu-eos-build"

mkdir -p "$WORKROOT"
if [ ! -d "$QEMU_DIR/.git" ]; then
    echo ">> cloning qemu-eos ($QEMU_BRANCH) ..."
    git clone --depth 1 -b "$QEMU_BRANCH" "$QEMU_REPO" "$QEMU_DIR"
fi

cd "$QEMU_DIR"

echo ">> repointing required submodules at live gitlab mirrors ..."
declare -A SUBS=(
  [capstone]="https://gitlab.com/qemu-project/capstone.git"
  [dtc]="https://gitlab.com/qemu-project/dtc.git"
  [slirp]="https://gitlab.com/qemu-project/libslirp.git"
  [ui/keycodemapdb]="https://gitlab.com/qemu-project/keycodemapdb.git"
  [tests/fp/berkeley-softfloat-3]="https://gitlab.com/qemu-project/berkeley-softfloat-3.git"
  [tests/fp/berkeley-testfloat-3]="https://gitlab.com/qemu-project/berkeley-testfloat-3.git"
)
for path in "${!SUBS[@]}"; do
    git config "submodule.$path.url" "${SUBS[$path]}"
done
git submodule sync >/dev/null 2>&1 || true

echo ">> fetching pinned submodule commits ..."
for path in "${!SUBS[@]}"; do
    sha="$(git ls-tree HEAD "$path" | awk '{print $3}')"
    url="${SUBS[$path]}"
    [ -n "$sha" ] || { echo "!! no pinned SHA for $path"; exit 1; }
    rm -rf "$path"; mkdir -p "$path"
    ( cd "$path"
      git init -q
      git remote add origin "$url"
      git fetch -q --depth 1 origin "$sha" || git fetch -q origin
      git checkout -q "$sha" )
    echo "   $path -> $(git -C "$path" rev-parse --short HEAD)"
done

# Seed the baseline for the 4 submodules the arm build actually uses, so
# `make` (with --disable-git-update) sees a clean status and won't re-fetch.
echo ">> seeding .git-submodule-status ..."
GIT=git ./scripts/git-submodule.sh update \
    ui/keycodemapdb tests/fp/berkeley-testfloat-3 tests/fp/berkeley-softfloat-3 dtc

echo ">> configuring (out-of-tree) ..."
rm -rf "$BUILD_DIR"; mkdir -p "$BUILD_DIR"; cd "$BUILD_DIR"
"$QEMU_DIR/configure" \
    --target-list=arm-softmmu \
    --enable-plugins --disable-docs --enable-vnc \
    --disable-gtk --disable-vte \
    --disable-werror --disable-git-update

echo ">> building qemu + ML plugin ..."
make -j"$(nproc)"
make plugins
cp tests/plugin/libmagiclantern.so arm-softmmu/plugins/

echo
echo ">> done:"
ls -la "$BUILD_DIR/arm-softmmu/qemu-system-arm" \
       "$BUILD_DIR/arm-softmmu/plugins/libmagiclantern.so"
