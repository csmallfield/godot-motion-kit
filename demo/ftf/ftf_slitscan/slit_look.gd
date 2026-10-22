# SPDX-License-Identifier: Apache-2.0
# Shared values for the FTF Slit-Scan take: palette and the beat grid that the
# piece and its three content sources all read (one timeline for everything).
class_name FTFSlitLook
extends RefCounted

const INK := Color("#07080c")
const CYAN := Color("#19e3ff")
const MAGENTA := Color("#ff2bd6")
const CHROME := Color("#eef3ff")
const STEEL := Color("#8a93a8")
const PINK := Color("#e92067")      # the FTF logo's own pink

const BPM := 180.0
const BEAT := 10.0                  # frames per beat at 180 bpm, 30 fps
const BAR := 40.0

# ---- Act I: Minimal Humans
const MH_SNAP := 40.0               # streaks resolve into the lockup (bar 1)
const PRESENTS_AT := 46.0
const MH_KICKS := [60.0, 70.0]      # time ripples through the held lockup
const MH_FOLD := 84.0               # folds back into streaks
const MH_RECOLOUR := 96.0           # streaks turn FTF cyan / magenta
# ---- Act II: tunnel
const TUNNEL := 120.0               # bar 3
const TUNNEL_FAST := 160.0          # bar 4: patterns on eighths
const TUNNEL_WHITE := 186.0
# ---- Act III: logo
const SCAN := 200.0                 # bar 5: the logo crosses the slit
const UNFOLD := 226.0
const LOGO_SNAP := 240.0            # bar 6: sharp
const ACCENTS := [270.0, 290.0, 310.0, 320.0]
const TEAR := 300.0
const PASSES := [256.0, 316.0]    # a scanner bump sweeps across the held logo
const EXIT := 340.0                 # bar 8.5: the logo stretches off right
const GONE := 392.0
const END := 420


static func decay_kick(f: float, ats: Array, amp: float, rate := 0.45) -> float:
	var v := 0.0
	for i in ats.size():
		var at: float = ats[i]
		if f >= at:
			v += amp * exp(-(f - at) * rate) * (1.0 if i % 2 == 0 else -1.0)
	return v
