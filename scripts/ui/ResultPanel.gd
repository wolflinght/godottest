## ResultPanel.gd
## 战斗结果覆盖层
extends Control

@onready var result_label: Label = $VBox/ResultLabel
@onready var retry_btn: Button = $VBox/RetryBtn

func _ready() -> void:
	hide()
	retry_btn.pressed.connect(func(): get_tree().reload_current_scene())

func show_result(winner: String) -> void:
	show()
	match winner:
		"players":
			result_label.text = "战斗胜利！"
			result_label.add_theme_color_override("font_color", Color.GOLD)
		"enemies":
			result_label.text = "战斗失败..."
			result_label.add_theme_color_override("font_color", Color.RED)
