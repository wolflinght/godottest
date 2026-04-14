## BattleFormula.gd
## 纯计算层：命中/招架/伤害公式，无副作用，服务器调用
class_name BattleFormula

## 命中判定
## 返回 true=命中，false=闪避
static func roll_hit(attacker: CombatantData, defender: CombatantData, is_flailing: bool) -> bool:
	var hit_chance := 0.8 + attacker.hit_bonus - defender.dodge_rate
	if is_flailing:
		hit_chance -= 0.5
	hit_chance = clamp(hit_chance, 0.05, 0.95)
	return randf() < hit_chance

## 招架判定（仅命中后、守方持有武器时调用）
## 返回 true=招架成功
static func roll_parry(defender: CombatantData) -> bool:
	if defender.equipped_weapon == null:
		return false
	return randf() < defender.parry_rate

## 普通攻击伤害计算
## ignore_def_ratio: 无视防御比例（绝招用）
## is_flailing: 乱挥惩罚
## parried: 招架成功
static func calc_damage(
	attacker: CombatantData,
	defender: CombatantData,
	damage_coeff: float,
	ignore_def_ratio: float = 0.0,
	is_flailing: bool = false,
	parried: bool = false
) -> int:
	var base_damage := attacker.atk * damage_coeff
	var effective_def := defender.internal_def * (1.0 - ignore_def_ratio)
	var raw := (base_damage - effective_def) * randf_range(0.9, 1.1)
	if is_flailing:
		raw *= 0.2
	if parried:
		raw *= 0.5
	return max(1, int(raw))

## 吸气回血量（固定公式，后续可扩展）
static func calc_heal(caster: CombatantData) -> int:
	return max(1, int(caster.max_hp * 0.15))
