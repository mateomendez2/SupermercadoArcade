extends Node2D

@export var tiempo_caminando: float = 2.0 
@export var tiempo_espera: float = 1.0 

@onready var hitbox: Area2D = %Hitbox
@onready var punto_final: Marker2D = %PuntoFinal

# NUEVO: Referencia al dibujo animado (que ahora es hijo de la Hitbox)
@onready var anim_sprite: AnimatedSprite2D = %Hitbox.get_node("AnimatedSprite2D")

@onready var posicion_inicial: Vector2 = hitbox.position
var ultima_posicion: Vector2
var last_direction: Vector2 = Vector2(1, 0) # Memoria de hacia dónde mira

func _ready() -> void:
	ultima_posicion = hitbox.position # Anotamos dónde arranca
	iniciar_patrullaje()
	hitbox.body_entered.connect(_on_hitbox_body_entered)

func iniciar_patrullaje() -> void:
	var patrulla_tween = create_tween().set_loops()
	patrulla_tween.tween_property(hitbox, "position", punto_final.position, tiempo_caminando)
	patrulla_tween.tween_interval(tiempo_espera)
	patrulla_tween.tween_property(hitbox, "position", posicion_inicial, tiempo_caminando)
	patrulla_tween.tween_interval(tiempo_espera)

# --- NUEVO: CEREBRO DE ANIMACIÓN ---
func _physics_process(delta: float) -> void:
	# Medimos cuánto se movió en este microsegundo
	var movimiento = hitbox.position - ultima_posicion
	ultima_posicion = hitbox.position # Guardamos la posición para el siguiente cálculo
	
	if movimiento.length() > 0.1: # Si se está moviendo
		last_direction = movimiento.normalized()
		update_animation(true)
	else: # Si el Tween está en "tiempo_espera" (quieto)
		update_animation(false)

func update_animation(is_moving: bool) -> void:
	anim_sprite.flip_h = false 
	
	# Comprobamos si se mueve más en horizontal o en vertical
	if abs(last_direction.x) > abs(last_direction.y):
		if last_direction.x > 0:
			anim_sprite.play("walk_right" if is_moving else "idle_right")
		else:
			anim_sprite.play("walk_left" if is_moving else "idle_left")
	else:
		if last_direction.y > 0:
			anim_sprite.play("walk_down" if is_moving else "idle_down")
		else:
			anim_sprite.play("walk_up" if is_moving else "idle_up")

# --- CASTIGO AL JUGADOR ---
func _on_hitbox_body_entered(body: Node2D) -> void:
	if body is Player:
		body.apply_penalty(5.0)
