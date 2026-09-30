class_name NewsItem
extends Entity
## Notícia (MMA Bible §27): sempre nasce de um trigger factual do mundo.

var outlet_id := ""            # content/media_outlets.json
var key := ""                  # chave estável do fato; mesma chave nunca vira duas notícias
var category := "eventos"      # resultados | eventos | mercado | rankings | bastidores
var importance := 1            # 1 nota · 2 destaque · 3 manchete
var channel := "site"          # site (veículo) | social (post de atleta, organização ou torcida)
var author_id := ""            # autor do post social: fighter, organization ou conta de torcida
var read := false              # já vista pelo jogador na central de notícias
var created_at := {}
var topic := ""                # story template id
var headline := ""
var body := ""
var tone := "neutral"
var reach := 0
var entity_ids: Array = []
var facts: Array = []          # Reason codes/fatos que dispararam a história
var consequences: Array = []
