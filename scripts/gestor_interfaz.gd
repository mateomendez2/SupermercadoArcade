extends TextureRect
## Este script maneja la interfaz: la franja de arriba, el cartel "NIVEL X",
## los minijuegos y la pantalla de resultados.
## (Está puesto en el nodo "Libreta" de juego.tscn; la libreta vieja ahora queda invisible)
## Es la MISMA interfaz para los dos modos: juego_coop.tscn hereda de juego.tscn y le suma
## la pantalla dividida (nodo "PantallaDividida"). Si ese nodo está, se juegan los niveles del modo 2 jugadores.

@onready var lista_visual: GridContainer = $ListaVisual
@onready var pantalla_resultados: ColorRect = %PantallaResultados
@onready var titulo_resultado: Label = %TituloResultado
@onready var boton_siguiente: Button = %BotonSiguiente
@onready var boton_niveles: Button = %BotonNiveles
@onready var boton_menu: Button = %BotonMenu
@onready var reloj_visual: Label = %RelojVisual
@onready var libreta: TextureRect = %Libreta

# NUEVO: La franja arcade de arriba (NIVEL, TIEMPO con bloques, LISTA con ticket)
const HudFranja = preload("res://scripts/hud_franja.gd")
var hud: HudFranja

# NUEVO (modo 2 jugadores): la pantalla partida al medio. Si no está, es el modo de un jugador.
@onready var pantalla_dividida: Node = get_node_or_null("%PantallaDividida")
var es_cooperativo: bool = false
const RUTA_SELECCION_NIVELES_COOP: String = "res://scenes/ui/seleccion_niveles_coop.tscn"

func _ready() -> void:
	es_cooperativo = pantalla_dividida != null
	# NUEVO: Arrancamos en el nivel que se eligió en la pantalla de niveles
	nivel_actual = clampi(_nivel_elegido(), 0, _rutas().size() - 1)
	
	# NUEVO: Los botones de la pantalla de resultados se recorren con el joystick
	for boton in [boton_siguiente, boton_niveles, boton_menu]:
		boton.gui_input.connect(_mover_entre_botones)
		_pintar_boton(boton) # Amarillo con letra y borde naranja
	boton_siguiente.get_parent().add_theme_constant_override("separation", 10)
	_crear_titulo_dibujado() # NUEVO: el título de ganar/perder con letras de colores
	_subir_pantalla_resultados.call_deferred() # NUEVO: más oscura y por encima de la franja de arriba (diferido: el padre todavía se está armando)
	_crear_fundido() # NUEVO: para el fundido a negro al salir de la pantalla de resultados
	_crear_sonidos_botones() # NUEVO: los mismos sonidos que en las pantallas de niveles y personajes
	
	# NUEVO: La libreta y el reloj viejos se esconden: ahora todo eso está en la franja
	libreta.texture = null
	lista_visual.hide()
	reloj_visual.hide()
	
	# NUEVO: Armamos la franja de arriba
	hud = HudFranja.new()
	hud.ticket_al_medio = es_cooperativo # En el modo 2 jugadores, el ticket va en el medio
	add_child(hud)
	
	# NUEVO: Armamos la pantalla negra con el cartel "NIVEL X"
	_crear_cartel_nivel()

	# NUEVO: Música de fondo (se repite sola mientras dure el juego)
	_poner_musica()
	
	# 1. Nos suscribimos a todas las señales
	GameManager.list_generated.connect(_on_lista_generada)
	GameManager.game_over_reached.connect(_on_game_over)
	GameManager.game_won.connect(_on_victoria)
	
	GameManager.start_qte_ui.connect(%QTE_Minigame.start_qte)
	%QTE_Minigame.qte_finished.connect(GameManager.resolve_qte)
	
	GameManager.start_qte_colores.connect(%QTE_Colores.start_qte)
	%QTE_Colores.qte_finished.connect(GameManager.resolve_qte)
	
	GameManager.start_qte_mashing.connect(%QTE_Mashing.start_qte)
	%QTE_Mashing.qte_finished.connect(GameManager.resolve_qte)
	
	# Le decimos que también se esconda si el jugador huye del cajón
	GameManager.qte_cancelled.connect(%QTE_Mashing.hide)
	GameManager.qte_cancelled.connect(func(): %QTE_Mashing.is_active = false)
	
	# NUEVO: el minijuego de los círculos que caen
	GameManager.start_qte_caida.connect(%QTE_Caida.start_qte)
	%QTE_Caida.qte_finished.connect(GameManager.resolve_qte)
	GameManager.qte_cancelled.connect(%QTE_Caida.hide)
	GameManager.qte_cancelled.connect(func(): %QTE_Caida.is_active = false)
	
	# NUEVO: el minijuego del truco del color (apretar el color de la tinta)
	GameManager.start_qte_tinta.connect(%QTE_Tinta.start_qte)
	%QTE_Tinta.qte_finished.connect(GameManager.resolve_qte)
	GameManager.qte_cancelled.connect(%QTE_Tinta.hide)
	GameManager.qte_cancelled.connect(func(): %QTE_Tinta.is_active = false)
	
	GameManager.qte_cancelled.connect(%QTE_Minigame.hide)
	GameManager.qte_cancelled.connect(func(): %QTE_Minigame.is_active = false)
	
	GameManager.qte_cancelled.connect(%QTE_Colores.hide)
	GameManager.qte_cancelled.connect(func(): %QTE_Colores.is_active = false)
	
	# NUEVO: Cargamos el nivel elegido. Al entrar, el nivel arma su lista
	# y eso dispara _on_lista_generada (cartel "NIVEL X", ticket, etc.)
	_cargar_nivel()

	# NUEVO (modo 2 jugadores): un juego de minijuegos para cada mitad de la pantalla
	if es_cooperativo:
		_armar_minijuegos_por_jugador.call_deferred() # (diferido: la interfaz todavía se está armando)

