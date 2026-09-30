class_name Organization
extends Entity
## Promoção (Game Design Bible §3, MMA Bible §19, §26).
## ruleset e jurisdição são entidades separadas: aqui só se referenciam ids.

var name := ""
var short_name := ""
var tier := "regional"         # global | national | regional
var base_country := ""
var base_city := ""
var reputation := 0
var is_player := false

var ruleset_id := "unified"
var business_model := "hybrid" # ppv | rights_guarantee | subscription | hybrid
var presentation := "sports_first"
var competition := "ranking"   # ranking | tournament | hybrid
var executive_traits: Array = [] # aggressive_buyer, prospect_first, ...
var season_goals: Array = []

var cash := 0
var roster: Array = []         # fighter ids
var titles := {}               # division -> {champion_id, interim_id}
var media_deal_ids: Array = []
var market_popularity := {}    # region -> 0..100
var brand_colors := {}

# IA rival (simulation/organizations/org_ai.gd): numeração de eventos e agenda.
var event_count := 0
var ai_state := {}               # next_event_after, next_signing_after (datas)

# Progressão (simulation/organizations/org_standing.gd). reputation continua
# sendo o valor inteiro exibido; reputation_exact acumula frações.
var reputation_exact := -1.0
var standing_history: Array = [] # append-only: {date, reputation, tier, cash, roster}
var objectives: Array = []       # metas da temporada atual: {id, target, season}
var season_reviews: Array = []   # append-only: {season, done, total, reputation_delta, cash}

# Sede (simulation/office/office.gd). A sede cresce por nível; o livro-caixa é
# append-only e explica cada movimento que não é uma noite de lutas.
var office_level := 1
var ledger: Array = []           # append-only: {date, kind, amount, label}
var deals: Array = []            # acordos ativos: {kind, name, value, until}
var office_state := {}           # cooldowns de dilemas, desdobramentos agendados, dicas
