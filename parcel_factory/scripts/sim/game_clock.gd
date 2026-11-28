class_name GameClock
extends RefCounted
## 게임 시계: 하루(09:00~18:00)가 실제 DAY_REAL_SEC초(×1 속도 기준). 시뮬레이션 시간(sim_time)으로 계산해요.

const DAY_START_MIN := 9 * 60
const DAY_END_MIN := 18 * 60
const DAY_REAL_SEC := 20.0 * 60.0


static func minutes(sim_time: float) -> float:
	var per_sec := float(DAY_END_MIN - DAY_START_MIN) / DAY_REAL_SEC
	return minf(DAY_START_MIN + sim_time * per_sec, DAY_END_MIN)


static func text(sim_time: float) -> String:
	var m := int(minutes(sim_time))
	return "%02d:%02d" % [int(m / 60.0), m % 60]
