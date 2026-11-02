# Handoff: procedural-animation action prototype (Motion Kit + Audio Kit in a live game)

Working title for the test project: **Cutout Isle**. A 2.5D top-down action-adventure slice in the spirit of
*The Swords of Ditto*: a hand-drawn feel, a sword, enemies that react, a small island. Most of the motion is
procedural, layered on top of a few authored key poses.

This document is the brief for a fresh session. It has three parts:

- **Kickoff prompt:** paste it into the new session.
- **Reference sections:** the session should read them before planning.
- **Decisions:** questions the session should put to Chris before building.

---

## 1. Kickoff prompt (paste this)

> We're starting a new project: a small playable prototype that tests the Godot Motion Kit and Godot Audio Kit
> as *live game* systems, not only as frame-pure, offline-rendered motion graphics. The game is a 2.5D
> top-down action slice in the spirit of The Swords of Ditto. It has a cutout-style hero with procedural
> locomotion and secondary motion, an authored sword swing, a training dummy and one or two simple enemies
> that react to hits, on one small flat-shaded island, with live procedural sound.
>
> Read `HANDOFF_procedural_action_prototype.md` first. Then read the motion kit's
> `skills/godot-motion-kit/SKILL.md`, `docs/API.md` (Game layer, 3D, Shapes) and `docs/techniques.md`, and
> the audio kit's `skills/godot-audio-kit/SKILL.md` and `addons/audio_kit/live/`.
>
> Before writing code, ask me the open decisions in section 6 and propose a phase plan with a stop for review
> after each phase. New reusable techniques belong in the kits (that's part of the point). Game-specific
> code stays in the prototype.

---

## 2. Context the new session won't have

**Repos.** All are on Chris's own GitHub account (`csmallfield`) and are private.

- `csmallfield/godot-motion-kit`
  - The motion graphics addon. Main is at `8976a40` as of the handoff.
  - The 20 FTF pieces in `demo/ftf/` are the best worked examples. See `demo/ftf/README.md`.
- `csmallfield/godot-audio-kit`
  - Procedural synthesis: recipes, cue maps, songs, a baked workflow and a LIVE workflow.
  - It has a Sound Lab editor tab: SFX, Loops, Sequencer, pseudo-speech.
- The motion kit links the audio kit through `tools/link_audio_kit.sh`, a git-ignored symlink into
  `addons/audio_kit`.

**Engine and machines.**

- Godot 4.5.1-stable.
- Chris's workstation: Windows, RTX 3080 (budget about 10 GB VRAM), 128 GB RAM. The game targets
  **Forward+**.
- Cloud sessions:
  - Render with Movie Maker under Xvfb with software GL (the Compatibility renderer). That is CPU
    rasterisation on two shared cores.
  - **Frame timings measured in the cloud do not represent the 3080.** Any performance claim must be
    profiled on Chris's machine, or labelled as a CPU-side script cost only.
  - Xvfb dies between turns, so start it inside each command.
  - Serialise Godot calls with `flock` when several agents share the box.

**How the kits work today.**

- `MotionComposition` is frame-pure. `_frame(f)` sets every property from `f` alone, so pieces can be
  scrubbed, rendered and played backwards.
- Motion is nested curves from `MK`. `f` is in frames at 30 fps; pass `fps` or convert seconds yourself.
  - `MK.spring(f, at, damping, stiffness, mass, fps)` and `spring_to`
  - `MK.wob`
  - `MK.shake` and `MK.shakes(f, ats, amp, dur)`
  - `MK.decay_kick`, `MK.accent`, `MK.flicker`
  - `MK.interp` and `MK.map` with easing callables, including `MK.bezier`
- Game layer, already in the kit (`addons/motion_kit/game/`):
  - `MotionSpring`: a stateful spring with `step(dt)`, `snap()` and `is_settled()`. It steps the same spring
    `MK.spring` evaluates.
  - `MotionReactive`: hover, focus and press springs on Controls.
  - `MotionTransition`: `change_scene` and `cover`/`uncover` styles.
  - `MotionCuePlayer`: composition cues to `AudioStream`s.
- 3D used in the Canyon, Gantry and Night Circuit pieces:
  - `MotionFlat3D`: flat poster tones by face normal, fog, and group motion keyed by UV2.
  - `MotionEdges3D`: constant-pixel-width outlines that are depth-tested and silhouette-aware.
  - `MotionDecalAtlas`: 2D drawings in one atlas, put on many quads in one draw call.
  - `MotionLens3D`: a perspective ↔ orthographic blend, which can land exactly on an iso view.
  - `MotionSvgMesh`: SVG parts to extruded or flat meshes, one draw call.
- 2D drawing:
  - `MotionMarks`: chevrons, ribbons, stripe bundles, hatching and more.
  - `MotionPath` and `MotionPoly`: path and polygon maths.
  - `MotionCable`: shaded tubes. **Its sag is analytic, not simulated.**
- Audio kit LIVE:
  - `AKLivePlayer.trigger(cue, intensity, data, delay_s)` and `trigger_at(cue, position, …)`.
  - `AKLiveVoice.set_param(param, value, glide_s)` gives continuous voices driven by game state.
  - `AKSpatial` and reverb zones.
  - **LIVE needs the native core (GDExtension) built for the target platform.** `AKLive.available()`
    reports whether it is. Without it, use baked banks of variations; see 4C.

**Godot 4.5.1 skeleton and IK classes.** Checked with `ClassDB` on 4.5.1.

- Present:
  - `SkeletonModifier3D`, `SpringBoneSimulator3D`, `LookAtModifier3D`, `AimModifier3D`
  - `CopyTransformModifier3D`, `ConvertTransformModifier3D`, `BoneConstraint3D`, `RetargetModifier3D`
  - `PhysicalBoneSimulator3D`
  - `SkeletonIK3D` (legacy)
  - In 2D: `Skeleton2D`, `Bone2D`, `SkeletonModificationStack2D`, and the `SkeletonModification2D`
    TwoBoneIK, FABRIK, CCDIK, Jiggle and LookAt modifications
- **Absent:** `TwoBoneIK3D`, `FABRIK3D`, `CCDIK3D`, `ChainIK3D`.
- So 3D two-bone IK must be written, either as a custom `SkeletonModifier3D` or as plain analytic maths on
  node transforms. It's about 30 lines.

**Chris's working preferences.**

- Be direct.
- Offer alternatives and tradeoffs, and challenge assumptions; don't just execute.
- No scheduled CI check-ins.
- Commit or push only when asked. Branch off main first.
- Reviews of the FTF pieces gave these taste notes, which apply to game juice too:
  - No bouncy staggered letter cascades.
  - Impacts must punch: prefer shake and rings over white flashes.
  - Holds stay alive.
  - Photosensitivity: no large-area flashes faster than 3 per second, and no saturated red strobing. This
    matters for damage flashes.

Chris has a related project: **Knockabout**, a 2D Godot ARPG with rooms, room-clear gates, a charged attack,
block/parry and TileMaps. It could supply combat code. It is also a natural second target once the
procedural layer works.

---

## 3. What the prototype must prove

1. **The kit's curve vocabulary works driven by game events instead of a timeline.** Reactions are pure
   functions of "time since event". Following behaviour uses `MotionSpring`. The two compose without jitter.
2. **Procedural locomotion and secondary motion read as hand-made.** Authored key poses carry the shape and
   the procedural layers add life. A wall of simulated wobble does not pass.
3. **The flat-shaded, outlined 3D look holds up in play.** That means a moving orthographic or near-ortho
   camera, many characters, and the hero walking behind props.
4. **Live procedural sound adds variety without a sample library.** A hundred sword swings must not sound
   the same, and footsteps change with the ground.
5. **It runs at 60 fps on the RTX 3080 under Forward+ with headroom.** Script cost goes in a measured budget,
   section 7.

Non-goals for the prototype: full procedural island generation, inventory, saving, menus beyond a title card,
networking, or final art.

---

## 4. Features to develop

The work is grouped by where it should live. Anything reusable across games goes into a kit with docs, tests
and an `API.md` entry, the same way the FTF work was consolidated. Anything specific to this game stays in the
prototype.

### 4A. Motion kit additions (new `addons/motion_kit/live/` or extend `game/`)

| Feature | What it does | Notes / prior art in the kit |
| --- | --- | --- |
| **Event clock** | Records game events (hit, land, swing start, pickup) with timestamps and answers "seconds or frames since the last X" and "all X within the last N s". It lets `MK.spring`, `decay_kick`, `shakes` and `accent` run on game time unchanged. | The bridge between the frame-pure maths and gameplay. Must respect `Engine.time_scale`, so hit-stop freezes reactions too, and have a per-clock unscaled option for UI. |
| **Hit-stop and time-scale envelopes** | Freeze or slow-mo for N ms, then ease back. Scoped globally or per entity. | Per-entity hit-stop (only the attacker and victim freeze) usually feels better than global. Decide which with Chris. |
| **Trauma camera shake** | Trauma 0..1 that hits add to and that decays; shake = trauma² × noise, with translation and rotation. Plus directional kicks along the hit vector. | `MK.shake` is event-pure. Trauma is the stateful, game-standard model. Offer both. Seeded noise keeps replays deterministic. |
| **Squash and stretch** | Volume-preserving scale from a velocity or impulse spring, plus a landing squash from the event clock. | Applied to a pivot, so it works on cutout parts and meshes. |
| **Verlet chain** | A fixed-step rope or chain with length constraints, an optional angular stiffness and a pinned root. Used for scarf, cape, hair, tail and dangling props. Draws as a ribbon (2D) or a flat strip mesh (3D). | **New.** `MotionCable` is analytic and can't react to the root turning. Run it in `_physics_process` with render interpolation. Same API in 2D and 3D if cheap to do. |
| **Two-bone IK** | Analytic two-bone solve with a pole or bend direction, in 2D and 3D. Works as a helper on plain nodes and as a `SkeletonModifier3D` subclass. | 4.5.1 has no `TwoBoneIK3D` (section 2). The 2D `SkeletonModification2DTwoBoneIK` exists, but a plain-node helper is simpler for cutout rigs. |
| **Procedural gait / foot planting** | Feet stay planted until the body is past a stride threshold, then step along an arc (lift curve from `MK`). Alternating phase, speed-scaled stride, body bob and lean from velocity and acceleration. | The core of "reads as hand-made". Tunables exposed as a Resource. |
| **Look-at and aim springs** | Head, eyes and torso turn toward a target with spring lag and per-joint limits. | Thin wrapper over `MotionSpring` for 2D. `LookAtModifier3D` exists for skeletal 3D. |
| **Pose curves (authored layer)** | Key poses as data, for example a sword swing as 4–6 poses with timing and easing per channel, sampled by time since the swing started. Supports blending and procedural offsets added on top. | The kit's `MK.interp` / `MK.bezier` model as a Resource. Makes attacks tweakable without code. It could get an inspector preview later. |
| **Cutout rig from SVG** | Build a hierarchy of part pivots from an SVG with named parts. Each part becomes a flat mesh (`MotionSvgMesh`, depth ≈ 0) or a 2D polygon, with pivots from a naming convention or a sidecar JSON. | Reuses the `MotionSvgData` part maps. Chris authors the parts in SVG, as with the logos. |
| **Live-safe 3D look** | Use `MotionFlat3D`, `MotionEdges3D` and `MotionDecalAtlas` outside a `MotionStage3D` composition, in a normal game scene. Check under Forward+ and with a moving orthographic camera. | They were built and tested under the Compatibility renderer in compositions. UV2 group motion may need a per-instance variant (instance uniforms) for many moving actors. |
| **Hitch prevention** | Prewarm SVG rasters and font sizes at load, and warm up shaders and pipelines (a hidden first-frame draw of every material). | `MotionSvg.prewarm()` exists. Forward+ pipeline compilation hitches are the new risk. |

### 4B. Use Godot's built-ins (don't re-implement)

- `SpringBoneSimulator3D` for jiggle on skeletal 3D characters, if a skinned path is chosen.
- `LookAtModifier3D` / `AimModifier3D` for skeletal heads and arms.
- `PhysicalBoneSimulator3D` for ragdoll KOs, if wanted (probably not for a cutout look).
- `SkeletonModification2D*` if Chris prefers a 2D `Skeleton2D` path.
- Navigation (`NavigationAgent3D`) for enemies, an `AnimationTree` only if a skinned path is chosen, and
  physics layers for hitboxes.

### 4C. Audio kit

- **Cue map for combat:**
  - swing (variants scaled by combo step)
  - hit (flesh / wood / metal by target)
  - block
  - footstep (grass / stone / sand / wood by ground)
  - land, dash, pickup, enemy alert and enemy KO
- Every recipe randomises within ranges per trigger: pitch, filter, transient and noise seed.
- **Continuous voices:**
  - wind or ambience bound to camera height or zone
  - a low-health heartbeat or drone bound to HP
  - a charge-attack riser bound to hold time
- **Positional:** `trigger_at` with `AKSpatial`, and reverb zones for cave versus open air.
- **Music:** an `AKSong` with sections (explore, combat), switched with `song_queue` and lane gains as enemies
  engage.
- **Fallback if the native core isn't built on Windows:** bake N variants per recipe (for example 8 swings,
  12 footsteps per surface) and pick randomly with a no-repeat rule. **Building the native core on Windows is
  a decision for Chris (section 6).** Check `native/README.md` (repo root).

