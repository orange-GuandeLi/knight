extends Area2D
## 金币：碰到就收，+100 分。

const VALUE := 100

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	sprite.play(&"spin")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		Game.add_coin()
		queue_free()