# --- CADA VEZ QUE EMPIEZA UN NIVEL ---
# (La franja se encarga sola de dibujar la lista en el ticket)
func _on_lista_generada(_target_list: Array[ItemData]) -> void:
	# Pantalla negra con "NIVEL X". El primero de la lista es el 0, así que sumamos 1.
	mostrar_cartel_nivel(nivel_actual + 1)
	hud.poner_nivel(nivel_actual + 1)
	_secuencia_de_entrada()

# La presentación completa del nivel, paso por paso:
# cartel "NIVEL X" -> sale el ticket impreso -> medio seg -> entra el jugador -> arranca el reloj
const TIEMPO_LECTURA_LISTA: float = 0.5 # Medio segundo y entra el jugador (la lista se lee mientras camina)
var numero_de_entrada: int = 0 # Para cortar una presentación vieja si arranca otra

func _secuencia_de_entrada() -> void:
	numero_de_entrada += 1
	var mi_entrada = numero_de_entrada
	
	# PASO 1: Esperamos a que el cartel se disuelva
	await get_tree().create_timer(CARTEL_TIEMPO_NEGRO + CARTEL_TIEMPO_DISOLVER).timeout
	if mi_entrada != numero_de_entrada: return
	
	# PASO 2: El ticket sale de la franja como de una impresora
	await hud.imprimir_ticket()
	if mi_entrada != numero_de_entrada: return
	
	# PASO 3: Tiempo para leer qué hay que juntar
	await get_tree().create_timer(TIEMPO_LECTURA_LISTA).timeout
	if mi_entrada != numero_de_entrada: return
	
	# PASO 4: Le avisamos al nivel que haga entrar al jugador
	#         (el reloj arranca cuando el jugador termina de entrar)
	_avisar_fin_cartel()

func mostrar_resultados(mensaje: String, gano: bool) -> void:
	get_tree().paused = true
	titulo_resultado.text = mensaje

	# BUGFIX: Recordamos si ganó o perdió, y el botón cambia de texto según eso
	ultimo_resultado_gano = gano
	# NUEVO: el título en letras de colores (verde si ganaste, rojo si perdiste)
	var ruta_titulo: String = RUTA_TITULO_GANASTE if gano else RUTA_TITULO_PERDISTE
	if ResourceLoader.exists(ruta_titulo):
		titulo_dibujado.texture = load(ruta_titulo)
		titulo_dibujado.show()
		titulo_resultado.hide()
	else:
		titulo_dibujado.hide()
		titulo_resultado.show()
	if gano:
		_poner_letras(boton_siguiente, "SIGUIENTE NIVEL")
	else:
		_poner_letras(boton_siguiente, "REINTENTAR")

	# NUEVO: Si ganó el último nivel, no hay "siguiente": queda elegir otro nivel o volver al menú
	var era_el_ultimo = gano and nivel_actual >= _rutas().size() - 1
	boton_siguiente.visible = not era_el_ultimo

	pantalla_resultados.show()
	if era_el_ultimo:
		boton_niveles.grab_focus()
	else:
		boton_siguiente.grab_focus()

