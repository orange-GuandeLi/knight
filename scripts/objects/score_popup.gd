extends Label
## 飘起来的加分提示。踩怪连踩时显示倍率。

const FLOAT_SPEED := -52.0
const LIFETIME := 0.75


func _ready() -> void:
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y + FLOAT_SPEED * LIFETIME, LIFETIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "modulate:a", 0.0, LIFETIME * 0.5) \
		.set_delay(LIFETIME * 0.5)
	tw.tween_callback(queue_free)