### 4D. Prototype game code (not kit)

- Hero controller with an 8-way analogue move, dash, a 3-hit sword combo and a charged swing (borrow from
  Knockabout), with hitboxes and hurtboxes.
- Training dummy: spring-wobble on hit, never dies. It's the main juice testbed.
- One or two enemy types (for example a hopping blob and a sword grunt) with a tiny state machine: idle,
  notice, approach, attack, stagger, KO.
- One hand-built island chunk, about 3×3 screens:
  - flat-shaded terrain tiles, props with outlines and decals
  - grass tufts that ripple from hits and footsteps (reuse the ring-rise idea from Time City)
  - one cave mouth with a reverb zone
- Camera: near-orthographic follow with look-ahead, using `MotionLens3D` for a perspective/ortho blend
  moment, for example entering the cave.
- HUD using kit pieces:
  - hearts or health with `MotionLiquidFill` slosh
  - damage numbers
  - a combo counter
  - a `MotionTransition` into and out of the cave
- Debug overlay: toggle each procedural layer on and off, timescale slider, a per-system timing readout.

---

## 5. Suggested phases (stop for review after each)

1. **Look and feel spike.** A grey-box hero (capsule plus cutout head) moving on one flat-shaded,
   outlined tile under Forward+ with an ortho camera. Add the event clock and trauma shake, and a dummy
   that wobbles when hit. Profile on Chris's machine.
