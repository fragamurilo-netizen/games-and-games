extends Node
## Compras na Google Play: a Carreira Completa (libera da 2ª temporada em diante e os mods) e o
## café (gorjeta consumível). A compra fica guardada no aparelho para o jogo seguir offline e é
## conferida com a Play sempre que houver conexão (restaura ao reinstalar, revoga se reembolsada).
## Fora da versão de loja (editor, PC, builds de debug) tudo vem liberado.

signal changed
signal message(text: String)

const FULL := "carreira_completa"
const TIP := "cafe"
const PRODUCTS := [FULL, TIP]
const FILE := "user://store.cfg"
const SALT := "mais-uma-rodada/1"

## -1 = automático; 0 = nunca cobra; 1 = sempre cobra (testes).
var enforce_override: int = -1
var owned: bool = false
var pending: bool = false
var prices := {FULL: "R$ 9,99", TIP: "R$ 2,99"}

var _client: Object = null
var _products_ready := false
var _want: String = ""


func _ready() -> void:
	_load()
	changed.connect(func(): Mods.allowed = unlocked())
	Mods.allowed = unlocked()
	if not enforced() or not Engine.has_singleton("GodotGooglePlayBilling"):
		return
	var script: Script = load("res://addons/GodotGooglePlayBilling/BillingClient.gd") if ResourceLoader.exists("res://addons/GodotGooglePlayBilling/BillingClient.gd") else null
	if script == null:
		return
	_client = script.new()
	add_child(_client)
	_client.connected.connect(_on_connected)
	_client.disconnected.connect(func(): _products_ready = false)
	_client.connect_error.connect(func(code: int, _msg: String): push_warning("Play Billing: erro %d ao conectar" % code))
	_client.query_product_details_response.connect(_on_details)
	_client.query_purchases_response.connect(_on_purchases_query)
	_client.on_purchase_updated.connect(_on_purchase_updated)
	_client.consume_purchase_response.connect(func(_r: Dictionary): pass)
	_client.acknowledge_purchase_response.connect(func(_r: Dictionary): pass)
	_client.start_connection()


## A versão de loja cobra; editor, PC e builds de debug não.
func enforced() -> bool:
	if enforce_override >= 0:
		return enforce_override == 1
	return OS.has_feature("android") and not OS.is_debug_build()


func unlocked() -> bool:
	return owned or not enforced()


## A carreira passou da temporada de demonstração e ainda não foi comprada.
func locked(w: GameWorld) -> bool:
	return w != null and w.season_number >= 2 and not unlocked()


func price(id: String = FULL) -> String:
	return String(prices.get(id, ""))


func buy(id: String = FULL) -> void:
	if not enforced():
		owned = true if id == FULL else owned
		_save()
		changed.emit()
		return
	if _client == null:
		message.emit("As compras só funcionam na versão instalada pela Google Play.")
		return
	if not _client.is_ready() or not _products_ready:
		_want = id
		message.emit("Conectando à Google Play...")
		_client.start_connection()
		return
	var r: Dictionary = _client.purchase(id)
	if int(r.get("response_code", -1)) != 0:
		message.emit(_error_text(int(r.get("response_code", -1))))


func restore() -> void:
	if _client == null:
		message.emit("As compras só funcionam na versão instalada pela Google Play.")
		return
	if not _client.is_ready():
		_client.start_connection()
		message.emit("Conectando à Google Play...")
		return
	_client.query_purchases(0)
	message.emit("Procurando suas compras...")


func _on_connected() -> void:
	_client.query_product_details(PackedStringArray(PRODUCTS), 0)
	_client.query_purchases(0)


func _on_details(r: Dictionary) -> void:
	if int(r.get("response_code", -1)) != 0:
		return
	for d in r.get("product_details", []):
		var offers: Variant = d.get("one_time_purchase_offer_details_list")
		if offers is Array and not offers.is_empty():
			prices[String(d.get("product_id", ""))] = String(offers[0].get("formatted_price", ""))
	_products_ready = true
	changed.emit()
	if _want != "":
		var id := _want
		_want = ""
		buy(id)


func _on_purchases_query(r: Dictionary) -> void:
	if int(r.get("response_code", -1)) != 0:
		return
	var has_full := false
	pending = false
	for p in r.get("purchases", []):
		if _has(p, FULL):
			if int(p.get("purchase_state", 0)) == 1:
				has_full = true
			elif int(p.get("purchase_state", 0)) == 2:
				pending = true
		_handle(p, false)
	if has_full != owned:
		owned = has_full
		_save()
	changed.emit()


func _on_purchase_updated(r: Dictionary) -> void:
	var code := int(r.get("response_code", -1))
	if code == 7: # já comprado: confere e libera
		_client.query_purchases(0)
		return
	if code != 0:
		if code != 1:
			message.emit(_error_text(code))
		return
	for p in r.get("purchases", []):
		_handle(p, true)
	changed.emit()


func _handle(p: Dictionary, fresh: bool) -> void:
	var state := int(p.get("purchase_state", 0))
	var token := String(p.get("purchase_token", ""))
	if state == 2:
		pending = true
		if fresh:
			message.emit("Pagamento pendente. A compra é liberada assim que o Google confirmar.")
		return
	if state != 1:
		return
	if _has(p, FULL):
		if not owned:
			owned = true
			pending = false
			_save()
			if fresh:
				message.emit("Carreira Completa liberada. Bom jogo!")
		if not bool(p.get("is_acknowledged", false)):
			_client.acknowledge_purchase(token)
	if _has(p, TIP):
		_client.consume_purchase(token)
		if fresh:
			message.emit("Valeu pelo café! Isso ajuda muito o jogo a continuar.")


static func _has(p: Dictionary, id: String) -> bool:
	return Array(p.get("product_ids", [])).has(id)


static func _error_text(code: int) -> String:
	match code:
		2, 12, -3:
			return "Sem conexão com a Google Play. Tente de novo quando estiver on-line."
		3:
			return "A Google Play não aceita compras neste aparelho ou nesta conta."
		4:
			return "Este item não está disponível no momento."
		7:
			return "Você já tem este item. Use \"Restaurar compras\"."
		-1:
			return "A conexão com a Google Play caiu. Tente de novo."
	return "Não foi possível concluir a compra (código %d)." % code


func _sig(v: bool) -> String:
	return ("%s|%s|%s" % [SALT, OS.get_unique_id(), "1" if v else "0"]).sha256_text()


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(FILE) != OK:
		return
	owned = String(cf.get_value("store", "full", "")) == _sig(true)


func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("store", "full", _sig(owned))
	cf.save(FILE)
