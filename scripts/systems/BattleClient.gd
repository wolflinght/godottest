## BattleClient.gd
## 客户端：接收服务器广播，驱动UI，发送玩家指令
## 挂载到场景树，所有客户端运行
extends Node

# 引用服务器节点（同一场景下，通过 get_node 获取）
@onready var battle_server: Node = $"../BattleServer"

# UI 信号（由 BattleScene 监听，解耦 UI 实现）
signal log_received(text: String)
signal status_updated(packed: Dictionary)
signal turn_started(peer_id: int)
signal battle_started()
signal battle_ended(winner: String)

# 本地玩家的 peer_id
var local_peer_id: int = 0

# 当前是否处于行动权窗口
var _has_action: bool = false
var _countdown: float = 0.0
const TIMEOUT := 10.0

func _ready() -> void:
	local_peer_id = multiplayer.get_unique_id()
	# 覆写服务器的 RPC 广播函数，让客户端能接收
	battle_server._rpc_broadcast_battle_start.connect(_on_battle_start)
	battle_server._rpc_broadcast_log.connect(_on_log)
	battle_server._rpc_broadcast_status.connect(_on_status)
	battle_server._rpc_broadcast_battle_end.connect(_on_battle_end)
	battle_server._rpc_turn_start.connect(_on_turn_start)

func _process(delta: float) -> void:
	if not _has_action:
		return
	_countdown -= delta
	if _countdown <= 0.0:
		_has_action = false
		# 超时自动攻击（客户端发送，服务器验证）
		battle_server.c2s_attack.rpc_id(1, local_peer_id)

# ============================================================
# 接收服务器广播
# ============================================================

func _on_battle_start() -> void:
	emit_signal("battle_started")

func _on_log(text: String) -> void:
	emit_signal("log_received", text)

func _on_status(packed: Dictionary) -> void:
	emit_signal("status_updated", packed)

func _on_battle_end(winner: String) -> void:
	_has_action = false
	emit_signal("battle_ended", winner)

func _on_turn_start(peer_id: int) -> void:
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
	battle_server.c2s_attack.rpc_id(1, local_peer_id)

func send_ultimate(target_peer_id: int) -> void:
	if not _has_action:
		return
	_has_action = false
	battle_server.c2s_ultimate.rpc_id(1, local_peer_id, target_peer_id)

func send_absorb() -> void:
	if not _has_action:
		return
	_has_action = false
	battle_server.c2s_absorb.rpc_id(1, local_peer_id)

func send_switch_weapon(weapon_res_path: String) -> void:
	if not _has_action:
		return
	_has_action = false
	battle_server.c2s_switch_weapon.rpc_id(1, local_peer_id, weapon_res_path)

func send_switch_art(art_res_path: String) -> void:
	if not _has_action:
		return
	_has_action = false
	battle_server.c2s_switch_art.rpc_id(1, local_peer_id, art_res_path)

## 剩余决策时间（0~10，供 UI 倒计时显示）
func get_countdown() -> float:
	return _countdown if _has_action else 0.0
