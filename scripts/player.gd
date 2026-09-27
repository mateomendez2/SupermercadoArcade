extends CharacterBody2D
class_name Player

@onready var sonido_recoger: AudioStreamPlayer2D = $SonidoRecoger

@export var speed: float = 200.0
@export var acceleration: float = 1500.0
@export var friction: float = 1200.0
@onready var default_speed: float = speed
@onready var default_friction: float = friction
@onready var default_acceleration: float = acceleration

var is_frozen: bool = false 

# --- SISTEMA DE INTERACCIÓN ---
var current_interactable: Interactable = null 
@onready var interaction_area: Area2D = $InteractionArea
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

var last_direction: Vector2 = Vector2(1, 0)
var is_penalized: bool = false
var knockback_vector: Vector2 = Vector2.ZERO

func _ready() -> void:
	interaction_area.area_entered.connect(_on_area_entered)
	interaction_area.area_exited.connect(_on_area_exited)
	
	GameManager.item_collected.connect(_on_item_recolectado)
	GameManager.item_dropped.connect(_animar_perdida_item)

func _physics_process(delta: float) -> void:
	if is_frozen:
		return 
		
	move_state(delta)

func move_state(delta: float) -> void:
	if knockback_vector != Vector2.ZERO:
		velocity = knockback_vector
		move_and_slide() 
		return 
	
	# 1. Leemos el joystick REAL (Para saber la intención de la animación)
	var raw_direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# 2. Redondeamos a lo bruto (Para que la cámara no tiemble)
	var direction: Vector2 = raw_direction.round()
	
	if direction != Vector2.ZERO:
		# ¡El cerebro guarda la intención sutil, no la redondeada!
		last_direction = raw_direction 
		
		velocity = velocity.move_toward(direction * speed, acceleration * delta)
		update_animation(true) 
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		update_animation(false) 
		
	move_and_slide()

# --- MÁQUINA DE ANIMACIONES ---
func update_animation(is_moving: bool) -> void:
	anim_sprite.flip_h = false 
	
	# ¡LA MAGIA! Comparamos: ¿Estás empujando más fuerte en Horizontal o en Vertical?
	if abs(last_direction.x) > abs(last_direction.y):
		# Gana Horizontal
		if last_direction.x > 0:
			if is_moving: anim_sprite.play("walk_right")
			else: anim_sprite.play("idle_right")
		else:
			if is_moving: anim_sprite.play("walk_left")
			else: anim_sprite.play("idle_left")
	else:
		# Gana Vertical
		if last_direction.y > 0:
			if is_moving: anim_sprite.play("walk_down")
			else: anim_sprite.play("idle_down")
		else:
			if is_moving: anim_sprite.play("walk_up")
			else: anim_sprite.play("idle_up")

# --- INPUT DE INTERACCIÓN ---
func _unhandled_input(event: InputEvent) -> void:
	if is_frozen: return 
	
	if event.is_action_pressed("interact") and current_interactable != null:
		get_viewport().set_input_as_handled() 
		velocity = Vector2.ZERO 
		current_interactable.interact()

func _on_area_entered(area: Area2D) -> void:
	if area is Interactable:
		current_interactable = area

func _on_area_exited(area: Area2D) -> void:
	if area == current_interactable:
		current_interactable = null

# El charco llamará a esta función
func set_slippery(is_slippery: bool) -> void:
	if is_slippery:
		# ¡MODO CÁSCARA DE BANANA!
		# Usamos "last_direction" para saber hacia dónde venías caminando
		var direccion_patinazo = last_direction.normalized()
		
		# Te inyectamos una velocidad brutal hacia ADELANTE (pierdes el control)
		# Cambiamos 500 por 800 para más impulso
		knockback_vector = direccion_patinazo * 400.0 
		
		# Cambiamos 0.4 a 0.8 para que tarde más en frenar
		var patinazo_tween = create_tween()
		patinazo_tween.tween_property(self, "knockback_vector", Vector2.ZERO, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		# Como el Tween de arriba ya frena al personaje de forma natural,
		# aquí no necesitamos hacer nada especial al salir del charco.
		pass

func _on_item_recolectado(_item: ItemData) -> void:
	sonido_recoger.play()
	is_frozen = true 
	
	if last_direction.x > 0:
		anim_sprite.play("pickup_right")
	elif last_direction.x < 0:
		anim_sprite.play("pickup_left")
	elif last_direction.y > 0:
		anim_sprite.play("pickup_down")
	elif last_direction.y < 0:
		anim_sprite.play("pickup_up")
		
	await anim_sprite.animation_finished
	
	is_frozen = false 
	update_animation(false) 

# --- SISTEMA DE PENALIZACIÓN CORREGIDO ---
func apply_penalty(duracion: float, pos_enemigo: Vector2 = Vector2.ZERO) -> void:
	if is_penalized: return 
	
	is_penalized = true
	
	# --- EFECTO KNOCKBACK (FÍSICO) ---
	if pos_enemigo != Vector2.ZERO:
		# ¡CAMBIO AQUI! Ponemos el signo MENOS al principio del paréntesis para que rebote hacia atrás
		var direccion_empuje = -(pos_enemigo - global_position).normalized()
		
		knockback_vector = direccion_empuje * 400.0
		
		var kb_tween = create_tween()
		kb_tween.tween_property(self, "knockback_vector", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# ---------------------------------
	
	speed = default_speed / 2.0
	
	var blink_tween = create_tween().set_loops()
	blink_tween.tween_property(anim_sprite, "modulate:a", 0.3, 0.15) 
	blink_tween.tween_property(anim_sprite, "modulate:a", 1.0, 0.15) 
	
	await get_tree().create_timer(duracion).timeout
	
	speed = default_speed
	blink_tween.kill() 
	anim_sprite.modulate.a = 1.0 
	is_penalized = false

func _animar_perdida_item(item: ItemData) -> void:
	var sprite_caido = Sprite2D.new()
	sprite_caido.texture = item.icon
	
	sprite_caido.global_position = global_position
	get_tree().current_scene.add_child(sprite_caido)
	
	var caida_tween = create_tween()
	caida_tween.tween_property(sprite_caido, "position:y", global_position.y - 40.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	caida_tween.tween_property(sprite_caido, "position:y", global_position.y + 300.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	await caida_tween.finished
	sprite_caido.queue_free()