# NUEVO: Botones amarillos con letra y borde naranja (igual que "VOLVER AL MENÚ" de la pantalla de niveles)
const BOTON_AMARILLO: Color = Color8(255, 214, 40)
const BOTON_AMARILLO_APRETADO: Color = Color8(230, 170, 20)
const BOTON_BORDE: Color = Color8(232, 96, 8)
const BOTON_LETRA: Color = Color8(214, 78, 6)
const BOTON_ILUMINADO: Color = Color(1.18, 1.18, 1.18) # Cuánto se ilumina el botón elegido

const BOTON_ANCHO: float = 330.0  # Tamaño de los botones (como las tarjetas de la pantalla de niveles)
const BOTON_ALTO: float = 40.0
const BOTON_TAMANO_LETRA: int = 32
const BOTON_BOTE: float = 2.0     # Cuántos pixeles sube y baja el botón elegido
const BOTON_REDONDEO: int = 10    # Qué tan redondeadas son las esquinas (más grande = más redondo)

func _pintar_boton(boton: Button) -> void:
	# Mismo estilo que las tarjetas de la pantalla de niveles: esquinas redondeadas
	# y una "base" más gruesa abajo, para que parezca un botón de verdad
	var normal = StyleBoxFlat.new()
	normal.bg_color = BOTON_AMARILLO
	normal.set_border_width_all(2)
	normal.border_width_bottom = 5
	normal.border_color = BOTON_BORDE
	normal.set_corner_radius_all(BOTON_REDONDEO)
	normal.anti_aliasing = false
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 0
	normal.content_margin_bottom = 4
	# Apretado: se hunde (la base se achica y la letra baja un poquito)
	var apretado = normal.duplicate()
	apretado.bg_color = BOTON_AMARILLO_APRETADO
	apretado.border_width_bottom = 3
	apretado.content_margin_top = 2
	apretado.content_margin_bottom = 2
	# El elegido no lleva borde extra: se ilumina y flota un poquito (ver abajo)
	var foco = StyleBoxEmpty.new()
	boton.add_theme_stylebox_override("normal", normal)
	boton.add_theme_stylebox_override("hover", normal)
	boton.add_theme_stylebox_override("pressed", apretado)
	boton.add_theme_stylebox_override("hover_pressed", apretado)
	boton.add_theme_stylebox_override("focus", foco)
	for clave in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		boton.add_theme_color_override(clave, BOTON_LETRA)
	boton.add_theme_font_size_override("font_size", BOTON_TAMANO_LETRA)
	boton.custom_minimum_size = Vector2(BOTON_ANCHO, BOTON_ALTO)
	_poner_letras(boton, boton.text) # Letras dibujadas (las mismas del botón "VOLVER" de las pantallas del menú)
	boton.focus_entered.connect(_boton_elegido.bind(boton))
	boton.focus_exited.connect(_boton_soltado.bind(boton))

# NUEVO: el texto de cada botón es un dibujo (letras naranjas gruesas, como "VOLVER").
# Si un texto no tiene dibujo, se deja el texto común.
const LETRAS_BOTONES: Dictionary = {
	"SIGUIENTE NIVEL": "res://assets/ui/titulos/siguiente_nivel.png",
	"REINTENTAR": "res://assets/ui/titulos/reintentar.png",
	"SELECCIÓN DE NIVELES": "res://assets/ui/titulos/seleccion_de_niveles.png",
	"VOLVER AL MENÚ": "res://assets/ui/titulos/volver_al_menu.png",
}
func _poner_letras(boton: Button, texto: String) -> void:
	var letras: TextureRect = boton.get_node_or_null("Letras")
	if not LETRAS_BOTONES.has(texto) or not ResourceLoader.exists(LETRAS_BOTONES[texto]):
		boton.text = texto
		if letras: letras.hide()
		return
	boton.text = ""
	if letras == null:
		letras = TextureRect.new()
		letras.name = "Letras"
		letras.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boton.add_child(letras)
	letras.texture = load(LETRAS_BOTONES[texto])
	letras.show()
	var tam: Vector2 = letras.texture.get_size()
	letras.set_anchors_preset(Control.PRESET_CENTER)
	letras.offset_left = -floor(tam.x / 2.0)
	letras.offset_top = -floor(tam.y / 2.0) - 1 # Centrado en la parte amarilla (la base de abajo es más gruesa que el borde de arriba)
	letras.offset_right = letras.offset_left + tam.x
	letras.offset_bottom = letras.offset_top + tam.y

