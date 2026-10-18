#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Render a composition offline with Godot's Movie Maker: PNG frames plus f.wav.
#
#   tools/render.sh <scene.tscn> <out_dir> <frames> [start_frame] [fps]
#   tools/render.sh res://demo/examples/race_ident.tscn out/race 180
#   tools/render.sh res://demo/scf/g1_lava.tscn out/g1 220 200      # frames 200-419 as files 0-219
#
# GODOT names the Godot 4 binary (default: godot on PATH). With no display, an
# Xvfb server on :99 is started (software GL: correct, but slow for heavy blurs).
set -euo pipefail
scene=$1; out=$2; frames=$3; start=${4:-0}; fps=${5:-30}
godot=${GODOT:-godot}
cd "$(dirname "$0")/.."
if [ -z "${DISPLAY:-}" ]; then
  pgrep -x Xvfb >/dev/null || (Xvfb :99 -screen 0 1920x1080x24 >/dev/null 2>&1 &)
  sleep 0.5
  export DISPLAY=:99
fi
rm -rf "$out"; mkdir -p "$out"
args=()
[ "$start" != 0 ] && args=(-- "--mk-start=$start")
"$godot" --path . --rendering-driver opengl3 --resolution 1920x1080 \
  --write-movie "$out/f.png" --fixed-fps "$fps" --quit-after "$frames" "$scene" "${args[@]}" 2>&1 \
  | grep -E "SCRIPT ERROR|Parse Error|^ERROR|recorded" || true
echo "$(ls "$out"/f*.png | wc -l) frames in $out"
