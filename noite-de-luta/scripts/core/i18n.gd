class_name I18n
extends RefCounted
## Idiomas do jogo. O texto-fonte é o português escrito direto no código e nos JSON de dados;
## os outros idiomas ficam em data/i18n/<idioma>.json no formato {"texto em pt": "tradução"}.
##
## Os Controls do Godot traduzem sozinhos o que recebem em .text (auto_translate), então a
## maior parte das telas não precisa chamar nada. Textos montados com "%s"/"%d" ou "{nome}"
## viram moldes: a chave "Semana %s" → "Week %s" traduz o texto pronto "Semana 12".
## Na tradução, "{1}", "{2}"... reordenam os trechos capturados; "[[m|f]]" escolhe pela
## concordância que o português marcou com {o}/{a}/{ao} na frase original.
## Textos que faltarem continuam aparecendo em português (nada quebra).
## tools/i18n_check.py lista o que falta; os passeios de tela com --i18n-miss=ARQ gravam o que
## apareceu na tela sem tradução.

const DEFAULT := "pt"
const LANGS: Array[String] = ["pt", "en", "es", "de", "fr", "ru", "zh"]
## Cada idioma escrito nele mesmo (é assim que quem não lê português acha o seu).
const LANG_NAMES: Array[String] = ["Português", "English", "Español", "Deutsch", "Français", "Русский", "中文"]
const _LOCALES := {"pt": "pt_BR", "en": "en", "es": "es", "de": "de", "fr": "fr", "ru": "ru", "zh": "zh_CN"}

static var lang: String = DEFAULT
static var _tables: Dictionary = {} # idioma → PatternTranslation
## Textos que chegaram à tela sem tradução (só quando `log_misses`, para as ferramentas).
static var log_misses := false
static var misses: Dictionary = {}
## Arquivo onde cada texto sem tradução entra numa linha (JSON), assim que aparece.
static var miss_path := ""


## Idioma do aparelho, se o jogo tiver; senão inglês.
static func detect() -> String:
	var l := OS.get_locale_language()
	if l in LANGS:
		return l
	return "en"


## Aplica o idioma (chamado ao abrir o app e ao trocar nas Opções).
static func apply(code: String) -> void:
	if code == "" or code not in LANGS:
		code = detect()
	lang = code
	# Só a tabela do idioma escolhido fica registrada: o Godot cai no locale "en" como
	# reserva, então deixar o inglês carregado traduziria até quando o jogo está em português.
	for other in _tables:
		TranslationServer.remove_translation(_tables[other])
	if code != DEFAULT:
		if not _tables.has(code):
			var t := _build(code)
			if t != null:
				_tables[code] = t
		if _tables.has(code):
			TranslationServer.add_translation(_tables[code])
	TranslationServer.set_locale(_LOCALES[code])


## Traduz um texto que não vai para um Control (desenhado à mão, comparado, cortado).
static func t(text: String) -> String:
	if lang == DEFAULT or text == "":
		return text
	var table: PatternTranslation = _tables.get(lang, null)
	if table == null:
		return text
	var out := table.lookup(text)
	return text if out == "" else out


## Tradução com contexto: a chave "contexto|texto" do catálogo vale antes da do texto sozinho
## (a mesma palavra em português com dois sentidos: "Mosca" é categoria e é barba).
static func tc(ctx: String, text: String) -> String:
	if lang == DEFAULT or text == "":
		return text
	var table: PatternTranslation = _tables.get(lang, null)
	if table == null:
		return text
	var out := table.exact(ctx + "|" + text)
	return out if out != "" else t(text)


## Formas da tradução separadas por "|" no catálogo ([texto] se não houver tradução).
static func forms(text: String) -> PackedStringArray:
	var table: PatternTranslation = _tables.get(lang, null)
	if lang == DEFAULT or table == null:
		return PackedStringArray([text])
	var f := table.forms(text)
	return f if not f.is_empty() else PackedStringArray([text])


static func is_pt() -> bool:
	return lang == DEFAULT


## Idiomas sem espaço entre palavras e sem caixa alta.
static func is_cjk() -> bool:
	return lang == "zh"


static func lang_name(code: String) -> String:
	var i := LANGS.find(code)
	return LANG_NAMES[i] if i >= 0 else code


static func _build(code: String) -> PatternTranslation:
	var path := "res://data/i18n/%s.json" % code
	if not FileAccess.file_exists(path):
		push_warning("I18n: sem arquivo de tradução para '%s'" % code)
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_warning("I18n: %s inválido" % path)
		return null
	var t := PatternTranslation.new()
	t.locale = _LOCALES[code]
	t.lang = code
	t.load_entries(parsed)
	return t


static func note_miss(src: String) -> void:
	if misses.has(src) or misses.size() >= 20000:
		return
	misses[src] = true
	if miss_path == "":
		return
	var f := FileAccess.open(miss_path, FileAccess.READ_WRITE if FileAccess.file_exists(miss_path) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify(src))
