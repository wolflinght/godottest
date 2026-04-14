## BattleClient.gd
## 客户端：接收服务器广播，驱动UI，发送玩家指令
## 挂载到场景树，所有客户端运行
extends Node

# 引用服务器节点（同场景下）
@onready var battle_server: Node = $"../BattleServer"

# UI 信号（由 BattleScene 监听）
signal log_received(text: String)
signal status_updated(packed: Dictionary)
signal turn_started(peer_id: int)
signal battle_started()
signal battle_ended(winner: String)

var local_peer_id: int = 0
var _has_action: bool = false
var _countdown: float = 0.0
const TIMEOUT := 10.0

func _ready() -> void:
	local_peer_id = multiplayer.get_unique_id()

func _process(delta: float) -> void:
	if not _has_action:
		return
	_countdown -= delta
	if _countdown <= 0.0:
		_has_action = false
		if multiplayer.is_server():
			battle_server.c2s_attack(local_peer_id)
		else:
			battle_server.c2s_attack.rpc_id(1, local_peer_id)

# ============================================================
# 接收服务器广播（服务器调用这些函数广播到所有客户端）
# ============================================================

@rpc("authority", "call_local", "reliable")
func receive_battle_start() -> void:
	emit_signal("battle_started")

@rpc("authority", "call_local", "reliable")
func receive_log(text: String) -> void:
	emit_signal("log_received", text)

@rpc("authority", "call_local", "reliable")
func receive_status(packed: Dictionary) -> void:
	emit_signal("status_updated", packed)

@rpc("authority", "call_local", "reliable")
func receive_battle_end(winner: String) -> void:
	_has_action = false
	emit_signal("battle_ended", winner)

@rpc("authority", "call_remote", "reliable")
func receive_turn_start(peer_id: int) -> void:
	if peer_id != local_peer_id:
		return
	_has_action = true
	_countdown = TIMEOUT
	emit_signal("turn_started", peer_id)

# ============================================================
# 玩家指令发送（由 UI 调用）
# ============================================================

func send_attack() -> void:
	if not _has_action:
		return
	_has_action = false
	if multiplayer.is_server():
		battle_server.c2s_attack(local_peer_id)
	else:
		battle_server.c2s_attack.rpc_id(1, local_peer_id)

func send_ultimate(target_peer_id: int) -> void:
	if not _has_action:
		return
	_has_action = false
	if multiplayer.is_server():
		battle_server.c2s_ultimate(local_peer_id, target_peer_id)
	else:
		battle_server.c2s_ultimate.rpc_id(1, local_peer_id, target_peer_id)

func send_absorb() -> void:
	if not _has_action:
		return
	_has_action = false
	if multiplayer.is_server():
		battle_server.c2s_absorb(local_peer_id)
	else:
		battle_server.c2s_absorb.rpc_id(1, local_peer_id)

func send_switch_weapon(weapon_res_path: String) -> void:
	if not _has_action:
		return
	_has_action = false
	if multiplayer.is_server():
		battle_server.c2s_switch_weapon(local_peer_id, weapon_res_path)
	else:
		battle_server.c2s_switch_weapon.rpc_id(1, local_peer_id, weapon_res_path)

func send_switch_art(art_res_path: String) -> void:
	if not _has_action:
		return
	_has_action = false
	if multiplayer.is_server():
		battle_server.c2s_switch_art(local_peer_id, art_res_path)
	else:
		battle_server.c2s_switch_art.rpc_id(1, local_peer_id, art_res_path)

func get_countdown() -> float:
	return _countdown if _has_action else 0.0
