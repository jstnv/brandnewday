# Progress and handoff

## Current state

Milestone 1 and Milestone 2 passed the user's hands-on playtests and are accepted. Milestone 3, First Retrieval Expedition, is implemented on `codex/milestone-3-retrieval` from the published remote `origin/codex/milestone-2-firearms` history.

The local GitHub push was blocked by unavailable write credentials. A binary-capable one-commit transfer patch named `brand-new-day-milestone-3.patch` was exported from the published Milestone 2 base for authenticated publication.

The project now launches at a minimal bunker/deployment screen. Deploying enters one handcrafted depot map containing the accepted survivor combat kit, stable-identity zombies, a neutral bunker-supply objective, interior partitions, an outdoor return/extraction area, and a complete retreat/retry loop.

Implemented Milestone 3 behavior:

- `Enter` deploys from the bunker into the depot. Returning to the western outdoor extraction area automatically ends the expedition after the survivor has moved into the map.
- The initial spawn cannot immediately extract. The survivor must first depart beyond the approach threshold and later return to the green outdoor area.
- The bunker supply uses stable item identity `bunker_supply_01`. Pressing `F` nearby secures it, removes it from later expeditions, and permanently completes the `supply_secured` objective step for the current run.
- Returning before securing the supply records a safe retreat. Deploying again retries the same objective with prior mission consequences intact.
- Core zombies use stable IDs. Death is recorded immediately, regardless of whether it came from melee, normal firearm damage, or execution. Dead zombies do not respawn on later expeditions.
- One new zombie is introduced at the eastern map perimeter when each retry begins. Introduced zombies also have stable IDs and remain dead after being killed. No zombies spawn during an active expedition.
- The bunker screen reports objective status, expedition count, successful returns, retreats, persistent kills, collected mission items, and the latest result.
- `F6` on the bunker screen clears in-memory mission persistence for repeated debug playtests.
- The map adds physical collision to the survivor, zombies, and interior depot partitions while preserving accepted combat behavior.

Persistence is deliberately session-scoped in this milestone. It proves stable identity and retry accounting without establishing a disk-save format or broader campaign economy.

No story significance was assigned to the bunker supply. No additional maps, extraction types, bunker simulation, save files, injury system, encumbrance, progression, acoustic propagation, or Milestone 4 systems were added.

## Launch and controls

Open `brand-new-day/project.godot` in Godot 4.7.1 and run the project, or run the executable with `--path brand-new-day`.

Bunker:

- `Enter`: deploy
- `F6`: clear mission persistence for debug replay

Expedition:

- `WASD`: move
- Mouse: aim
- `Shift`: sprint
- `Ctrl` or `C`: crouch
- `1`: select melee
- `2`: select pistol
- Left mouse button: use selected weapon
- `Space`: ordinary melee while melee is selected
- `E`: execute; tap/hold choice applies to seated target with pistol selected
- `R`: reload pistol
- `Q`: cycle loose-round magazine target
- `L`: load loose rounds while stationary
- `F`: collect bunker supply when nearby
- `F1`: toggle debug HUD

Walk back into the green western outdoor approach after entering the depot to retreat or extract. Objective completion determines the return result.

## Verification performed

- The branch was created from remote Milestone 2 commit `0a90df3`; the differently hashed local Milestone 2 branch was preserved unchanged.
- Godot 4.7.1 stable (`a13da4feb`) completed the import/parser pass with no script, scene, or invalid-node-reference errors.
- The main bunker scene completed a runtime smoke check.
- The focused verifier passed 66/66 checks. All accepted Milestone 1 and 2 checks still pass, plus checks confirming:
  - first expedition core zombies and available supply;
  - stable zombie identities and immediate death recording;
  - supply disappearance and persistent objective completion;
  - no mid-expedition zombie introduction;
  - successful return through outdoor extraction;
  - killed zombies absent on retry;
  - collected supply absent on retry;
  - a new stable-identity zombie introduced at the perimeter between expeditions;
  - safe retreat before objective completion;
  - incomplete objective persistence across retreat/retry;
  - bunker-first launch and bunker-to-expedition deployment.
- Rendered 1280×720 frames of both screens were inspected. Bunker state text, map partitions, actors, objective, green outdoor extraction, controls, mission status, ammunition HUD, and events were visible and readable.

Direct keyboard/mouse automation remains unavailable because the native window is not exposed to the available UI-control surface. The user should perform the subjective Milestone 3 playtest; no direct manual interaction is claimed here.

## Provisional choices and limitations

- Mission persistence is in memory and lasts until the game closes or `F6` clears it.
- One perimeter zombie is added per retry. This is a provisional pressure curve.
- The bunker supply and map use original placeholder geometry and neutral wording.
- Equipment and ammunition are initialized on each deployment; campaign inventory persistence and economy remain deferred.
- The handcrafted depot uses simple collision partitions rather than navigation/pathfinding. Zombies pursue directly and can be separated by walls.
- Survivor injury consequences remain deferred; incoming attacks still report hits and interrupt executions.

## Next action

Playtest the first retrieval loop. Evaluate clarity of deployment, the meaningful distance to extraction, objective discovery/interaction, whether retreat feels understandable, whether persistent kills and removed supply are obvious on retry, and whether one perimeter zombie per expedition creates useful pressure. Stop after this review; do not begin Milestone 4.
