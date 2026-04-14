## MoveData.gd
## 单个招式数据（属于某功法的招式池或绝招）
class_name MoveData
extends Resource

@export var move_name: String = ""
@export var damage_coeff: float = 1.0   # 伤害系数
@export var weight: int = 100           # 随机权重（攻击招式用）
# 播报模板，{caster} {target} 为占位符
@export_multiline var broadcast_template: String = "{caster}使出了{move_name}，攻向{target}。"