2. **Cutout rig and locomotion.** SVG to cutout rig, two-bone IK legs and arms, foot planting, body bob and
   lean, look-at.
3. **Secondary motion.** A verlet scarf or cape and dangling props, plus squash and stretch.
4. **Authored layer.** Pose-curve Resource, the 3-hit combo and charged swing, hit-stop, hit reactions with
   direction.
5. **Sound.** Combat cue map with variation, footsteps by surface, continuous voices, music state switching.
   Decide between LIVE and baked banks from the native-core status.
6. **World and enemies.** Island chunk, grass ripples, cave with reverb zone and lens blend, 1–2 enemy types,
   HUD.
7. **Consolidate.** Move the reusable pieces into the kits with docs, tests and an example scene. Update both
   skills with a "live game" section. Record a capture.

---

## 6. Decisions to put to Chris before building

1. **Where the prototype lives:**
   - a new repo (recommended: it keeps the kits clean and tests them as addons the way a real game would)
   - or a `demo/live/` folder in the motion kit
2. **Character construction:**
   - **(a) Flat cutout parts in 3D:** `MotionSvgMesh` parts on a node hierarchy, outlines from
     `MotionEdges3D`. Cheap per character and scales to crowds. Recommended.
   - **(b) Fully procedural 2D vector bodies drawn every frame** (Rain World-style). Very expressive, but
     a GDScript CPU cost per character.
   - **(c) A skinned 3D mesh** with `Skeleton3D` and the built-in modifiers. The most standard, but the least
     use of the kit.
