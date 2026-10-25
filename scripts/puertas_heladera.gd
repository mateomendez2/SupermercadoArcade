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

# --- BRILLO EN EL VIDRIO ---
# Con la heladera cerrada, el vidrio de la puerta izquierda brilla como los productos,
# para avisar que ahí hay algo para agarrar. Al abrirse, el brillo pasa al producto.
const SHADER_BRILLO = preload("res://scripts/brillo_vidrio.gdshader")
const VIDRIO_IZQUIERDO: Rect2 = Rect2(2, 12, 30, 32) # Dónde está el vidrio dentro del dibujo cerrado
var brillo_vidrio: Sprite2D
var anim_brillo: Tween

func _ready() -> void:
	heladera.area_entered.connect(_on_area_entered)
	heladera.area_exited.connect(_on_area_exited)
	# Si el producto vuelve a la heladera (porque se te cayó) y está cerrada, lo escondemos.
	# Va "deferred" para que pase DESPUÉS de que la góndola lo vuelva a mostrar.
	GameManager.item_dropped.connect(_on_item_devuelto, CONNECT_DEFERRED)
	producto.scale = Vector2.ZERO # Arranca cerrada: no se ve el producto
	_crear_brillo_vidrio()
	_mostrar_brillo(not heladera.is_empty, 0.0)

func _on_area_entered(area: Area2D) -> void:
	if area.get_parent() is Player:
		abrir()

func _on_area_exited(area: Area2D) -> void:
	if area.get_parent() is Player:
		cerrar()

func abrir() -> void:
	abierta = true
	_mostrar_brillo(false, 0.1) # El vidrio se corre: el brillo ahora lo tiene el producto
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
	# Si todavía tiene el producto, el vidrio vuelve a brillar cuando terminan de cerrarse las puertas
	if not heladera.is_empty:
		_mostrar_brillo(true, 0.2, 0.3)
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
		_mostrar_brillo(true, 0.2) # Volvió el producto: el vidrio brilla otra vez

# Una capa transparente encima del vidrio izquierdo, donde solo se dibuja la franja de luz
func _crear_brillo_vidrio() -> void:
	var blanco = Gradient.new()
	blanco.offsets = PackedFloat32Array([0.0])
	blanco.colors = PackedColorArray([Color.WHITE])
	var textura = GradientTexture2D.new()
	textura.gradient = blanco
	textura.width = int(VIDRIO_IZQUIERDO.size.x)
	textura.height = int(VIDRIO_IZQUIERDO.size.y)

	brillo_vidrio = Sprite2D.new()
	brillo_vidrio.name = "BrilloVidrio"
	brillo_vidrio.texture = textura
	brillo_vidrio.centered = false
	var material = ShaderMaterial.new()
	material.shader = SHADER_BRILLO
	brillo_vidrio.material = material
	# El dibujo de la heladera está centrado: calculamos dónde cae el vidrio
	var tam_cuadro = Vector2(dibujo.texture.get_width() / float(dibujo.hframes), dibujo.texture.get_height())
	brillo_vidrio.position = dibujo.offset - tam_cuadro / 2.0 + VIDRIO_IZQUIERDO.position
	dibujo.add_child(brillo_vidrio)

func _mostrar_brillo(mostrar: bool, duracion: float, demora: float = 0.0) -> void:
	if anim_brillo: anim_brillo.kill()
	var destino = 1.0 if mostrar else 0.0
	if duracion <= 0.0 and demora <= 0.0:
		brillo_vidrio.modulate.a = destino
		return
	anim_brillo = create_tween()
	if demora > 0.0: anim_brillo.tween_interval(demora)
	anim_brillo.tween_property(brillo_vidrio, "modulate:a", destino, duracion)
