# Development instructions

## Read first

Read `docs/DESIGN.md`, `docs/MILESTONES.md`, and `docs/PROGRESS.md`. Godot project root is `brand-new-day/`; repository root is one directory above it. Preserve existing work.

The user's latest explicit instructions override these files. Confirmed design rules override proposals and provisional tuning. Earlier design documents describing a design-only phase do not prohibit implementation when the user assigns a development milestone.

## Autonomy

Complete the assigned milestone through implementation, relevant runtime checks, repairs, and handoff. Decide routine architecture, file names, placeholder visuals, controls, and provisional numeric tuning without asking. Record meaningful assumptions. Do not expand into subsequent milestones without an assignment covering them.

Ask when a necessary decision would change a locked design rule, establish new story canon, or substantially enlarge scope. Follow existing authorization for external writes; do not publish releases, spend money, rewrite shared history, or delete user work without authorization. Do not send messages to others.

## Model policy

Use GPT-5.6 Sol for the remainder of Brand New Day development. Do not select GPT-6 Astra for project work unless the user explicitly changes this decision; its cost is outside the intended project budget. Keep tasks bounded to the assigned milestone so Sol can work from focused context and leave a clean handoff.

## Implementation

- Use Godot and favor readable GDScript, small scenes, and explicit state transitions. Introduce abstractions only when needed.
- Inspect `project.godot` and available editor version before choosing version-sensitive APIs. Do not silently downgrade the declared version.
- Make provisional combat timings, damage, speeds, and thresholds easy to tune. Identify them as provisional rather than confirmed design.
- Do not introduce a generic survivor health pool: injury regions and blood are the locked model. If that system is outside the milestone, explicitly defer injury consequences.
- Do not introduce online services, multiplayer, heavy camp simulation, procedural worlds, or paid assets.
- Use original placeholder assets or appropriately licensed assets with provenance. Do not copy assets from inspiration games.
- Keep generated `.godot/` data, secrets, and build output out of git. Keep source assets and required Godot resource identifiers under version control.

## Verification and handoff

The user does not want a test suite prerequisite. Use relevant import/parser checks and manual play checks when Godot is available. Add automated tests only when requested or when a small targeted check resolves a concrete risky behavior; do not create tests merely to mirror implementation.

Never claim a game was run, a behavior verified, or a build exported when it was not. Report unavailable tools and the resulting limitations. Do not repeatedly run checks once the relevant concern is resolved.

Update `docs/PROGRESS.md` with completed work, controls, actual verification, provisional choices, known issues, and the next actionable step. Keep the project resumable. Provide a concise milestone handoff for the user to judge gameplay feel.
