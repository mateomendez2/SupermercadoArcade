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

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		if body.atrapado: return # (modo 2 jugadores: el guardia lo está llevando a la puerta)
		body.set_slippery(true)
		# ¡NUEVA LÍNEA! Te hace perder una fruta al pisarlo
		GameManager.perder_ultimo_item(body.prefijo_acciones)

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		body.set_slippery(false)

var anim_tween: Tween

# El nivel llamará a esta función y le dirá cuántos segundos tiene de vida
func animar_ciclo(tiempo_de_vida: float) -> void:
	if anim_tween: anim_tween.kill() # Matamos animaciones viejas
	
	sprite.frame = 0 # Arrancamos chiquitos
	anim_tween = create_tween()
	
	_mojar() # Por si venía de secarse en el turno anterior
	
	# Calculamos los tiempos
	var tiempo_crecer = 1.0
	var tiempo_achicar = 0.8
	var tiempo_desaparecer = 0.25
	var tiempo_espera = tiempo_de_vida - tiempo_crecer - tiempo_achicar - tiempo_desaparecer
	
	# Por seguridad, si el tiempo es muy corto, no esperamos nada
	if tiempo_espera < 0: tiempo_espera = 0.1 
	
	# 1. Crecer (Pasa del frame 0 al 3 en 1 segundo)
	anim_tween.tween_property(sprite, "frame", 3, tiempo_crecer)
	
	# 2. Quedarse grande (Pausa la animación)
	anim_tween.tween_interval(tiempo_espera)
	
	# 3. Encogerse antes de desaparecer (Pasa del 3 al 0)
	anim_tween.tween_property(sprite, "frame", 0, tiempo_achicar)
	
	# 4. NUEVO: Termina de secarse del todo (antes quedaba un charquito chiquito un rato largo)
	anim_tween.tween_property(sprite, "modulate:a", 0.0, tiempo_desaparecer)
	anim_tween.tween_callback(_secar)

# Cambia cuánto le queda al charco SIN reiniciar su animación (se queda grande y se seca a tiempo).
# Lo usa el nivel al arrancar el primer turno, porque los primeros charcos aparecen
# antes de la entrada del jugador y si no se secaban unos segundos antes de la primera mezcla.
func ajustar_vida(tiempo_restante: float) -> void:
	if not sprite.visible: return
	if anim_tween: anim_tween.kill()
	anim_tween = create_tween()
	var tiempo_achicar = 0.8
	var tiempo_desaparecer = 0.25
	var tiempo_crecer = 0.0
	if sprite.frame < 3:
		tiempo_crecer = 0.3
		anim_tween.tween_property(sprite, "frame", 3, tiempo_crecer)
	anim_tween.tween_interval(maxf(0.1, tiempo_restante - tiempo_crecer - tiempo_achicar - tiempo_desaparecer))
	anim_tween.tween_property(sprite, "frame", 0, tiempo_achicar)
	anim_tween.tween_property(sprite, "modulate:a", 0.0, tiempo_desaparecer)
	anim_tween.tween_callback(_secar)

# El charco ya no está: no se ve y no hace resbalar
func _secar() -> void:
	sprite.hide()
	set_deferred("monitoring", false)
	for body in get_overlapping_bodies():
		if body is Player:
			body.set_slippery(false)

# El charco vuelve a aparecer: se ve y hace resbalar de nuevo
func _mojar() -> void:
	sprite.modulate.a = 1.0
	sprite.show()
	set_deferred("monitoring", true)
