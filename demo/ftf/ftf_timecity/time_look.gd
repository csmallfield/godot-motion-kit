# SPDX-License-Identifier: Apache-2.0
# Shared values for the FTF Time City take: palette and the beat grid that the
# piece, its city content and the sound all read (one timeline for everything).
extends RefCounted

const BPM := 120.0
const BEAT := 15.0                  # frames per beat at 120 bpm, 30 fps
const BAR := 60.0

# ---- palette (MC-202: red, cream, black, grey on paper)
const PAPER := Color("#efece4")
const GROUND := Color("#dedad0")
const RED := Color("#e8322a")
const INK := Color("#141417")
const BLACK := Color("#000000")
const CREAM := Color("#f8f4eb")
const EDGE := Color(0.08, 0.08, 0.09, 0.85)

# ---- I: the city builds through a time wave, the monument snaps sharp
const RISE := 4.0                   # content: city rings start rising (8 rings)
const RINGS := 8
const RING_STEP := 1.875            # thirty-seconds
const WAVE_D := 30.0                # columns: the right edge lags this much
const MH_RISE := 34.0               # content: monument rises out of the plaza 34..52
const MH_UNFOLD := 44.0             # content: M layers telescope 44..60
const MH_SNAP := 60.0               # bar 1: the time ripple collapses, sharp
const RIPPLES := [75.0, 90.0, 105.0]   # ripples of time pass through the lockup
const STAMP := 75.0                 # PRESENTS stamped on the plinth
const STAMP_JP := 97.5
# ---- II: crane to the FTF plaza, the slab rises through a time smear
const MH_SINK := 120.0              # bar 2
const CRANE := 128.0                # the crane / whip, smeared through rows
const ARRIVE := 165.0
const DRAIN := 168.0                # blocks in front of the FTF plaza drain
const FTF_RISE := 180.0             # bar 3: the slab starts rising
const COLLAPSE := 226.0             # the smear collapses 226..240
const DROP := 240.0                 # bar 4: slab locks, sharp, front elevation
# ---- hold
const ACCENTS := [270.0, 285.0, 315.0, 345.0]   # CHANNELS time fringes
const TEAR := 300.0                 # bar 5: a time tear (random row delays)
const PASS := 330.0                 # a ripple scans down the held logo
# ---- III: streaks and drain to black
const STREAK := 360.0               # bar 6: columns fold into the slit
const SINK := 376.0                 # content: logo and city sink (under the streaks)
const DARK := 388.0                 # content: ground darkens 388..400
const DARK_END := 400.0
const BLACK_AT := 412.0             # black from here
const END := 420


## Seeded, signed decaying kicks on a list of frames (alternating direction).
static func kicks(f: float, ats: Array, amp: float, rate := 0.35) -> float:
	var v := 0.0
	for i in ats.size():
		var at: float = ats[i]
		if f >= at:
			v += amp * exp(-(f - at) * rate) * (1.0 if i % 2 == 0 else -1.0)
	return v
