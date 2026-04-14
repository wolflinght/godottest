## MartialArtData.gd
## 功法数据：包含招式池、绝招、兵刃标签绑定
class_name MartialArtData
extends Resource

enum AoEType {
	SINGLE,      # 单体
	ALL_ENEMIES  # 敌方全体
}

@export var art_name: String = ""
@export var skill_id: String = ""         # 唯一ID，对应 PlayerProfile.learned_arts 的 key
@export var weapon_tag: WeaponData.WeaponTag = WeaponData.WeaponTag.UNARMED
@export var prerequisite_id: String = ""  # 基本功前置（如"basic_sword"），等级不能超过它
@export var agi_bonus_per_10: int = 0     # 每10级提供的身法加成（剑法用）
@export var str_bonus_per_10: int = 0     # 每10级提供的臂力加成（刀法用）

# ---- 普通攻击招式池 ----
# 每个元素为 MoveData，系统按 weight 加权随机抽取
@export var move_pool: Array[MoveData] = []

# ---- 绝招 ----
@export_group("Ultimate")
@export var ultimate_name: String = ""
@export var ultimate_mp_cost: int = 0
@export var ultimate_damage_coeff: float = 1.0
@export var ultimate_ignore_def_ratio: float = 0.0   # 无视防御比例（0~1）
@export var ultimate_aoe: AoEType = AoEType.SINGLE
@export var ultimate_apply_stun: bool = false         # 是否施加点穴
@export_multiline var ultimate_broadcast: String = ""

## 按 weight 加权随机抽取一个招式
func pick_random_move() -> MoveData:
	var total_weight := 0
	for m in move_pool:
		total_weight += m.weight
	var roll := randi() % total_weight
	var acc := 0
	for m in move_pool:
		acc += m.weight
		if roll < acc:
			return m
	return move_pool[-1]
