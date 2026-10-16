class_name EffectCatalog
extends RefCounted
## Catalogue of buffs and debuffs. Each entry describes how an effect changes
## a unit while active. Effects are referenced by id from skill data.
##
## Fields:
##   kind:  "buff" or "debuff" (debuffs can be resisted, buffs cannot)
##   mods:  stat multipliers applied while active, e.g. {"atk": 0.5} = +50% ATK
##   flags: behavioural flags: "skip_turn", "no_heal", "taunt"
##   dot:   damage-over-time as fraction of the victim's max HP per turn

const EFFECTS := {
	"atk_up": {"name": "Attack Up", "kind": "buff", "mods": {"atk": 0.50}},
	"atk_down": {"name": "Attack Down", "kind": "debuff", "mods": {"atk": -0.50}},
	"def_up": {"name": "Defense Up", "kind": "buff", "mods": {"def": 0.60}},
	"def_down": {"name": "Defense Down", "kind": "debuff", "mods": {"def": -0.70}},
	"spd_up": {"name": "Speed Up", "kind": "buff", "mods": {"spd": 0.30}},
	"spd_down": {"name": "Speed Down", "kind": "debuff", "mods": {"spd": -0.30}},
	"crit_up": {"name": "Critical Up", "kind": "buff", "mods": {"crit_rate": 0.50}},
	"stun": {"name": "Stun", "kind": "debuff", "flags": ["skip_turn"]},
	"burn": {"name": "Burn", "kind": "debuff", "dot": 0.05},
	"bleed": {"name": "Bleed", "kind": "debuff", "dot": 0.04},
	"provoke": {"name": "Provoke", "kind": "debuff", "flags": ["taunt"]},
	"heal_block": {"name": "Heal Block", "kind": "debuff", "flags": ["no_heal"]},
	"immunity": {"name": "Immunity", "kind": "buff", "flags": ["immune"]},
}


static func get_effect(id: String) -> Dictionary:
	if not EFFECTS.has(id):
		push_error("Unknown effect id: %s" % id)
		return {}
	return EFFECTS[id]


static func is_debuff(id: String) -> bool:
	return get_effect(id).get("kind", "") == "debuff"
