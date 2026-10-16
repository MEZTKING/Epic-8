# Covenant of Stars — Project Roadmap

Working title. An original turn-based hero-collector RPG in the style of modern
mobile gacha RPGs, built in Godot 4.3 (GDScript), targeting Steam (PC) first.

Legend: ✅ done · 🔄 in progress · ⬜ not started

---

## Milestone 0 — Foundation ✅ (this session)
Goal: a project that runs, with the core rules implemented as pure, testable code.

- ✅ Godot 4.3 project, GL Compatibility renderer (runs on weak PCs and later mobile)
- ✅ Data-driven heroes and skills (`data/heroes.json`, `data/skills.json`)
- ✅ Stat model with level scaling (`src/core/stats.gd`)
- ✅ Five-element cycle with advantage/disadvantage (`src/core/elements.gd`)
- ✅ Buff/debuff catalogue (`src/core/effect_catalog.gd`)
- ✅ Initiative-gauge turn engine, cooldowns, DoTs, stun, provoke, immunity,
  heal block, team Resolve resource (`src/battle/battle_engine.gd`)
- ✅ Damage formula, crit, elemental multipliers, effectiveness vs resistance
  (`src/battle/damage_calc.gd`)
- ✅ Gear: 6 slots, main stat, substats, enhancement, 10 sets (`src/gear/`)
- ✅ Summon system with published rates and hard pity (`src/gacha/`)
- ✅ Headless test suite, 19 tests (`tests/run_tests.gd`)
- ✅ Text-mode sandbox scene: roster, auto-battle log, 10x summon (`scenes/main.tscn`)
- ✅ Legal guardrails document (`docs/LEGAL_NOTES.md`)

## Milestone 1 — Combat depth ✅
Goal: the battle rules feel complete enough to balance against.

- ✅ Counterattack (Fury set), dual attack (Twin set), lifesteal (Siphon set), extra turn
- ✅ Dispel, cleanse, barrier (shield) effects
- ✅ Passive skills: on_turn_start, on_hit, on_ally_attacked, on_kill triggers with chance and cooldown
- ✅ Skill enhancement tiers (ordered upgrade deltas per skill; `BattleUnit.set_skill_level`)
- ✅ Manual input API: `manual_teams`, `submit_action(skill, target, empower)`; Resolve spent by the player
- ✅ Battle replay: `BattleEngine.to_replay()` → JSON → `BattleReplay.run()`; verified bit-identical logs
- ✅ Balance harness (`tests/balance_harness.gd`) with per-matchup and per-hero win rates
- ✅ New hero Ilsabet Dawnforge (barrier, dispel, cleanse, passive); 33 tests
- ⬜ Buff steal, stat-scaling barriers from DEF/HP, passive cooldown display
- ⬜ Balance pass. First harness run (200 games per matchup, no gear) found:
  sustain beats burst 93.5% and draws control by timeout. Heal output and the
  300-turn cap need tuning before PvE content is built on top.

## Milestone 2 — Content pipeline ✅
Goal: adding a hero takes 15 minutes and no engine changes.

- ✅ Decision: keep JSON as the source of truth (diffable, moddable, validator-friendly,
  works under the headless runner). Godot Resources can wrap it later if the editor
  inspector becomes the preferred authoring tool.
- ✅ Data validator (`src/core/data_validator.gd`, `tests/validate_data.gd`): schema,
  ranges, orphan skills, effect ids, AI profiles, portrait existence
- ✅ GitHub Actions workflow: import, validate, test, balance snapshot on every push
- ✅ Art spec (`docs/ART_SPEC.md`) and generated placeholder portraits for all 30 units
  (`tools/gen_portraits.py`, abstract shapes only)
- ✅ 12 playable heroes (≥2 per element), 15 enemy types, 3 hunt bosses
- ✅ Enemy AI profiles: skill modes strongest/support/rotation/random, target modes
  lowest_hp/highest_atk/lowest_def/random; bosses rotate skills and carry passives
- ✅ Defense-scaling damage for knights

## Milestone 3 — Progression ✅
- ✅ Hero levels and XP curve, star promotion 3★→6★ with same-star fodder and gold, level caps per star
- ✅ Awakening tiers 1–6 using element shards/cores and gold, cumulative stat bonuses
- ✅ Bonds: duplicate merge raises a role-based stat for the whole team (max 5)
- ✅ Player profile: gold, crystals, mileage, energy with timed regen, materials, heroes, gear, team presets
- ✅ Equip/unequip with ownership transfer; `build_team()` produces battle units with gear, skill levels and bonds
- ✅ Save/load to `user://save.json` with checksum, backup file, tamper detection; 44 tests
- ⬜ Steam Cloud sync (Milestone 9, needs GodotSteam)

## Milestone 4 — Gear economy ⬜ (next)
- ⬜ Inventory UI, equip/unequip, compare panel
- ⬜ Enhancement cost curve, reforge at +15, gear conversion
- ⬜ Crafting from boss materials
- ⬜ Lifesteal/counter set behaviours wired into engine

## Milestone 5 — Summoning and store ⬜
- ⬜ Banner definitions (featured hero, rotation dates, rate-up)
- ⬜ Mileage/exchange currency alongside hard pity
- ⬜ Rate disclosure panel (mandatory for Steam and most jurisdictions)
- ⬜ Free pull timers, daily/weekly reward loops
- ⬜ Decide: real-money purchases vs premium one-time purchase (see LEGAL_NOTES)

## Milestone 6 — Battle presentation ⬜
Goal: first thing that looks like a game.

- ⬜ 2D battle scene: 4v4 layout, HP bars, turn-order bar driven by the gauge
- ⬜ Skill buttons, target selection, auto/manual toggle, 1x/2x/3x speed
- ⬜ Skill animation pipeline: AnimationPlayer per hero + VFX scenes
- ⬜ Damage numbers, status icons, elemental advantage indicator
- ⬜ Controller and keyboard navigation (Steam Deck verification needs this)

## Milestone 7 — PvE content ⬜
- ⬜ Adventure chapters (10 chapters × 10 stages), stage rewards, star ratings
- ⬜ Boss hunts (gear farming, 13 difficulty tiers)
- ⬜ Ascension tower, daily material dungeons
- ⬜ Story delivery: dialogue scenes with portraits (original writing only)

## Milestone 8 — Meta UI ⬜
- ⬜ Lobby, hero list, hero detail (stats, skills, gear), team presets
- ⬜ Quests/achievements, mail, settings, localization framework (CSV → Godot translations)
- ⬜ Accessibility: scalable UI, colour-blind safe element icons

## Milestone 9 — Multiplayer and services ⬜
- ⬜ Async arena: fight AI-controlled defence teams uploaded by other players
- ⬜ Backend (if online economy chosen): account, inventory authority, anti-tamper
- ⬜ Guilds, leaderboards
- ⬜ Steamworks: achievements, cloud, rich presence via GodotSteam

## Milestone 10 — Polish and release ⬜
- ⬜ Original art pass (commissioned or in-house), original soundtrack, SFX
- ⬜ Steam store page, trailer, age rating questionnaire (loot-box disclosure)
- ⬜ Closed beta, balance pass from telemetry, crash reporting
- ⬜ Launch; live-ops calendar (banners, events)

---

## Order of operations after this session
1. Open the project in the Godot 4.3 editor and press F5 to see the sandbox.
2. Milestone 1 items are pure code and tests; do those before any UI.
3. Milestone 6 (battle scene) is the first visual milestone and the first
   thing worth showing other people.
