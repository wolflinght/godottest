## BattleServer.gd
## 服务器权威端：隐藏时间轴、行动权分发、所有战斗判定
## 挂载到场景树，仅在 is_multiplayer_authority() 时运行核心逻辑
extends Node

@onready var _client: Node = $"../BattleClient"

const TIMELINE_THRESHOLD := 1000.0
const TICK_INTERVAL := 0.1          # 秒
const PLAYER_TIMEOUT := 10.0        # 玩家决策超时秒数

# 场上所有参战者（服务器维护）
var combatants: Array[CombatantData] = []

# 当前等待决策的角色（同一时刻可能有多个玩家同时到达阈值，队列处理）
var _pending_actions: Array[CombatantData] = []
var _timeout_timers: Dictionary = {}   # peer_id -> float 剩余时间

var _tick_accum: float = 0.0
var _battle_active: bool = false

# ---- 对外信号（服务器本地用，广播走RPC）----
signal battle_ended(winner_side: String)  # "players" / "enemies"

# ============================================================
# 战斗启动
# ============================================================

func start_battle(player_data: Array[CombatantData], enemy_data: Array[CombatantData]) -> void:
	assert(multiplayer.is_server(), "start_battle 只能在服务器调用")
	combatants.clear()
	_pending_actions.clear()
	_timeout_timers.clear()

	for c in player_data:
		c.init_combat_stats()
		combatants.append(c)
	for c in enemy_data:
		c.init_combat_stats()
		combatants.append(c)

	_battle_active = true
	# 广播战斗开始
	_client.receive_battle_start.rpc()
	# 广播所有角色初始状态
	for c in combatants:
		_client.receive_status.rpc(_pack_status(c))

# ============================================================
# 时间轴 Tick（_process 驱动）
# ============================================================

func _process(delta: float) -> void:
	if not _battle_active:
		return
	if not multiplayer.is_server():
		return

	# 超时倒计时
	for peer_id in _timeout_timers.keys():
		_timeout_timers[peer_id] -= delta
		if _timeout_timers[peer_id] <= 0.0:
			_timeout_timers.erase(peer_id)
			_auto_attack_for_peer(peer_id)

	# 有玩家正在决策时，整个时间轴冻结，等待玩家指令
	if not _timeout_timers.is_empty():
		return

	_tick_accum += delta
	if _tick_accum < TICK_INTERVAL:
		return
	_tick_accum -= TICK_INTERVAL

	# 推进所有存活且未被点穴的角色进度
	for c in combatants:
		if not c.is_alive:
			continue
		if c.stun_freeze > 0.0:
			c.stun_freeze -= c.spd  # 消耗冻结量
			if c.stun_freeze <= 0.0:
				c.stun_freeze = 0.0
				_client.receive_log.rpc(_fmt_stun_recover(c))
			continue
		c.timeline_progress += c.spd
		if c.timeline_progress >= TIMELINE_THRESHOLD:
			c.timeline_progress = 0.0
			_grant_action(c)

# ============================================================
# 行动权分发
# ============================================================

func _grant_action(c: CombatantData) -> void:
	if c.is_player:
		_timeout_timers[c.peer_id] = PLAYER_TIMEOUT
		var local_id := multiplayer.get_unique_id()
		if c.peer_id == local_id:
			_client.receive_turn_start(c.peer_id)
		else:
			_client.receive_turn_start.rpc_id(c.peer_id, c.peer_id)
	else:
		_npc_decide(c)

## 超时自动攻击
func _auto_attack_for_peer(peer_id: int) -> void:
	var actor := _find_by_peer(peer_id)
	if actor == null or not actor.is_alive:
		return
	var targets := _get_alive_enemies_of(actor)
	if targets.is_empty():
		return
	var target: CombatantData = targets[randi() % targets.size()]
	_resolve_attack(actor, target)

## NPC AI：随机攻击存活玩家
func _npc_decide(npc: CombatantData) -> void:
	var targets := _get_alive_enemies_of(npc)
	if targets.is_empty():
		return
	var target: CombatantData = targets[randi() % targets.size()]
	_resolve_attack(npc, target)

# ============================================================
# 客户端指令入口（RPC，客户端 → 服务器）
# ============================================================

