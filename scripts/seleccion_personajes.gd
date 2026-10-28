extends Control
## PANTALLA DE ELEGIR PERSONAJE (modo 2 JUGADORES - ROBO)
## Cada jugador mueve su marco con SU palanca (J1 rojo, J2 azul) y elige con cualquier botón.
## Con el botón rojo se arrepiente y vuelve a elegir.
## No pueden elegir los dos el mismo ladrón. Cuando los dos están listos, arranca el juego.
## Los ladrones salen de GameManager.PERSONAJES_COOP (ahí se agregan o se cambian).
## Los nodos Titulo, Personajes y Ayuda se pueden mover desde el editor.

const RUTA_JUEGO_COOP: String = "res://scenes/ui/juego_coop.tscn"
const RUTA_MUSICA_MENU: String = "res://assets/audio/MusicaMenu.ogg"
const VOLUMEN_MUSICA_MENU: float = -8.0
const CARPETA_LETRAS: String = "res://assets/ui/modo/"

# --- TAMAÑOS (se pueden cambiar desde el Inspector) ---
@export var tamano_tarjeta: Vector2 = Vector2(112, 150)
@export var escala_personajes: int = 3
@export var espera_antes_de_jugar: float = 0.8 # Segundos entre que los dos están listos y que arranca

# --- COLORES ---
const COLOR_TARJETA: Color = Color8(58, 44, 96)       # Violeta oscuro
const COLOR_TARJETA_BORDE: Color = Color8(24, 16, 44)
const COLOR_J1: Color = Color8(236, 60, 56)           # Rojo del jugador 1
const COLOR_J2: Color = Color8(50, 120, 240)          # Azul del jugador 2
const GROSOR_MARCO: int = 3
const BRILLO_TARJETA: Color = Color(1.15, 1.15, 1.15)

var SONIDO_MOVER: AudioStream = load("res://assets/audio/MenuMover.wav")
var SONIDO_ELEGIR: AudioStream = load("res://assets/audio/MenuElegir.wav")
var SONIDO_NO: AudioStream = load("res://assets/audio/VidaPerdida.wav")

@onready var fila: HBoxContainer = %Personajes
@onready var fundido: ColorRect = %Fundido

var tarjetas: Array[Panel] = []
var sprites: Array[AnimatedSprite2D] = []
var marcos: Array = [[], []]      # marcos[jugador][tarjeta]: el recuadro de color de cada jugador
var carteles_j: Array = [[], []]  # carteles "J1" / "J2" arriba de cada tarjeta
var carteles_listo: Array[TextureRect] = []
var cursor: Array[int] = [0, 1]   # En qué tarjeta está cada jugador
var listo: Array[bool] = [false, false]
var arrancando: bool = false
var listo_para_tocar: bool = false
var sonido: AudioStreamPlayer
var musica: AudioStreamPlayer

func _ready() -> void:
	preload("res://scripts/controles_coop.gd").armar()
	sonido = AudioStreamPlayer.new()
	add_child(sonido)
	_poner_musica()

	for i in GameManager.PERSONAJES_COOP.size():
		var tarjeta = _crear_tarjeta(i)
		fila.add_child(tarjeta)
		tarjetas.append(tarjeta)

	# Arrancan donde quedaron la última vez (si se puede)
	for j in 2:
		if j < GameManager.personajes_coop.size():
			cursor[j] = clampi(GameManager.personajes_coop[j], 0, tarjetas.size() - 1)
	if cursor[0] == cursor[1]:
		cursor[1] = (cursor[0] + 1) % tarjetas.size()
	_actualizar()

	fundido.color.a = 1.0
	var t = create_tween()
	t.tween_property(fundido, "color:a", 0.0, 0.25)
	await get_tree().create_timer(0.2).timeout
	listo_para_tocar = true

