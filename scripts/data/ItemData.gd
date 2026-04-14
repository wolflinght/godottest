## ItemData.gd
## 物品基础数据（Resource，编辑器配置）
class_name ItemData
extends Resource

enum ItemType {
	CONSUMABLE,  # 消耗品（包子、金疮药）
	MATERIAL,    # 材料（铁矿、草药）
	QUEST,       # 任务物品（书信、卷轴）
	WEAPON,      # 兵刃
	ARMOR,       # 衣服
	SHOES,       # 鞋履
	ACCESSORY    # 饰品
}

@export var item_id: String = ""
@export var item_name: String = ""
@export var item_type: ItemType = ItemType.CONSUMABLE
@export var weight: float = 0.5
@export_multiline var description: String = ""

# ---- 装备类专用 ----
@export_group("Equipment")
@export var weapon_tag: WeaponData.WeaponTag = WeaponData.WeaponTag.UNARMED  # 仅兵刃用
@export var atk_bonus: int = 0
@export var def_bonus: int = 0
@export var spd_bonus: int = 0
@export var hp_bonus: int = 0
@export var luck_bonus: int = 0
@export var special_tag: String = ""  # 特殊词条描述，如"防点穴"

# ---- 消耗品专用 ----
@export_group("Consumable")
@export var restore_hp: int = 0
@export var restore_hunger: int = 0
@export var restore_thirst: int = 0
