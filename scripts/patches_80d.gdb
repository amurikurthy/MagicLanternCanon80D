# Emulation patches for the 80D (fw 1.0.3), distilled from
# qemu-eos/magiclantern/cam_config/80D/patches.gdb.
#
# These let the Canon firmware get past hardware it can't fully emulate:
#   - stub out startup capture/develop prep (thumb 'bx lr' = 0x4770)
#   - force the RscMgr EstimatedSize() return value, which otherwise asserts
#     at Resource/EstimatedSize.c:1484
#
# NOTE: there is a known handshake wrinkle between this (old) qemu-eos gdbstub
# and modern gdb-multiarch: right after `target remote`, gdb may report the
# target as "running" and refuse `set`/`continue`. If you hit that, a `stepi`
# (or using arm-none-eabi-gdb instead of gdb-multiarch) usually syncs it. This
# is still being worked out — see docs/port-status.md.

set pagination off
set confirm off

target remote localhost:1234

# startupPrepareCapture: pretend OmarInit completed
set *(int*)0xFE0D91C8 = 0x4770
# SHT_CAPTURE_PATH_InitializeCapturePath
set *(int*)0xFE1C0BF4 = 0x4770
# startupPrepareDevelop
set *(int*)0xFE0D52C2 = 0x4770

# EstimatedSize: force a sane size so the RscMgr assert is skipped
break *0xFE19B06A
commands
  silent
  set $r0 = 0x7D0
  continue
end

continue
