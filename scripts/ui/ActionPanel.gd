## ActionPanel.gd
## 玩家操作面板：5个指令按钮 + 10秒倒计时
extends Control

signal attack_pressed
signal ultimate_pressed(target_peer_id: int)
signal absorb_pressed
signal switch_weapon_pressed(res_path: String)
signal switch_art_pressed(res_path: String)

@onready var btn_attack: Button = $Rows/Row1/BtnAttack
@onready var btn_ultimate: Button = $Rows/Row1/BtnUltimate
@onready var btn_absorb: Button = $Rows/Row1/BtnAbsorb
@onready var btn_weapon: Button = $Rows/Row2/BtnWeapon
@onready var btn_art: Button = $Rows/Row2/BtnArt
@onready var countdown_label: Label = $CountdownLabel
@onready var battle_client: Node  # 由 BattleScene 注入

var _countdown: float = 0.0
var _active: bool = false

func _ready() -> void:
	hide()
	btn_attack.pressed.connect(_on_attack)
	btn_ultimate.pressed.connect(_on_ultimate)
	btn_absorb.pressed.connect(_on_absorb)
	btn_weapon.pressed.connect(_on_switch_weapon)
	btn_art.pressed.connect(_on_switch_art)

func _process(delta: float) -> void:
	if not _active:
		return
	_countdown -= delta
	countdown_label.text = "%.1f" % max(0.0, _countdown)
	if _countdown <= 3.0:
		countdown_label.add_theme_color_override("font_color", Color.RED)
	else:
		countdown_label.add_theme_color_override("font_color", Color.WHITE)

func _on_turn_started(_peer_id: int) -> void:
	_active = true
	_countdown = 10.0
	show()
	btn_ultimate.disabled = false  # 后续可根据MP判断

func _hide_panel() -> void:
	_active = false
	hide()

# ---- 按钮回调 ----

func _on_attack() -> void:
	_hide_panel()
	emit_signal("attack_pressed")

func _on_ultimate() -> void:
	# 简化：目标默认传0（服务器随机选单体敌人）
	# 后续可做点击敌人头像选目标
	_hide_panel()
	emit_signal("ultimate_pressed", 0)

func _on_absorb() -> void:
	_hide_panel()
	emit_signal("absorb_pressed")

func _on_switch_weapon() -> void:
	# TODO: 弹出背包武器列表弹窗
	# 当前简化：直接发空手（切回空手）
	_hide_panel()
	emit_signal("switch_weapon_pressed", "")

func _on_switch_art() -> void:
	# TODO: 弹出功法列表弹窗
	# 当前简化：切换到太极拳
	_hide_panel()
	emit_signal("switch_art_pressed", "res://resources/martial_arts/taiji_fist.tres")
