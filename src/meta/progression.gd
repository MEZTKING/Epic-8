class_name Progression
extends RefCounted
## Progression tables: level caps, XP curve, promotion, awakening, bonds.
## Every number here is tuning and will move during balance passes.

const MIN_STARS := 3
const MAX_STARS := 6
const LEVEL_CAPS := {3: 30, 4: 40, 5: 50, 6: 60}
const MAX_AWAKENING := 6
const MAX_BOND := 5
const BOND_PER_LEVEL := 0.02          # +2% of the bond stat per bond level, team-wide
const BOND_PERCENT_PER_LEVEL := 0.01  # for percent stats (crit, eff, res)

## Gold cost of promoting from `stars` to `stars + 1`.
const PROMOTION_GOLD := {3: 20000, 4: 60000, 5: 150000}

## Materials per awakening tier (element-specific shard/core ids are built from the hero's element).
const AWAKENING_COSTS := [
	{"shard": 10, "core": 0, "gold": 5000},
	{"shard": 20, "core": 0, "gold": 10000},
	{"shard": 30, "core": 5, "gold": 20000},
	{"shard": 40, "core": 10, "gold": 40000},
	{"shard": 50, "core": 20, "gold": 80000},
	{"shard": 60, "core": 30, "gold": 150000},
]

## Cumulative stat bonuses at each awakening tier (0..6). Percent stats are flat additions.
const AWAKENING_BONUS := [
	{},
	{"atk": 0.03, "hp": 0.03},
	{"atk": 0.06, "hp": 0.06, "def": 0.03},
	{"atk": 0.09, "hp": 0.09, "def": 0.06, "crit_rate": 0.03},
	{"atk": 0.12, "hp": 0.12, "def": 0.09, "crit_rate": 0.05},
	{"atk": 0.16, "hp": 0.16, "def": 0.12, "crit_rate": 0.07, "spd": 0.02},
	{"atk": 0.20, "hp": 0.20, "def": 0.15, "crit_rate": 0.10, "spd": 0.04},
]

const BOND_STAT_BY_ROLE := {
	"warrior": "atk", "knight": "def", "mage": "atk",
	"ranger": "crit_rate", "healer": "hp", "assassin": "crit_dmg",
}


static func level_cap(stars: int) -> int:
	return LEVEL_CAPS.get(clampi(stars, MIN_STARS, MAX_STARS), 30)


## XP needed to go from `level` to `level + 1`.
static func xp_for_level(level: int) -> int:
	return int(roundf(120.0 * pow(float(level), 1.6)))


## Total XP from level 1 to `level`.
static func total_xp_to(level: int) -> int:
	var t := 0
	for l in range(1, level):
		t += xp_for_level(l)
	return t


static func awakening_bonus(tier: int) -> Dictionary:
	return AWAKENING_BONUS[clampi(tier, 0, MAX_AWAKENING)]


static func awakening_cost(next_tier: int, element: Elements.Type) -> Dictionary:
	if next_tier < 1 or next_tier > MAX_AWAKENING:
		return {}
	var c: Dictionary = AWAKENING_COSTS[next_tier - 1]
	var el: String = str(Elements.NAMES[element]).to_lower()
	var out := {"gold": int(c["gold"])}
	out["%s_shard" % el] = int(c["shard"])
	if int(c["core"]) > 0:
		out["%s_core" % el] = int(c["core"])
	return out


static func bond_stat_for_role(role: String) -> String:
	return BOND_STAT_BY_ROLE.get(role, "atk")


## Applies a hero's bond to a stat dictionary in place.
static func apply_bond(stats: Dictionary, role: String, bond_level: int) -> void:
	if bond_level <= 0:
		return
	var key := bond_stat_for_role(role)
	if key in Stats.PERCENT_KEYS:
		stats[key] = float(stats[key]) + BOND_PERCENT_PER_LEVEL * bond_level
	else:
		stats[key] = roundf(float(stats[key]) * (1.0 + BOND_PER_LEVEL * bond_level))
