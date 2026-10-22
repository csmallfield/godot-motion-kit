# Full Throttle Flux intro

A 14 s boot intro for Full Throttle Flux: "Minimal Humans presents" glitching
into FTF's acid palette, a run of team liveries, then the FTF logo slamming in
on the drop with an acid HUD around it. Wipeout / Designers Republic /
neo-futurist. The brief and the frame-by-frame beat sheet are in the header of
`ftf_intro.gd`.

| File | What it is |
| --- | --- |
| `ftf_intro.gd` / `.tscn` | The composition (1920×1080, 30 fps, 420 frames) and its cue sheet |
| `ftf_kit.gd` | `FTFKit`: palette, fonts, the FTF logo's part map and drawn marks (chevrons, checkers, hatching, X boxes, crosshairs, barcodes, rounded ribbons, stripe bundles), for reuse in the menus |
| `assets/ftf_logo.svg` | `FTF_logo_pink_v1.svg` from the FTF repo, imported as Motion SVG |
| `assets/noto-jp-ftf-900.woff2` | Noto Sans JP Black, subset to the piece's Japanese (OFL, see `demo/assets/fonts/OFL-noto-sans-cjk-jp.txt`) |
| `audio/make.py` | Writes every sound recipe, the cue map and the music (sound sheet in its docstring) |
| `audio/bake.gd` | Bakes the soundtrack to `audio/ftf_intro_track.res` and writes `audio/ftf_intro_cues.json` |
| `audio/ftf_intro_track.res` | The baked soundtrack, so the piece plays its sound without the audio kit |

## Timing

150 bpm, 4/4, first downbeat at frame 0: a beat is exactly 12 frames, a bar 48.
Every animation and cue starts from the constants at the top of the script, so
retiming a beat moves its sound too. To swap in a different music track, keep
150 bpm with its first downbeat at 0.0 s; the drop lands on bar 4 (frame 192,
6.4 s).

Markers: `in` 0, `logo` 192, `hold` 264, `out` 336. For the game's boot, play it
and `await finished`, or skip by seeking to the end; it ends on black so it can
cut straight to the menu.

## Sound

Link the audio kit (`tools/link_audio_kit.sh`, a git-ignored symlink to
`../godot-audio-kit`) and the piece scores itself through an `AKCueBridge`;
without it, it plays the committed bake. After changing recipes, the song or any
cue timing:

```sh
tools/link_audio_kit.sh
python3 demo/ftf/audio/make.py
godot --headless --path . -s res://demo/ftf/audio/bake.gd
godot --headless --path . -s res://addons/audio_kit/tools/review.gd -- \
    --cues demo/ftf/audio/ftf_intro_cues.json --map res://demo/ftf/audio/ftf_map.tres \
    --song res://demo/ftf/audio/music/ftf_song.tres --out out/review/ftf
python3 ../godot-audio-kit/tools/analyze/analyze.py out/review/ftf
```

## Render

```sh
tools/render.sh res://demo/ftf/ftf_intro.tscn out/ftf 420
ffmpeg -framerate 30 -i out/ftf/f%08d.png -i out/ftf/f.wav -c:v libx264 -pix_fmt yuv420p -crf 18 -shortest ftf_intro.mp4
```

The FTF and Minimal Humans logos are Minimal Humans trademarks and are not
covered by the repository's Apache-2.0 grant.