3. **Rig backbone for (a):** plain node pivots with the kit's IK helpers (simpler, recommended), or
   `Skeleton3D` with custom `SkeletonModifier3D`s (interoperates with Godot tooling).
4. **Camera:** pure orthographic iso-ish, or near-ortho perspective (small FOV), with lens-blend moments.
5. **Audio path:** build the audio kit's native core on Windows now (enables LIVE), or start with baked
   variation banks.
6. **Art source:** Chris supplies the hero's SVG parts, or the session makes placeholder parts in the kit
   style first.
7. **Hit-stop scope:** global, or per entity.

---

## 7. Performance budget and how to measure

- 60 fps means a 16.7 ms frame. Initial targets for the procedural layer, with the hero and 10 enemies on
  screen:
  - **under 2 ms** of GDScript per frame
  - **under 1 ms** for the verlet chains
  - **no frame over 20 ms** during 60 s of play
- Measure on Chris's machine with Godot's profiler and monitors. Add a small in-game timing overlay per
  system (event clock, IK, gait, chains, HUD) using `Time.get_ticks_usec()`.
- Known CPU-heavy kit features stay out of gameplay unless reworked:
  - the 2.5D extrude cities (`MotionExtrude`)
  - `MotionGreebler` at full detail
  - the print plate stacks
  - time slices with many bands
