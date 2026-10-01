extends RefCounted


static func current_difficulty() -> String:
	var value := str(Configs.configs.get("difficulty", "normal")).to_lower()
	match value:
		"easy", "facil", "fácil":
			return "easy"
		"hard", "dificil", "difícil":
			return "hard"
		_:
			return "normal"


static func current_job() -> String:
	var value := str(Configs.configs.get("job", "programador")).to_lower()
	if value == "engenheiro" or value == "engenheiro_eletrico":
		return "engenheiro_eletrico"
	return "programador"


static func initial_time_seconds() -> float:
	var difficulty := current_difficulty()
	if current_job() == "engenheiro_eletrico":
		match difficulty:
			"easy":
				return 20.0 * 60.0
			"hard":
				return 10.0 * 60.0
			_:
				return 15.0 * 60.0
	match difficulty:
		"easy":
			return 15.0 * 60.0
		"hard":
			return 10.0 * 60.0
		_:
			return 30.0 * 60.0


static func cooling_reward_seconds() -> float:
	match current_difficulty():
		"easy":
			return 90.0
		"hard":
			return 45.0
		_:
			return 60.0


static func neural_answers_per_parameter() -> int:
	return 2


static func asimov_answers_per_law() -> int:
	return 2


static func health_regeneration_delay() -> float:
	match current_difficulty():
		"easy":
			return 12.0
		"hard":
			return 20.0
		_:
			return 16.0


static func health_regeneration_per_second() -> float:
	match current_difficulty():
		"easy":
			return 4.0
		"hard":
			return 1.0
		_:
			return 2.0


static func drone_profile() -> Dictionary:
	match current_difficulty():
		"easy":
			return {
				"health": 50.0,
				"speed_multiplier": 0.82,
				"detection_range": 110.0,
				"alert_duration": 0.75,
				"shot_interval": 1.4,
				"shot_telegraph": 0.5,
				"projectile_speed": 125.0,
				"projectile_damage": 12.0,
				"spawn_interval": 45.0,
				"max_active": 2,
			}
		"hard":
			return {
				"health": 100.0,
				"speed_multiplier": 1.18,
				"detection_range": 140.0,
				"alert_duration": 0.4,
				"shot_interval": 0.8,
				"shot_telegraph": 0.24,
				"projectile_speed": 165.0,
				"projectile_damage": 24.0,
				"spawn_interval": 20.0,
				"max_active": 4,
			}
		_:
			return {
				"health": 75.0,
				"speed_multiplier": 1.0,
				"detection_range": 125.0,
				"alert_duration": 0.55,
				"shot_interval": 1.05,
				"shot_telegraph": 0.32,
				"projectile_speed": 145.0,
				"projectile_damage": 18.0,
				"spawn_interval": 30.0,
				"max_active": 3,
			}
