# AGENTS.md — RIFTERMATH development rules

> Это постоянные инструкции для Codex в корне проекта. Выполняй их при любой задаче в этом репозитории.

## Project purpose and source of truth

- **Project:** RIFTERMATH — fast 3D first-person shooter in which the player draws actual spatial rifts in the air.
- **Game design source of truth:** [`docs/RIFTERMATH.md`](docs/RIFTERMATH.md). Read the relevant sections before editing mechanics; do not silently replace requirements with generic FPS/magic effects.
- **Development approach:** [`docs/TECH_STACK_AND_PLAN.md`](docs/TECH_STACK_AND_PLAN.md). Track actual delivery and tests in [`docs/PROGRESS.md`](docs/PROGRESS.md).
- **Current assigned first task:** [`CODEX_PROMPT.md`](CODEX_PROMPT.md): build a playable *SCAR vertical slice*, then expand later.
- Source document and task scope conflict? The source defines the *eventual vision*, but the explicit current task defines the *phase*. Do not attempt the entire 7-ability game in phase 1.

## Mandatory tech stack

- **Godot 4.7.2 Stable / Standard**, 3D desktop project.
- **GDScript**, Godot built-in nodes/physics, `.tscn` and `.tres`, **Godot Shader Language** (`.gdshader`).
- Do not replace Godot with Unity, Unreal, JS/Three.js, HTML/canvas, or a homebrew engine.
- Keep project files in the repository root: `project.godot` in root, scenes/resources/scripts organized by features.
- Avoid plugins, third-party addons, online downloads, build-time network requests and experimental native dependencies unless separately requested.
- If a version change is required, explain why and validate compatibility; do not silently upgrade.

## Core game invariants (never regress)

1. Gameplay is a **true 3D first-person game**, not pseudo-3D or screen-space mockup.
2. Movement is quick and responsive: air control, bunnyhop, momentum conservation, dash, slide, double jump.
3. Player can **keep moving while drawing**, with no pause or automatic time dilation.
4. Drawing uses **relative mouse motion**. Camera still turns during drawing with configurable reduced sensitivity (target ~0.30 multiplier).
5. Gesture points are defined in a **camera-relative virtual drawing plane** (~2 m ahead) and converted consistently into world geometry at release.
6. Rift visuals have *3D thickness / readable parallax*, bright fractured edges, a dark internal void, and angular fragments. **Never replace the main mechanic with a HUD line, colored laser, standard glowing ball, or flat untextured sheet**.
7. Preserve the distinct phases **INCISION → FRACTURE → PROPAGATION**. SCAR must look like a flying cut/rupture in space.
8. Geometry/trajectory matter: stroke length and orientation influence attack shape/orientation; projectiles need robust hit detection at high speeds.
9. Low-poly brutalist sci-fi: clear silhouettes, geometric debris, high visual contrast. Effects must not obscure enemies or aiming.
10. No real 4D physics or universal runtime slicing of arbitrary meshes in MVP. Use prepared/procedural fragments and credible pseudo-4D illusions only later.

## Implementation architecture

Use clear, small responsibilities. Example components (adapt names if needed, keep roles distinct):

- `PlayerController` (movement, view)
- `GestureCapture` (relative mouse input, filtering and 2D gesture points)
- `GestureRecognizer` (future extensible line/V/Z classification)
- `RiftRenderer` (3D mesh, edges, dark inner surface, animated rift lifecycle)
- `RiftProjectile` (travel, swept hit tests/collision, damage, cleanup)
- `EnemyController` or `Damageable` (HP, hit/death feedback)
- Later only: `CombatDirector`, `RiftInteractionSystem`, `DimensionalEffects`

Prefer exported tuning variables / lightweight data resources for speed, sensitivity, rift parameters. Prefer scene composition, signals and small reusable scripts over a single monolithic controller. Avoid premature abstractions that block a playable first build.

### Input/camera specifics

