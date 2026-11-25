class_name PatternTranslation
extends Translation
## Tradução por texto exato e por molde ("Meta: %s", "{a} derruba {b}.").
## Usada pelo I18n; o TranslationServer consulta _get_message para todo texto de Control.
##
## Moldes: cada "%s", "%d", "%.1f" ou "{nome}" da chave vira um trecho capturado do texto
## pronto. Na tradução, "%s" segue a ordem original e "{1}", "{2}"... escolhem o trecho.
## Trechos capturados que também são textos do jogo ("Pesado", "Rússia") vão traduzidos.
## "[[masc|fem]]" na tradução escolhe pela concordância que o português marcou com {o}, {a},
## {ao} ou {um} (o trecho capturado é "o"/"a", "ão"/"ã", "um"/"uma").

const _TOKEN := "%(?:\\.\\d+)?[sdf]|\\{[A-Za-z_][A-Za-z0-9_]*\\}"
const _CACHE_MAX := 6000
## Moldes com até tantas letras fixas são fracos (ver `_lookup_uncached`).
const _WEAK_LETTERS := 3
const _GENDER_TOKENS := ["{o}", "{a_}", "{ao}", "{um}", "{ele}", "{dele}"]
const _FEM_VALUES := ["a", "ã", "uma", "ela", "dela"]

var lang := ""
## Títulos em caixa alta ("NOITE DE LUTA") usam cópias em maiúsculas das chaves.
var _exact: Dictionary = {}
var _exact_upper: Dictionary = {}
var _exact_lower_first: Dictionary = {} # "pesado" → chave "Pesado" (texto que vem cortado)
## Traduções com formas separadas por "|" (gênero do gentílico, plurais do russo): a tela
## mostra a primeira; quem sabe escolher pede todas com `forms`.
var _forms: Dictionary = {}
## Moldes por palavra: a palavra mais longa do molde aponta para ele; o texto só testa os
## moldes das palavras que tem.
var _by_word: Dictionary = {}
var _by_word_upper: Dictionary = {}
var _cache: Dictionary = {}
var _token_re := RegEx.create_from_string(_TOKEN)
var _target_re := RegEx.create_from_string("%(?:\\.\\d+)?[sdf]|\\{[A-Za-z0-9_]+\\}")
var _letter_re := RegEx.create_from_string("\\p{L}")
var _word_re := RegEx.create_from_string("\\p{L}+")
var _ordinal_re := RegEx.create_from_string("(\\d+)[ºª]")
var _lead_num_re := RegEx.create_from_string("^([-+]?[\\d.,%]+ )(\\p{L}.*)$")
var _punct_re := RegEx.create_from_string("^(.*?)([.!?:…]+)$")
var _affix_re := RegEx.create_from_string("^(.*?)( [-+]?[\\d.,%]+| \\([^()]*\\)|[.!?:…]+)$")
var _gender_re := RegEx.create_from_string("\\[\\[([^|\\]]*)\\|([^\\]]*)\\]\\]")


func load_entries(entries: Dictionary) -> void:
	for key in entries:
		var src := String(key)
		var dst := String(entries[key])
		if src.begins_with("_") or dst == "":
			continue
		var has_tok := _token_re.search(src) != null
		if dst.contains("|") and not dst.contains("[["):
			_forms[src] = dst.split("|")
			dst = String(_forms[src][0])
		_exact[src] = dst if has_tok else _finish(dst, false)
		_exact_upper[src.to_upper()] = _exact[src].to_upper()
		var lf := src.substr(0, 1).to_lower() + src.substr(1)
		if lf != src and not _exact_lower_first.has(lf):
			_exact_lower_first[lf] = src
		if has_tok:
			_add_pattern(src, dst, false)
			_add_pattern(src, dst, true)
	# Moldes mais longos primeiro: o mais específico vence.
	for idx: Dictionary in [_by_word, _by_word_upper]:
		for w in idx:
			(idx[w] as Array).sort_custom(func(a, b): return a["len"] > b["len"])


func _get_message(src_message: StringName, _context: StringName) -> StringName:
	var src := String(src_message)
	var out := lookup(src)
	if out == "" and I18n.log_misses and _letter_re.search(src) != null:
		I18n.note_miss(src)
	return StringName(out) if out != "" else StringName()


## Todas as formas da tradução ("brasileño", "brasileña"); vazio se não houver tradução.
## Só a chave exata, sem moldes nem pedaços (chaves com contexto "ctx|texto").
func exact(src: String) -> String:
	return String(_exact.get(src, ""))


func forms(src: String) -> PackedStringArray:
	if _forms.has(src):
		return _forms[src]
	var t := lookup(src)
	return PackedStringArray([t]) if t != "" else PackedStringArray()


## Tradução do texto, ou "" se não houver.
func lookup(src: String, depth: int = 0) -> String:
	if src == "":
		return ""
	var hit: Variant = _exact.get(src, null)
	if hit != null:
		return hit
	if depth == 0 and _cache.has(src):
		return _cache[src]
	var out := _lookup_uncached(src, depth)
	if depth == 0:
		if _cache.size() >= _CACHE_MAX:
			_cache.clear()
		_cache[src] = out
	return out


