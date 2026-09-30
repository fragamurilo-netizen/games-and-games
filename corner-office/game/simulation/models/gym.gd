class_name Gym
extends Entity
## Academia (Game Design Bible §11, MMA Bible §10).

var name := ""
var city := ""
var country := ""
var region := ""
var reputation := 0
var specialties: Array = []
var coaches := {}              # role -> {name, rating}
var identity := ""