# =====================================================================
# ARMADO DE LAS TARJETAS
# =====================================================================
func _crear_tarjeta(indice: int) -> Panel:
	var tarjeta = Panel.new()
	tarjeta.custom_minimum_size = tamano_tarjeta
	var estilo = StyleBoxFlat.new()
	estilo.bg_color = COLOR_TARJETA
	estilo.set_border_width_all(2)
	estilo.border_width_bottom = 5
	estilo.border_color = COLOR_TARJETA_BORDE
	estilo.set_corner_radius_all(4)
	estilo.anti_aliasing = false
	tarjeta.add_theme_stylebox_override("panel", estilo)

	# El ladrón
	var sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = load(GameManager.PERSONAJES_COOP[indice])
	sprite.scale = Vector2(escala_personajes, escala_personajes)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2(round(tamano_tarjeta.x / 2.0), round(tamano_tarjeta.y / 2.0 - 6))
	sprite.play("idle_down")
	sprite.frame = indice % 3
	sprite.animation_finished.connect(_festejar.bind(indice))
	tarjeta.add_child(sprite)
	sprites.append(sprite)

	# "LISTO" abajo (aparece cuando alguien lo elige)
	var cartel_listo = _letras("listo")
	cartel_listo.position = Vector2(round((tamano_tarjeta.x - cartel_listo.size.x) / 2.0), tamano_tarjeta.y - cartel_listo.size.y - 12)
	cartel_listo.visible = false
	tarjeta.add_child(cartel_listo)
	carteles_listo.append(cartel_listo)

	# Un marco y un cartelito por jugador
	for j in 2:
		var marco = Panel.new()
		marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var e = StyleBoxFlat.new()
		e.draw_center = false
		e.set_border_width_all(GROSOR_MARCO)
		e.border_color = COLOR_J1 if j == 0 else COLOR_J2
		e.set_corner_radius_all(5)
		e.anti_aliasing = false
		marco.add_theme_stylebox_override("panel", e)
		marco.visible = false
		tarjeta.add_child(marco)
		marcos[j].append(marco)
		var cartel = _letras("j1" if j == 0 else "j2")
		cartel.visible = false
		tarjeta.add_child(cartel)
		carteles_j[j].append(cartel)
	return tarjeta

func _letras(nombre: String) -> TextureRect:
	var r = TextureRect.new()
	r.texture = load(CARPETA_LETRAS + nombre + ".png")
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = r.texture.get_size()
	return r

# =====================================================================
# CONTROLES DE CADA JUGADOR
# =====================================================================
func _process(_delta: float) -> void:
	if arrancando or not listo_para_tocar: return
	for j in 2:
		var p: String = "p%d_" % (j + 1)
		if listo[j]:
			if Input.is_action_just_pressed(p + "btn_rojo"):
				_arrepentirse(j)
			continue
		if Input.is_action_just_pressed(p + "move_left"):
			_mover(j, -1)
		elif Input.is_action_just_pressed(p + "move_right"):
			_mover(j, 1)
		elif Input.is_action_just_pressed(p + "interact"):
			_elegir(j)

# Se corre para el costado, salteando el ladrón que el otro ya eligió
func _mover(j: int, paso: int) -> void:
	var otro: int = 1 - j
	var nueva: int = cursor[j]
	while true:
		nueva += paso
		if nueva < 0 or nueva >= tarjetas.size(): return # No hay más para ese lado
		if not (listo[otro] and cursor[otro] == nueva): break
	cursor[j] = nueva
	_tocar(SONIDO_MOVER)
	_actualizar()

func _elegir(j: int) -> void:
	var otro: int = 1 - j
	if listo[otro] and cursor[otro] == cursor[j]:
		_tocar(SONIDO_NO) # Ese ya lo eligió el otro
		_sacudir(tarjetas[cursor[j]])
		return
	listo[j] = true
	_tocar(SONIDO_ELEGIR)
	var sprite = sprites[cursor[j]]
	sprite.play("pickup_down")
	# Si el otro estaba parado acá sin elegir, lo corremos a uno libre
	if not listo[otro] and cursor[otro] == cursor[j]:
		_correr_a_uno_libre(otro)
	_actualizar()
	if listo[0] and listo[1]:
		_arrancar()