func _lookup_uncached(src: String, depth: int) -> String:
	var upper := src == src.to_upper() and src != src.to_lower()
	if upper:
		var hu: Variant = _exact_upper.get(src, null)
		if hu != null:
			return hu
	# Texto que perdeu a maiúscula do começo ("pesado" de "Pesado") ou ganhou ("Vitória" de "vitória").
	var lf := src.substr(0, 1).to_lower() + src.substr(1)
	if lf != src:
		var hl: Variant = _exact.get(lf, null)
		if hl != null:
			return _cap_first(hl)
	elif _exact_lower_first.has(src):
		return _low_first(_exact[_exact_lower_first[src]])
	if _letter_re.search(src) == null:
		return ""
	# Texto com quebra de linha: cada linha sozinha.
	if src.contains("\n") and depth < 2:
		var lines := src.split("\n")
		var any := false
		for i in lines.size():
			var tl := lookup(lines[i], depth + 1) if lines[i].strip_edges() != "" else ""
			if tl != "":
				lines[i] = tl
				any = true
		if any:
			return "\n".join(lines)
	var out := _match_patterns(src, depth, upper, false)
	if out == "" and lf != src:
		var low := _match_patterns(lf, depth, false, false)
		if low != "":
			out = _cap_first(low)
	if out == "" and depth < 2:
		out = _split_compound(src, depth)
	if out == "" and depth < 3:
		out = _strip_affix(src, depth)
	# Moldes quase sem texto fixo ("%s a %s", "%s e %s") só por último: pegam quase qualquer frase.
	if out == "":
		out = _match_patterns(src, depth, upper, true)
	return out


## "Chutes 91", "Pronto.", "confiante (+5)": traduz o miolo e devolve o resto como estava.
func _strip_affix(src: String, depth: int) -> String:
	var lead := _lead_num_re.search(src)
	if lead != null:
		var rest := lookup(lead.get_string(2), depth + 1)
		if rest != "":
			return lead.get_string(1) + rest
	var pm := _punct_re.search(src)
	if pm != null and _letter_re.search(pm.get_string(1)) != null:
		var tp := lookup(pm.get_string(1), depth + 1)
		if tp != "":
			return tp + pm.get_string(2)
	var m := _affix_re.search(src)
	if m == null:
		return ""
	var head := m.get_string(1)
	var tail := m.get_string(2)
	if head == "" or tail == "" or _letter_re.search(head) == null:
		return ""
	var th := lookup(head, depth + 1)
	if tail.begins_with(" (") and _letter_re.search(tail) != null:
		# "Michael Francis (Galo)": o nome fica, o que está entre parênteses traduz.
		var inner := lookup(tail.substr(2, tail.length() - 3), depth + 1)
		if inner != "":
			return (th if th != "" else head) + " (" + inner + ")"
	if th == "":
		return ""
	return th + tail


func _match_patterns(src: String, depth: int, upper: bool, weak: bool) -> String:
	var idx: Dictionary = _by_word_upper if upper else _by_word
	var tried := {}
	var best: Dictionary = {}
	var best_m: RegExMatch = null
	for wm in _word_re.search_all(src):
		var w := wm.get_string()
		if tried.has(w):
			continue
		tried[w] = true
		var list: Variant = idx.get(w, null)
		if list == null:
			continue
		for p: Dictionary in list:
			if not best.is_empty() and p["len"] <= best["len"]:
				break
			if bool(p["weak"]) != weak:
				continue
			var m: RegExMatch = p["re"].search(src)
			if m == null:
				continue
			best = p
			best_m = m
			break
	if best.is_empty():
		return ""
	var out := _finish(_render(best, best_m, depth), true)
	if upper:
		return out.to_upper()
	# "Ingresso padrão" → "%s ticket" → "Standard ticket": a frase começa maiúscula como a original.
	if src.substr(0, 1) != src.substr(0, 1).to_lower() and out.substr(0, 1) == out.substr(0, 1).to_lower():
		out = _cap_first(out)
	return out


## "Rodada 3 · Brasil A", "Vitória / Derrota": cada parte sozinha.
func _split_compound(src: String, depth: int) -> String:
	# Frases coladas no código ("Ajuda." + " Outra frase."): tenta cortar em dois pedaços inteiros.
	var at := src.find(". ")
	while at >= 0:
		var left := lookup(src.substr(0, at + 1), depth + 1)
		if left != "":
			var right := src.substr(at + 1)
			var tr: Variant = _exact.get(right, null)
			var tr2 := String(tr) if tr != null else lookup(right.strip_edges(), depth + 1)
			if tr2 != "":
				return left + (tr2 if tr2.begins_with(" ") else " " + tr2)
		at = src.find(". ", at + 1)
	for sep in [" · ", " — ", " / ", ": ", " | ", ". ", ", "]:
		if not src.contains(sep):
			continue
		var parts := src.split(sep)
		var any := false
		for j in parts.size():
			var core := parts[j].strip_edges()
			if sep == ". " and j < parts.size() - 1:
				parts[j] += "."
				core += "."
			var tp := lookup(core, depth + 1) if core != "" else ""
			if tp != "":
				parts[j] = parts[j].replace(core, tp)
				any = true
		if any:
			if sep == ". ":
				for j in parts.size() - 1:
					if parts[j].ends_with("."):
						parts[j] = parts[j].substr(0, parts[j].length() - 1)
			return sep.join(parts)
	return ""


