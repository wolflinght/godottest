## WeaponData.gd
## 兵刃数据
class_name WeaponData
extends Resource

enum WeaponTag {
	UNARMED,  # 拳脚（空手/拳套/指虎）
	BLADE,    # 刀法
	SWORD     # 剑法
}

@export var weapon_name: String = ""
@export var weapon_tag: WeaponTag = WeaponTag.UNARMED
@export var atk_bonus: int = 0    # 装备后额外ATK加成
