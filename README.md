# Magic Lantern — Canon EOS 80D (firmware 1.0.3)

Reproducible setup for building, ROM-dumping, and emulating Magic Lantern (ML)
on the **Canon EOS 80D**, firmware **1.0.3** (DIGIC 6, internal codename `K350`).

This repo does **not** contain Magic Lantern itself or any camera firmware. It
contains the scripts and notes to reproduce a working dev environment from the
upstream sources plus your own ROM dump.

> ⚠️ **Never commit ROM/firmware here.** `ROM1.BIN`, `SFDATA.BIN`, and `*.FIR`
> are copyrighted Canon code. `.gitignore` is set up to keep them out — keep it
> that way.

## Status of the port (as of this writing)

The 80D is **already partially ported** in
[`reticulatedpines/magiclantern_simplified`](https://github.com/reticulatedpines/magiclantern_simplified)
as platform `80D.103`. The hard reverse-engineering (102 ROM stubs) is done.

| Area | State |
|------|-------|
| Build (`autoexec.bin` + modules) | ✅ builds clean |
| Boots in QEMU; ML `autoexec.bin` loads & executes | ✅ verified |
| Canon firmware 1.0.3 runs in QEMU from a real ROM | ✅ verified |
| `CONFIG_STATE_OBJECT_HOOKS` | ❌ disabled |
| Image capture | ❌ `CONFIG_IMAGE_CAPTURE_NOT_WORKING` |
| SRM memory allocator | ❌ `CONFIG_MEMORY_SRM_NOT_WORKING` |
| Full ML GUI in QEMU | ⚠️ DIGIC 6 display emulation is partial upstream |

See [`docs/port-status.md`](docs/port-status.md) for detail.

## Expected directory layout

The scripts assume this sibling layout (qemu-eos requires it):

```
<workroot>/                         # default: /home/user/src
├── magiclantern_simplified/        # upstream ML (cloned)
├── qemu-eos/                       # upstream patched QEMU (cloned)
├── qemu-eos-build/                 # out-of-tree QEMU build
└── roms/
    └── 80D/
        ├── ROM1.BIN                # your dump (NOT in git)
        └── SFDATA.BIN              # your dump (NOT in git)
```

Override the root with `WORKROOT=/path make ...` or the env var the scripts read.

## Quick start

```bash
# 0. host dependencies (Debian/Ubuntu)
scripts/00_install_deps.sh

# 1. clone + build Magic Lantern for the 80D
scripts/10_build_ml.sh

# 2. clone + build qemu-eos (handles the dead-submodule-server workaround)
scripts/20_build_qemu.sh

# 3. place YOUR dump at roms/80D/ROM1.BIN and roms/80D/SFDATA.BIN
#    (see docs/rom-dump.md for how to dump safely), then build a bootable SD:
scripts/30_make_sd_image.sh

# 4. boot it headless and capture the serial log
scripts/40_boot_qemu.py --boot        # boot ML from the emulated card
scripts/40_boot_qemu.py               # boot bare Canon firmware
scripts/40_boot_qemu.py --boot --gdb  # apply emulation patches via gdb
```

## Why these scripts exist (non-obvious workarounds)

Building this today required several fixes that aren't in the upstream docs,
mostly because modern toolchains and cloud/container hosts differ from what the
ML QEMU workflow assumes:

- **qemu-eos submodules** point at `git.qemu.org`, which is dead (HTTP 405).
  `20_build_qemu.sh` repoints the 6 required submodules at the live
  `gitlab.com/qemu-project` mirrors and checks out the pinned commits.
- **QEMU 4.2.1 vs GCC 13+** trips a `-Werror` configure probe → `--disable-werror`.
- **`make` still tries to re-fetch submodules** → `--disable-git-update` plus a
  correctly-seeded `.git-submodule-status` (only the 4 build submodules).
- **`make disk_image` needs libguestfs**, which can't run in a container (no
  `/boot` kernel, no KVM). `30_make_sd_image.sh` builds the FAT image with
  `mtools` instead — no mounting, no kernel.
- **`run_qemu.py` hardcodes a GTK display.** `40_boot_qemu.py` drives
  `QemuRunner` headless (`display=None`) with serial captured to a file.

## License / provenance notes

- Magic Lantern is GPL; this repo only orchestrates it and adds original scripts/docs.
- Upstream's [`LLM_POLICY.md`](https://github.com/reticulatedpines/magiclantern_simplified/blob/main/LLM_POLICY.md)
  restricts contributing substantial LLM-generated code. Treat any code destined
  for upstream accordingly: understand and rewrite, don't paste.
