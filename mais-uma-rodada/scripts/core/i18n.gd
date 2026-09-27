class_name I18n
extends RefCounted
## Idiomas do jogo. O texto-fonte é o português escrito direto no código e nos JSON;
## inglês e espanhol ficam em data/i18n/<idioma>.json no formato {"texto em pt": "tradução"}.
##
## Os Controls do Godot traduzem sozinhos o que recebem em .text (auto_translate), então a
## maior parte das telas não precisa chamar nada. Para textos montados com "%s"/"%d" ou
## "{nome}", a chave do JSON vira um molde: "Meta: %s" → "Goal: %s" traduz "Meta: Acesso".
## Na tradução, "{1}", "{2}"... reordenam os trechos capturados quando a frase pedir.
## Textos novos que faltarem continuam aparecendo em português (nada quebra).
## tools/i18n_check.py lista o que ainda falta traduzir.

const DEFAULT := "pt"
const LANGS: Array[String] = ["pt", "en", "es"]
const LANG_NAMES: Array[String] = ["Português", "English", "Español"]
const _LOCALES := {"pt": "pt_BR", "en": "en", "es": "es"}

static var lang: String = DEFAULT
static var _tables: Dictionary = {} # idioma → PatternTranslation


## Aplica o idioma salvo nas opções (chamado ao abrir o app e ao trocar nas Opções).
static func apply(code: String) -> void:
	if code not in LANGS:
		code = DEFAULT
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


## Traduz um texto fora dos Controls (narração, notícias, sons de texto desenhados à mão).
static func t(text: String) -> String:
	if lang == DEFAULT or text == "":
		return text
	var table: PatternTranslation = _tables.get(lang, null)
	if table == null:
		return text
	var out := table.lookup(text)
	return text if out == "" else out


static func is_pt() -> bool:
	return lang == DEFAULT


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
	t.load_entries(parsed)
	return t