# Al quedar elegido se ilumina y sube y baja de a un pixel (como las tarjetas de niveles)
func _boton_elegido(boton: Button) -> void:
	boton.modulate = BOTON_ILUMINADO
	_frenar_bote(boton)
	# Esperamos a que la caja de botones los acomode (si no, tomaríamos una altura vieja)
	await get_tree().process_frame
	if not boton.has_focus(): return
	_frenar_bote(boton)
	var y_base: float = boton.position.y
	boton.set_meta("y_base", y_base)
	var bote = boton.create_tween().set_loops()
	bote.tween_method(func(v: float): boton.position.y = y_base - round(v), 0.0, BOTON_BOTE, 0.35)
	bote.tween_method(func(v: float): boton.position.y = y_base - round(v), BOTON_BOTE, 0.0, 0.35)
	boton.set_meta("bote", bote)

func _boton_soltado(boton: Button) -> void:
	boton.modulate = Color.WHITE
	_frenar_bote(boton)

func _frenar_bote(boton: Button) -> void:
	if boton.has_meta("bote"):
		var bote: Tween = boton.get_meta("bote")
		if bote and bote.is_valid(): bote.kill()
		boton.remove_meta("bote")
	if boton.has_meta("y_base"):
		boton.position.y = boton.get_meta("y_base")

# --- FONDO DE LA PANTALLA DE GANAR / PERDER ---
# Más oscuro que el de los minijuegos, y tapa también la franja de arriba (la franja está en la capa 5)
const COLOR_FONDO_RESULTADOS: Color = Color(0.02, 0.0, 0.04, 0.88)
const CAPA_RESULTADOS: int = 6 # Arriba de la franja (5), abajo del cartel "NIVEL X" (10) y del fundido (11)

func _subir_pantalla_resultados() -> void:
	var capa = CanvasLayer.new()
	capa.layer = CAPA_RESULTADOS
	add_child(capa)
	pantalla_resultados.reparent(capa, false)
	pantalla_resultados.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pantalla_resultados.color = COLOR_FONDO_RESULTADOS

# --- TÍTULO DE GANAR / PERDER (dibujado, como los carteles "NIVEL X") ---
const RUTA_TITULO_GANASTE: String = "res://assets/ui/titulo_ganaste.png"
const RUTA_TITULO_PERDISTE: String = "res://assets/ui/titulo_perdiste.png"
var titulo_dibujado: TextureRect

func _crear_titulo_dibujado() -> void:
	titulo_dibujado = TextureRect.new()
	titulo_dibujado.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	titulo_dibujado.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	titulo_dibujado.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caja: Control = titulo_resultado.get_parent()
	caja.add_child(titulo_dibujado)
	caja.move_child(titulo_dibujado, titulo_resultado.get_index())
	# El texto viejo queda centrado por si falta el dibujo
	titulo_resultado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Los botones no se estiran si el título es más ancho: quedan centrados
	for boton in [boton_siguiente, boton_niveles, boton_menu]:
		boton.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

# --- FUNDIDO A NEGRO al salir de la pantalla de resultados ---
const TIEMPO_FUNDIDO: float = 0.35
var fundido: ColorRect
var fundiendo: bool = false

func _crear_fundido() -> void:
	var capa = CanvasLayer.new()
	capa.layer = 11 # Por encima de todo, hasta del cartel "NIVEL X"
	capa.process_mode = Node.PROCESS_MODE_ALWAYS # Anda aunque el juego esté en pausa
	add_child(capa)
	fundido = ColorRect.new()
	fundido.color = Color(0, 0, 0, 0)
	fundido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(fundido)
	fundido.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