- `MotionSvgMesh`/`MotionFlat3D` geometry is cheap: about one draw call per merged mesh.
- Prefer merged static meshes and instance uniforms for per-actor variation. Avoid one SubViewport per
  character (`MotionPanel3D` doesn't scale past a few).
- If a hot loop (IK across many actors, chains) blows the budget, the escalation path is: fewer actors with
  full detail plus level of detail by distance, then a C++ GDExtension (the audio kit already has a native
  build setup to copy).

---

## 8. Pitfalls already learned

- `MK` functions assume frames at 30 fps. Convert game seconds explicitly (`t * 30.0`) or pass `fps`; don't
  mix units silently.
- Frame-pure reactions plus stateful springs can fight. Each animated property should have one owner, with
  layers added in a defined order: authored pose → procedural offsets → reactions → camera.
- Damage flashes: tint and flicker small areas only, keep to 3 flashes per second at most, and avoid
  full-screen white or red.
- Godot rewrites `importer_version` in `.import` files on import. Discard that churn rather than committing
  it.
- Fixed-step simulation (verlet, foot planting) belongs in `_physics_process`, with interpolation for
  rendering, or it jitters at high refresh rates.
- Forward+ and Compatibility differ in fog, glow and MSAA. Judge the look on Forward+.

---

## 9. Files to read first

- Motion kit:
  - `skills/godot-motion-kit/SKILL.md`
  - `docs/API.md`: Core, Game layer, Shapes, 3D
  - `docs/techniques.md`: "Three ways to do 3D"
  - `addons/motion_kit/core/mk.gd`
  - `addons/motion_kit/game/*.gd`
  - `addons/motion_kit/three/motion_flat_3d.gd`, `motion_edges_3d.gd`, `motion_svg_mesh.gd`,
    `motion_lens_3d.gd`, `motion_decal_atlas.gd`
  - `addons/motion_kit/cable/motion_cable.gd` (as the drawing reference for chains)
- Worked example of the 3D look: `demo/ftf/ftf_canyon/` and its `KIT_NOTES.md`.
- Audio kit:
  - the skill
  - `addons/audio_kit/live/live_player.gd`, `live_voice.gd`, `spatial.gd`, reverb zones
  - `addons/audio_kit/core/live.gd`
  - `native/README.md` (repo root)
