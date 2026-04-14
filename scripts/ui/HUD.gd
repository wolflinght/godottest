## HUD.gd
## 战斗HUD：文字播报日志 + 角色状态栏
extends Control

@onready var log_label: RichTextLabel = $LogPanel/LogLabel
@onready var combatant_list: VBoxContainer = $StatusPanel/VBox/CombatantList

# peer_id/name → 状态行节点
var _status_rows: Dictionary = {}

func _on_battle_started() -> void:
	log_label.clear()
	_append_log("[color=gold]=== 战斗开始 ===[/color]")

func _on_log_received(text: String) -> void:
	_append_log(text)

func _on_status_updated(packed: Dictionary) -> void:
	var key = packed.get("peer_id", packed.get("name", ""))
	if not _status_rows.has(key):
		_create_status_row(key, packed)
	else:
		_update_status_row(key, packed)

func _append_log(text: String) -> void:
	log_label.append_text(text + "\n")
	await get_tree().process_frame
	log_label.scroll_to_line(log_label.get_line_count() - 1)

func _create_status_row(key, packed: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.name = str(key)

	var name_lbl := Label.new()
	name_lbl.name = "Name"
	name_lbl.text = packed.get("name", "???")
	name_lbl.custom_minimum_size = Vector2(100, 0)

	var hp_bar := ProgressBar.new()
	hp_bar.name = "HPBar"
	hp_bar.max_value = packed.get("max_hp", 100)
	hp_bar.value = packed.get("hp", 100)
	hp_bar.custom_minimum_size = Vector2(160, 18)
	hp_bar.show_percentage = false

	var hp_lbl := Label.new()
	hp_lbl.name = "HPLabel"
	hp_lbl.text = "%d/%d" % [packed.get("hp", 0), packed.get("max_hp", 0)]
	hp_lbl.custom_minimum_size = Vector2(70, 0)

	var mp_bar := ProgressBar.new()
	mp_bar.name = "MPBar"
	mp_bar.max_value = packed.get("max_mp", 100)
	mp_bar.value = packed.get("mp", 100)
	mp_bar.custom_minimum_size = Vector2(100, 18)
	mp_bar.show_percentage = false
	# 内力条蓝色
	mp_bar.modulate = Color(0.4, 0.6, 1.0)

	var mp_lbl := Label.new()
	mp_lbl.name = "MPLabel"
	mp_lbl.text = "内力%d" % packed.get("mp", 0)
	mp_lbl.custom_minimum_size = Vector2(60, 0)
	mp_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))

	row.add_child(name_lbl)
	row.add_child(hp_bar)
	row.add_child(hp_lbl)
	row.add_child(mp_bar)
	row.add_child(mp_lbl)
	combatant_list.add_child(row)
	_status_rows[key] = row

func _update_status_row(key, packed: Dictionary) -> void:
	var row: HBoxContainer = _status_rows[key]
	var hp_bar: ProgressBar = row.get_node("HPBar")
	var hp_lbl: Label = row.get_node("HPLabel")
	var mp_bar: ProgressBar = row.get_node("MPBar")
	var mp_lbl: Label = row.get_node("MPLabel")
	var name_lbl: Label = row.get_node("Name")

	hp_bar.max_value = packed.get("max_hp", hp_bar.max_value)
	hp_bar.value = packed.get("hp", 0)
	hp_lbl.text = "%d/%d" % [packed.get("hp", 0), packed.get("max_hp", 0)]
	mp_bar.max_value = packed.get("max_mp", mp_bar.max_value)
	mp_bar.value = packed.get("mp", 0)
	mp_lbl.text = "内力%d" % packed.get("mp", 0)

	# 死亡变灰，点穴变橙
	if not packed.get("is_alive", true):
		row.modulate = Color(0.4, 0.4, 0.4)
	elif packed.get("stunned", false):
		name_lbl.add_theme_color_override("font_color", Color.ORANGE)
	else:
		name_lbl.remove_theme_color_override("font_color")
