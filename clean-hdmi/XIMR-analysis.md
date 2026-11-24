# XimrContext analysis (from camera dump, LiveView w/ AF box)

XIMR_CONTEXT = 0x57a74. Holds two 0x5C-byte layer descriptors; MARV embedded at
descriptor offset +0x0C. Layer A @ ctx+0x00, Layer B @ ctx+0x5C.

| field (desc off) | Layer A (ctx+0x00) | Layer B (ctx+0x5C) |
|---|---|---|
| MARV sig +0x0C | 0x5652414D | 0x5652414D |
| bitmap +0x10   | 0x41785B00 | 0x043ED100  (= rgb_vram_info) |
| opacity +0x14  | 0x41707100 | 0x00000000 |
| flags +0x18    | 0x01000102 | 0x05000004 |
| width +0x1C    | 960 | 960 |
| height +0x20   | 540 | 540 |
| pmem +0x24     | 0x41882D1C | 0x045E751C |
| blend +0x44..  | present    | all zero |

Layer A has a separate opacity plane + blend params -> likely the image/video.
Layer B's bitmap matches MARV0.BIN (rgb_vram_info) -> Canon GUI layer (AF box).

Experiment 02: invalidate Layer B's MARV sig (ctx+0x68) + XimrExe, in a loop,
to test whether the GUI (AF box) drops out of the LiveView/HDMI feed while the
video (Layer A) stays. Expected outcomes:
  - AF box gone, video intact  -> mechanism works; next: find clean/persistent hook
  - no change                  -> compositor uses a layer count, not sig-scan; try width=0 / count field
  - freeze                     -> compositor chokes on invalid sig; try a gentler field