# Oscurece la pantalla, hace lo que se pidió y (si seguimos en el juego) vuelve a aclarar
func _fundir_y(accion: Callable) -> void:
	if fundiendo: return
	fundiendo = true
	_tocar_sonido_boton(SONIDO_ELEGIR) # Se eligió un botón
	var t = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(fundido, "color:a", 1.0, TIEMPO_FUNDIDO)
	await t.finished
	accion.call()
	if not is_inside_tree(): return # Se cambió de escena
	# El nivel nuevo arranca con su cartel "NIVEL X" en negro, así que sacamos el fundido de golpe
	await get_tree().process_frame
	fundido.color.a = 0.0
	fundiendo = false

# NUEVO: Arriba/abajo con el joystick (o WASD) para pasar de un botón a otro
func _mover_entre_botones(event: InputEvent) -> void:
	# Modo 2 jugadores: cada uno también aprieta el botón elegido con sus teclas (el J1 con C/V/B)
	# (las que ya son de "aceptar", como J/K/L o los botones del mando, las maneja el botón solo)
	if es_cooperativo and not event.is_action_pressed("ui_accept"):
		for p in ["p1_", "p2_"]:
			if InputMap.has_action(p + "interact") and event.is_action_pressed(p + "interact"):
				var elegido = get_viewport().gui_get_focus_owner()
				if elegido is Button and elegido.visible:
					get_viewport().set_input_as_handled()
					elegido.pressed.emit()
				return
	var paso = 0
	if event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"): paso = -1
	elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"): paso = 1
	if paso == 0: return
	get_viewport().set_input_as_handled()
	var botones = [boton_siguiente, boton_niveles, boton_menu].filter(func(b): return b.visible)
	var actual = botones.find(get_viewport().gui_get_focus_owner())
	var nuevo: int = clampi(actual + paso, 0, botones.size() - 1)
	if nuevo != actual: _tocar_sonido_boton(SONIDO_MOVER) # Mismo sonido que en las pantallas de niveles y personajes
	botones[nuevo].grab_focus()

# --- SONIDOS DE LOS BOTONES DE GANASTE / PERDISTE ---
var SONIDO_MOVER: AudioStream = load("res://assets/audio/MenuMover.wav")
var SONIDO_ELEGIR: AudioStream = load("res://assets/audio/MenuElegir.wav")
var sonido_botones: AudioStreamPlayer

func _crear_sonidos_botones() -> void:
	sonido_botones = AudioStreamPlayer.new()
	sonido_botones.process_mode = Node.PROCESS_MODE_ALWAYS # El juego está en pausa en esa pantalla
	add_child(sonido_botones)

func _tocar_sonido_boton(sonido: AudioStream) -> void:
	sonido_botones.stream = sonido
	sonido_botones.play()

# Arranca en 0, que es el primer nivel de la lista
var nivel_actual: int = 0
var ultimo_resultado_gano: bool = false

# NUEVO: La lista de niveles ahora está en GameManager (gestor_juego.gd -> RUTAS_NIVELES),
# porque también la usa la pantalla de selección de niveles. Para agregar un nivel, sumalo ahí.
const RUTA_SELECCION_NIVELES: String = "res://scenes/ui/seleccion_niveles.tscn"

func _on_boton_siguiente_pressed() -> void:
	_fundir_y(_siguiente_nivel)

func _siguiente_nivel() -> void:
	get_tree().paused = false
	pantalla_resultados.hide()

	# BUGFIX: Solo avanzamos de nivel si GANAMOS. Si perdimos, repetimos el mismo.
	if ultimo_resultado_gano:
		nivel_actual += 1 # Suma 1. Así que del 0 pasará al 1.

	if nivel_actual < _rutas().size():
		_guardar_nivel_elegido(nivel_actual)
		# Si es un reintento, lo ponemos exactamente donde estaba el anterior
		_cargar_nivel(not ultimo_resultado_gano)
		_musica_del_nivel() # Cada nivel con su canción
	else:
		print("¡JUEGO COMPLETADO!")
		get_tree().change_scene_to_file(_pantalla_de_niveles())

