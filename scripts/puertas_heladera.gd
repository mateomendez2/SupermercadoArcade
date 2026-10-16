extends Node
## PUERTAS DE HELADERA
## Va adentro de las heladeras de donde se agarran productos (heladera_agua, heladera_yogur).
## Cuando el jugador se acerca (entra a la zona para agarrar), las puertas se abren
## y el producto aparece en el hueco de la puerta. Cuando se va, se cierran y el producto se esconde.

@onready var heladera: Interactable = get_parent()
@onready var dibujo: Sprite2D = get_parent().get_node("ShelfVisual")
@onready var producto: Sprite2D = get_parent().get_node("ItemVisual")

var abierta: bool = false
var anim_puertas: Tween
var anim_producto: Tween

func _ready() -> void:
	heladera.area_entered.connect(_on_area_entered)
	heladera.area_exited.connect(_on_area_exited)
	# Si el producto vuelve a la heladera (porque se te cayó) y está cerrada, lo escondemos.
	# Va "deferred" para que pase DESPUÉS de que la góndola lo vuelva a mostrar.
	GameManager.item_dropped.connect(_on_item_devuelto, CONNECT_DEFERRED)
	producto.scale = Vector2.ZERO # Arranca cerrada: no se ve el producto

func _on_area_entered(area: Area2D) -> void:
	if area.get_parent() is Player:
		abrir()

func _on_area_exited(area: Area2D) -> void:
	if area.get_parent() is Player:
		cerrar()

func abrir() -> void:
	abierta = true
	_mover_puertas(dibujo.hframes - 1) # Último cuadro = abierta
	# Si todavía tiene el producto, aparece con un "pop" mientras se abre la puerta
	if not heladera.is_empty:
		if anim_producto: anim_producto.kill()
		anim_producto = create_tween()
		anim_producto.tween_interval(0.15)
		anim_producto.tween_property(producto, "scale", Vector2(1.2, 1.2), 0.12)
		anim_producto.tween_property(producto, "scale", Vector2.ONE, 0.08)

func cerrar() -> void:
	abierta = false
	_mover_puertas(0) # Primer cuadro = cerrada
	# Si ya te lo llevaste, la góndola se encarga de su animación: no lo tocamos
	if not heladera.is_empty:
		if anim_producto: anim_producto.kill()
		anim_producto = create_tween()
		anim_producto.tween_property(producto, "scale", Vector2.ZERO, 0.15)

func _mover_puertas(cuadro_final: int) -> void:
	if anim_puertas: anim_puertas.kill()
	anim_puertas = create_tween()
	anim_puertas.tween_property(dibujo, "frame", cuadro_final, 0.3)

func _on_item_devuelto(_item: ItemData) -> void:
	if not abierta and not heladera.is_empty:
		producto.scale = Vector2.ZERO
