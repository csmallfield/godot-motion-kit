# SPDX-License-Identifier: Apache-2.0
# Shared values for the FTF Stargate Board take: palette and the beat grid that
# the piece and its two logo sources all read (one timeline for everything).
extends RefCounted

const INK := Color("#07070b")
const PAPER := Color("#f4f1ea")
const PINK := Color("#e92067")      # the FTF logo's own pink
const LIME := Color("#d7ff1f")
const CYAN := Color("#19d3ff")
const LILAC := Color("#a98bff")
const ORANGE := Color("#ff6a13")
const STEEL := Color("#8a93a8")
const DUSK := Color("#5d5788")      # the hold's board: dusky violet checks, so the white plate reads

const BPM := 180.0
const BEAT := 1800.0 / BPM          # frames per beat at 30 fps
const BAR := 4.0 * BEAT

# ---- I: Minimal Humans
const SLIT_OPEN := 8.0              # the centre slit draws; the board starts to shear in time
const POUR_MH := 12.0               # the lockup pours out of the slit as time-stretched arches
const MH_SNAP := 40.0               # bar 1: sharp
const PRESENTS_AT := 46.0
const MH_KICKS := [60.0, 70.0, 80.0, 85.0]   # time ripples through the lockup and the board
const MH_FOLD := 96.0               # the lockup folds back into the slit; the board unrolls
# ---- II: stargate
const GATE := 120.0                 # bar 3: perspective walls left and right
const FLOOR := 140.0                # walls above and below: the board unrolled into floor and ceiling
const TUNNEL := 160.0               # bar 4: four walls
# ---- III: FTF
const POUR := 200.0                 # bar 5: the logo pours out of the slit
const UNFOLD := 222.0
const DROP := 240.0                 # bar 6: sharp, big
const ACCENTS := [260.0, 280.0, 290.0, 300.0, 320.0, 330.0]   # time-split fringes
const STRETCH := 340.0              # bar 8.5: the board stretches into streaks
const DARK := 396.0                 # black from here
const END := 420