func _arrepentirse(j: int) -> void:
	listo[j] = false
	_tocar(SONIDO_MOVER)
	_actualizar()

func _correr_a_uno_libre(j: int) -> void:
	for distancia in range(1, tarjetas.size()):
		for paso in [1, -1]:
			var i: int = cursor[j] + paso * distancia
			if i >= 0 and i < tarjetas.size() and i != cursor[1 - j]:
				cursor[j] = i
				return

func _arrancar() -> void:
	arrancando = true
	GameManager.personajes_coop = [cursor[0], cursor[1]]
	await get_tree().create_timer(espera_antes_de_jugar).timeout
	var t = create_tween()
	t.tween_property(fundido, "color:a", 1.0, 0.35)
	if musica:
		t.parallel().tween_property(musica, "volume_db", -40.0, 0.35)
	await t.finished
	get_tree().change_scene_to_file(RUTA_JUEGO_COOP)

# =====================================================================
# DIBUJO (marcos, carteles y animaciones según cómo está cada uno)
# =====================================================================
func _actualizar() -> void:
	for i in tarjetas.size():
		var esta: Array[bool] = [cursor[0] == i, cursor[1] == i]
		var los_dos: bool = esta[0] and esta[1]
		var elegido: bool = (listo[0] and esta[0]) or (listo[1] and esta[1])
		for j in 2:
			# Marco: si están los dos en la misma tarjeta, el del J2 va un poquito más afuera
			var marco: Panel = marcos[j][i]
			marco.visible = esta[j]
			var afuera: float = GROSOR_MARCO + (GROSOR_MARCO if los_dos and j == 1 else 0)
			marco.position = Vector2(-afuera, -afuera)
			marco.size = tamano_tarjeta + Vector2(afuera, afuera) * 2.0
			# Cartelito J1 a la izquierda y J2 a la derecha, montado en el borde de arriba
			var cartel: TextureRect = carteles_j[j][i]
			cartel.visible = esta[j]
			var x: float = 6.0 if j == 0 else tamano_tarjeta.x - cartel.size.x - 6.0
			cartel.position = Vector2(x, -afuera - cartel.size.y / 2.0)
		carteles_listo[i].visible = elegido
		tarjetas[i].modulate = BRILLO_TARJETA if (esta[0] or esta[1]) else Color.WHITE
		var sprite = sprites[i]
		if not elegido and sprite.animation != &"idle_down":
			sprite.play("idle_down")
		elif elegido and sprite.animation == &"idle_down":
			sprite.play("pickup_down")

# Después de "agarrar", queda caminando en el lugar (contento) mientras siga elegido
func _festejar(i: int) -> void:
	var sigue: bool = (listo[0] and cursor[0] == i) or (listo[1] and cursor[1] == i)
	if sigue and sprites[i].animation == &"pickup_down":
		sprites[i].play("walk_down")

func _sacudir(tarjeta: Control) -> void:
	var sprite = sprites[tarjetas.find(tarjeta)]
	var x: float = round(tamano_tarjeta.x / 2.0)
	var t = create_tween()
	for dx in [-3, 3, -2, 2, 0]:
		t.tween_property(sprite, "position:x", x + dx, 0.04)

func _tocar(sonido_nuevo: AudioStream) -> void:
	sonido.stream = sonido_nuevo
	sonido.play()

func _poner_musica() -> void:
	if not ResourceLoader.exists(RUTA_MUSICA_MENU): return
	musica = AudioStreamPlayer.new()
	var cancion: AudioStream = load(RUTA_MUSICA_MENU)
	cancion.loop = true
	musica.stream = cancion
	musica.volume_db = VOLUMEN_MUSICA_MENU
	add_child(musica)
	musica.play(GameManager.posicion_musica_menu)
	GameManager.posicion_musica_menu = 0.0
