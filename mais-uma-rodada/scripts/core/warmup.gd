class_name Warmup
extends RefCounted
## Monta os caches preguiçosos (dados lidos na primeira consulta) antes de um trabalho em thread:
## assim a thread de trabalho e a tela nunca montam o mesmo dicionário ao mesmo tempo.

static var _done := false


static func run() -> void:
	if _done:
		return
	_done = true
	MarketAI.cfg()
	ClubDNA.db()
	ClubPhilosophy._db()
	BrandCatalog.find("")
	if CupManager._uf_cache.is_empty():
		for d in DatabaseManager.club_data("BRA"):
			CupManager._uf_cache[String(d.get("key", ""))] = String(d.get("uf", ""))
