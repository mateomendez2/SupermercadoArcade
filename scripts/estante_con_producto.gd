extends Area2D
class_name Interactable

# Aquí es donde pondremos el archivo "apple.tres"
@export var item_content: ItemData 

# Variable para saber si ya agarramos la manzana
var is_empty: bool = false 

# Esto busca el nodo que tiene el dibujo de la manzana
@onready var item_visual: Sprite2D = $ItemVisual
# BUGFIX: Guardamos la altura original y la animación del "pop" para poder cortarla
@onready var item_pos_y_original: float = item_visual.position.y
var pop_tween: Tween

# --- VARIABLES DEL RELOJ Y CASTIGO ---
@export var tiempo_castigo: float = 8.0 # Segundos totales que durará el bloqueo
var fallos: int = 0
var is_locked: bool = false # Para saber si está bloqueada

@onready var cooldown_clock: Sprite2D = $CooldownClock

# NUEVAS VARIABLES PARA LA ANIMACIÓN
@onready var reloj_pos_y_original: float = cooldown_clock.position.y
var reloj_tween: Tween

var minijuego_guardado: String = "" # Puede ser "barrita", "colores" o ""

# --- TIC-TAC DEL RELOJ ---
# Mientras la góndola está bloqueada, si el jugador está parado en su zona se escucha el reloj
const RUTA_TIC: String = "res://assets/audio/RelojTic.wav"
const RUTA_TAC: String = "res://assets/audio/RelojTac.wav"
var sonido_tic: AudioStream
var sonido_tac: AudioStream
const TIEMPO_TIC: float = 0.5   # Medio segundo entre "tic" y "tac"
const VOLUMEN_TIC: float = -10.0
var sonido_reloj: AudioStreamPlayer

# --- BRUMA EN LA ZONA DE AGARRAR ---
# Una bruma del color del producto sale del cuadrado de adelante, donde hay que pararse para agarrarlo.
# Solo se ve mientras el producto está disponible (no si ya lo agarraste o si está el reloj).
@export var color_bruma: Color = Color(0, 0, 0, 0) # Transparente = automático (se saca del dibujo del producto)
const CUADRADO_PISO: float = 16.0 # Los cuadraditos del piso: la bruma ocupa uno hacia abajo
const ALCANCE_JUGADOR: float = 12.0 # Mitad del alto del área con la que el jugador detecta (para estirar la zona)
static var textura_bruma: ImageTexture # Una sola para todas las góndolas
var bruma: CPUParticles2D
# La bruma aparece recién cuando el jugador está cerca (no apenas se ve en pantalla)
const DISTANCIA_BRUMA: float = 80.0 # En pixeles (32 = una baldosa). Más grande = aparece desde más lejos
var jugador_cerca: bool = false
var espera_chequeo: float = 0.0

func _ready() -> void:
	# Nos suscribimos a la señal del GameManager para saber cuándo se le cae algo al jugador
	GameManager.item_dropped.connect(_on_item_devuelto)
	sonido_tic = load(RUTA_TIC)
	sonido_tac = load(RUTA_TAC)
	sonido_reloj = AudioStreamPlayer.new()
	sonido_reloj.volume_db = VOLUMEN_TIC
	add_child(sonido_reloj)
	_crear_bruma()

func interact() -> ItemData:
	# NUEVO: Si está bloqueada, no hacemos nada y rechazamos la interacción
	if is_locked:
		print("Góndola: Espera a que termine el castigo.")
		return null
		
	if not is_empty and item_content != null:
		GameManager.request_qte(self) 
	else:
		print("Góndola: Ya te llevaste esto, está vacío.")
		
	return null

