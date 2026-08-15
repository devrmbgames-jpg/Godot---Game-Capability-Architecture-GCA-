extends Node3D
class_name GameGameplayExamplesGalleryExample

# ======== EXPORT =========
@export var enemy: GameEnemyExample = null
@export var player: GameThirdPersonCharacterExample = null

# ======= OVERRIDE =======
func _ready() -> void:
	if enemy != null and player != null:
		enemy.set_target(player)
