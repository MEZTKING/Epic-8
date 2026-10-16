# Design Reference — Core Systems

This document is the source of truth for rule names. Every name here is
original to this project. See `docs/LEGAL_NOTES.md` for why that matters.

## Elements
Flame → Verdant → Frost → Flame (each beats the next). Radiant and Umbral beat
each other. Advantage: +15% crit chance, ×1.10 damage. Disadvantage: −25% crit
chance.

## Stats
| Stat | Notes |
|---|---|
| Attack | Main damage source |
| Defense | Mitigation = 1 / (1 + DEF × 0.003) |
| Health | |
| Speed | Fills the initiative gauge |
| Crit Rate / Crit Damage | Base 15% / 150% |
| Effectiveness | Reduces the target's chance to resist debuffs |
| Resistance | Chance to resist debuffs; never below 15% |

Level scaling: a stat at level L = max × (0.35 + 0.65 × (L−1)/59). Percent stats
do not scale.

## Initiative gauge
Every unit's gauge fills continuously at a rate equal to its Speed. The first
unit to reach 100 takes a turn, then drops to 0. Skills can push gauges
(e.g. +20% to all allies). Ties break by higher Speed, then player team, then
slot.

## Turn flow
1. Damage-over-time ticks on the actor.
2. If stunned, the turn is skipped.
3. The team gains 10 Resolve (cap 100). Resolve empowers skills that have a
   Resolve cost: ×1.25 damage.
4. Skill chosen → targets chosen → skill resolved → cooldowns and effect
   durations tick down.

## Effects
Buffs cannot be resisted. Debuffs roll: base chance, then
`resist = max(RES − EFF, 0.15)`. Immunity blocks debuffs. Provoke forces the
provoked unit to attack its provoker. Heal Block prevents healing.

## Reactions and passives
- **Counterattack** (Fury set): when hit by a single-target attack, 20% chance to
  reply with skill 1. Stunned units cannot counter.
- **Dual attack** (Twin set): when an ally lands a single-target attack, each
  Twin-wearing ally has a 20% chance to follow up with skill 1. One per attack.
- **Lifesteal** (Siphon set): heal 20% of damage dealt.
- **Extra turn**: the skill refills the actor's gauge to 100 immediately.
- Reactions never set cooldowns and never trigger further reactions.
- **Passives** fire on a trigger (`on_turn_start`, `on_hit`, `on_ally_attacked`,
  `on_kill`), with an optional chance and cooldown. They can heal, push the
  owner's gauge, and apply effects to the owner, the attacker, or the victim.

## Barriers, dispel, cleanse
- **Barrier** absorbs damage before HP. Its size scales with the caster's Attack
  and/or the target's max HP. A new barrier replaces a weaker one, never stacks.
- **Dispel** removes N buffs from an enemy (newest first). It rolls against
  Resistance like a debuff.
- **Cleanse** removes N debuffs from an ally.

## Skill enhancement
Each skill has an ordered list of upgrade deltas (multiplier, chance, cooldown,
heal, gauge push). A hero's skill level selects how many apply. Base data is
never mutated.

## Manual play and replays
Teams in `manual_teams` pause the engine for input. Every action (AI or human)
is recorded as a decision. Seed + team specs + decisions replay to an identical
log, which is the basis for bug reports and asynchronous PvP verification.

## Gear
Six slots: Weapon (ATK), Helm (HP), Armor (DEF) have fixed main stats;
Necklace, Ring, Boots roll theirs. Rarity 2–5★ gives 1–4 starting substats.
Enhancement +0..+15; every third level adds or improves a substat. Set bonuses
require 2 or 4 pieces and stack.

## Summons
5★ 1.5%, 4★ 5%, 3★ 93.5%. Half of 5★ results on a featured banner are the
featured hero. Hard pity guarantees the featured hero on the 120th pull since
the last featured result. All of these numbers are displayed in-game.

## Naming glossary (ours → generic description)
- Initiative gauge — speed-based turn meter
- Resolve — team-wide resource spent to empower skills
- Bonds — duplicate-hero passive (Milestone 3)
- Relics — equippable team-wide passive items (Milestone 4)
- Awakening — material-gated stat tiers (Milestone 3)
