class_name Store
extends RefCounted
## In-game store: currency/material offers with purchase limits, the mileage
## exchange, and real-money product definitions routed through a
## PurchaseProvider (see purchase_provider.gd). The store never grants paid
## currency without a receipt.

## limit: "none" | "daily" | "weekly" | "once"; max = purchases per period.
const OFFERS := {
	"gold_small": {"name": "Gold pouch", "cost": {"crystals": 50}, "reward": {"gold": 25000}, "limit": "daily", "max": 5},
	"energy_refill": {"name": "Energy refill", "cost": {"crystals": 40}, "reward": {"energy": 60}, "limit": "daily", "max": 3},
	"reforge_stone": {"name": "Reforge stone", "cost": {"crystals": 300}, "reward": {"reforge_stone": 1}, "limit": "weekly", "max": 2},
	"crafting_alloy": {"name": "Crafting alloy ×5", "cost": {"gold": 30000}, "reward": {"crafting_alloy": 5}, "limit": "daily", "max": 4},
	"mileage_ticket": {"name": "Summon ticket", "cost": {"mileage": 10}, "reward": {"summon_ticket": 1}, "limit": "none", "max": 0},
	"mileage_selector": {"name": "5★ hero selector", "cost": {"mileage": 200}, "reward": {"selector_5star": 1}, "limit": "none", "max": 0},
	"starter_pack": {"name": "Starter pack", "cost": {"crystals": 500}, "reward": {"gold": 100000, "summon_ticket": 10, "reforge_stone": 1}, "limit": "once", "max": 1},
}

## Real-money products. Prices are placeholders for the store page; the
## platform (Steam) is the source of truth for the displayed price.
const PRODUCTS := {
	"crystals_s": {"name": "Handful of crystals", "crystals": 600, "bonus": 0, "price_usd_cents": 499},
	"crystals_m": {"name": "Pouch of crystals", "crystals": 1300, "bonus": 100, "price_usd_cents": 999},
	"crystals_l": {"name": "Chest of crystals", "crystals": 2800, "bonus": 400, "price_usd_cents": 1999},
	"crystals_xl": {"name": "Vault of crystals", "crystals": 7500, "bonus": 1500, "price_usd_cents": 4999},
}

static var last_error: String = ""


static func period_key(limit: String, now_unix: int) -> String:
	var dt := Time.get_datetime_dict_from_unix_time(now_unix)
	match limit:
		"daily":
			return "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]
		"weekly":
			var days := int(now_unix / 86400)
			return "w%d" % int((days + 3) / 7)   # ISO-ish week starting Monday
		"once":
			return "once"
	return "none"


static func purchases_in_period(profile: PlayerProfile, offer_id: String, now_unix: int) -> int:
	var offer: Dictionary = OFFERS.get(offer_id, {})
	if offer.is_empty():
		return 0
	var rec: Dictionary = profile.flags.get("store_purchases", {}).get(offer_id, {})
	if str(rec.get("period", "")) != period_key(offer["limit"], now_unix):
		return 0
	return int(rec.get("count", 0))


static func remaining(profile: PlayerProfile, offer_id: String, now_unix: int) -> int:
	var offer: Dictionary = OFFERS.get(offer_id, {})
	if offer.is_empty():
		return 0
	if offer["limit"] == "none":
		return 999999
	return maxi(int(offer["max"]) - purchases_in_period(profile, offer_id, now_unix), 0)


static func buy(profile: PlayerProfile, offer_id: String, now_unix: int) -> bool:
	last_error = ""
	var offer: Dictionary = OFFERS.get(offer_id, {})
	if offer.is_empty():
		last_error = "unknown offer"
		return false
	if remaining(profile, offer_id, now_unix) <= 0:
		last_error = "purchase limit reached"
		return false
	if not profile.spend(offer["cost"]):
		last_error = "cannot afford"
		return false
	profile.grant(offer["reward"])
	var all: Dictionary = profile.flags.get("store_purchases", {})
	var key := period_key(offer["limit"], now_unix)
	var rec: Dictionary = all.get(offer_id, {})
	if str(rec.get("period", "")) != key:
		rec = {"period": key, "count": 0}
	rec["count"] = int(rec["count"]) + 1
	all[offer_id] = rec
	profile.flags["store_purchases"] = all
	return true


## Grants a real-money product after the provider verified the receipt.
## Receipts are remembered so a replayed callback cannot grant twice.
static func apply_purchase(profile: PlayerProfile, product_id: String, receipt_id: String) -> bool:
	last_error = ""
	var product: Dictionary = PRODUCTS.get(product_id, {})
	if product.is_empty():
		last_error = "unknown product"
		return false
	if receipt_id == "":
		last_error = "missing receipt"
		return false
	var receipts: Dictionary = profile.flags.get("receipts", {})
	if receipts.has(receipt_id):
		last_error = "receipt already applied"
		return false
	receipts[receipt_id] = product_id
	profile.flags["receipts"] = receipts
	profile.grant({"crystals": int(product["crystals"]) + int(product["bonus"])})
	return true
