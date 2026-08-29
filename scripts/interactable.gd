extends Area2D
class_name Interactable

# Aquí es donde pondremos el archivo "apple.tres"
@export var item_content: ItemData 

# Variable para saber si ya agarramos la manzana
var is_empty: bool = false 

# Esto busca el nodo que tiene el dibujo de la manzana
@onready var item_visual: Sprite2D = $ItemVisual 

# Ahora interact() no devuelve la fruta de inmediato
func interact() -> void:
	if not is_empty and item_content != null:
		# En lugar de darle el objeto, iniciamos el minijuego
		GameManager.request_qte(self) 
	else:
		print("Góndola: Ya está vacía.")

# Esta función SOLO se llama si el GameManager dice que ganaste el QTE
func succesful_interaction() -> void:
	is_empty = true 
	item_visual.hide() 
	
	print("Góndola: Toma tu ", item_content.item_name)
	# Entregamos el ítem al inventario
	GameManager.add_item(item_content)
