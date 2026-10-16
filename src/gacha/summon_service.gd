class_name SummonService
extends RefCounted
## Summons through a PlayerProfile: pays the cost (ticket first, then
## currency, or a free pull), keeps per-banner pity in the profile, grants
## heroes and mileage, and records statistics for the disclosure panel.
##
## RNG: pass a seeded generator for tests/replays; by default the service
## randomises so reloading a save cannot reroll results.

const MILEAGE_PER_PULL := 1
const MAX_MULTI := 10

static var last_error: String = ""


static func pity_counter(profile: PlayerProfile, banner: Banner) -> int:
	return int(profile.flags.get("pity", {}).get(banner.id, 0))


static func free_pull_ready(profile: PlayerProfile, banner: Banner, now_unix: int) -> bool:
	if banner.free_pull_interval <= 0:
		return false
	var last := int(profile.flags.get("free_pull", {}).get(banner.id, -banner.free_pull_interval))
	return now_unix - last >= banner.free_pull_interval


## Returns {"ok": bool, "error": String, "results": Array, "paid": Dictionary, "free": bool}
static func pull(profile: PlayerProfile, banner: Banner, count: int, now_unix: int, rng: RandomNumberGenerator = null) -> Dictionary:
	last_error = ""
	var out := {"ok": false, "error": "", "results": [], "paid": {}, "free": false}
	if banner == null:
		out["error"] = "no banner"
	elif not banner.is_active(now_unix):
		out["error"] = "banner is not active"
	elif count < 1 or count > MAX_MULTI:
		out["error"] = "count must be 1..%d" % MAX_MULTI
	if out["error"] != "":
		last_error = out["error"]
		return out

	# Work out payment: free pull (single) > tickets > currency.
	var paid := {}
	var free := false
	if count == 1 and free_pull_ready(profile, banner, now_unix):
		free = true
	else:
		var tickets := int(profile.materials.get(banner.ticket, 0)) if banner.ticket != "" else 0
		var use_tickets := mini(tickets, count)
		var remaining := count - use_tickets
		var currency_cost := {}
		for k in banner.cost.keys():
			currency_cost[k] = int(banner.cost[k]) * remaining
		if remaining > 0 and not profile.can_afford(currency_cost):
			out["error"] = "not enough %s" % ", ".join(currency_cost.keys())
			last_error = out["error"]
			return out
		if use_tickets > 0:
			paid[banner.ticket] = use_tickets
			profile.spend({banner.ticket: use_tickets})
		if remaining > 0:
			profile.spend(currency_cost)
			for k in currency_cost.keys():
				paid[k] = int(paid.get(k, 0)) + int(currency_cost[k])

	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var system := SummonSystem.new(0, banner.featured_id)
	system.rng = rng
	system.pity_counter = pity_counter(profile, banner)
	var results := system.pull_many(count)
	for r in results:
		var h := profile.add_hero(r["hero_id"])
		r["uid"] = h.uid if h != null else ""
	_set_flag(profile, "pity", banner.id, system.pity_counter)
	if free:
		_set_flag(profile, "free_pull", banner.id, now_unix)
	profile.grant({"mileage": MILEAGE_PER_PULL * count})
	var stats: Dictionary = profile.flags.get("summon_stats", {})
	stats["total"] = int(stats.get("total", 0)) + count
	for r in results:
		var key := "r%d" % int(r["rarity"])
		stats[key] = int(stats.get(key, 0)) + 1
	profile.flags["summon_stats"] = stats
	out["ok"] = true
	out["results"] = results
	out["paid"] = paid
	out["free"] = free
	return out


static func _set_flag(profile: PlayerProfile, group: String, key: String, value) -> void:
	var g: Dictionary = profile.flags.get(group, {})
	g[key] = value
	profile.flags[group] = g


## Player-facing probability disclosure for a banner.
static func disclosure(banner: Banner) -> String:
	var lines: PackedStringArray = []
	lines.append("%s — summon rates" % banner.name)
	for row in SummonSystem.rate_table():
		lines.append("  %d★ hero: %.2f%%" % [row["rarity"], row["rate"] * 100.0])
	if banner.featured_id != "":
		var h := HeroDB.get_hero(banner.featured_id)
		var fname := h.name if h != null else banner.featured_id
		lines.append("  Featured (%s): %.1f%% of 5★ results, i.e. %.3f%% per summon" % [fname, banner.rate_up * 100.0, SummonSystem.RATES[5] * banner.rate_up * 100.0])
		lines.append("  Guarantee: the featured hero is granted on the %dth summon without a featured result. The counter is per banner and persists." % SummonSystem.HARD_PITY)
	else:
		lines.append("  No featured hero. 5★ results are evenly distributed among the summonable 5★ heroes.")
	lines.append("  Every summon grants %d mileage, exchangeable in the store." % MILEAGE_PER_PULL)
	if banner.free_pull_interval > 0:
		lines.append("  One free summon every %d hours." % (banner.free_pull_interval / 3600))
	var pool: PackedStringArray = []
	for r in [5, 4, 3]:
		var names: PackedStringArray = []
		for id in HeroDB.heroes_by_rarity(r):
			names.append(HeroDB.get_hero(id).name)
		pool.append("  %d★ pool (%d, equal odds within rarity): %s" % [r, names.size(), ", ".join(names)])
	lines.append_array(pool)
	return "\n".join(lines)
