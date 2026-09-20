extends Area2D

# Exponemos dos variables vacías para que arrastres las imágenes de Natasha en el Inspector
@export var tex_agua: Texture2D
@export var tex_gaseosa: Texture2D

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# Conectamos las señales físicas
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# La Magia Aleatoria: 
	# Armamos una lista con las dos texturas
	var posibles_artes = [tex_agua, tex_gaseosa]
	
	# pick_random() es una función nativa de Godot 4 que elige uno al azar
	var arte_elegido = posibles_artes.pick_random()
	
	# Si cargaste imágenes en el inspector, se la aplicamos al Sprite
	if arte_elegido != null:
		sprite.texture = arte_elegido

# Cuando alguien pisa el charco...
func _on_body_entered(body: Node2D) -> void:
	# Preguntamos si el que pisó es de la clase Player
	if body is Player:
		body.set_slippery(true)

# Cuando alguien sale del charco...
func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		body.set_slippery(false)

var anim_tween: Tween

# El nivel llamará a esta función y le dirá cuántos segundos tiene de vida
func animar_ciclo(tiempo_de_vida: float) -> void:
	if anim_tween: anim_tween.kill() # Matamos animaciones viejas
	
	sprite.frame = 0 # Arrancamos chiquitos
	anim_tween = create_tween()
	
	# Calculamos los tiempos
	var tiempo_crecer = 1.0
	var tiempo_achicar = 1.0
	var tiempo_espera = tiempo_de_vida - tiempo_crecer - tiempo_achicar
	
	# Por seguridad, si el tiempo es muy corto, no esperamos nada
	if tiempo_espera < 0: tiempo_espera = 0.1 
	
	# 1. Crecer (Pasa del frame 0 al 3 en 1 segundo)
	anim_tween.tween_property(sprite, "frame", 3, tiempo_crecer)
	
	# 2. Quedarse grande (Pausa la animación)
	anim_tween.tween_interval(tiempo_espera)
	
	# 3. Encogerse antes de desaparecer (Pasa del 3 al 0 en 1 segundo)
	anim_tween.tween_property(sprite, "frame", 0, tiempo_achicar)
