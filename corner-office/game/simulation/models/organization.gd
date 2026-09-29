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
