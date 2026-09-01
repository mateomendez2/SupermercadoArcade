extends CharacterBody2D
class_name Player

@export var speed: float = 250.0
@export var acceleration: float = 1500.0
@export var friction: float = 1200.0
@onready var default_speed: float = speed
@onready var default_friction: float = friction
@onready var default_acceleration: float = acceleration

var is_frozen: bool = false 

# --- SISTEMA DE INTERACCIÓN ---
# Aquí guardaremos el objeto con el que podemos interactuar actualmente
var current_interactable: Interactable = null 

# Referencia al nodo Area2D que creamos (arrastra el nodo desde el árbol aquí manteniendo CTRL)
@onready var interaction_area: Area2D = $InteractionArea

# Referenciamos el nuevo nodo animado
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D 

# Variable para recordar hacia dónde miramos por última vez (por defecto a la derecha)
var last_direction: Vector2 = Vector2(1, 0)

func _ready() -> void:
	interaction_area.area_entered.connect(_on_area_entered)
	interaction_area.area_exited.connect(_on_area_exited)
	
	# NUEVO: El Jugador ahora escucha cuando el GameManager suma algo a la lista
	GameManager.item_collected.connect(_on_item_recolectado)

func _physics_process(delta: float) -> void:
	if is_frozen:
		return # Si está congelado, NO lee el movimiento
		
	move_state(delta)

func move_state(delta: float) -> void:
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if direction != Vector2.ZERO:
		# Si nos movemos, guardamos esa dirección en la memoria
		last_direction = direction
		velocity = velocity.move_toward(direction * speed, acceleration * delta)
		update_animation(true) # true = está caminando
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		update_animation(false) # false = está quieto (Idle)
		
	move_and_slide()

# --- MÁQUINA DE ANIMACIONES ---
func update_animation(is_moving: bool) -> void:
	# Nos aseguramos de que el sprite NUNCA esté volteado por código
	anim_sprite.flip_h = false 
	
	# Prioridad al movimiento horizontal
	if last_direction.x > 0:
		if is_moving:
			anim_sprite.play("walk_right")
		else:
			anim_sprite.play("idle_right")
			
	elif last_direction.x < 0:
		if is_moving:
			anim_sprite.play("walk_left") # ¡Usamos tu animación real!
		else:
			anim_sprite.play("idle_left")
			
	# Movimiento vertical
	elif last_direction.y > 0:
		if is_moving:
			anim_sprite.play("walk_down")
		else:
			anim_sprite.play("idle_down")
			
	elif last_direction.y < 0:
		if is_moving:
			anim_sprite.play("walk_up")
		else:
			anim_sprite.play("idle_up")

func _unhandled_input(event: InputEvent) -> void:
	# NUEVO: Si estamos congelados, ignoramos los botones
	if is_frozen: return 
	
	if event.is_action_pressed("interact") and current_interactable != null:
		current_interactable.interact()

# --- FUNCIONES DE SEÑALES ---
# Se dispara automáticamente cuando otra área entra en nuestra InteractionArea
func _on_area_entered(area: Area2D) -> void:
	if area is Interactable:
		current_interactable = area
		print("Objeto en rango. Presiona E para interactuar.")

# Se dispara cuando nos alejamos del objeto
func _on_area_exited(area: Area2D) -> void:
	if area == current_interactable:
		current_interactable = null
		print("Saliste del rango del objeto.")

# El charco llamará a esta función
func set_slippery(is_slippery: bool) -> void:
	if is_slippery:
		# Modo Patinaje torpe: 
		# Fricción baja (resbala), Aceleración baja (le cuesta arrancar)...
		friction = 200.0 
		acceleration = 400.0
		# ¡Y cortamos la velocidad a la mitad!
		speed = default_speed / 2.0
	else:
		# Volvemos a la normalidad instantáneamente
		speed = default_speed
		friction = default_friction
		acceleration = default_acceleration

# --- ANIMACIÓN DE RECOLECCIÓN ---
func _on_item_recolectado(_item: ItemData) -> void:
	# 1. Congelamos al jugador para que no pueda caminar
	is_frozen = true 
	
	# 2. Elegimos la animación correcta según la memoria de estado
	if last_direction.x > 0:
		anim_sprite.play("pickup_right")
	elif last_direction.x < 0:
		anim_sprite.play("pickup_left")
	elif last_direction.y > 0:
		anim_sprite.play("pickup_down")
	elif last_direction.y < 0:
		anim_sprite.play("pickup_up")
		
	# 3. ¡LA MAGIA DE LA CORRUTINA! 
	# El código se pausa en esta línea hasta que la animación termine por completo.
	await anim_sprite.animation_finished
	
	# 4. Le devolvemos el control al jugador
	is_frozen = false 
	update_animation(false) # Forzamos a que vuelva al estado Idle (respirar)
