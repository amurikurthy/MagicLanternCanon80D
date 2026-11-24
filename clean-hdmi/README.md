# Clean HDMI on the 80D — un-faking Canon-overlay suppression

Goal: hide Canon's GUI overlay (specifically the **AF box**) from the LiveView /
HDMI feed **while autofocus stays active**, so the 80D can output a clean feed.

## Why it doesn't work out of the box

ML's overlay-suppression (`canon_gui_disable_front_buffer()`) is a DIGIC 4/5
mechanism that flips a window-system "BMP dirty bit". On the 80D that bit is
**faked** (`function_overrides.c: int winsys_bmp_dirty_bit_neg = 0;`), so the
call is a no-op. No DIGIC 6 cam has real overlay suppression.

## The real mechanism (DIGIC 6)

DIGIC 6 composites the display with a hardware **Ximr** compositor. Canon's GUI
(including the AF box) is **layer 0** (`CANON_GUI_LAYER_ID`). The 80D uses the
pure-Ximr path with its `XimrContext` at `0x57a74` (`XIMR_CONTEXT` in
`consts.h`). Hiding Canon's overlay = disabling/removing that layer from the
Ximr context. To do it we need the `XimrContext` struct layout, which isn't
documented for the 80D — so we dump it from the camera and map it.

## Iteration vehicle

The 80D port has `FEATURE_DONT_CLICK_ME` → `run_test()` in `src/debug.c`, a dev
hook triggerable from ML's Debug menu. We put experiments there, build, test on
camera, repeat.

## Experiments

### 01 — compositor dump (read-only) — `01-compositor-dump.patch`
Adds to `run_test()`: dump `XIMR_CONTEXT` (0x400 bytes) → `ML/LOGS/XIMR.BIN`,
dump the ML/Canon GUI-layer MARV → `ML/LOGS/MARV0.BIN`, and print pointers
on-screen. Run in LiveView with the AF box visible. Purely reads memory.

Next: analyze `XIMR.BIN` to locate the layer array + the Canon layer's enable,
then write experiment 02 that disables it and test whether the feed goes clean
with AF still working.
