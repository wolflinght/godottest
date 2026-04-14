## BattleScene.gd
## 战斗场景根节点：组装 BattleServer + BattleClient，连接UI信号
extends Node

@onready var battle_server: Node = $BattleServer
@onready var battle_client: Node = $BattleClient
@onready var hud: Node = $UI/HUD
@onready var action_panel: Node = $UI/ActionPanel
@onready var result_panel: Node = $UI/ResultPanel

func _ready() -> void:
	# 连接客户端信号到UI
	battle_client.battle_started.connect(hud._on_battle_started)
	battle_client.log_received.connect(hud._on_log_received)
	battle_client.status_updated.connect(hud._on_status_updated)
	battle_client.turn_started.connect(action_panel._on_turn_started)
	battle_client.battle_ended.connect(_on_battle_ended)

	# 连接操作面板指令到客户端
	action_panel.attack_pressed.connect(battle_client.send_attack)
	action_panel.absorb_pressed.connect(battle_client.send_absorb)
	action_panel.ultimate_pressed.connect(func(target_id): battle_client.send_ultimate(target_id))
	action_panel.switch_weapon_pressed.connect(func(path): battle_client.send_switch_weapon(path))
	action_panel.switch_art_pressed.connect(func(path): battle_client.send_switch_art(path))

	# 如果是服务器，启动测试战斗
	if multiplayer.is_server():
		_start_test_battle()

func _start_test_battle() -> void:
	var players: Array[CombatantData] = [_make_test_player()]
	var enemies: Array[CombatantData] = [_make_test_enemy()]
	battle_server.start_battle(players, enemies)

func _make_test_player() -> CombatantData:
	var c := CombatantData.new()
	c.display_name = "令狐冲"
	c.is_player = true
	c.peer_id = 1  # Host 的 peer_id
	c.bravery = 12
	c.agility = 14
	c.constitution = 10
	c.current_mp = 500
	c.max_mp = 500
	# 装备太极拳
	var art: MartialArtData = load("res://resources/martial_arts/taiji_fist.tres")
	c.learned_arts.append(art)
	c.current_martial_art = art
	c.loadout[WeaponData.WeaponTag.UNARMED] = art
	return c

func _make_test_enemy() -> CombatantData:
	var c := CombatantData.new()
	c.display_name = "东方不败"
	c.is_player = false
	c.peer_id = 0
	c.bravery = 10
	c.agility = 18
	c.constitution = 8
	c.current_mp = 500
	c.max_mp = 500
	var art: MartialArtData = load("res://resources/martial_arts/taiji_sword.tres")
	c.learned_arts.append(art)
	c.current_martial_art = art
	return c

func _on_battle_ended(winner: String) -> void:
	action_panel.hide()
	result_panel.show_result(winner)