## 玩家发送攻击指令
@rpc("any_peer", "call_remote", "reliable")
func c2s_attack(actor_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	# 验证：只有拥有行动权的玩家才能发指令
	if not _timeout_timers.has(actor_peer_id):
		return
	_timeout_timers.erase(actor_peer_id)

	var actor := _find_by_peer(actor_peer_id)
	if actor == null or not actor.is_alive:
		return
	var targets := _get_alive_enemies_of(actor)
	if targets.is_empty():
		return
	var target: CombatantData = targets[randi() % targets.size()]
	_resolve_attack(actor, target)

## 玩家发送绝招指令
@rpc("any_peer", "call_remote", "reliable")
func c2s_ultimate(actor_peer_id: int, target_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if not _timeout_timers.has(actor_peer_id):
		return
	_timeout_timers.erase(actor_peer_id)

	var actor := _find_by_peer(actor_peer_id)
	if actor == null or not actor.is_alive:
		return
	if actor.current_martial_art == null:
		return
	var art := actor.current_martial_art
	if actor.current_mp < art.ultimate_mp_cost:
		return

	actor.current_mp -= art.ultimate_mp_cost

	# AOE 或 单体
	var targets: Array[CombatantData] = []
	if art.ultimate_aoe == MartialArtData.AoEType.ALL_ENEMIES:
		targets = _get_alive_enemies_of(actor)
	else:
		var t := _find_by_peer(target_peer_id)
		if t == null:
			# target_peer_id 可能是 NPC 的 index 编码，此处简化：随机单体
			targets = [_get_alive_enemies_of(actor)[0]] if not _get_alive_enemies_of(actor).is_empty() else []
		else:
			targets = [t]

	for target in targets:
		_resolve_ultimate(actor, target, art)

	_check_battle_end()

## 玩家发送吸气指令
@rpc("any_peer", "call_remote", "reliable")
func c2s_absorb(actor_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if not _timeout_timers.has(actor_peer_id):
		return
	_timeout_timers.erase(actor_peer_id)

	var actor := _find_by_peer(actor_peer_id)
	if actor == null or not actor.is_alive:
		return

	var mp_cost := 50
	if actor.current_mp < mp_cost:
		_client.receive_log.rpc("内力不足，无法吸气！")
		_grant_action(actor)  # 内力不足，重新给行动权
		return

	actor.current_mp -= mp_cost
	var heal := BattleFormula.calc_heal(actor)
	actor.current_hp = min(actor.current_hp + heal, actor.max_hp)

	var log_text := "%s运功调息，恢复了 %d 点气血。" % [actor.display_name, heal]
	_client.receive_log.rpc(log_text)
	_client.receive_status.rpc(_pack_status(actor))

## 玩家换兵刃
@rpc("any_peer", "call_remote", "reliable")
func c2s_switch_weapon(actor_peer_id: int, weapon_res_path: String) -> void:
	if not multiplayer.is_server():
		return
	if not _timeout_timers.has(actor_peer_id):
		return
	_timeout_timers.erase(actor_peer_id)

	var actor := _find_by_peer(actor_peer_id)
	if actor == null:
		return

	var weapon: WeaponData = load(weapon_res_path) if weapon_res_path != "" else null
	actor.equipped_weapon = weapon

	# 智能换装：自动切换预设功法
	var new_tag := actor.weapon_tag()
	if actor.loadout.has(new_tag):
		actor.current_martial_art = actor.loadout[new_tag]
		var log_text: String
		if weapon != null:
			log_text = "%s手腕一翻，抽出【%s】，顺势摆出了《%s》的起手式！" % [
				actor.display_name, weapon.weapon_name,
				actor.current_martial_art.art_name
			]
		else:
			log_text = "%s收起兵器，摆出《%s》的起手式。" % [
				actor.display_name, actor.current_martial_art.art_name
			]
		_client.receive_log.rpc(log_text)
	else:
		actor.current_martial_art = null
		var wname := weapon.weapon_name if weapon != null else "空手"
		_client.receive_log.rpc("%s换上了【%s】，但未设置对应功法。" % [actor.display_name, wname])

	_client.receive_status.rpc(_pack_status(actor))

## 玩家换功法
@rpc("any_peer", "call_remote", "reliable")
func c2s_switch_art(actor_peer_id: int, art_res_path: String) -> void:
	if not multiplayer.is_server():
		return
	if not _timeout_timers.has(actor_peer_id):
		return
	_timeout_timers.erase(actor_peer_id)

	var actor := _find_by_peer(actor_peer_id)
	if actor == null:
		return

	var art: MartialArtData = load(art_res_path)
	actor.current_martial_art = art
	_client.receive_log.rpc("%s剑锋一转，气势陡变，将功法套路变更为《%s》。" % [
		actor.display_name, art.art_name
	])
	_client.receive_status.rpc(_pack_status(actor))

# ============================================================
# 战斗判定核心
# ============================================================

func _resolve_attack(actor: CombatantData, target: CombatantData) -> void:
	var art := actor.current_martial_art
	var flailing := actor.is_flailing()

	# 选招式
	var move: MoveData = null
	var coeff := 1.0
	if art != null:
		move = art.pick_random_move()
		coeff = move.damage_coeff

	# 播报出招
	var broadcast := _fmt_attack(actor, target, move, flailing)
	_client.receive_log.rpc(broadcast)

	# 命中判定
	if not BattleFormula.roll_hit(actor, target, flailing):
		_client.receive_log.rpc("%s身形一闪，躲过了这招。" % target.display_name)
		_check_battle_end()
		return

	# 招架判定
	var parried := BattleFormula.roll_parry(target)
	if parried:
		_client.receive_log.rpc("%s举起武器格挡，化解了部分力道。" % target.display_name)

	# 伤害
	var dmg := BattleFormula.calc_damage(actor, target, coeff, 0.0, flailing, parried)
	target.current_hp = max(0, target.current_hp - dmg)
	_client.receive_log.rpc("%s受到了 %d 点伤害！" % [target.display_name, dmg])
	_client.receive_status.rpc(_pack_status(target))

	if target.current_hp <= 0:
		target.is_alive = false
		_client.receive_log.rpc("%s重伤倒地，退出了战斗！" % target.display_name)

	_check_battle_end()

func _resolve_ultimate(actor: CombatantData, target: CombatantData, art: MartialArtData) -> void:
	_client.receive_log.rpc(art.ultimate_broadcast.replace(
		"{caster}", actor.display_name).replace("{target}", target.display_name))

	# 绝招必中，不走命中判定
	var parried := BattleFormula.roll_parry(target)
	if parried:
		_client.receive_log.rpc("%s举起武器格挡，化解了部分力道。" % target.display_name)

	var dmg := BattleFormula.calc_damage(
		actor, target,
		art.ultimate_damage_coeff,
		art.ultimate_ignore_def_ratio,
		false, parried
	)
	target.current_hp = max(0, target.current_hp - dmg)
	_client.receive_log.rpc("%s受到了 %d 点伤害！" % [target.display_name, dmg])

	# 点穴
	if art.ultimate_apply_stun:
		target.stun_freeze = TIMELINE_THRESHOLD
		_client.receive_log.rpc("%s被点中要穴，动弹不得！" % target.display_name)

	_client.receive_status.rpc(_pack_status(target))

	if target.current_hp <= 0:
		target.is_alive = false
		_client.receive_log.rpc("%s重伤倒地，退出了战斗！" % target.display_name)

# ============================================================
# 战斗结束检测
# ============================================================

func _check_battle_end() -> void:
	var players_alive := combatants.any(func(c): return c.is_player and c.is_alive)
	var enemies_alive := combatants.any(func(c): return not c.is_player and c.is_alive)

	if not enemies_alive:
		_end_battle("players")
	elif not players_alive:
		_end_battle("enemies")

func _end_battle(winner: String) -> void:
	_battle_active = false
	_client.receive_battle_end.rpc(winner)
	emit_signal("battle_ended", winner)

# ============================================================
# 工具函数
# ============================================================

func _find_by_peer(peer_id: int) -> CombatantData:
	for c in combatants:
		if c.peer_id == peer_id:
			return c
	return null

func _get_alive_enemies_of(actor: CombatantData) -> Array[CombatantData]:
	var result: Array[CombatantData] = []
	for c in combatants:
		if c.is_player != actor.is_player and c.is_alive:
			result.append(c)
	return result

func _pack_status(c: CombatantData) -> Dictionary:
	return {
		"peer_id": c.peer_id,
		"name": c.display_name,
		"hp": c.current_hp,
		"max_hp": c.max_hp,
		"mp": c.current_mp,
		"max_mp": c.max_mp,
		"is_alive": c.is_alive,
		"stunned": c.stun_freeze > 0.0
	}

func _fmt_attack(actor: CombatantData, target: CombatantData, move: MoveData, flailing: bool) -> String:
	if flailing:
		if actor.equipped_weapon != null:
			return "%s根本不懂刀剑之术，只能凭蛮力胡乱挥舞手中的【%s】，破绽百出，惹人发笑！" % [
				actor.display_name, actor.equipped_weapon.weapon_name
			]
		else:
			return "%s毫无章法可言，像市井无赖一般朝%s胡乱抓打过去！" % [
				actor.display_name, target.display_name
			]
	if move == null:
		return "%s向%s发起了攻击！" % [actor.display_name, target.display_name]
	return move.broadcast_template\
		.replace("{caster}", actor.display_name)\
		.replace("{target}", target.display_name)\
		.replace("{move_name}", move.move_name)

func _fmt_stun_recover(c: CombatantData) -> String:
	return "%s真气冲破穴道，恢复了行动。" % c.display_name
