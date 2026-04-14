## PlayerProfile.gd
## 玩家完整档案，对应策划文档的四大模块
## 服务器权威存储，客户端只读副本
class_name PlayerProfile
extends Resource

# ============================================================
# 1. 基础档案与生活状态
# ============================================================

@export var player_id: String = ""
@export var character_name: String = ""
@export var sect: String = "散人"          # 门派
@export var age: int = 14                  # 建号默认14岁
@export var appearance_desc: String = "相貌平平"

# 隐藏属性
var morality: int = 0                      # 善恶 -1000~1000
var luck: int = 50                         # 福缘（建号时由根骨+随机生成）

# 货币类资源
var potential: int = 0                     # 潜能
var experience: int = 0                    # 阅历

# 生存状态
var hunger: int = 100                      # 饱食度 0~100
var thirst: int = 100                      # 饮水度 0~100

# ============================================================
# 2. 四大先天属性（建号Roll点，总和80）
# ============================================================

@export_group("Base Stats")
@export var str_stat: int = 20   # 臂力
@export var agi_stat: int = 20   # 身法
@export var con_stat: int = 20   # 根骨
@export var int_stat: int = 20   # 悟性

# ============================================================
# 3. 武学档案
# ============================================================

# 已掌握武学：skill_id -> 等级
var learned_arts: Dictionary = {}   # { "taiji_sword": 95, "basic_sword": 100 }

# 战斗预设槽位
var loadout_neigong: String = ""          # 主修内功 skill_id
var loadout_qinggong: String = ""         # 主修轻功 skill_id
var loadout_unarmed: String = ""          # 拳脚预设 skill_id
var loadout_blade: String = ""            # 刀法预设 skill_id
var loadout_sword: String = ""            # 剑法预设 skill_id

# ============================================================
# 4. 装备槽位
# ============================================================

var equip_weapon: ItemData = null
var equip_armor: ItemData = null
var equip_shoes: ItemData = null
var equip_accessory: ItemData = null

# ============================================================
# 5. 行囊
# ============================================================

# 每个元素：{ "item": ItemData, "qty": int }
var inventory: Array = []

# ============================================================
# 派生属性计算（战斗时调用，生成 CombatantData）
# ============================================================

## 最大负重 = 臂力 * 2
func max_carry_weight() -> float:
	return str_stat * 2.0

## 当前负重
func current_carry_weight() -> float:
	var total := 0.0
	for slot in inventory:
		total += slot.item.weight * slot.qty
	return total

## 气血上限 = 根骨 * 10 + 装备加成 + 武学加成（简化）
func calc_max_hp() -> int:
	var base := con_stat * 10
	if equip_armor:
		base += equip_armor.hp_bonus
	# 饱食/饮水为0时减半
	if hunger <= 0 or thirst <= 0:
		base = base / 2
	return base

## 内力上限（主修内功决定，简化为固定值+内功等级）
func calc_max_mp() -> int:
	var base := 100
	if loadout_neigong != "" and learned_arts.has(loadout_neigong):
		base += learned_arts[loadout_neigong] * 5
	return base

## ATK = 臂力*2 + 兵刃加成
func calc_atk() -> int:
	var base := str_stat * 2
	if equip_weapon:
		base += equip_weapon.atk_bonus
	return base

## DEF = 根骨 + 衣服加成
func calc_def() -> int:
	var base := con_stat
	if equip_armor:
		base += equip_armor.def_bonus
	return base

## SPD = 身法*3 + 鞋履加成
func calc_spd() -> int:
	var base := agi_stat * 3
	if equip_shoes:
		base += equip_shoes.spd_bonus
	return base

## 招架率 = 臂力 * 1%，上限50%
func calc_parry_rate() -> float:
	return clamp(str_stat * 0.01, 0.0, 0.5)

## 闪避率 = 身法 * 0.8%，上限40%（主修轻功额外加成）
func calc_dodge_rate() -> float:
	var base := agi_stat * 0.008
	if loadout_qinggong != "" and learned_arts.has(loadout_qinggong):
		base += learned_arts[loadout_qinggong] * 0.0005
	return clamp(base, 0.0, 0.4)

