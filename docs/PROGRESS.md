# Progress and handoff

## Current state

Milestone 1, Movement and Melee Combat Slice, is implemented on `codex/milestone-1-combat`. The Godot 4.7 project now launches directly into a small combat room with one survivor, two standard zombies, a fixed camera, original placeholder floor/walls, and a live state/event HUD.

The completed work is committed locally. Publishing the branch is blocked by unavailable GitHub write authentication: no credential is stored, `gh` is not installed, and the Git Credential Manager prompt is not exposed to the available UI-control surface. After authenticating Git for the repository, resume with `git push -u origin codex/milestone-1-combat`; no implementation work remains before that push.

Implemented gameplay:

- WASD walking, reduced-speed crouching, sprinting with stamina drain and delayed recovery, and mouse-directed aiming.
- Ordinary directional melee with damage, interruption, knockdown, closest-valid-target selection, a strict one-target-per-swing limit, and ordinary-melee kills.
- Health-based seated/prone knockdowns. A second ordinary hit moves a seated zombie to prone unless lethal.
- Execution eligibility for seated and prone zombies. Executions choose the closest eligible zombie, bind every bash to that one target, anchor the survivor to the exact starting position, lock movement and attacks, apply every bash immediately, stop on death, and choose bash count naturally from remaining health.
- A seated execution's first bash forces prone and uses the slower opening delay; already-prone and subsequent bashes use the faster cadence.
- Zombie hits visibly report an incoming hit and interrupt an execution without reverting bash damage. No temporary survivor health pool exists; injury consequences remain deferred.
- Standard-zombie detection, fast approach, visible windup, committed nontracking lunge, missed-lunge recovery, and ordinary-melee interruption during both windup and lunge.
- Instant room reset and a toggleable debug HUD for repeated testing.

No firearms, ammunition, inventory, acoustics, expeditions, bunker systems, progression, save data, campaign simulation, or survivor injury model was added.

## Launch and controls

Open `brand-new-day/project.godot` in Godot 4.7.1 and run the project, or from the repository root run:

```powershell
& "C:\path\to\Godot_v4.7.1-stable_win64.exe" --path brand-new-day
```

Controls:

- `WASD`: move
- Mouse: aim
- `Shift`: sprint
- `Ctrl` or `C`: crouch
- Left mouse button or `Space`: ordinary melee
- `E`: execute the nearest seated/prone zombie in range
- `R`: reset the room
- `F1`: toggle the debug HUD

## Verification performed

- Godot 4.7.1 stable (`a13da4feb`) completed the editor import/parser pass after the implementation. No parser, scene-load, or invalid-node-reference errors remained.
- The main scene ran under Godot for a runtime smoke check without milestone-related errors.
- `godot --headless --path brand-new-day --script res://scripts/milestone_verifier.gd` passed 26/26 focused in-engine checks:
  - scene launch with one survivor and two zombies;
  - walk, crouch, sprint, and stamina drain;
  - only the closest valid melee target is hit, with exactly one damaged/knocked-down target when two zombies occupy the same position;
  - high-health seated knockdown, seated-to-prone follow-up, and ordinary-melee death;
  - closest-eligible execution selection, every bash remaining bound to that one target even if another becomes closer, seated and prone eligibility, immediate per-bash damage, seated first-bash prone transition, distinct cadence, exact position anchoring against held movement and simulated external displacement, attack lock, no stamina cost, and stop-on-death;
  - execution interruption by an operator hit with already-applied damage retained;
  - telegraphed windup, fixed nontracking lunge direction, missed-lunge recovery, and melee interruption of both windup and active lunge.
- A rendered 1280×720 project frame was captured and inspected. Room boundaries, floor grid, survivor/aim indicator, both zombies, zombie health bars, controls, stamina, enemy states, deferred-injury notice, and event log were visible and readable.

The environment launched the native game process, but its window was not exposed to the available UI-control surface. Direct keyboard/mouse play was therefore unavailable and is not claimed as verified. The in-engine verifier exercises the actual scene scripts and input actions; it does not establish subjective combat feel.

## Provisional tuning and choices

All provisional values are centralized in `brand-new-day/scripts/combat_tuning.gd`:

- Movement: 210 px/s walk, 105 px/s crouch, 340 px/s sprint.
- Stamina: 100 maximum, 34/s sprint drain, 25/s recovery after a 0.65 s delay.
- Melee: 34 damage, 78 px range, 0.38 s cooldown.
- Execution: 24 damage per bash, 0.62 s seated opening delay, 0.31 s prone cadence.
- Standard zombie: 100 health, prone at 48 or less, 470 px detection, 155 px/s chase, 0.52 s windup, 455 px/s lunge for 0.28 s, 0.72 s recovery, and 4 s knockdown recovery.

The single-target rule selects the closest valid target in the aimed melee arc; it never applies one swing to a list of targets. Executions select the closest eligible downed zombie and retain that target for every bash. Simple drawn shapes keep all visuals original and make attack states readable by color.

## Known limitations

- The user's direct playtest is still needed to assess feel and tune movement, stamina, melee reach, telegraph readability, lunge pressure, and execution rhythm.
- The placeholder room and actors are deliberately minimal drawn geometry.
- Survivor injury, blood, incapacitation, and death are deferred exactly as required. Zombie hits currently report and interrupt only.
- Knockdown recovery is a provisional four-second timer.
- No controller bindings are included in this slice.

## Next action

Playtest Milestone 1 and record tuning feedback. Evaluate sprint pressure, whether melee range and cooldown feel deliberate, whether windup and lunge are readable but dangerous, whether knockdown recovery is fair, and whether seated versus prone executions feel meaningfully different. Do not begin Milestone 2 until that combat-feel review is complete.
