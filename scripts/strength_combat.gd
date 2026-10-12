extends RefCounted

const START_STRENGTH := 10
const DEATH_THRESHOLD := -10


static func damage_for_strength(strength: int) -> int:
	return 0 if strength <= 0 else 1 + (strength - 1) / 100


# Both sides use this exchange, regardless of who initiated the attack.
# A supplied roll makes the rules reproducible without changing live randomness.
static func exchange(player: int, enemy: int, sword_bonus: int, roll: int) -> Dictionary:
	var total := maxi(player, 0) + maxi(enemy, 0)
	var player_hit := total > 0 and roll < maxi(player, 0)
	var damage := 0
	if total > 0:
		if player_hit:
			damage = damage_for_strength(player) + maxi(sword_bonus, 0)
			enemy -= damage
		else:
			damage = damage_for_strength(enemy)
			player -= damage
	return {"player": player, "enemy": enemy, "player_hit": player_hit,
		"damage": damage, "killed": enemy <= 0}