## 生成战斗用 CombatantData（进入战斗时调用）
func to_combatant(peer_id_val: int) -> CombatantData:
	var c := CombatantData.new()
	c.display_name = character_name
	c.is_player = true
	c.peer_id = peer_id_val

	# 直接写入派生属性，跳过 init_combat_stats
	c.atk = calc_atk()
	c.spd = calc_spd()
	c.max_hp = calc_max_hp()
	c.current_hp = c.max_hp
	c.max_mp = calc_max_mp()
	c.current_mp = c.max_mp
	c.parry_rate = calc_parry_rate()
	c.dodge_rate = calc_dodge_rate()
	c.internal_def = calc_def()

	# 装备武器
	c.equipped_weapon = equip_weapon

	# 加载已学功法（Resource路径映射，简化版）
	_apply_loadout(c)

	return c

func _apply_loadout(c: CombatantData) -> void:
	# 根据当前装备的兵刃Tag，自动选对应预设功法
	var tag := WeaponData.WeaponTag.UNARMED
	if equip_weapon:
		tag = equip_weapon.weapon_tag

	var art_id := ""
	match tag:
		WeaponData.WeaponTag.UNARMED: art_id = loadout_unarmed
		WeaponData.WeaponTag.BLADE:   art_id = loadout_blade
		WeaponData.WeaponTag.SWORD:   art_id = loadout_sword

	if art_id != "":
		var path := "res://resources/martial_arts/%s.tres" % art_id
		if ResourceLoader.exists(path):
			c.current_martial_art = load(path)

	# 预设loadout字典供战中换兵刃用
	if loadout_unarmed != "":
		var p := "res://resources/martial_arts/%s.tres" % loadout_unarmed
		if ResourceLoader.exists(p):
			c.loadout[WeaponData.WeaponTag.UNARMED] = load(p)
	if loadout_blade != "":
		var p := "res://resources/martial_arts/%s.tres" % loadout_blade
		if ResourceLoader.exists(p):
			c.loadout[WeaponData.WeaponTag.BLADE] = load(p)
	if loadout_sword != "":
		var p := "res://resources/martial_arts/%s.tres" % loadout_sword
		if ResourceLoader.exists(p):
			c.loadout[WeaponData.WeaponTag.SWORD] = load(p)

# ============================================================
# 行囊操作
# ============================================================

## 添加物品，返回是否成功（超重则失败）
func add_item(item: ItemData, qty: int = 1) -> bool:
	if current_carry_weight() + item.weight * qty > max_carry_weight():
		return false
	for slot in inventory:
		if slot.item.item_id == item.item_id:
			slot.qty += qty
			return true
	inventory.append({"item": item, "qty": qty})
	return true

## 移除物品
func remove_item(item_id: String, qty: int = 1) -> bool:
	for i in inventory.size():
		if inventory[i].item.item_id == item_id:
			inventory[i].qty -= qty
			if inventory[i].qty <= 0:
				inventory.remove_at(i)
			return true
	return false

## 使用消耗品（战斗外）
func use_consumable(item_id: String) -> String:
	for slot in inventory:
		if slot.item.item_id == item_id and slot.item.item_type == ItemData.ItemType.CONSUMABLE:
			var item: ItemData = slot.item
			# 应用效果
			if item.restore_hunger > 0:
				hunger = min(100, hunger + item.restore_hunger)
			if item.restore_thirst > 0:
				thirst = min(100, thirst + item.restore_thirst)
			remove_item(item_id, 1)
			return "你吃下了【%s】。" % item.item_name
	return "没有找到该物品。"

# ============================================================
# 建号工具
# ============================================================

## 建号时随机分配属性（总和80，单项10~30）
static func roll_base_stats() -> Dictionary:
	var stats := {"str": 10, "agi": 10, "con": 10, "int": 10}
	var remaining := 40  # 已有40基础，还剩40分配
	var keys := ["str", "agi", "con", "int"]
	for i in range(3):  # 前三项随机，第四项取剩余
		var max_add := min(remaining - (3 - i) * 0, 20)  # 每项最多再加20（上限30）
		var add := randi() % (max_add + 1)
		stats[keys[i]] += add
		remaining -= add
	stats[keys[3]] += remaining
	# 确保不超30
	for k in keys:
		stats[k] = clamp(stats[k], 10, 30)
	return stats
