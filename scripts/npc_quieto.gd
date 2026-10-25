@tool
extends StaticBody2D
## NPC QUIETO
## Un cliente parado que no se mueve: solo hace su animación de "idle" (respirar).
## Sirve como obstáculo que ocupa un lugar, por ejemplo adelante de un mueble como si buscara algo.
## No te saca ítems ni te empuja: solo no te deja pasar.
## En el Inspector elegís hacia dónde mira (se ve el cambio en el editor).

enum Direccion { ABAJO, ARRIBA, IZQUIERDA, DERECHA }
const ANIMACIONES: Array[StringName] = [&"idle_down", &"idle_up", &"idle_left", &"idle_right"]

@export var mirando: Direccion = Direccion.ARRIBA:
	set(valor):
		mirando = valor
		_actualizar()

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	_actualizar()
	if not Engine.is_editor_hint():
		# Cada uno arranca en un momento distinto de la animación, así no "respiran" todos juntos
		sprite.frame = randi() % sprite.sprite_frames.get_frame_count(sprite.animation)
		sprite.speed_scale = randf_range(0.85, 1.15)

func _actualizar() -> void:
	if sprite == null: return
	sprite.play(ANIMACIONES[mirando])
