class_name Agent
extends Entity
## Agência/agente (Game Design Bible §9). Agentes têm memória: `relationship`
## guarda confiança por organização e é afetada por negociações hostis.

var name := ""
var profile := ""
var behavior := ""
var reputation := 0
var traits: Array = []
var client_ids: Array = []
var relationship := {}         # org_id -> trust -100..100
var memory: Array = []         # append-only log de negociações
