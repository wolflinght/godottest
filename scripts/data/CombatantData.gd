## CombatantData.gd
## 战斗参与者的属性数据（Resource，服务器与客户端共享结构）
class_name CombatantData
extends Resource

# ---- 身份 ----
@export var display_name: String = ""
@export var is_player: bool = false   # true=玩家，false=NPC/敌人
var peer_id: int = 0                  # 联机时对应的 peer_id（NPC为0）

# ---- 基础属性 ----
@export_group("Base Stats")
@export var bravery: int = 10      # 臂力 → ATK、招架率
@export var agility: int = 10      # 身法 → SPD、闪避率
@export var constitution: int = 10 # 根骨 → HP上限、内功防御

# ---- 派生战斗属性（由基础属性计算，战斗开始时初始化）----
var atk: int = 0
var spd: int = 0
var max_hp: int = 0
var parry_rate: float = 0.0   # 招架率 0~1
var dodge_rate: float = 0.0   # 闪避率 0~1
var hit_bonus: float = 0.0    # 命中加成（叠加到基础80%上）
var internal_def: int = 0     # 内功防御

# ---- 当前战斗状态（服务器维护）----
var current_hp: int = 0
var current_mp: int = 100
var max_mp: int = 100
var timeline_progress: float = 0.0  # 隐藏集气条进度（0~1000）
var stun_freeze: float = 0.0        # 点穴剩余冻结量（>0时不增长进度）
var is_alive: bool = true

# ---- 装备与功法 ----
var equipped_weapon: WeaponData = null          # 当前装备的兵刃（null=空手）
var current_martial_art: MartialArtData = null  # 当前激活的功法（null=无）
# 战前预设：兵刃Tag → 默认功法
var loadout: Dictionary = {}  # WeaponData.WeaponTag -> MartialArtData
# 已学功法列表
var learned_arts: Array[MartialArtData] = []

## 根据基础属性初始化派生战斗属性
func init_combat_stats() -> void:
	atk = bravery * 2
	spd = agility * 3
	max_hp = constitution * 10
	current_hp = max_hp
	parry_rate = clamp(bravery * 0.01, 0.0, 0.5)
	dodge_rate = clamp(agility * 0.008, 0.0, 0.4)
	hit_bonus = 0.0
	internal_def = constitution

## 是否处于乱挥状态
func is_flailing() -> bool:
	if current_martial_art != null:
		return false
	# 有武器但无对应功法 → 乱挥；空手无功法 → 也算乱挥
	return true

## 当前武器的 Tag（空手返回 UNARMED）
func weapon_tag() -> WeaponData.WeaponTag:
	if equipped_weapon == null:
		return WeaponData.WeaponTag.UNARMED
	return equipped_weapon.weapon_tag

## 获取当前兵刃对应的已学功法列表（用于换功法面板过滤）
func get_arts_for_current_weapon() -> Array[MartialArtData]:
	var tag = weapon_tag()
	var result: Array[MartialArtData] = []
	for art in learned_arts:
		if art.weapon_tag == tag:
			result.append(art)
	return result
