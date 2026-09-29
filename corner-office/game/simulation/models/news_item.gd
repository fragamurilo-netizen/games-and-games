class_name NewsItem
extends Entity
## Notícia (MMA Bible §27): sempre nasce de um trigger factual do mundo.

var outlet_id := ""
var created_at := {}
var topic := ""                # story template id
var headline := ""
var body := ""
var tone := "neutral"
var reach := 0
var entity_ids: Array = []
var facts: Array = []          # Reason codes/fatos que dispararam a história
var consequences: Array = []
