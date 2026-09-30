class_name ContentDB
extends RefCounted
## Carrega o conteúdo "mod-friendly" de res://content/*.json
## (Game Design Bible §22). Nomes, organizações, lutadores canônicos, regras e
## cores vivem em dados, não em código.

const CONTENT_DIR := "res://content"


static func load_json(file_name: String) -> Variant:
	var path := "%s/%s" % [CONTENT_DIR, file_name]
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("ContentDB: não foi possível abrir %s" % path)
		return null
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data == null:
		push_error("ContentDB: JSON inválido em %s" % path)
	return normalize_ints(data)


## JSON não distingue int de float; no conteúdo autoral, número sem parte
## fracionária é int (anos, recordes, ratings).
static func normalize_ints(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			return int(v) if v == floorf(v) else v
		TYPE_ARRAY:
			return v.map(normalize_ints)
		TYPE_DICTIONARY:
			var out := {}
			for k in v:
				out[k] = normalize_ints(v[k])
			return out
	return v
