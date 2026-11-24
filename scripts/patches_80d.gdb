# Emulation patches for the 80D (fw 1.0.3), for use with:
#   qemu ... -S -gdb tcp::1234   +   gdb-multiarch -nx -batch -x patches_80d.gdb
#
# FINDINGS (see docs/port-status.md):
#   * gdb-multiarch attaches fine IF qemu is stable (needs sd+cf drives attached,
#     or it dies with "CF init failed" and gdb can't connect).
#   * The EstimatedSize breakpoint below is ENOUGH to get past the fatal
#     ASSERT at Resource/EstimatedSize.c:1484. With it, the 80D boots on into
#     DryOS (display backlight, SD, filesystem, movie-size calc).
#   * The three `set *(int*)...=0x4770` ROM writes from upstream's patches.gdb,
#     when applied at reset, STALL ML's early boot (never reaches K350 READY).
#     They are left DISABLED here. They are meant to stub capture/develop prep;
#     applying them later (not at reset) is future work.
#   * Even past the assert, boot hangs at capture/movie init and the emulated
#     LCD never renders (DIGIC 6 display emulation is incomplete upstream —
#     there are no reference screenshots for any DIGIC 6 cam). So this is useful
#     for boot/code-path work, NOT for seeing a GUI.

set pagination off
set confirm off

target remote localhost:1234

# EstimatedSize: force a sane size so the RscMgr assert is skipped.
# This alone gets the 80D past Resource/EstimatedSize.c:1484.
break *0xFE19B06A
commands
  silent
  set $r0 = 0x7D0
  continue
end

# --- DISABLED: these stall early boot when applied at reset (see findings) ---
# set *(int*)0xFE0D91C8 = 0x4770   # startupPrepareCapture
# set *(int*)0xFE1C0BF4 = 0x4770   # SHT_CAPTURE_PATH_InitializeCapturePath
# set *(int*)0xFE0D52C2 = 0x4770   # startupPrepareDevelop

continue