# NUEVO: Saca el nivel que esté puesto y pone el de nivel_actual
func _cargar_nivel(misma_posicion: bool = false) -> void:
	var contenedor = %ContenedorNivel
	# Guardamos la posición del nivel viejo (por si estaba corrido)
	var posicion_nivel_anterior := Vector2.ZERO
	for hijo in contenedor.get_children():
		if hijo is Node2D:
			posicion_nivel_anterior = hijo.position
		hijo.queue_free()
	var ruta = _rutas()[nivel_actual]
	if not ResourceLoader.exists(ruta):
		push_error("No existe el nivel: " + ruta)
		return
	var nuevo_nivel = load(ruta).instantiate()
	if es_cooperativo:
		# Modo 2 jugadores: el nivel va adentro de la pantalla partida (ella saca el anterior)
		pantalla_dividida.poner_nivel(nuevo_nivel, misma_posicion)
		return
	if misma_posicion:
		nuevo_nivel.position = posicion_nivel_anterior
	contenedor.add_child(nuevo_nivel)

# NUEVO: Botón "SELECCIÓN DE NIVELES" de la pantalla de resultados
func _on_boton_niveles_pressed() -> void:
	_fundir_y(_ir_a_niveles)

func _ir_a_niveles() -> void:
	get_tree().paused = false
	# La pantalla de niveles arranca parada en el que sigue (si ganó) o en este (si perdió)
	if ultimo_resultado_gano and nivel_actual + 1 < _rutas().size():
		_guardar_nivel_elegido(nivel_actual + 1)
	else:
		_guardar_nivel_elegido(nivel_actual)
	get_tree().change_scene_to_file(_pantalla_de_niveles())

# --- MINIJUEGOS EN EL MODO 2 JUGADORES ---
# Cada jugador tiene sus propios minijuegos, que se abren solo en su mitad de la pantalla
# (los mismos de siempre, con sus botones). Mientras tanto el otro se puede seguir moviendo.
const ESCENAS_MINIJUEGOS: Dictionary = {
	"barrita": "res://scenes/ui/qte_barrita.tscn",
	"colores": "res://scenes/ui/qte_colores.tscn",
	"mashing": "res://scenes/ui/qte_machaque.tscn",
	"caida": "res://scenes/ui/qte_caida.tscn",
	"tinta": "res://scenes/ui/qte_tinta.tscn",
}
const ANCHO_RAYITA_MEDIO: int = 2 # La rayita negra que separa las dos mitades
var minijuegos_coop: Dictionary = {} # "p1_" / "p2_" -> { "barrita": nodo, "colores": nodo, ... }

func _armar_minijuegos_por_jugador() -> void:
	var pantalla: Vector2 = get_viewport().get_visible_rect().size
	var ancho_mitad: float = floor((pantalla.x - ANCHO_RAYITA_MEDIO) / 2.0)
	var capa: Control = %QTE_Minigame.get_parent() # InterfazFlotante (donde están los minijuegos de siempre)
	for p in ["p1_", "p2_"]:
		var mitad = Control.new()
		mitad.name = "Minijuegos" + p.to_upper().trim_suffix("_")
		mitad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mitad.position = Vector2(0 if p == "p1_" else ancho_mitad + ANCHO_RAYITA_MEDIO, 0)
		mitad.size = Vector2(ancho_mitad, pantalla.y)
		capa.add_child(mitad)
		minijuegos_coop[p] = {}
		for tipo in ESCENAS_MINIJUEGOS:
			var mini: Control = load(ESCENAS_MINIJUEGOS[tipo]).instantiate()
			mini.prefijo = p
			mini.visible = false
			mini.set_meta("camara_sacudir", pantalla_dividida.camara_de(p))
			mitad.add_child(mini)
			mini.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			# Lo que está puesto a mano (sin anclas, ej. el texto de ayuda) se corre para quedar
			# en el mismo lugar respecto del cartel, ahora que la pantalla es la mitad de ancha
			for parte in mini.get_children():
				if parte is Control and parte.anchor_left == 0.0 and parte.anchor_right == 0.0:
					parte.position.x += round((ancho_mitad - pantalla.x) / 2.0)
			mini.qte_finished.connect(_minijuego_coop_terminado.bind(p))
			minijuegos_coop[p][tipo] = mini
	GameManager.start_qte_jugador.connect(_abrir_minijuego_coop)
	GameManager.qte_cancelado_jugador.connect(_cerrar_minijuegos_coop)
	GameManager.qte_cancelled.connect(_cerrar_todos_los_minijuegos_coop)

