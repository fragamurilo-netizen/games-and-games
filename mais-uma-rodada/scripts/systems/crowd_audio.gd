class_name CrowdAudio
extends RefCounted
## Som de torcida gravado de verdade, por clube, liga ou país. Quando existe uma gravação, ela toca
## no lugar da torcida sintetizada (CrowdSynth continua como reserva para quem não tem arquivo).
##
## Onde o jogo procura (o primeiro que existir):
##   user://custom/crowd/  (arquivos do jogador; no Android, a pasta de dados do app)
##   res://audio/crowd/    (os que vierem com o jogo)
## Nomes (OGG ou MP3):
##   <CHAVE_DO_CLUBE>.ogg          ambiente/cantos da torcida do clube (ex.: ENG_MSR.ogg)
##   <CHAVE_DO_CLUBE>_entrada.ogg  entrada dos times (ex.: o hino antes do jogo)
##   <CHAVE_DO_CLUBE>_gol.ogg      comemoração de gol
##   <LIGA>.ogg (ENG1, BRA1...), <PAÍS>.ogg (ARG, TUR...) e default.ogg valem para quem não tem o seu.

const DIRS: Array[String] = ["user://custom/crowd/", "res://audio/crowd/"]
const EXTS: Array[String] = ["ogg", "mp3"]

static var _cache: Dictionary = {}


## Ambiente em loop da torcida desse perfil (CrowdProfile.for_club), ou null.
static func loop_for(prof: Dictionary) -> AudioStream:
	for name in [String(prof.get("club", "")), String(prof.get("league", "")), String(prof.get("nation", "")), "default"]:
		if name == "":
			continue
		var st := _load(name, true)
		if st != null:
			return st
	return null


## Trecho especial ("entrada" ou "gol") do clube, ou null.
static func clip_for(prof: Dictionary, kind: String) -> AudioStream:
	var club := String(prof.get("club", ""))
	if club == "":
		return null
	return _load("%s_%s" % [club, kind], false)


static func _load(name: String, loop: bool) -> AudioStream:
	var key := name + ("|l" if loop else "")
	if _cache.has(key):
		return _cache[key]
	var st: AudioStream = null
	for d in DIRS:
		for ext in EXTS:
			var path := "%s%s.%s" % [d, name, ext]
			if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
				continue
			if ext == "ogg":
				var o := AudioStreamOggVorbis.load_from_file(path)
				if o != null:
					o.loop = loop
					st = o
			else:
				var m := AudioStreamMP3.new()
				m.data = FileAccess.get_file_as_bytes(path)
				m.loop = loop
				st = m
			if st != null:
				break
		if st != null:
			break
	_cache[key] = st
	return st


static func folder() -> String:
	return ProjectSettings.globalize_path(DIRS[0])
