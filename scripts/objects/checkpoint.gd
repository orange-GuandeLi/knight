extends Area2D
## 检查点：立在路边的一块木牌。碰到就激活，之后死了从这儿复活。
##
## 节点原点放在牌子底部的地面高度（格子下沿），所以生成时直接给格子的底边中点。

signal activated(respawn_position: Vector2)

## 激活后的颜色：木牌染成金色
const ACTIVE_COLOR := Color(1.0, 0.84, 0.35)

@onready var sprite: Sprite2D = $Sprite

var is_active := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if is_active or not body is Player:
		return
	is_active = true
	sprite.modulate = ACTIVE_COLOR
	Audio.play_sfx("power_up")
	# 弹一下，让玩家注意到牌子亮了
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.35, 1.35), 0.08)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.14)
	# 复活点 = 牌子所在格子的底部中点（玩家原点 = 脚底）
	activated.emit(global_position)
