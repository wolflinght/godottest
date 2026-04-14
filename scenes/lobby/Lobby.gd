## Lobby.gd
## 联机入口：Host 开房 / Join 加入
extends Control

const PORT := 7777
const MAX_PLAYERS := 4
const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"

@onready var btn_host: Button = $VBox/BtnHost
@onready var btn_join: Button = $VBox/BtnJoin
@onready var ip_input: LineEdit = $VBox/IPInput
@onready var status_label: Label = $VBox/StatusLabel
@onready var player_list: VBoxContainer = $VBox/PlayerList
@onready var btn_start: Button = $VBox/BtnStart

func _ready() -> void:
	btn_host.pressed.connect(_on_host)
	btn_join.pressed.connect(_on_join)
	btn_start.pressed.connect(_on_start)
	btn_start.hide()

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

func _on_host() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		status_label.text = "开房失败：%s" % error_string(err)
		return
	multiplayer.multiplayer_peer = peer
	status_label.text = "已开房，等待玩家加入...\n端口：%d" % PORT
	btn_host.disabled = true
	btn_join.disabled = true
	btn_start.show()
	_add_player_entry("你（房主）", multiplayer.get_unique_id())

func _on_join() -> void:
	var ip := ip_input.text.strip_edges()
	if ip == "":
		ip = "127.0.0.1"
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		status_label.text = "连接失败：%s" % error_string(err)
		return
	multiplayer.multiplayer_peer = peer
	status_label.text = "正在连接 %s:%d ..." % [ip, PORT]
	btn_host.disabled = true
	btn_join.disabled = true

func _on_start() -> void:
	if not multiplayer.is_server():
		return
	# 通知所有客户端切换场景
	_rpc_load_battle.rpc()

@rpc("authority", "call_local", "reliable")
func _rpc_load_battle() -> void:
	get_tree().change_scene_to_file(BATTLE_SCENE)

# ---- 联机回调 ----

func _on_peer_connected(id: int) -> void:
	status_label.text = "玩家 %d 加入" % id
	_add_player_entry("玩家 %d" % id, id)

func _on_peer_disconnected(id: int) -> void:
	status_label.text = "玩家 %d 断开" % id
	_remove_player_entry(id)

func _on_connected_to_server() -> void:
	status_label.text = "已连接！等待房主开始..."
	_add_player_entry("你", multiplayer.get_unique_id())

func _on_connection_failed() -> void:
	status_label.text = "连接失败，请检查IP和端口"
	btn_host.disabled = false
	btn_join.disabled = false

# ---- 玩家列表 ----

func _add_player_entry(name_text: String, id: int) -> void:
	var lbl := Label.new()
	lbl.name = str(id)
	lbl.text = "▶ %s  (id:%d)" % [name_text, id]
	player_list.add_child(lbl)

func _remove_player_entry(id: int) -> void:
	var node := player_list.get_node_or_null(str(id))
	if node:
		node.queue_free()
