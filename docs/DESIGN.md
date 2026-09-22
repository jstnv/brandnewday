# Design reference

This is the repository's implementation reference, consolidated from the design conversation and the Google Docs below. Later explicit user decisions take precedence. Items marked open or provisional are not approved features or fixed values.

## Sources

- [Overview](https://docs.google.com/document/d/109TVr5et9JMso8EyuYAxn64P4BNRqKDSnWkkeErqzsQ)
- [Combat](https://docs.google.com/document/d/18y2SSaXC6a2QSxpZX4bV0ALs57Gv2sW8GS3cCDe3K9M)
- [Expeditions](https://docs.google.com/document/d/1aS8WEhIDeb5n42xOiLRmg5TTYSXDgbiCW0qmdFRSSRg)
- [Design folder](https://drive.google.com/drive/folders/1Jq62Rt7nRSzlghNPcqe5raHRM2LBTp8E)

The source documents were reviewed at v0.3. The conversation subsequently confirmed damage per execution bash, weighted injury selection, the unconsciousness transition, and persistence of collected loot and completed objective steps. Those amendments are incorporated below. This file does not imply the Google Docs have been updated with those amendments.

## Identity and loop

Working title: **Brand New Day**. Godot, top-down zombie survival action inspired by Hotline Miami. A complete standalone experience with an ambiguous possible connection to Second Dawn; no explicit franchise branding or new shared-universe canon.

Deploy from the bunker, complete an objective or retreat, return through the entry approach, and retain expedition consequences. Operators can die permanently. Bunker continuity survives operator loss. First mission type: retrieval of something useful to the bunker. A replacement power unit in a maintenance depot is a proposal, not locked story content.

The opening duo consists of a playable survivor and a permanent NPC encountered in the tutorial. The NPC cannot deploy and can recruit a level-0 survivor when no operator is available. Detailed identities, relationships, and future roster size are open.

Stealth, loud, and mixed approaches are supported. Actions influence stat progression. **Strength → Toughness** is confirmed; the complete stat tree and Toughness's effect under the injury model are unresolved. Avoid heavy simulation gameplay.

## Movement

- Walking, crouching/sneaking, and sprinting. Sprint consumes stamina.
- Aiming and firing retain full current movement speed with no movement accuracy penalty. Encumbrance and injury can still reduce that current speed.
- Ordinary melee and executions do not consume stamina for now.
- Firearm reloading permits movement but prevents shooting until complete. Switching weapons cancels the reload.

## Standard zombie and combat

- One landed bullet kills a standard zombie. Weapon spread may still cause misses.
- A clean melee hit damages and knocks down one zombie. Each swing can knock down only one target; separate swings may leave several zombies down.
- Melee interrupts both attack windup and an active lunge.
- The standard zombie closes quickly after detection, briefly telegraphs, performs a committed nontracking lunge, and has a recovery period after missing. Exact timings are provisional.
- Remaining zombie health determines whether knockdown leaves it seated or prone. Both states permit execution. Another ordinary hit on a seated zombie makes it prone unless it kills it.
- Repeated ordinary melee damage can kill without an execution.
- Executions are fully committed: no voluntary cancellation, movement, or alternative attack. The operator remains vulnerable.
- Execution bashes each apply damage immediately. Remaining zombie health determines the required bash count; no fixed count or guaranteed final hit.
- Against a seated zombie, the first bash makes it prone, then finishing bashes use the faster prone cadence. An already prone zombie starts that cadence immediately.
- Applied damage persists if the operator dies or becomes incapacitated during an execution. Stop the attack when the target dies.

Earlier universal execution-duration proposals are superseded by damage-per-bash behavior. A three-second knockdown was a provisional baseline; seated/prone recovery, timer resets, damage, and cadence need tuning. Special enemy variants are not first-milestone requirements.

## Ammunition

Magazines are individual items with compatible ammunition and tracked round counts. Firearm reloading swaps magazines and retains partially filled magazines. The original stays inserted until reload completion; cancellation performs no swap, and retry restarts the timer.

Loose ammunition is loaded into a magazine through a separate action, including during expeditions. Stand still and add rounds individually. Moving cancels loading; rounds already loaded remain. Capacities, compatibility categories, and action timings remain provisional.

## Hearing

A hidden acoustic tile grid propagates each sound from its source level. Distance and traversed materials reduce the received level; geometry affects propagation paths. Walls are not transparent circles: obstructed routes must attenuate sound, while sound may reach around obstacles through connected routes.

Keep the strongest arrival at a tile for a given event rather than adding duplicate paths. Open doorways impose minimal loss, furniture smaller loss, closed wooden doors moderate loss, concrete larger loss, and soundproofing very large loss. Exact values and units are gameplay tuning, not a physical acoustics simulation.

Zombies ignore low received levels, may investigate intermediate levels, and reliably investigate high levels. They navigate toward the source using their navigation system; hearing does not grant omniscient tracking. Door state affects propagation. Hearing-roll frequency, thresholds, and timing remain open. A single roll per zombie per sound event is a possible implementation choice.

## Survivor injury and rescue

Use body-region condition and blood rather than a generic survivor HP bar. Working regions are head, torso, and left/right arms and legs. Weighted hit selection makes head hits less common; exact weights are provisional.

Injury states affect movement. Critical blood loss or critical non-arm region condition can incapacitate; arm injury alone does not. Mobile, conscious downed/crawling, unconscious, and dead are distinct states. Fatal damage or blood loss can cause permanent death; thresholds remain open.

While consciously downed, the survivor may slowly crawl and self-bandage. Bandaging stops bleeding without instantly restoring blood or limb condition. Normal attacks and carrying another survivor are unavailable. A desperate committed execution is possible: an already downed zombie is faster to execute; a standing zombie requires a leg strike and much longer ground execution.

Being lowered makes the survivor harder to see but still audible. Zombies that witness the collapse continue attacking; downing does not erase target awareness.

Full unconsciousness makes the survivor unplayable and immediately returns play to the bunker. Freeze that survivor's condition between expeditions. The next expedition can rescue them; their location, condition, and equipment persist. Deterioration and hostile interaction resume during the rescue expedition. Stabilize, then carry them to extraction; carrying adds encumbrance. Recruit a fresh level-0 operator if necessary. Actual death remains permanent.

Repeated rescue failure, multiple missing survivors, recovery after rescue, exact carry accounting, and detailed injury thresholds remain open.

## Inventory and encumbrance

Pants provide small-item pockets, jackets can add compartments, and backpacks provide more capacity. Model storage by weight capacity and allowed item categories, not a Resident Evil grid or one item per literal slot.

Total carried weight, including equipped items, determines encumbrance. Light permits full speed; Burdened reduces movement and sprint speed; Heavy slows further and disables sprint. Numeric thresholds, container restrictions, and the combination of injury and encumbrance penalties are provisional.

## Missions and persistence

- Entry and extraction share the same approach. Extraction is an outdoor area a meaningful distance beyond the doorway, not a door interaction.
- Walking into the valid exit area extracts automatically. Do not immediately extract the player on initial spawn; use departure/return state or suitable placement.
- Retreating before completion permits a later retry.
- Killed zombies remain dead. Collected loot remains gone and completed objective steps persist across retries.
- New zombies appear at the outer perimeter **between expeditions**, never as replenishment during an active expedition.
- Persistent mission objects need stable identities. Unresolved accounting details must not produce duplicate loot or silently resurrect killed zombies.

Survival expeditions are intended later; their rules are unresolved. Retreat reward accounting, bunker upgrades, resource economy, and leveling curves need further decisions.

## Scope discipline

Build a small, readable action prototype before the full campaign. Placeholder visuals and tunable numbers are acceptable. Deferring a locked system is acceptable when the milestone explicitly excludes it; replacing it with conflicting behavior is not. Inspiration games are references, not permission to import all their systems.
