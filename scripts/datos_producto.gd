extends Resource
class_name ItemData # Al ponerle nombre, Godot lo añade a su lista de nodos/recursos internos

@export var item_name: String = "Nuevo Item"
@export var icon: Texture2D # Aquí Natasha pondrá el pixel art del ítem (32x32)
@export var is_fragile: bool = false # Ejemplo: si es vidrio, si te chocan se rompe. (Ideal para Arcade)
