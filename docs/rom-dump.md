# Dumping the 80D ROM (safely)

To emulate your camera in qemu-eos you need its ROM. Canon firmware cannot be
redistributed, so you dump it from your own body. This is read-only and does
**not** modify the camera.

## What you need

- A small SD card, **≤32 GB, formatted FAT32** (not exFAT), nothing important on it.
- The **Magic Lantern Portable ROM Dumper** FIR for the 80D (`DUMP_80D.FIR`).
  It is a single model-aware dumper; verify it against a published MD5 before use.
  Source: the ML forum Portable ROM Dumper thread.

## Procedure

1. Copy `DUMP_80D.FIR` to the **root** of the card.
2. Fully charge the battery. Insert the card, power on.
3. Canon menu → **Firmware Update** → select it → run.
   This runs the dumper (not a real update) and writes to the card.
   **Do not interrupt or remove power.**
4. Power off, remove the card. You should have:
   - `ROM1.BIN`   (32 MB — the main firmware)
   - `SFDATA.BIN` (8 MB — serial flash; required by the 80D QEMU model)
   - `ROM1.MD5`, `SFDATA.MD5`, `RESCUE.LOG`
5. **Verify integrity**: `md5sum -c ROM1.MD5` and `md5sum -c SFDATA.MD5`.

## Verifying it's a good 80D 1.0.3 dump

`RESCUE.LOG` should report, e.g.:

```
- Model ID: 0x350 80D
- Camera model: Canon EOS 80D
- Firmware version: 1.0.3 / 6.2.4 9D(84)
- Boot flags: FIR=0 BOOT=0        <- camera's boot flag untouched (safe)
- ROMBASEADDR: 0xFE0A0000
```

`ROMBASEADDR 0xFE0A0000` matches `MAIN_FIRMWARE_ADDR` in the platform Makefile,
and `0x350` matches the FIR's firmware ID `0x80000350`.

## Where the files go

Place them for the emulator (NOT in this git repo — see `.gitignore`):

```
$WORKROOT/roms/80D/ROM1.BIN
$WORKROOT/roms/80D/SFDATA.BIN
```

## Brick-risk note

- The **FIR portable dumper makes no persistent change** — it only reads ROM and
  writes to the card. Lowest-risk path. Confirm `BOOT=0` in `RESCUE.LOG`.
- The genuinely dangerous, persistent step is later: setting the **boot flag** to
  actually *run* ML on the camera. Keep your verified ROM dump as a recovery
  backup before doing that.
- A camera that "won't boot" after a bad card is usually recoverable: remove
  battery, reformat the card in a computer, reinsert.
