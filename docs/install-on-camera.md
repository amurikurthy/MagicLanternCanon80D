# Running ML on the real 80D

QEMU can't show the 80D's GUI (see `port-status.md`), so seeing ML actually run
means installing on the camera. This is the higher-risk path — read
`rom-dump.md`'s brick-risk notes first. Your verified ROM dump is your recovery
reference; keep it.

> Status: this is the **plan**, not yet a verified procedure on hardware. The
> 80D is not a finished port — expect ML to be incomplete and possibly unstable
> (image capture, SRM, state hooks are known-broken). Treat first boot as an
> experiment, not a daily-driver install.

## Prerequisites

- Camera on firmware **1.0.3** (matches the `80D.103` port).
- A fresh ML build: `scripts/10_build_ml.sh` → `platform/80D.103/build/magiclantern.zip`.
- A card **≤32 GB, FAT32**, made **bootable** for EOS.
- Your ROM dump saved somewhere safe (recovery reference).

## The two persistent changes ML needs

1. **Bootable card flag** — a magic marker in the card's boot sector so DryOS
   looks for `autoexec.bin`. Reversible by reformatting the card.
2. **Camera boot flag (`BOOT=1`)** — tells the camera to run `autoexec.bin` from
   a bootable card. This is a **persistent change to the camera** (set via a FIR
   through Canon's firmware-update flow). This is the irreversible-risk step.

`RESCUE.LOG` from the dump shows your camera currently at `FIR=0 BOOT=0` — i.e.
untouched.

## Outline (to be validated carefully)

1. Put ML on the card: extract `magiclantern.zip` to the card root
   (`autoexec.bin` + `ML/`).
2. Make the card bootable (EOS boot-sector flag). On a camera that already runs
   ML you'd use ML's own tools; for a first install this is usually done with a
   helper (e.g. `make_bootable` / EOScard-style tooling) — verify the method for
   the 80D before use.
3. Set the camera boot flag. Upstream ships `installer/` FIRs for several cams —
   **but not the 80D**. So the boot-flag step for the 80D is not a solved,
   in-tree procedure yet; it needs an 80D-specific enable-boot FIR or method
   confirmed working by the community. **Do not improvise this step** — a wrong
   FIR through the update flow is the hard-brick path.
4. Power-cycle. If ML loads, you get its UI; if `autoexec.bin` is bad the camera
   hangs → pull battery, reformat card, Canon boots normally.

## Honest blockers before this is safe to attempt

- **No in-tree 80D boot-flag installer.** This is the single biggest gap between
  "builds + emulates" and "runs on the camera." Resolve this first, from a
  trusted source, with a verified checksum.
- **Recovery plan ready**: keep the ROM backup; know the battery-pull + reformat
  recovery; ideally have the portable dumper handy.

## Lower-risk alternative to make progress now

Since on-camera install is gated on the boot-flag method, the productive
non-risky work is in QEMU on **boot/code-path** issues (not GUI): pushing past
the capture/movie-init hang, then tackling SRM / state-object hooks / image
capture at the code level. That advances the port without touching the camera.
