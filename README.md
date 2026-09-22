# Brand New Day

A standalone, top-down zombie expedition game in Godot. Fast, deliberate combat; persistent survivors; a bunker to return to. Any future connection to Second Dawn remains ambiguous.

## Project

Open `brand-new-day/project.godot` in the compatible Godot editor. The project currently declares Godot **4.7** and uses the Compatibility renderer. Verify the available editor version before changing project settings; do not silently downgrade the project.

Open the **repository root** as the coding workspace so development instructions and design documents are available.

- [Agent instructions](AGENTS.md)
- [Design decisions](docs/DESIGN.md)
- [Development milestones](docs/MILESTONES.md)
- [Handoff and progress](docs/PROGRESS.md)

## Starting autonomous development

Suggested first task:

> Read AGENTS.md and the docs. Implement milestone 1, using placeholder visuals and configurable provisional tuning. Run Godot when available, fix relevant errors, and update PROGRESS.md with what works, how to play, and remaining limitations. Continue through routine implementation choices without asking for confirmation. Stop at the milestone so I can assess the feel.

## Running

From the repository root, with the compatible Godot executable on PATH:

```sh
godot --editor --path brand-new-day
```

Once a main scene exists:

```sh
godot --path brand-new-day
```

For an import/parser check (not a substitute for playing):

```sh
godot --headless --path brand-new-day --editor --quit
```

Some systems name the executable `godot4`; use the installed executable or its full path. No export presets or packaged builds exist yet.
