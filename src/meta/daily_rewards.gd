class_name DailyRewards
extends RefCounted
## Daily login rewards on a 7-day cycle with a streak that resets after a
## missed day. Days roll over at 00:00 UTC.

const CYCLE := [
	{"gold": 10000},
	{"energy": 40},
	{"summon_ticket": 1},
	{"gold": 20000, "crafting_alloy": 2},
	{"crystals": 100},
	{"energy": 60, "gold": 15000},
	{"summon_ticket": 2, "crystals": 200},
]


static func day_key(now_unix: int) -> String:
	var dt := Time.get_datetime_dict_from_unix_time(now_unix)
	return "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]


static func can_claim(profile: PlayerProfile, now_unix: int) -> bool:
	return str(profile.flags.get("login_day", "")) != day_key(now_unix)


static func streak(profile: PlayerProfile) -> int:
	return int(profile.flags.get("login_streak", 0))


## Claims today's reward. Returns the reward granted, or {} if already claimed.
static func claim(profile: PlayerProfile, now_unix: int) -> Dictionary:
	if not can_claim(profile, now_unix):
		return {}
	var today := day_key(now_unix)
	var yesterday := day_key(now_unix - 86400)
	var s := streak(profile)
	s = s + 1 if str(profile.flags.get("login_day", "")) == yesterday else 1
	var reward: Dictionary = CYCLE[(s - 1) % CYCLE.size()].duplicate()
	profile.grant(reward)
	profile.flags["login_day"] = today
	profile.flags["login_streak"] = s
	return reward