# Esta función SOLO se llama si el GameManager dice que ganaste el QTE
func succesful_interaction() -> void:
	minijuego_guardado = "" 
	is_empty = true 
	_actualizar_bruma()
	
	# --- ¡CAMBIO DE ORDEN! ---
	# Le avisamos al GameManager AL INSTANTE. 
	# Esto dispara la animación del Jugador, el sonido y tacha la libreta.
	print("Góndola: Toma tu ", item_content.item_name)
	GameManager.add_item(item_content)
	# -------------------------
	
	# Y MIENTRAS TANTO, la fruta hace su propio show:
	var pos_original_y = item_pos_y_original
	if pop_tween: pop_tween.kill()
	pop_tween = create_tween()
	
	pop_tween.set_parallel(true)
	pop_tween.tween_property(item_visual, "position:y", pos_original_y - 30.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(item_visual, "scale", Vector2(1.5, 1.5), 0.3)
	
	pop_tween.chain() 
	pop_tween.tween_interval(0.4) 
	
	pop_tween.set_parallel(true) 
	pop_tween.tween_property(item_visual, "position:y", pos_original_y - 15.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	pop_tween.tween_property(item_visual, "modulate:a", 0.0, 0.3)
	
	await pop_tween.finished
	item_visual.hide()
	item_visual.position.y = pos_original_y
	# BUGFIX: Acá había un segundo GameManager.add_item() que te devolvía el ítem
	# si un NPC te lo sacaba durante esta animación. Se borró.

# El GameManager llamará a esta función si pierdes TODO el minijuego
func failed_interaction() -> void:
	# Como el minijuego ya contó los 5 fallos adentro suyo, 
	# si llegamos acá significa que se agotaron las oportunidades.
	# ¡Bloqueamos directamente!
	print("Góndola: Agotaste los intentos. ¡Bloqueando!")
	iniciar_cooldown()

# La rutina que bloquea y anima el reloj
func iniciar_cooldown() -> void:
	is_locked = true
	_actualizar_bruma()
	cooldown_clock.show()
	
	# --- EFECTO VISUAL: SUBIR Y BAJAR (FLOTAR) ---
	reloj_tween = create_tween().set_loops() # Bucle infinito
	
	# Sube 6 píxeles usando una curva matemática suave (SINE)
	reloj_tween.tween_property(cooldown_clock, "position:y", reloj_pos_y_original - 6.0, 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
	# Baja a la posición original suavemente
	reloj_tween.tween_property(cooldown_clock, "position:y", reloj_pos_y_original, 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# ---------------------------------------------
	
	_tic_tac() # Arranca el sonido del reloj (solo suena si el jugador está cerca)

	var tiempo_por_frame = tiempo_castigo / float(cooldown_clock.hframes)
	
	for i in range(cooldown_clock.hframes):
		cooldown_clock.frame = i 
		await get_tree().create_timer(tiempo_por_frame).timeout 
		
	# --- LIMPIEZA AL TERMINAR EL CASTIGO ---
	if reloj_tween:
		reloj_tween.kill() # Destruimos la animación de flotar
		
	cooldown_clock.position.y = reloj_pos_y_original # Lo devolvemos a su lugar exacto por si quedó a la mitad
	cooldown_clock.hide()
	cooldown_clock.frame = 0 
	fallos = 0 
	is_locked = false
	_actualizar_bruma()
	print("Góndola: ¡Desbloqueada!")

# Cuando el jugador se aleja de la góndola
func _on_area_exited(area: Area2D) -> void:
	
	# NUEVO GUARDIA: ¿El dueño de esta área es el Jugador?
	if area.get_parent() is Player:
		
		# Si era el jugador, verificamos si estábamos jugando
		if GameManager.gondola_actual == self:
			print("🏃 Góndola: Cerrando por ALEJAMIENTO DEL JUGADOR.")
			GameManager.cancelar_qte()

# Cuando el jugador pierde un ítem por un choque
func _on_item_devuelto(item_perdido: ItemData) -> void:
	# Si esta góndola está vacía, Y su contenido es igual al que el jugador perdió...
	if is_empty and item_content == item_perdido:
		# ¡Magia! Se vuelve a llenar
		is_empty = false

		# BUGFIX: Si la animación del "pop" seguía corriendo, la cortamos
		# (si no, al terminar escondía la fruta y la góndola quedaba "llena pero invisible")
		if pop_tween and pop_tween.is_valid():
			pop_tween.kill()

		item_visual.show()

		# IMPORTANTE: Restauramos el color original por si quedó transparente de la vez que lo agarramos
		item_visual.modulate.a = 1.0
		item_visual.scale = Vector2(1.0, 1.0)
		item_visual.position.y = item_pos_y_original
		_actualizar_bruma()
		
		print("Góndola: He recuperado mi ", item_content.item_name)

# Mientras dure el bloqueo, cada medio segundo suena "tic" o "tac" si el jugador está en la zona
func _tic_tac() -> void:
	var agudo := true
	while is_locked:
		if _jugador_cerca():
			sonido_reloj.stream = sonido_tic if agudo else sonido_tac
			sonido_reloj.play()
		agudo = not agudo
		await get_tree().create_timer(TIEMPO_TIC, false).timeout

func _jugador_cerca() -> bool:
	for area in get_overlapping_areas():
		if area.get_parent() is Player:
			return true
	return false

# =====================================================================
# BRUMA
# =====================================================================
func _crear_bruma() -> void:
	var zona: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if zona == null or not zona.shape is RectangleShape2D: return
	var forma: RectangleShape2D = zona.shape
	var arriba: float = zona.position.y - forma.size.y / 2.0
	var abajo: float = zona.position.y + forma.size.y / 2.0
	# La bruma baja hasta la línea de cuadraditos del piso que sigue (un cuadradito hacia abajo)
	var arriba_global: float = global_position.y + arriba
	var linea: float = ceilf((arriba_global + CUADRADO_PISO / 2.0) / CUADRADO_PISO) * CUADRADO_PISO
	var abajo_bruma: float = linea - global_position.y
	# Estiramos un poco la zona hacia abajo (copia propia, no toca la de las otras góndolas):
	# así, parado en cualquier parte de la bruma, el jugador puede agarrar
	var extra: float = maxf(0.0, (abajo_bruma - ALCANCE_JUGADOR) - abajo)
	if extra > 0.0:
		var nueva: RectangleShape2D = forma.duplicate()
		nueva.size.y += extra
		zona.shape = nueva
		zona.position.y += extra / 2.0

	var alto_bruma: float = abajo_bruma - arriba
	bruma = CPUParticles2D.new()
	bruma.name = "Bruma"
	bruma.z_index = 1 # Por encima del jugador: si estás parado ahí, quedás "adentro" de la bruma
	bruma.position = Vector2(zona.position.x, arriba + alto_bruma / 2.0)
	bruma.texture = _textura_bruma()
	bruma.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bruma.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	bruma.emission_rect_extents = Vector2(forma.size.x / 2.0, alto_bruma / 2.0)
	bruma.amount = int(clampf(forma.size.x * alto_bruma / 45.0, 10, 40))
	bruma.lifetime = 1.8
	bruma.preprocess = 2.0
	bruma.direction = Vector2(0, -1)
	bruma.spread = 25.0
	bruma.gravity = Vector2.ZERO
	bruma.initial_velocity_min = 2.0
	bruma.initial_velocity_max = 5.0
	bruma.scale_amount_min = 0.9
	bruma.scale_amount_max = 1.4
	var tono: Color = color_bruma if color_bruma.a > 0.0 else _color_del_producto()
	var rampa = Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	rampa.colors = PackedColorArray([Color(tono, 0.0), Color(tono, 0.9), Color(tono.lightened(0.3), 0.0)])
	bruma.color_ramp = rampa
	add_child(bruma)
	_actualizar_bruma()

# Prendida solo si el producto se puede agarrar y el jugador está cerca
func _actualizar_bruma() -> void:
	if bruma:
		bruma.emitting = jugador_cerca and not is_empty and not is_locked and item_content != null

# Cada un ratito nos fijamos si el jugador se acercó o se alejó
func _process(delta: float) -> void:
	if bruma == null: return
	espera_chequeo -= delta
	if espera_chequeo > 0.0: return
	espera_chequeo = 0.15
	var jugador = get_tree().get_first_node_in_group("Player")
	var cerca: bool = jugador != null and jugador.global_position.distance_to(bruma.global_position) < DISTANCIA_BRUMA
	if cerca != jugador_cerca:
		jugador_cerca = cerca
		_actualizar_bruma()

# El color de la bruma sale del dibujo del producto: el promedio de sus colores más vivos, aclarado
func _color_del_producto() -> Color:
	var defecto = Color(0.75, 0.9, 1.0)
	if item_content == null or item_content.icon == null: return defecto
	var img: Image = item_content.icon.get_image()
	if img == null: return defecto
	if img.is_compressed(): img.decompress()
	var suma = Vector3.ZERO
	var peso_total = 0.0
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a < 0.5: continue
			var peso = c.s * c.v + 0.02 # Pesan más los colores vivos (no el borde negro ni lo gris)
			suma += Vector3(c.r, c.g, c.b) * peso
			peso_total += peso
	if peso_total <= 0.0: return defecto
	var promedio = Color(suma.x / peso_total, suma.y / peso_total, suma.z / peso_total)
	# Bien vivo y clarito, para que se vea sobre el piso
	return Color.from_hsv(promedio.h, clampf(promedio.s, 0.45, 0.75), 1.0)

# Una mancha redonda suave (se arma una sola vez)
static func _textura_bruma() -> ImageTexture:
	if textura_bruma: return textura_bruma
	var tam = 18
	var img = Image.create(tam, tam, false, Image.FORMAT_RGBA8)
	var centro = (tam - 1) / 2.0
	for y in tam:
		for x in tam:
			var d = Vector2(x - centro, y - centro).length() / (tam / 2.0)
			var a = clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	textura_bruma = ImageTexture.create_from_image(img)
	return textura_bruma
