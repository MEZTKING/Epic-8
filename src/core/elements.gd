class_name Elements
extends RefCounted
## Five-element cycle. Flame > Verdant > Frost > Flame. Radiant and Umbral
## counter each other. These names are original to this project.

enum Type { FLAME, FROST, VERDANT, RADIANT, UMBRAL }

const NAMES := {
	Type.FLAME: "Flame",
	Type.FROST: "Frost",
	Type.VERDANT: "Verdant",
	Type.RADIANT: "Radiant",
	Type.UMBRAL: "Umbral",
}


static func parse(name: String) -> Type:
	match name.to_lower():
		"flame": return Type.FLAME
		"frost": return Type.FROST
		"verdant": return Type.VERDANT
		"radiant": return Type.RADIANT
		"umbral": return Type.UMBRAL
	push_error("Unknown element: %s" % name)
	return Type.FLAME


## +1 = attacker has advantage, -1 = disadvantage, 0 = neutral.
static func advantage(attacker: Type, defender: Type) -> int:
	if attacker == Type.FLAME and defender == Type.VERDANT: return 1
	if attacker == Type.VERDANT and defender == Type.FROST: return 1
	if attacker == Type.FROST and defender == Type.FLAME: return 1
	if attacker == Type.RADIANT and defender == Type.UMBRAL: return 1
	if attacker == Type.UMBRAL and defender == Type.RADIANT: return 1
	if defender == Type.FLAME and attacker == Type.VERDANT: return -1
	if defender == Type.VERDANT and attacker == Type.FROST: return -1
	if defender == Type.FROST and attacker == Type.FLAME: return -1
	return 0
