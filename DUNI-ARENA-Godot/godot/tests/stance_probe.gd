extends SceneTree
## Stance balance probe (not part of test_runner; takes ~10 minutes):
##   godot --headless --path . --script res://tests/stance_probe.gd   (ROLE=melee|standoff|rear to limit)
## Seeded 3v3 battles: three allies of one role get one stance; the enemy is a fixed mixed
## team (melee warrior, standoff hero, rear archer) in the normal stance.
const ROLES = {"melee":[0,9,14], "standoff":[17,21,23], "rear":[1,2,13]}
const ENEMIES = [0, 17, 1]
const STANCES = [&"normal", &"rush", &"cautious"]
const GAMES = 40
var dealt: float = 0
var taken: float = 0
func _hit(source, target, amount: float, _crit: bool) -> void:
	if is_instance_valid(source) and source.team == 0 and target.team == 1:dealt += amount
	if is_instance_valid(target) and target.team == 0:taken += amount
func _init() -> void:
	await process_frame
	var only: String = OS.get_environment("ROLE")
	for role in ROLES:
		if only != "" and role != only:continue
		for stance in STANCES:
			var m := {"win":0.0, "up":0.0, "alive":0.0, "dealt":0.0, "taken":0.0, "boost":0, "dt_sum":0.0, "dt_n":0.0, "da_sum":0.0, "da_n":0.0, "ends":0, "retreats":0, "switch":0, "chase_sum":0.0, "chase_n":0}
			for g in range(GAMES):
				var setup := CustomBattleSetup.new()
				for i in range(3):
					setup.add(ROLES[role][i], 0, Vector2(200, 260 + i * 140))
					setup.set_stance(int(setup.entries[-1].id), stance)
					setup.add(ENEMIES[i], 1, Vector2(600 + i * 40, 260 + i * 140))
				var b := BattleManager.new();b.auto_start = false;b.custom_mode = true;root.add_child(b)
				b.start_battle(setup.placements(), 1000 + g);b.set_physics_process(false)
				# Same as the custom battle screen: stances go on the spawned units.
				for i in range(b.units.size()):b.units[i].stance = setup.entries[i].stance
				dealt = 0;taken = 0;b.damage_resolver.damage_applied.connect(_hit)
				var allies: Array = b.units.filter(func(u):return u.team == 0)
				var track := {}
				for u in allies:track[u] = {"was":false, "end_d":-1.0, "end_t":0.0, "tgt":null, "boost":0.0, "chase":-1.0, "contact":false, "last":u.position}
				var t := 0
				while not b.finished and t < 60 * 90:
					b.simulate(1.0 / 60);t += 1
					var now: float = b.clock.elapsed
					for u in allies:
						var s: Dictionary = track[u]
						if not u.alive:continue
						m.alive += 1
						var attacking: bool = u.combat_state != CombatController.State.IDLE or not u.ultimate.cast.is_empty()
						if attacking:m.up += 1
						var tg = u.target
						var valid: bool = tg != null and is_instance_valid(tg) and tg.alive and tg.team != u.team
						var d: float = u.position.distance_to(tg.position) if valid else -1.0
						if valid:m.dt_sum += d;m.dt_n += 1
						var near: float = INF
						for a in allies:
							if a != u and a.alive:near = minf(near, u.position.distance_to(a.position))
						if near < INF:m.da_sum += near;m.da_n += 1
						# Retreat right after an attack: distance to the target grows within 0.6 s.
						# Retreat after an attack: in the next 0.6 s the unit itself steers away from its
						# target for at least a third of the time (knockback and crowd separation excluded).
						if s.was and not attacking and valid:s.end_d = d;s.end_t = now;s.away = 0;s.frames = 0
						if s.end_d >= 0:
							if valid and u.knockback_velocity.length() <= 30:
								s.frames += 1
								if u.brain.desired_direction.normalized().dot((tg.position - u.position).normalized()) < -.3:s.away += 1
							if now - s.end_t >= .6:
								m.ends += 1
								if s.away * 3 >= maxi(1, s.frames):m.retreats += 1
								s.end_d = -1.0
						s.was = attacking
						# Target switches while the old target is still a valid enemy.
						if valid and s.tgt != null and s.tgt != tg and is_instance_valid(s.tgt) and s.tgt.alive:m.switch += 1
						if valid:s.tgt = tg
						# Chase: path walked while a target already met is out of reach.
						if valid and d <= u.data.attack_range + 40:s.contact = true
						var out: bool = valid and s.contact and d > u.data.attack_range + 40
						# Only the distance walked toward the runner counts (walking back home does not).
						if out:
							if s.chase < 0:s.chase = 0.0
							s.chase += maxf(0, (u.position - s.last).dot((tg.position - s.last).normalized()))
						elif s.chase >= 0:m.chase_sum += s.chase;m.chase_n += 1;s.chase = -1.0
						s.last = u.position
						var until: float = float(u.state_value("counterBoostUntil"))
						if until > s.boost + .001:m.boost += 1
						s.boost = maxf(s.boost, until)
				var hp := func(team: int) -> float:
					var total: float = 0
					for u in b.units:
						if u.team == team:total += maxf(0, u.current_hp) / u.max_hp
					return total
				var ours: float = hp.call(0);var theirs: float = hp.call(1)
				m.win += 1.0 if ours > theirs else .5 if is_equal_approx(ours, theirs) else 0.0
				m.dealt += dealt;m.taken += taken
				b.free()
			print("PROBE %s %s win=%.0f%% uptime=%.1f%% dealt=%.0f taken=%.0f boosts=%.2f dist_target=%.0f dist_ally=%.0f retreat=%.0f%% switches=%.2f chase=%.0f" % [role, stance, m.win / GAMES * 100, m.up / maxf(1, m.alive) * 100, m.dealt / GAMES, m.taken / GAMES, float(m.boost) / GAMES, m.dt_sum / maxf(1, m.dt_n), m.da_sum / maxf(1, m.da_n), float(m.retreats) / maxf(1, m.ends) * 100, float(m.switch) / GAMES, m.chase_sum / maxf(1, m.chase_n)])
	quit()
