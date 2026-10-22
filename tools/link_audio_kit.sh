#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Link a local Godot Audio Kit checkout into this project, so pieces that use it
# (demo/ftf) are scored live by its AKCueBridge and can be re-baked:
#   tools/link_audio_kit.sh [path/to/godot-audio-kit]
# The link is git-ignored; the motion kit never requires the audio kit (pieces
# fall back to their committed baked tracks).
set -e
cd "$(dirname "$0")/.."
src="${1:-../godot-audio-kit}"
[ -d "$src/addons/audio_kit" ] || { echo "no audio kit at $src" >&2; exit 1; }
ln -sfn "$(cd "$src/addons/audio_kit" && pwd)" addons/audio_kit
echo "linked addons/audio_kit -> $src/addons/audio_kit"
