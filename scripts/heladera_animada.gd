extends StaticBody2D

@export var textura_variante: Texture2D 

@onready var sprite: Sprite2D = $Sprite2D
@onready var sensor: Area2D = $SensorPuertas

# Variable para guardar nuestra animación
var anim_tween: Tween

func _ready() -> void:
	# Si le pusiste una imagen de Yogurt en el Inspector, ¡úsela!
	if textura_variante != null:
		sprite.texture = textura_variante
		
	# Nos conectamos al sensor (lo que ya tenías)
	sensor.body_entered.connect(_on_sensor_body_entered)
	sensor.body_exited.connect(_on_sensor_body_exited)

func _on_sensor_body_entered(body: Node2D) -> void:
	if body is Player:
		abrir_puertas()

func _on_sensor_body_exited(body: Node2D) -> void:
	if body is Player:
		cerrar_puertas()

# --- FUNCIONES DE ANIMACIÓN PROCEDURAL ---

func abrir_puertas() -> void:
	# Matamos la animación anterior por si acaso
	if anim_tween: anim_tween.kill()
	
	anim_tween = create_tween()
	# tween_property (Nodo, propiedad a animar, valor final, duración en segundos)
	# Le decimos: Anima el "frame" hasta llegar al 4 (abierta) en 0.3 segundos.
	anim_tween.tween_property(sprite, "frame", 4, 0.3)

func cerrar_puertas() -> void:
	if anim_tween: anim_tween.kill()
	
	anim_tween = create_tween()
	# Le decimos: Anima el "frame" hasta volver al 0 (cerrada) en 0.3 segundos.
	anim_tween.tween_property(sprite, "frame", 0, 0.3)
