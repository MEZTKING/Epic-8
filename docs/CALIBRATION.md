# Calibration notes

Source: a player's own account export from a third-party gear optimizer for a
comparable live game (290 heroes, 2,172 items). Only aggregate magnitudes were
taken from it. No names, art, text or data tables were imported.

## Endgame hero stats (6★, fully geared, per-hero final values)
| Stat | p50 | p90 | max |
|---|---|---|---|
| Attack | 1,722 | 3,818 | 6,484 |
| Health | 9,620 | 19,944 | 32,716 |
| Defense | 967 | 1,604 | 3,610 |
| Speed | 179 | 248 | 304 |
| Crit chance % | 36 | 103 | 152 |
| Crit damage % | 182 | 327 | 390 |
| Effectiveness % | 7 | 79 | 210 |
| Resistance % | 0 | 105 | 250 |

Roughly: gear triples base Attack, doubles-to-triples Health, and adds 50–110
Speed on top of a ~100 base. Our level-60 base stats are already on this scale.

## Gear budget per fully-equipped hero (sum over 6 pieces, excluding set bonuses)
| Contribution | p10 | p50 | p90 |
|---|---|---|---|
| Flat ATK | 515 | 525 | 721 |
| ATK % | 0 | 96 | 173 |
| Flat HP | 2,700 | 2,835 | 3,421 |
| HP % | 9 | 57 | 191 |
| Flat DEF | 310 | 310 | 415 |
| DEF % | 0 | 25 | 87 |
| Speed | 24 | 76 | 108 |
| Crit chance % | 4 | 53 | 77 |
| Crit damage % | 6 | 114 | 160 |
| Effectiveness % | 0 | 16 | 87 |
| Resistance % | 0 | 8 | 116 |

## Main stat at +15 (top item tier)
ATK 525 · HP 2,835 · DEF 310 · ATK/DEF/HP/EFF/RES % 65 · Speed 45 ·
Crit chance 60 · Crit damage 70. The tier below is ~5% lower on main stats.

## Substat value per roll (top tier / tier below)
| Substat | tier below (p10–p90) | top tier (p10–p90) |
|---|---|---|
| Flat ATK | 35–43 | 46–55 |
| Flat DEF | 28–34 | ~35–42 |
| Flat HP | 168–195 | ~210–245 |
| ATK/DEF/HP/EFF/RES % | 5–7.5 | 6–9 |
| Crit chance % | 3–5 | 4–6 |
| Crit damage % | 4.5–6.5 | 5.5–8 |
| Speed | 2–4 | 3.5–5 |

Top-tier rolls are ~1.25× the tier below; main stats only ~1.05×.

## Structure confirmed
- Items start with 4 (top rank), 3 or 2 substats and gain 5 rolls to +15:
  every observed +15 item had exactly starting + 5 rolls.
- Slot main stats: Weapon ATK, Helm HP, Armor DEF fixed; Necklace rolls crit
  damage most often; Ring ATK %; Boots Speed (two-thirds of all boots).
- 20 set types in use; Speed set is on 38% of equipped pieces.
- Best single-item Speed substat totals: p50 9, p90 17, max 27.

## Changes applied to our tuning
- Crit chance main stat at +15: 0.55 → 0.60.
- Flat substat rolls tightened: ATK 30–45, DEF 25–35, HP 150–200.
- Tier 2 (reforged) items: main stat ×1.05, substat rolls ×1.25 (was ×1.10 both).
- Added five sets so build variety is comparable: Pierce (ignore 15% DEF),
  Wrath (+30% damage to debuffed targets), Aegis (Immunity for 1 turn at battle
  start), Bastion (Barrier of 10% max HP at battle start), Reckless (+10%
  damage, −10% max HP).
- Added to roadmap (Milestone 8): an in-game gear optimizer, since the export
  shows players rely on one.
