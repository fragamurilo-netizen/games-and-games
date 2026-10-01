class_name Dilemma
extends Entity
## Decisão na caixa de entrada (Game Design Bible §19 Sistema de eventos).
## Nasce de pré-condição do mundo (content/office_events.json); cada opção
## tem consequência imediata e pode agendar desdobramentos.

var def_id := ""
var organization_id := ""
var category := "staff"
var priority := "medium"        # low | medium | high | critical
var title := ""
var body := ""
var staff_ids: Array = []
var fighter_ids: Array = []
var context := {}               # valores resolvidos na criação (rival, valor, patrocinador…)
var options: Array = []         # [{id, label, hint}]
var status := "open"            # open | resolved | expired
var created_on := {}
var expires_on := {}
var resolved_on := {}
var choice := ""
var outcome := ""               # texto do que aconteceu
var read := false
