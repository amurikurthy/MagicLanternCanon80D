# 80D port status & notes

Camera: **Canon EOS 80D**, firmware **1.0.3**, DIGIC 6, internal codename `K350`,
model ID `0x350` (FIRMWARE_ID `0x80000350`), `ROMBASEADDR 0xFE0A0000`.

## IMPORTANT: the ML GUI works on the real 80D (QEMU just can't show it)

The 80D port was written by **kitor** (core ML dev, 191 commits) — commit
`4c971353 "80D_103 full build"` (2023-05-11). He posted a photo of ML's menu
running on a real 80D, calling it "on par with 750D" (working: Global Draw,
Movie Tweaks, Shoot Preferences, DOF, Lens info, Screenshot, Show tasks, Free
Memory, Shutter Count). The port is maintained in-tree through 2026.

So: **this port shows a working ML menu on actual hardware.** The blank/gray
framebuffer we see in QEMU is a DIGIC 6 *display-emulation* gap, NOT the state
of the port on the camera. Do not read "no GUI in QEMU" as "no GUI on the 80D."
What's incomplete is advanced capture (image capture, SRM, raw) — not the UI.

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

### Root cause of the blank QEMU GUI (diagnosed)

Instrumented boot (`-d io`, EstimatedSize + capture/develop patches) shows the
blank screen is a **boot hang, not a display bug**:

- The firmware writes **zero** display registers (`0xD2030108` "BMP VRAM",
  `0xD2013800` "Display resolution" never appear in the io log) — because it
  never reaches display init.
- It hangs looping on `[RSC] ERROR GetEstimatedSizeOfMovie NOT Exist Size or
  FrameRate K347` — the resource manager can't compute movie-record buffer
  sizes because that data isn't emulated (it comes from hardware/config qemu
  doesn't model).
- The capture/develop ROM stubs (`0xFE0D91C8`, `0xFE1C0BF4`, `0xFE0D52C2`) must
  be applied at the Canon-fw entry (`tbreak *0xFE0A0000`), NOT at reset — at
  reset they corrupt ML's `reboot.c` relocation and stall boot at the jump.
  Even applied correctly, they do not clear the RSC hang.

Upstream's 80D patch script does NOT patch the RSC movie-size path, because on
real hardware it works (kitor's on-camera photo). It only hangs in emulation.
This is why no DIGIC 6 cam has GUI reference screenshots. Getting a GUI in QEMU
would require faking the movie-size tables / MPU path — deep, open work.

### ROOT CAUSE (fully traced): incomplete MPU emulation

Deep trace of the hang:
1. Caught the stuck PC — the firmware sits in the DryOS **idle loop**
   (`0xFE2090E4`: spin on a flag + `wfi`). So the **startup task has blocked**,
   leaving nothing runnable; display init is never reached.
2. The `GetEstimatedSizeOfMovie` "NOT Exist" errors are a **red herring** —
   disassembly (`0xFE19B1AE`+) shows that function logs the error and returns a
   default (`0x1CFC`), it does not hang. It reads a movie-config **table that is
   empty in emulation**.
3. That table is normally filled from the **MPU** (the camera's secondary
   processor). qemu-eos emulates the MPU with canned "spells", and the 80D uses
   only the minimal **`generic.h`** spell set (based on the DIGIC 4 60D).
4. `generic.h`'s own header documents the result verbatim:
   *"Assert at EstimatedSize, dumpf works: 5D3 6D 70D 80D 100D EOSM2."* and lists
   only DIGIC 4/5 cams under "menu navigation works". **The ML team themselves
   only ever got the 80D to the EstimatedSize assert + ROM dump in QEMU — never
   to GUI.** No DIGIC 6 cam has a dedicated MPU spell set.

**Conclusion:** the blank QEMU GUI is not a display bug and not a quick patch —
it's that the 80D's MPU boot dialogue isn't emulated, so startup blocks waiting
for config/events that never arrive. This is a known, unsolved DIGIC 6 limitation.

**The one real path to fix it:** build a proper 80D MPU spell set by capturing
the real MPU<->CPU messages from an actual 80D (ML can log them on-camera, now
that the boot flag is set) and encoding them into qemu-eos. That is a
substantial, iterative camera+emulator RE project — the same per-camera work the
ML team does, which has not been done for any DIGIC 6 body.
3. **SRM allocator** (`CONFIG_MEMORY_SRM_NOT_WORKING`) — find `SRM_BUFFER_SIZE`
   and the real allocator entry points.
4. **State object hooks** (`CONFIG_STATE_OBJECT_HOOKS`).
5. **Image capture** (`CONFIG_IMAGE_CAPTURE_NOT_WORKING`).

## Upstream LLM policy (important for contributing)

`LLM_POLICY.md` only accepts LLM-generated code under ~15 lines, and requires
disclosure of LLM involvement. Anything headed upstream must be your own
understood/rewritten work, not pasted model output.