func _abrir_minijuego_coop(p: String, tipo: String) -> void:
	if minijuegos_coop.has(p) and minijuegos_coop[p].has(tipo):
		minijuegos_coop[p][tipo].start_qte()

func _minijuego_coop_terminado(success: bool, p: String) -> void:
	GameManager.resolve_qte_jugador(p, success)

func _cerrar_todos_los_minijuegos_coop() -> void:
	for p in minijuegos_coop:
		_cerrar_minijuegos_coop(p)

func _cerrar_minijuegos_coop(p: String) -> void:
	if not minijuegos_coop.has(p): return
	for mini in minijuegos_coop[p].values():
		mini.hide()
		mini.is_active = false

# --- LO QUE CAMBIA ENTRE EL MODO DE 1 JUGADOR Y EL DE 2 ---
func _rutas() -> Array[String]:
	return GameManager.RUTAS_NIVELES_COOP if es_cooperativo else GameManager.RUTAS_NIVELES

func _nivel_elegido() -> int:
	return GameManager.nivel_coop_elegido if es_cooperativo else GameManager.nivel_elegido

func _guardar_nivel_elegido(indice: int) -> void:
	if es_cooperativo: GameManager.nivel_coop_elegido = indice
	else: GameManager.nivel_elegido = indice

func _pantalla_de_niveles() -> String:
	return RUTA_SELECCION_NIVELES_COOP if es_cooperativo else RUTA_SELECCION_NIVELES

func _on_boton_menu_pressed() -> void:
	_fundir_y(_ir_al_menu)

func _ir_al_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/menu_principal.tscn")

func _on_victoria() -> void:
	# NUEVO: Se abre el nivel que sigue
	if es_cooperativo:
		GameManager.desbloquear_nivel_coop(nivel_actual + 1)
	else:
		GameManager.desbloquear_nivel(nivel_actual + 1)
	mostrar_resultados("¡NIVEL COMPLETADO!", true)

func _on_game_over() -> void:
	mostrar_resultados("¡SE ACABÓ EL TIEMPO!", false)

# --- MÚSICA DE FONDO ---
# Las canciones se van turnando nivel por nivel: nivel 1 la primera, nivel 2 la segunda,
# nivel 3 la tercera, nivel 4 vuelve a la primera, y así. Para sumar otra, agregala a la lista.
const RUTAS_MUSICA: Array[String] = [
	"res://assets/audio/MusicaSuper.ogg",  # Niveles 1 y 4
	"res://assets/audio/MusicaSuper2.ogg", # Nivel 2
	"res://assets/audio/MusicaSuper3.ogg", # Nivel 3
]
# NUEVO: el modo 2 jugadores (ROBO) tiene sus propias canciones, más tensas, de persecución
# (se turnan igual: nivel 1 la primera, nivel 2 la segunda, nivel 3 la tercera, y vuelve a empezar)
const RUTAS_MUSICA_COOP: Array[String] = [
	"res://assets/audio/MusicaCoop1.ogg", # "Persecución" (La menor, rápida)
	"res://assets/audio/MusicaCoop2.ogg", # "Sigilo" (Re menor, tensa)
	"res://assets/audio/MusicaCoop3.ogg", # "Huida" (Mi menor, a todo galope)
]
const VOLUMEN_MUSICA: float = -8.0 # En decibeles: más negativo = más bajito
const FUNDIDO_MUSICA: float = 0.5  # Segundos que tarda en bajar la canción vieja al cambiar de nivel
var musica: AudioStreamPlayer
var ruta_sonando: String = ""

func _poner_musica() -> void:
	GameManager.apagar_musica_menu() # Por si venía sonando la del menú
	musica = AudioStreamPlayer.new()
	musica.volume_db = VOLUMEN_MUSICA
	# Sigue sonando aunque el juego esté en pausa (pantalla de resultados)
	musica.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(musica)
	_musica_del_nivel(false)