func _add_pattern(src: String, dst: String, upper: bool) -> void:
	var rx := "^"
	var names: Array = []
	var last := 0
	var literal_len := 0
	var lits := ""
	var raw := ""
	for m in _token_re.search_all(src):
		var lit := src.substr(last, m.get_start() - last).replace("%%", "%")
		if upper:
			lit = lit.to_upper()
		rx += _escape(lit)
		literal_len += lit.length()
		lits += " " + _whole_words(lit, last > 0, true)
		raw += lit
		var tok := m.get_string()
		names.append(tok)
		if tok == "%d":
			rx += "(-?[\\d.,]+)"
		elif tok.ends_with("f"):
			rx += "(-?[\\d.,]+)"
		elif tok in _GENDER_TOKENS:
			rx += "(\\p{L}{0,4})"
		else:
			rx += "(.*?)"
		last = m.get_end()
	var tail := src.substr(last).replace("%%", "%")
	if upper:
		tail = tail.to_upper()
	rx += _escape(tail) + "$"
	literal_len += tail.length()
	lits += " " + _whole_words(tail, last > 0, false)
	raw += tail
	# A palavra mais longa do molde é a porta de entrada; molde sem palavra não traduz nada.
	var key := ""
	for wm in _word_re.search_all(lits):
		var w := wm.get_string()
		if w.length() > key.length():
			key = w
	if key == "":
		return
	var re := RegEx.create_from_string(rx)
	if not re.is_valid():
		return
	var idx: Dictionary = _by_word_upper if upper else _by_word
	if not idx.has(key):
		idx[key] = []
	var letters := 0
	for ch in raw:
		if _is_letter(ch):
			letters += 1
	idx[key].append({"re": re, "names": names, "target": dst, "len": literal_len, "weak": letters <= _WEAK_LETTERS})


func _render(p: Dictionary, m: RegExMatch, depth: int) -> String:
	var names: Array = p["names"]
	var groups: Array = []
	var fem := false
	for i in names.size():
		var g := m.get_string(i + 1)
		if names[i] in _GENDER_TOKENS or (g.length() <= 2 and g in ["a", "o", "ã", "ão"]):
			# Marca de gênero do português ("Nascid%s", "campe{ao}"): decide o [[m|f]].
			if g in _FEM_VALUES:
				fem = true
			groups.append(g)
			continue
		if depth < 2 and not g.is_valid_int() and _letter_re.search(g) != null:
			var tg := lookup(g, depth + 1)
			if tg != "":
				g = tg
		groups.append(g)
	var target: String = p["target"]
	if target.contains("[["):
		target = _gender(target, fem)
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
	return (out + target.substr(last)).replace("%%", "%")


func _gender(text: String, fem: bool) -> String:
	var out := ""
	var last := 0
	for m in _gender_re.search_all(text):
		out += text.substr(last, m.get_start() - last) + m.get_string(2 if fem else 1)
		last = m.get_end()
	return out + text.substr(last)


## Tira do trecho fixo as palavras coladas num marcador ("Nascid" de "Nascid%s"): no texto pronto
## elas aparecem com outro final e não serviriam de porta de entrada.
static func _whole_words(lit: String, token_before: bool, token_after: bool) -> String:
	var out := lit
	if token_after and out != "" and _is_letter(out[out.length() - 1]):
		var cut := out.length()
		while cut > 0 and _is_letter(out[cut - 1]):
			cut -= 1
		out = out.substr(0, cut)
	if token_before and out != "" and _is_letter(out[0]):
		var start := 0
		while start < out.length() and _is_letter(out[start]):
			start += 1
		out = out.substr(start)
	return out


static func _is_letter(ch: String) -> bool:
	return ch.to_upper() != ch.to_lower()


static func _escape(s: String) -> String:
	var out := ""
	for ch in s:
		if "\\^$.|?*+()[]{}".contains(ch):
			out += "\\"
		out += ch
	return out


static func _cap_first(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)


static func _low_first(s: String) -> String:
	return s.substr(0, 1).to_lower() + s.substr(1)


## Acabamento do texto traduzido: concordância padrão (masculino) e ordinais do idioma
## ("3º" vira "3rd", "3.", "3e"...).
func _finish(text: String, rendered: bool) -> String:
	var out := text
	if not rendered and out.contains("[["):
		out = _gender(out, false)
	if out.contains("º") or out.contains("ª"):
		for m in _ordinal_re.search_all(out):
			out = out.replace(m.get_string(), Fmt.ordinal_in(lang, int(m.get_string(1))))
	return out
