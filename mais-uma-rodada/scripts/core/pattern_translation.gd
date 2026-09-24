class_name PatternTranslation
extends Translation
## Tradução por texto exato e por molde ("Meta: %s", "{player} marcou").
## Usada pelo I18n; o TranslationServer consulta _get_message para todo texto de Control.

const _TOKEN := "%(?:\\.\\d+)?[sdf]|\\{[A-Za-z_][A-Za-z0-9_]*\\}"
const _CACHE_MAX := 4000

## Títulos em caixa alta ("CENTRAL DO CLUBE") usam cópias em maiúsculas das chaves.
var _exact: Dictionary = {}
var _exact_upper: Dictionary = {}
var _patterns: Array = [] # {re: RegEx, anchor: String, names: Array, target: String, upper: bool}
var _patterns_upper: Array = []
var _cache: Dictionary = {}
var _token_re := RegEx.create_from_string(_TOKEN)
var _target_re := RegEx.create_from_string("%(?:\\.\\d+)?[sdf]|\\{[A-Za-z0-9_]+\\}")
var _letter_re := RegEx.create_from_string("\\p{L}")
var _ordinal_re := RegEx.create_from_string("(\\d+)[ºª]")


func load_entries(entries: Dictionary) -> void:
	for key in entries:
		var src := String(key)
		var dst := String(entries[key])
		if src.begins_with("_") or dst == "":
			continue
		_exact[src] = _ordinals(dst) if not dst.contains("%") else dst
		_exact_upper[src.to_upper()] = _exact[src].to_upper()
		if _token_re.search(src) != null:
			_add_pattern(src, dst, false)
			_add_pattern(src, dst, true)
	# Moldes mais longos primeiro: o mais específico vence.
	for list: Array in [_patterns, _patterns_upper]:
		list.sort_custom(func(a, b): return a["len"] > b["len"])


func _get_message(src_message: StringName, _context: StringName) -> StringName:
	var out := lookup(String(src_message))
	return StringName(out) if out != "" else StringName()


## Tradução do texto, ou "" se não houver.
func lookup(src: String, depth: int = 0) -> String:
	if src == "":
		return ""
	var hit: Variant = _exact.get(src, null)
	if hit != null:
		return hit
	if depth == 0 and _cache.has(src):
		return _cache[src]
	var upper := src == src.to_upper()
	if upper:
		hit = _exact_upper.get(src, null)
		if hit != null:
			return hit
	var out := ""
	for p in (_patterns_upper if upper else _patterns):
		if not src.contains(p["anchor"]):
			continue
		var m: RegExMatch = p["re"].search(src)
		if m == null:
			continue
		out = _ordinals(_render(p, m, depth))
		if upper:
			out = out.to_upper()
		break
	if depth == 0:
		if _cache.size() >= _CACHE_MAX:
			_cache.clear()
		_cache[src] = out
	return out


func _add_pattern(src: String, dst: String, upper: bool) -> void:
	var rx := "^"
	var names: Array = []
	var last := 0
	var anchor := ""
	var literal_len := 0
	for m in _token_re.search_all(src):
		var lit := src.substr(last, m.get_start() - last)
		if upper:
			lit = lit.to_upper()
		rx += _escape(lit)
		literal_len += lit.length()
		if lit.strip_edges().length() > anchor.length():
			anchor = lit.strip_edges()
		var tok := m.get_string()
		names.append(tok)
		if tok == "%d":
			rx += "(-?\\d+)"
		elif tok.ends_with("f"):
			rx += "(-?[\\d.,]+)"
		else:
			rx += "(.*?)"
		last = m.get_end()
	var tail := src.substr(last)
	if upper:
		tail = tail.to_upper()
	rx += _escape(tail) + "$"
	literal_len += tail.length()
	if tail.strip_edges().length() > anchor.length():
		anchor = tail.strip_edges()
	# Moldes sem nenhuma palavra ("%s (%d)") não têm o que traduzir.
	if _letter_re.search(anchor) == null:
		return
	var re := RegEx.create_from_string(rx)
	if not re.is_valid():
		return
	(_patterns_upper if upper else _patterns).append({"re": re, "anchor": anchor, "names": names, "target": dst, "len": literal_len})


func _render(p: Dictionary, m: RegExMatch, depth: int) -> String:
	var names: Array = p["names"]
	var groups: Array = []
	for i in names.size():
		var g := m.get_string(i + 1)
		# Trechos capturados que também são textos do jogo ("Acesso", "Zagueiro") vão traduzidos.
		if depth < 2 and not g.is_valid_int():
			var tg := lookup(g, depth + 1)
			if tg != "":
				g = tg
			elif g.contains(" · "):
				# Trecho composto ("Rodada 3 · Brasil A"): cada parte é traduzida sozinha.
				var parts := g.split(" · ")
				for j in parts.size():
					var tp := lookup(parts[j], depth + 1)
					if tp != "":
						parts[j] = tp
				g = " · ".join(parts)
		groups.append(g)
	var target: String = p["target"]
	var out := ""
	var last := 0
	var seq := 0
	for tm in _target_re.search_all(target):
		out += target.substr(last, tm.get_start() - last)
		var tok := tm.get_string()
		var val := tok
		if tok.begins_with("%"):
			# Placeholders "%" seguem a ordem da frase original.
			while seq < names.size() and not String(names[seq]).begins_with("%"):
				seq += 1
			if seq < groups.size():
				val = groups[seq]
			seq += 1
		else:
			var inner := tok.substr(1, tok.length() - 2)
			if inner.is_valid_int():
				var idx := int(inner) - 1
				if idx >= 0 and idx < groups.size():
					val = groups[idx]
			else:
				var idx := names.find(tok)
				if idx >= 0:
					val = groups[idx]
		out += val
		last = tm.get_end()
	return out + target.substr(last)


static func _escape(s: String) -> String:
	var out := ""
	for ch in s:
		if "\\^$.|?*+()[]{}".contains(ch):
			out += "\\"
		out += ch
	return out


## Em inglês, "3º" das traduções vira "3rd" depois que o número entra na frase.
func _ordinals(text: String) -> String:
	if not locale.begins_with("en") or not text.contains("º"):
		return text
	var out := text
	for m in _ordinal_re.search_all(text):
		var n := int(m.get_string(1))
		out = out.replace(m.get_string(), Fmt.ordinal(n))
	return out
