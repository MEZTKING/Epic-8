# Covenant of Stars (working title)

Original turn-based hero-collector RPG built in Godot 4.3. See
[ROADMAP.md](ROADMAP.md) for the milestone plan and
[docs/DESIGN.md](docs/DESIGN.md) for the rules.

## Run
1. Install Godot 4.3 (standard build, no .NET needed).
2. Open `project.godot`, press F5. The sandbox scene shows the roster,
   simulates a seeded auto-battle, and rolls a 10x summon.

## Test
```
godot --headless --path . --script tests/run_tests.gd
```
Exits non-zero if any test fails.

## Layout
```
data/        hero and skill definitions (JSON)
src/core/    stats, elements, effects, data loading
src/battle/  initiative-gauge engine and damage math
src/gear/    gear, sets, generator
src/gacha/   summon system with pity
scenes/      Godot scenes (sandbox only for now)
tests/       headless test runner
docs/        design reference, legal notes
```
