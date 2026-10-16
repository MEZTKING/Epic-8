class_name DamageCalc
extends RefCounted
## Pure damage math. Tuning constants are this project's own.

const DEF_CONSTANT := 0.003        # mitigation = 1 / (1 + DEF * DEF_CONSTANT)
const ADV_CRIT_BONUS := 0.15       # elemental advantage: +15% crit chance
const ADV_DMG_MULT := 1.10         # elemental advantage: +10% damage
const DISADV_CRIT_PENALTY := 0.25  # disadvantage: -25% crit chance
const MIN_RESIST := 0.15           # debuffs can always be resisted 15% of the time
const VARIANCE := 0.05             # +/- 5% random roll


static func mitigation(defense: float) -> float:
	return 1.0 / (1.0 + maxf(defense, 0.0) * DEF_CONSTANT)


static func crit_chance(attacker: BattleUnit, defender: BattleUnit) -> float:
	var c := attacker.stat("crit_rate")
	var adv := Elements.advantage(attacker.data.element, defender.data.element)
	if adv > 0:
		c += ADV_CRIT_BONUS
	elif adv < 0:
		c -= DISADV_CRIT_PENALTY
	return clampf(c, 0.0, 1.0)


## Returns {"damage": float, "crit": bool, "advantage": int}
static func compute(attacker: BattleUnit, defender: BattleUnit, skill: SkillData, rng: RandomNumberGenerator, force_crit := false) -> Dictionary:
	var raw := attacker.stat("atk") * skill.multiplier + attacker.max_hp() * skill.hp_scaling + attacker.stat("def") * skill.def_scaling
	var adv := Elements.advantage(attacker.data.element, defender.data.element)
	var crit := force_crit or rng.randf() < crit_chance(attacker, defender)
	var dmg := raw
	if crit:
		dmg *= attacker.stat("crit_dmg")
	if adv > 0:
		dmg *= ADV_DMG_MULT
	dmg *= mitigation(defender.stat("def"))
	dmg *= 1.0 + rng.randf_range(-VARIANCE, VARIANCE)
	return {"damage": maxf(roundf(dmg), 1.0), "crit": crit, "advantage": adv}


## Chance that a debuff lands: base chance, then an Effectiveness vs Resistance check.
static func debuff_lands(base_chance: float, attacker: BattleUnit, defender: BattleUnit, rng: RandomNumberGenerator) -> bool:
	if rng.randf() >= base_chance:
		return false
	var resist := clampf(defender.stat("res") - attacker.stat("eff"), 0.0, 1.0)
	resist = maxf(resist, MIN_RESIST)
	return rng.randf() >= resist
