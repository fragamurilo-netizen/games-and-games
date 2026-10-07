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
## Formato 3 (em fluxo): cada clube e cada jogador vira um bloco comprimido gravado direto no disco,
## um de cada vez — nunca existe uma cópia inteira do mundo na memória (no celular, o pico de memória
## do save antigo podia fazer o Android fechar o jogo). O GameManager usa o mesmo escritor aos poucos.
static func save_world(world: GameWorld, slot: int) -> Error:
	var wr := Writer.open(slot, world.clubs.size(), world.players.size())
	if wr == null:
		return ERR_CANT_OPEN
	for c in world.clubs:
		wr.add(c.to_dict())
	wr.add_all(encode_all(world.players.values()))
	var err := wr.finish(world)
	if err == OK:
		write_meta(world, slot)
	return err


const MAGIC3 := "MUR3"


## Escritor do formato 3: [MUR3][nº de clubes][nº de jogadores] blocos... [cabeça]; cada bloco é
## [tamanho original][tamanho comprimido][bytes zstd]. Grava num .tmp e troca no fim (atômico).
class Writer:
	var f: FileAccess
	var slot: int
	var tmp: String
	var closed := false

	static func open(slot_i: int, n_clubs: int, n_players: int) -> Writer:
		SaveManager._ensure_dir()
		var w := Writer.new()
		w.slot = slot_i
		w.tmp = SaveManager.slot_path(slot_i) + ".tmp"
		w.f = FileAccess.open(w.tmp, FileAccess.WRITE)
		if w.f == null:
			return null
		w.f.store_buffer(SaveManager.MAGIC3.to_ascii_buffer())
		w.f.store_32(n_clubs)
		w.f.store_32(n_players)
		return w

	func add(d: Dictionary) -> void:
		add_encoded(SaveManager.encode(d))

	## Bloco já pronto ([tamanho original, bytes zstd], de SaveManager.encode).
	func add_encoded(e: Array) -> void:
		var z: PackedByteArray = e[1]
		f.store_32(int(e[0]))
		f.store_32(z.size())
		f.store_buffer(z)

	func add_all(blocks: Array) -> void:
		for e in blocks:
			add_encoded(e)

	func abort() -> void:
		if closed:
			return # já cancelado ou terminado: não mexe no .tmp de outro save
		closed = true
		if f != null:
			f.close()
			f = null
		DirAccess.remove_absolute(tmp)

	func finish(world: GameWorld) -> Error:
		if closed:
			return ERR_ALREADY_IN_USE
		add(world.to_dict(false))
		closed = true
		f.close()
		f = null
		var path := SaveManager.slot_path(slot)
		var d := DirAccess.open(SaveManager.DIR)
		if d == null:
			return ERR_CANT_OPEN
		if FileAccess.file_exists(path):
			if FileAccess.file_exists(path + ".bak"):
				d.remove(path.get_file() + ".bak")
			d.rename(path.get_file(), path.get_file() + ".bak")
		return d.rename(tmp.get_file(), path.get_file())


## Um bloco do save: [tamanho original, bytes comprimidos].
static func encode(d: Dictionary) -> Array:
	var raw := var_to_bytes(d)
	return [raw.size(), raw.compress(FileAccess.COMPRESSION_ZSTD)]


## Serializa e comprime jogadores (ou clubes) em paralelo, na ordem. Ninguém pode mexer no
## mundo enquanto isso roda (quem chama espera o resultado).
static func encode_all(items: Array) -> Array:
	return Parallel.map_chunks(items.size(), func(a: int, b: int) -> Array:
		var out: Array = []
		for i in range(a, b):
			out.append(encode(items[i].to_dict()))
		return out, 128)


static func _read_block(f: FileAccess) -> Variant:
	var raw_n := f.get_32()
	var z_n := f.get_32()
	if raw_n <= 0 or z_n <= 0 or f.get_position() + z_n > f.get_length():
		return null
	var z := f.get_buffer(z_n)
	return bytes_to_var(z.decompress(raw_n, FileAccess.COMPRESSION_ZSTD))


## Lê o formato 3 bloco a bloco (clubes e jogadores já montados) — pico de memória pequeno.
static func _load_v3(path: String) -> GameWorld:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_buffer(4).get_string_from_ascii() != MAGIC3:
		return null
	var n_clubs := f.get_32()
	var n_players := f.get_32()
	var clubs: Array = []
	for i in n_clubs:
		var cd: Variant = _read_block(f)
		if not cd is Dictionary:
			return null
		clubs.append(Club.from_dict(cd))
	# Lê os blocos dos jogadores em sequência (disco) e abre em paralelo (CPU).
	var sizes := PackedInt32Array()
	sizes.resize(n_players)
	var blobs: Array = []
	blobs.resize(n_players)
	for i in n_players:
		var raw_n := f.get_32()
		var z_n := f.get_32()
		if raw_n <= 0 or z_n <= 0 or f.get_position() + z_n > f.get_length():
			return null
		sizes[i] = raw_n
		blobs[i] = f.get_buffer(z_n)
	var players := Parallel.map_chunks(n_players, func(a: int, b: int) -> Array:
		var out: Array = []
		for i in range(a, b):
			var pd: Variant = bytes_to_var((blobs[i] as PackedByteArray).decompress(sizes[i], FileAccess.COMPRESSION_ZSTD))
			out.append(Player.from_dict(pd, true) if pd is Dictionary else null)
		return out, 128)
	blobs.clear()
	if players.size() != n_players or players.has(null):
		return null
	var head: Variant = _read_block(f)
	f.close()
	if not head is Dictionary:
		return null
	head = migrate(head)
	if head.is_empty():
		return null
	return GameWorld.from_dict(head, clubs, players)


## Formato 2 (APKs de teste anteriores): blocos de bytes dentro de um store_var comprimido.
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
		var w3 := _load_v3(path)
		if w3 != null:
			if w3.clubs.is_empty() or w3.season == null:
				continue
			ClubGenerator.upgrade_crests(w3)
			KitDesign.ensure_all(w3)
			DropIns.apply_world(w3)
			return w3
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
		ClubGenerator.upgrade_kits(w) # saves de antes dos uniformes reais
		KitDesign.ensure_all(w) # saves antigos: reservas da cor do titular
		DropIns.apply_world(w)
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