# Pone la canción que le toca al nivel actual. Si ya está sonando esa
# (por ejemplo, al reintentar el mismo nivel), la deja seguir sin cortarla.
func _musica_del_nivel(con_fundido: bool = true) -> void:
	var lista: Array[String] = RUTAS_MUSICA_COOP if es_cooperativo else RUTAS_MUSICA
	var ruta: String = lista[nivel_actual % lista.size()]
	if ruta == ruta_sonando or not ResourceLoader.exists(ruta): return
	ruta_sonando = ruta
	if con_fundido and musica.playing:
		var bajar = musica.create_tween()
		bajar.tween_property(musica, "volume_db", -40.0, FUNDIDO_MUSICA)
		await bajar.finished
		if ruta != ruta_sonando: return # Mientras bajaba ya se pidió otra
	var cancion: AudioStream = load(ruta)
	cancion.loop = true # Al terminar vuelve a empezar, sin cortes
	musica.stream = cancion
	musica.volume_db = VOLUMEN_MUSICA
	musica.play()

# --- CARTEL "NIVEL X" CON PANTALLA NEGRA ---
const CARTEL_TIEMPO_NEGRO: float = 1.4    # Segundos con la pantalla en negro y el cartel
const CARTEL_TIEMPO_DISOLVER: float = 0.8 # Segundos que tarda en disolverse
const RUTA_CARTELES: String = "res://assets/ui/nivel_%d.png" # Los dibujos de cada nivel

var fondo_negro: ColorRect
var imagen_cartel: TextureRect
var texto_cartel: Label # Por si un nivel no tiene dibujo (ej: un nivel 4 nuevo)
var tween_cartel: Tween

func _crear_cartel_nivel() -> void:
	# Una capa propia, por encima de TODA la interfaz (franja, minijuegos)
	var capa = CanvasLayer.new()
	capa.layer = 10
	add_child(capa)
	
	fondo_negro = ColorRect.new()
	fondo_negro.color = Color.BLACK
	fondo_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(fondo_negro)
	fondo_negro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT) # Toda la pantalla
	fondo_negro.hide()
	
	# El dibujo va adentro del fondo negro, así se disuelven juntos
	imagen_cartel = TextureRect.new()
	imagen_cartel.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED # Tamaño original, centrado
	imagen_cartel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fondo_negro.add_child(imagen_cartel)
	imagen_cartel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Respaldo de texto, con los colores del reloj
	texto_cartel = Label.new()
	texto_cartel.add_theme_font_size_override("font_size", 32)
	texto_cartel.add_theme_color_override("font_color", Color(0.98, 1.0, 0.59))
	texto_cartel.add_theme_color_override("font_outline_color", Color(0.75, 0.21, 0.05))
	texto_cartel.add_theme_constant_override("outline_size", 6)
	texto_cartel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto_cartel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fondo_negro.add_child(texto_cartel)
	texto_cartel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func mostrar_cartel_nivel(numero: int) -> void:
	# 1. Elegimos qué mostrar: el dibujo si existe, si no el texto
	var contenido: Control
	var ruta = RUTA_CARTELES % numero
	if ResourceLoader.exists(ruta):
		imagen_cartel.texture = load(ruta)
		imagen_cartel.show()
		texto_cartel.hide()
		contenido = imagen_cartel
	else:
		texto_cartel.text = "NIVEL " + str(numero)
		texto_cartel.show()
		imagen_cartel.hide()
		contenido = texto_cartel
	
	# 2. Le avisamos al nivel que espere antes de hacer entrar al jugador
	#    (se libera al final de _secuencia_de_entrada)
	GameManager.mostrando_cartel = true
	
	# 3. Pantalla en negro de golpe
	if tween_cartel: tween_cartel.kill()
	fondo_negro.modulate.a = 1.0
	fondo_negro.show()
	contenido.pivot_offset = get_viewport_rect().size / 2.0 # Para que crezca desde el centro de la pantalla
	contenido.scale = Vector2(0.6, 0.6)
	
	# 4. La coreografía
	tween_cartel = create_tween()
	# El cartel aparece con un "pop"
	tween_cartel.tween_property(contenido, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Se queda quieto un rato
	tween_cartel.tween_interval(CARTEL_TIEMPO_NEGRO - 0.35)
	# Se disuelve todo (el negro y el cartel juntos)
	tween_cartel.tween_property(fondo_negro, "modulate:a", 0.0, CARTEL_TIEMPO_DISOLVER)
	tween_cartel.tween_callback(fondo_negro.hide)

# Se llama al final de toda la presentación (cartel + ticket). Libera al jugador.
func _avisar_fin_cartel() -> void:
	GameManager.mostrando_cartel = false
	GameManager.cartel_nivel_terminado.emit()
