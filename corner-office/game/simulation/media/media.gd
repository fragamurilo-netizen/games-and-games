class_name Media
extends RefCounted
## Media & Narrative Engine (Game Design Bible §10; MMA Bible §27).
## Notícia = consequência de estado do mundo. Cada story template declara
## triggers factuais (content/story_templates.json); sem trigger, sem notícia.


func publish(world: WorldState, topic: String, facts: Array, entity_ids: Array) -> NewsItem:
	var item := NewsItem.new()
	item.id = world.new_id("news")
	item.created_at = world.date
	item.topic = topic
	item.facts = facts
	item.entity_ids = entity_ids
	# TODO(M1): escolher outlet, tom e headline a partir do template.
	world.add("news", item)
	EventBus.news_published.emit(item.id)
	return item


## Varre o mundo procurando triggers satisfeitos (ex.: "champion ducking #1").
func scan_triggers(_world: WorldState) -> Array:
	# TODO(M1)
	return []
