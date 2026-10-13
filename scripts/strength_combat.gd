extends RefCounted

const START_STRENGTH := 10
const DEATH_THRESHOLD := -10


static func damage_for_strength(strength: int) -> int:
	return 0 if strength <= 0 else 1 + (strength - 1) / 100


static func effective_strength(strength: int, weapon_bonus: int, multiplier := 1) -> int:
	# Weapons improve a living fighter's strength, but cannot replace their own.
	return 0 if strength <= 0 else strength * maxi(multiplier, 1) + maxi(weapon_bonus, 0)


# Both sides use this exchange, regardless of who initiated the attack.
# A supplied roll makes the rules reproducible without changing live randomness.
static func exchange(player: int, enemy: int, weapon_bonus: int, roll: int, multiplier := 1) -> Dictionary:
	var player_power := effective_strength(player, weapon_bonus, multiplier)
	var total := player_power + maxi(enemy, 0)
	var player_hit := total > 0 and roll < player_power
	var damage := 0
	if total > 0:
		if player_hit:
			damage = damage_for_strength(player_power)
			enemy -= damage
		else:
			damage = damage_for_strength(enemy)
			player -= damage
	return {"player": player, "enemy": enemy, "player_hit": player_hit,
		"damage": damage, "killed": enemy <= 0}
