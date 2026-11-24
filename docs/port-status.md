# 80D port status & notes

Camera: **Canon EOS 80D**, firmware **1.0.3**, DIGIC 6, internal codename `K350`,
model ID `0x350` (FIRMWARE_ID `0x80000350`), `ROMBASEADDR 0xFE0A0000`.

## What exists upstream

`magiclantern_simplified/platform/80D.103/` is a real, early-to-mid-stage port:

- `stubs.S` — **102 resolved ROM stubs** (the expensive reverse-engineering).
- `consts.h`, `function_overrides.c`, `fps-engio_per_cam.c`, etc.
- Listed in `platform/Makefile` `ML_CAMS`, so it builds with the default set.

Config highlights (`internals.h`, `features.h`):

```
CONFIG_DIGIC_VI
CONFIG_NO_BFNT            # D6 has no bitmap font in ROM; loaded from card
CONFIG_LIVEVIEW
CONFIG_MALLOC_STRUCT_V2
CONFIG_TASK_STRUCT_V2
CONFIG_TASK_ATTR_STRUCT_V4
CONFIG_MEMORY_SRM_NOT_WORKING     # SRM faked to allow building
# CONFIG_STATE_OBJECT_HOOKS       # disabled
CONFIG_IMAGE_CAPTURE_NOT_WORKING  # null-ptr crash on AF-lock fail
CONFIG_PROP_REQUEST_CHANGE        # property writes ENABLED (brick-risk vector)
CONFIG_AUTOBACKUP_ROM
```

## Verified working (in QEMU, from a real 1.0.3 ROM)

- ML builds: `autoexec.bin` (~240 KB) + `magiclantern.zip`.
- Bare Canon firmware boots: serial shows `K350 ICU Firmware Version 1.0.3 ( 6.2.4 )`.
- ML boots: DryOS bootloader finds the card bootable, loads **our** `autoexec.bin`
  (`File size : 0x3AD60`), `Now jump to AUTOEXEC.BIN!!`, ML's early hijack runs.
- Both stop at `ASSERT: Resource/EstimatedSize.c:1484 (RscMgr)` — the standard
  QEMU stop that `patches_80d.gdb` is meant to skip.

## QEMU boot — what actually happens (measured)

Driving qemu-eos directly (suspended + `gdb-multiarch` applying
`scripts/patches_80d.gdb`), with sd+cf drives attached:

1. DryOS bootloader finds the card bootable, loads our `autoexec.bin`
   (`File size : 0x3AD60`), `Now jump to AUTOEXEC.BIN!!`.
2. ML's early hijack runs, hands back to DryOS: `K350 READY`,
   `[SF] InstallSerialFlash ... 0x800000` (our SFDATA), `K350 ICU Firmware
   Version 1.0.3 ( 6.2.4 )`.
3. **The EstimatedSize breakpoint patch is enough to pass the fatal assert** at
   `Resource/EstimatedSize.c:1484`. Boot then continues: `[DISP]`, SD init,
   filesystem mount, `[RSC] GetEstimatedSizeOfMovie ...`.
4. Boot then **hangs at capture/movie init**, and the emulated **LCD never
   renders** — every `screendump` is a uniform gray 720×480 framebuffer.

### GDB handshake notes (resolved)

- gdb-multiarch attaches and `set`/`continue` work **as long as qemu is stable**.
  The earlier "target is running" failures were a symptom of qemu dying early
  (`CF init failed`) when no `-drive if=sd` / `-drive if=ide` were attached.
- **Do not apply the three `set *(int*)...=0x4770` ROM writes at reset** — they
  stall ML's early boot (never reaches `K350 READY`). The EstimatedSize
  breakpoint alone is what gets past the assert. See `scripts/patches_80d.gdb`.

## Known gaps / next work

1. **No GUI in QEMU for the 80D.** DIGIC 6 display emulation is incomplete
   upstream — there are **no reference screenshots for any DIGIC 6 camera** in
   `qemu-eos/.../expected_test_output` (only DIGIC 4/5: 50D, 60D, 100D, 500D,
   700D, 5D3). QEMU is useful here for boot/stub/code-path work, **not** for
   seeing or verifying the ML GUI. Real GUI/feature verification needs the camera.
2. **Boot hang at capture/movie init** — likely needs the capture/develop prep
   functions stubbed, but applying those stubs at reset stalls boot (above).
   Applying them at a later breakpoint is unexplored.
3. **DIGIC 6 display/compositor emulation** in qemu-eos would be the upstream
   work required to ever get a GUI screenshot for this camera.
3. **SRM allocator** (`CONFIG_MEMORY_SRM_NOT_WORKING`) — find `SRM_BUFFER_SIZE`
   and the real allocator entry points.
4. **State object hooks** (`CONFIG_STATE_OBJECT_HOOKS`).
5. **Image capture** (`CONFIG_IMAGE_CAPTURE_NOT_WORKING`).

## Upstream LLM policy (important for contributing)

`LLM_POLICY.md` only accepts LLM-generated code under ~15 lines, and requires
disclosure of LLM involvement. Anything headed upstream must be your own
understood/rewritten work, not pasted model output.
