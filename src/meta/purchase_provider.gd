class_name PurchaseProvider
extends RefCounted
## Interface for real-money purchases. The game calls start_purchase(); the
## provider later emits purchase_completed with a receipt id that the Store
## turns into currency. Milestone 9 adds a GodotSteam-backed provider.

signal purchase_completed(product_id: String, receipt_id: String)
signal purchase_failed(product_id: String, reason: String)


func start_purchase(_product_id: String) -> bool:
	push_error("PurchaseProvider.start_purchase not implemented")
	return false


## Development provider: completes instantly with a fake receipt when
## `auto_complete` is true, otherwise fails. Never ship with this enabled.
class Offline extends PurchaseProvider:
	var auto_complete := false
	var _counter := 0

	func start_purchase(product_id: String) -> bool:
		if not auto_complete:
			purchase_failed.emit(product_id, "purchases unavailable offline")
			return false
		_counter += 1
		purchase_completed.emit(product_id, "offline-%d" % _counter)
		return true
