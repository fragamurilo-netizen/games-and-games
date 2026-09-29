class_name FightEvent
extends Entity
## Evento/noite de lutas (Game Design Bible §8, MMA Bible §17).

var organization_id := ""
var name := ""
var date := {}
var format := "fight_night"    # ppv | fight_night | international | stadium | prospect_series | grand_prix
var venue := ""
var city := ""
var country := ""
var region := ""
var jurisdiction_id := ""
var fight_ids: Array = []      # ordem = ordem do card (último = main event)
var status := "planned"        # planned | announced | completed | cancelled

var projected := {}            # {gate, audience, purses, production, sponsors, margin}
var actual := {}
