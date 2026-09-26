class_name SaveManager
extends RefCounted
## Saves versionados em slots. Formato: Dictionary → store_var comprimido (ZSTD).
## Escrita atômica (.tmp → .sav, anterior vira .bak) e metadados leves (.meta.json) para listar rápido.

const DIR := "user://saves"
const SLOTS := 5
const MAGIC := "MUR1"
## Saves anteriores ao mundo multinacional (versão 1, país fictício) não são compatíveis.
const MIN_VERSION := 2


static func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		DirAccess.make_dir_recursive_absolute(DIR)


static func slot_path(slot: int) -> String:
	return "%s/slot_%d.sav" % [DIR, slot]


static func meta_path(slot: int) -> String:
	return "%s/slot_%d.meta.json" % [DIR, slot]


static func has_save(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot)) or FileAccess.file_exists(slot_path(slot) + ".bak")


## Grava o mundo no slot. Retorna OK ou o código de erro.
## Formato 2: cada clube e cada jogador vira um bloco de bytes à parte e o resto do mundo outro.
## Assim o GameManager monta o save aos poucos (alguns jogadores por quadro) e só a gravação
## comprimida vai para outra thread, sem travar a tela.
static func save_world(world: GameWorld, slot: int) -> Error:
	var cl: Array = []
	for c in world.clubs:
		cl.append(var_to_bytes(c.to_dict()))
	var pl: Array = []
	for p in world.players.values():
		pl.append(var_to_bytes(p.to_dict()))
	var err := write_file(pack_file(world, cl, pl), slot)
	if err == OK:
		write_meta(world, slot)
	return err


## Junta os blocos de clubes e jogadores ao resto do mundo (que é serializado aqui, na hora).
static func pack_file(world: GameWorld, club_blobs: Array, player_blobs: Array) -> Dictionary:
	return {"magic": MAGIC, "fmt": 2, "head": var_to_bytes(world.to_dict(false)), "cl": club_blobs, "pl": player_blobs}


## Escrita atômica do arquivo já montado. Só mexe em bytes prontos: pode rodar em outra thread.
static func write_file(data: Dictionary, slot: int) -> Error:
	_ensure_dir()
	var path := slot_path(slot)
	var tmp := path + ".tmp"
	var f := FileAccess.open_compressed(tmp, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return FileAccess.get_open_error()
	f.store_var(data, false)
	f.close()
	var d := DirAccess.open(DIR)
	if d == null:
		return ERR_CANT_OPEN
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			d.remove(path.get_file() + ".bak")
		d.rename(path.get_file(), path.get_file() + ".bak")
	return d.rename(tmp.get_file(), path.get_file())


## Abre o formato 2 de volta no dicionário único que o GameWorld.from_dict entende.
static func _unpack_file(data: Dictionary) -> Variant:
	if int(data.get("fmt", 1)) < 2:
		return data
	var head: Variant = bytes_to_var(data.get("head", PackedByteArray()))
	if not head is Dictionary:
		return null
	var cl: Array = []
	for b: PackedByteArray in data.get("cl", []):
		cl.append(bytes_to_var(b))
	var pl: Array = []
	for b: PackedByteArray in data.get("pl", []):
		pl.append(bytes_to_var(b))
	head["clubs"] = cl
	head["players"] = pl
	head["magic"] = MAGIC
	return head


static func write_meta(world: GameWorld, slot: int) -> void:
	var u := world.user_club()
	var meta := {
		"version": GameWorld.SAVE_VERSION,
		"club": u.name if u != null else "",
		"short": u.short_name if u != null else "",
		"club_id": world.user_club_id,
		"division": world.league_name(u.league_id) if u != null else "",
		"nation": u.nation if u != null else "",
		"year": world.year,
		"season": world.season_number,
		"round": world.season.day + 1 if world.season != null else 0,
		"date": world.season.date_label(mini(world.season.day, world.season.calendar.size() - 1), false) if world.season != null else "",
		"manager": world.manager_name,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"unix": Time.get_unix_time_from_system(),
		"crest": u.crest if u != null else {},
	}
	var f := FileAccess.open(meta_path(slot), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(meta))


static func read_meta(slot: int) -> Dictionary:
	if not FileAccess.file_exists(meta_path(slot)):
		return {}
	var f := FileAccess.open(meta_path(slot), FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


## Carrega o mundo do slot (tenta o .bak se o principal estiver corrompido). null se falhar.
static func load_world(slot: int) -> GameWorld:
	for path in [slot_path(slot), slot_path(slot) + ".bak"]:
		if not FileAccess.file_exists(path):
			continue
		var f := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
		if f == null:
			continue
		var data: Variant = f.get_var(false)
		f.close()
		if not (data is Dictionary) or data.get("magic", "") != MAGIC:
			continue
		data = _unpack_file(data)
		if not data is Dictionary:
			continue
		data = migrate(data)
		if data.is_empty():
			continue
		var w := GameWorld.from_dict(data)
		if w.clubs.is_empty() or w.season == null:
			continue
		ClubGenerator.upgrade_crests(w)
		KitDesign.ensure_all(w) # saves antigos: reservas da cor do titular
		return w
	return null


## Atualiza saves antigos para a versão atual.
## Campos novos não exigem passo de migração: from_dict() usa valores padrão.
## Mudanças de formato (renomear/mover campos) entram aqui como "if v < N: ..." em ordem.
static func migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("version", 1))
	if v < MIN_VERSION:
		push_warning("Save da versão %d (mundo antigo) não é compatível com a versão %d." % [v, GameWorld.SAVE_VERSION])
		return {}
	if v > GameWorld.SAVE_VERSION:
		push_warning("Save de uma versão mais nova (%d); abrindo com compatibilidade parcial." % v)
	data["migrated_from"] = v
	data["version"] = GameWorld.SAVE_VERSION
	return data


static func delete_slot(slot: int) -> void:
	var d := DirAccess.open(DIR)
	if d == null:
		return
	for suffix in [".sav", ".sav.bak", ".sav.tmp", ".meta.json"]:
		var name := "slot_%d%s" % [slot, suffix]
		if d.file_exists(name):
			d.remove(name)


static func first_free_slot() -> int:
	for i in range(1, SLOTS + 1):
		if not has_save(i):
			return i
	return -1


## Slot salvo mais recentemente (para "Continuar"), ou -1.
static func latest_slot() -> int:
	var best := -1
	var best_t := -1.0
	for i in range(1, SLOTS + 1):
		var m := read_meta(i)
		if m.is_empty() or not has_save(i) or not is_compatible(m):
			continue
		var t := float(m.get("unix", 0.0))
		if t > best_t:
			best_t = t
			best = i
	return best


static func is_compatible(meta: Dictionary) -> bool:
	return int(meta.get("version", 1)) >= MIN_VERSION
