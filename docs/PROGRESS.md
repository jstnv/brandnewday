# Progress and handoff

## Current state

Milestone 1 passed the user's hands-on playtest on 2026-09-23 and is accepted. Milestone 2, Semi-Automatic Firearm and Magazine Actions, is implemented on `codex/milestone-2-firearms`. The combat room preserves all accepted movement, melee, execution, and zombie behavior while adding one provisional pistol and the minimal ammunition model required to exercise it.

The original GitHub push attempt was blocked by unavailable repository write credentials. A binary-capable three-commit transfer patch named `brand-new-day-milestone-2.patch` was exported for authenticated publication.

Implemented Milestone 2 behavior:

- A selectable semi-automatic pistol fires at most once per trigger press/cadence and damages one closest valid target along the aimed shot direction.
- Normal shots use zombie remaining health to produce seated, prone, or dead states. A seated zombie becomes prone unless killed. Prone zombies are excluded from firearm targeting and do not shield a valid standing/seated target behind them.
- Connected shots interrupt zombie windup and active lunge. Aiming and firing do not alter the survivor's current movement speed.
- With the pistol selected, tapping Execute on a seated zombie commits a fast firearm execution. The shot occurs after a short tell, consumes exactly one round at that moment, and guarantees the bound target's death.
- Holding Execute for 0.25 seconds on a seated target chooses the existing physical bash execution without ammunition use. An empty tap gives clear feedback; an empty hold can still deliberately bash.
- A prone target, or any eligible target while melee is selected, begins the physical execution immediately without waiting for the tap/hold threshold.
- Firearm and physical executions preserve the accepted exact position lock, single-target binding, vulnerability, immediate bash damage, and interruption rules. Interruption before the firearm shot spends no round and deals no damage; state after the shot persists.
- Three individual magazines have stable identities, compatibility, round counts, and capacity. One is inserted and two are carried separately.
- Reloading selects the compatible carried magazine with the most rounds, breaking ties by stable ID. Movement remains available and firing is blocked. The old magazine stays inserted until completion; weapon switching cancels without a swap; retry starts the full timer; partial magazines are retained.
- `Q` cycles the clearly displayed loose-round loading target. `L` loads that compatible magazine one round at a time while stationary. Each completed round persists immediately; movement cancels without reverting loaded rounds. Capacity and compatibility are enforced.
- The HUD shows selected weapon, action/progress state, inserted magazine ID/count, spare magazine IDs/counts, loose ammunition, loading target, zombie states, and recent firearm/reload/execution events.
- Firing reports a debug sound event on misses; acoustic propagation remains deferred.

No expedition, bunker, persistence, encumbrance, full inventory, survivor injury, progression, extra firearm, automatic fire, acoustic grid, or Milestone 3 feature was added.

## Launch and controls

Open `brand-new-day/project.godot` in Godot 4.7.1 and run the project, or run the editor/executable with `--path brand-new-day` from the repository root.

- `WASD`: move
- Mouse: aim
- `Shift`: sprint
- `Ctrl` or `C`: crouch
- `1`: select melee
- `2`: select pistol
- Left mouse button: use selected weapon
- `Space`: ordinary melee while melee is selected
- `E`: execute; tap/hold choice applies to a seated target with pistol selected
- `R`: reload pistol
- `Q`: cycle loose-round magazine target
- `L`: start/stop loading loose rounds into the displayed target magazine
- `F5`: reset combat room
- `F1`: toggle debug HUD

## Verification performed

- Godot 4.7.1 stable (`a13da4feb`) completed the import/parser pass with no script, scene, or invalid-node-reference errors.
- The main scene completed a runtime smoke check without milestone-related errors.
- The focused in-engine verifier passed 53/53 checks, including all accepted Milestone 1 checks plus:
  - semi-automatic cadence and one-round consumption;
  - standing firearm transitions to seated, prone, and dead;
  - seated firearm transitions to prone or dead;
  - prone-target exclusion while a valid target behind it remains hittable;
  - firearm interruption of windup and lunge;
  - full movement speed while aiming/firing;
  - tap firearm execution, held bash execution, empty tap, empty hold, and immediate prone execution;
  - mutually exclusive execution modes and correct ammunition use;
  - pre-shot and post-shot interruption persistence;
  - stable magazine identities/counts, deterministic reload selection, movement during reload, blocked fire, cancellation without swap, full-timer retry, and partial-magazine retention;
  - one-at-a-time stationary loose-round loading, movement cancellation with retained rounds, compatibility rejection, and capacity enforcement.
- A rendered 1280×720 frame was inspected. The expanded controls, weapon/action state, inserted and spare magazine identities/counts, loose ammunition, loading target, survivor/zombie state, room, and event display were visible and readable.

Direct keyboard/mouse automation remains unavailable because the launched native game window is not exposed to the available UI-control surface. The user should judge firearm feel in a hands-on playtest; no direct Milestone 2 manual interaction is claimed here.

## Provisional tuning and choices

All provisional values remain centralized in `brand-new-day/scripts/combat_tuning.gd`.

- Pistol: 38 damage, 560 px range, 2° spread, 0.22 s cadence.
- Magazine: 8-round capacity; initial `MAG-A` 5/8 inserted, `MAG-B` 8/8 and `MAG-C` 2/8 carried; 12 loose 9mm rounds.
- Reload: 1.15 s; highest-round compatible spare selected, stable ID breaks ties.
- Loose-round loading: 0.38 s per round.
- Execution input: 0.25 s hold threshold; firearm execution shot at 0.14 s after commitment.
- Existing Milestone 1 movement, melee, zombie, knockdown, and physical-execution tuning is unchanged.

## Known limitations

- Firearm feel, spread, cadence, damage, reload time, magazine capacity, and tap/hold readability require the user's playtest.
- Placeholder presentation remains simple drawn geometry; firing has event feedback rather than bespoke animation/audio.
- The ammunition representation is intentionally minimal and does not implement general inventory containers.
- Survivor injury consequences and acoustic propagation remain deferred.
- No controller bindings are included.

## Next action

Playtest Milestone 2. Evaluate pistol cadence and damage, target selection around prone bodies, shot/lunge interruption clarity, firearm-execution tell and tap/hold reliability, empty feedback, moving reload readability, and the friction of stationary per-round loading. Stop here until that feedback is recorded; do not begin Milestone 3.
