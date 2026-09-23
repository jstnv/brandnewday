# Development milestones

This is a proposed implementation sequence, not additional game design. Execute the milestone assigned by the user. Complete each with a playable handoff before expanding scope.

## 1 — Movement and melee combat slice

Create one small placeholder combat room, a playable survivor, a standard zombie, a camera, and a minimal state/debug display. Implement walk, crouch, sprint and stamina; directional aiming; single-target melee damage/knockdown; seated and prone states; and committed damage-per-bash executions. Implement the standard zombie's detection, approach, telegraphed nontracking lunge, interrupt, and recovery. Use simple sight/range detection until acoustic propagation is introduced.

Survivor injury is explicitly deferred in this milestone. Enemy attacks should visibly report a hit without inventing a survivor HP pool or claiming that the survival loop is complete. Use a debug reset to replay the room. No ammunition, inventory, mission persistence, or campaign economy yet.

Done when:

- The main scene launches and controls are documented.
- Sprint consumes stamina; melee and execution do not.
- One melee swing cannot knock down two zombies, including when two overlap in range.
- Seated and prone executions follow their different opening sequences, apply damage on every bash, and end on death.
- The player cannot move or voluntarily cancel during execution.
- A melee hit interrupts windup and lunge. A missed lunge has recovery.
- Actual checks and unavailable verification are recorded in PROGRESS.md.

All timings, controls, and health thresholds are provisional. The user reviews combat feel at this boundary.

## 2 — Firearms and magazine actions

Add one provisional semi-automatic pistol, individual magazines, loose rounds, moving firearm reloads, and stationary per-round magazine loading. Normal shots use the standard zombie's health-based seated/prone/death states; prone zombies cannot be shot. Add tap firearm execution versus held physical execution for seated targets while preserving immediate prone physical executions. Verify canceled actions preserve ammunition and magazine identity; aiming and shooting do not slow movement. Inventory UI may be minimal while preserving item identity.

## 3 — First retrieval expedition

Add a minimal bunker/deployment screen, a small retrieval map, a neutral bunker-supply objective, and return-to-entry outdoor extraction. Persist objective completion, collected loot, and zombie deaths across retreat/retry. Introduce new perimeter zombies only between expeditions. Demonstrate a complete deployment, retrieval, extraction, and retry cycle. Save/load format and stable object identifiers are implementation choices.

## 4 — Injury, incapacitation, and rescue

Implement region condition, blood loss, weighted hit location, crawling, bandaging, desperate execution, unconsciousness return, permanent death, and rescue. Add the permanent bunker NPC's level-0 replacement recruitment. Verify the distinction between active expedition deterioration and frozen between-expedition state. Resolve blocking injury/rescue design questions with the user before assigning invented permanent rules.

## 5 — Sound, carrying, and progression

Introduce acoustic grid propagation and material attenuation, weight-capacity containers, encumbrance, and action-based progression. Confirm unresolved progression effects and economy before implementing them. Keep survival mission design and wider campaign scope separate until the retrieval loop is worth replaying.
