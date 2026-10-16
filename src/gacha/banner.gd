class_name Banner
extends RefCounted
## A summon banner. Loaded from data/banners.json by BannerDB.

var id: String
var name: String
var description: String
var type: String = "standard"       # "standard" | "featured"
var featured_id: String = ""
var cost: Dictionary = {"crystals": 100}
var ticket: String = ""             # item id that can pay for one pull instead of `cost`
var free_pull_interval: int = 0     # seconds between free pulls; 0 = none
var starts_at: int = 0              # unix; 0 = always
var ends_at: int = 0                # unix; 0 = never ends
var rate_up: float = 0.0            # share of 5★ results that are the featured hero


static func from_dict(d: Dictionary) -> Banner:
	var b := Banner.new()
	b.id = str(d.get("id", ""))
	b.name = str(d.get("name", b.id))
	b.description = str(d.get("description", ""))
	b.type = str(d.get("type", "standard"))
	b.featured_id = str(d.get("featured", ""))
	b.cost = d.get("cost", {"crystals": 100}).duplicate()
	b.ticket = str(d.get("ticket", ""))
	b.free_pull_interval = int(d.get("free_pull_interval", 0))
	b.starts_at = int(d.get("starts_at", 0))
	b.ends_at = int(d.get("ends_at", 0))
	b.rate_up = float(d.get("rate_up", 0.0))
	return b


func is_active(now_unix: int) -> bool:
	if starts_at > 0 and now_unix < starts_at:
		return false
	if ends_at > 0 and now_unix >= ends_at:
		return false
	return true


func seconds_remaining(now_unix: int) -> int:
	return -1 if ends_at == 0 else maxi(ends_at - now_unix, 0)