- Derive gesture input from `InputEventMouseMotion.relative` while mouse is captured. Do not depend on absolute OS cursor positions.
- Mouse delta can affect gesture AND camera rotation; tune separately so aiming remains possible.
- While drawing, keep gesture points in local 2D plane coordinates. Use a consistent camera transform on release to bake the rift into world space; no sudden position jump when turning the camera.
- Treat tiny taps gracefully by generating a short, weaker SCAR instead of an invalid gesture.
- Guard against zero-length vectors, identical repeated points, excessive vertices, degenerate faces and NaN transforms.

### Rendering/collision specifics

- For rifts, favor `ArrayMesh`/`SurfaceTool` and minimal dedicated shaders over heavyweight arbitrary mesh-cutting or CSG.
- Ensure a visible dark interior with distinct bright edges, actual 3D geometry, animated opening/collapse, and angular fragments.
- Fast traveling rifts **must not tunnel** through enemies between physics frames: use a swept volume/shape cast or equivalent robust approach.
- Runtime updates to meshes should be bounded; cleanup temporary nodes, mesh instances, particles and collision bodies.
- Keep visual effects readable during fast camera rotation, jumping, and close-range combat.

## Work order (mandatory)

**Phase 1** first: create the Godot project and start scene; implement FPS controller; low-poly arena; relative-motion drawing; 3D incision/fracture/propagation of SCAR; collision, HP and visible target response; minimal HUD. Ensure playability before expanding scope.

**Phase 2** after phase 1 passes: gesture recognition line/V/Z, geometrically distinct FANG and CHAINBREAK, three enemy types, waves, health, restart, sounds, style score.

**Phase 3** only after phase 2: HOLLOW, SIMPLEX, FOLD, HYPERCUT, interactions, pseudo-4D and advanced destruction.

When asked to continue, first read `docs/PROGRESS.md`, inspect existing code, and preserve working controls and mechanics. Do not rewrite functioning systems just to change style.

## Required development workflow

1. Read the relevant design sections, inspect current files and existing game structure, and state a short implementation plan for non-trivial work.
2. Make **real file changes**; code and scenes must be loadable by Godot. Do not provide only conceptual instructions as if the feature were implemented.
3. Prefer vertical, verifiable changes. Fix parser errors and scene/resource load errors before adding major features.
4. If Godot binary is available, run `godot --version`, then `godot --headless --path . --editor --quit` (after `project.godot` exists). With a start scene, run `godot --headless --path . --quit-after 120` or an equivalent smoke test. Adjust binary name/path for the actual machine.
5. Check logs, fix errors and repeat. If unavailable/permission denied, record the precise blocker and stop claiming tests have passed.
6. If graphical execution/interactive QA is available, check actual FPS inputs and the 3D rift presentation. **Do not equate headless success with visual proof.**
7. Update `docs/PROGRESS.md` with files touched, completed and incomplete items, commands/results and manual QA TODOs.
8. Report the exact gameplay behavior delivered and how to run it. Explicitly distinguish **implemented**, **tested**, **untested**, and **planned**.

## Safety of user files and repo hygiene

- Do not delete the original `docs/RIFTERMATH.md`, `AGENTS.md`, or the user's existing scenes/files without explicit need. Make minimal targeted changes.
- Do not copy/install the Godot executable or other large binaries into the repo.
- Don't commit `.godot/`, editor caches, temporary OS files, exports, build artifacts, or packaged executables unless explicitly requested.
- Do not log secrets, credentials or local absolute personal paths into source control.
- Do not overwrite existing hand-authored artwork or assets without justification.
- Always keep the project runnable after each completed stage, or clearly state the blocker.

## Definition of done: first vertical slice

- [ ] Godot project loads and runs its main 3D scene.
- [ ] Quake-style movement and camera controls work; can still move and look during gesture.
- [ ] Holding LMB draws a *visible 3D rift* with depth and angular edges.
- [ ] Releasing LMB performs fracture, sends a geometric SCAR forward, then collapses.
- [ ] A target can be hit/killed with visible feedback; swept collision mitigates tunneling.
- [ ] Code separated by responsibility and tuning values are exposed.
- [ ] Headless Godot checks have been actually executed if binary is available; manual visual QA explicitly described.
- [ ] `docs/PROGRESS.md` accurately summarizes the current state.
