class_name MatchFormation
extends RefCounted
## Explicit offsets from the authoritative LOS; mirrored on possession changes.

static func arrange(rules: MatchRules, qb: FlagPlayer, receivers: Array[FlagPlayer], defenders: Array[FlagPlayer], routes: Array[ReceiverRoute]) -> void:
	var direction: int = rules.attack_direction()
	var los: float = rules.line_of_scrimmage
	qb.position = FootballField.clamp_athlete(Vector2(los - direction * 40, 180))
	receivers[0].position = Vector2(los, 100)
	receivers[1].position = Vector2(los, 260)
	var defensive_offsets: Array[Vector2] = [Vector2(90, 80), Vector2(90, 280), Vector2(150, 180), Vector2(240, 120), Vector2(240, 240)]
	for index: int in range(defenders.size()):
		var offset: Vector2 = defensive_offsets[index]
		defenders[index].position = FootballField.clamp_athlete(Vector2(los + direction * offset.x, offset.y))
	for index: int in range(routes.size()):
		routes[index].origin = receivers[index].global_position
		routes[index].attack_direction = direction
		routes[index].waypoint_index = 0
	var offensive_color: Color = Color("51b9f2") if rules.offense == 0 else Color("d85c74")
	var defensive_color: Color = Color("d85c74") if rules.offense == 0 else Color("51b9f2")
	qb.jersey_color = offensive_color
	for receiver: FlagPlayer in receivers:
		receiver.jersey_color = offensive_color.lightened(0.15)
	for defender: FlagPlayer in defenders:
		defender.jersey_color = defensive_color
