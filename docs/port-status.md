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

## Known gaps / next work

1. **GDB-patched boot handshake.** Applying `patches_80d.gdb` over
   `gdb-multiarch` currently stalls at the ML jump because gdb reports the
   target "running" right after connect and refuses `set`/`continue`. To try:
   - `arm-none-eabi-gdb` instead of `gdb-multiarch`;
   - a `stepi` to force a sync before the memory writes;
   - a python-gdb driver that waits for a clean stop event.
2. **DIGIC 6 display emulation is partial upstream** — even past the assert, a
   fully rendered ML GUI may not appear in QEMU. QEMU is best here for
   boot/stub/code-path work; GUI/feature verification ultimately wants the camera.
3. **SRM allocator** (`CONFIG_MEMORY_SRM_NOT_WORKING`) — find `SRM_BUFFER_SIZE`
   and the real allocator entry points.
4. **State object hooks** (`CONFIG_STATE_OBJECT_HOOKS`).
5. **Image capture** (`CONFIG_IMAGE_CAPTURE_NOT_WORKING`).

## Upstream LLM policy (important for contributing)

`LLM_POLICY.md` only accepts LLM-generated code under ~15 lines, and requires
disclosure of LLM involvement. Anything headed upstream must be your own
understood/rewritten work, not pasted model output.
