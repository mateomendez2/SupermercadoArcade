extends TextureRect
## Este script maneja la interfaz: la franja de arriba, el cartel "NIVEL X",
## los minijuegos y la pantalla de resultados.
## (Está puesto en el nodo "Libreta" de juego.tscn; la libreta vieja ahora queda invisible)

@onready var lista_visual: GridContainer = $ListaVisual
@onready var pantalla_resultados: ColorRect = %PantallaResultados
@onready var titulo_resultado: Label = %TituloResultado
@onready var boton_siguiente: Button = %BotonSiguiente
@onready var reloj_visual: Label = %RelojVisual
@onready var libreta: TextureRect = %Libreta

# NUEVO: La franja arcade de arriba (NIVEL, TIEMPO con bloques, LISTA con ticket)
const HudFranja = preload("res://scripts/hud_franja.gd")
var hud: HudFranja

func _ready() -> void:
	# NUEVO: La libreta y el reloj viejos se esconden: ahora todo eso está en la franja
	libreta.texture = null
	lista_visual.hide()
	reloj_visual.hide()
	
	# NUEVO: Armamos la franja de arriba
	hud = HudFranja.new()
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
	
	# El primer nivel arma su lista ANTES de que exista la interfaz, así que arrancamos a mano
	_on_lista_generada(GameManager.target_list)

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
	if gano:
		boton_siguiente.text = "SIGUIENTE NIVEL"
	else:
		boton_siguiente.text = "REINTENTAR"

	pantalla_resultados.show()
	boton_siguiente.grab_focus()

# Arranca en 0, que es el primer nivel de la lista
var nivel_actual: int = 0
var ultimo_resultado_gano: bool = false

# La lista de niveles en orden. Para agregar un nivel nuevo, sumalo al final.
# (El primero es el que ya viene puesto en juego.tscn)
const RUTAS_NIVELES: Array[String] = [
	"res://scenes/levels/nivel_1.tscn", # 0 -> NIVEL 1
	"res://scenes/levels/nivel_2.tscn", # 1 -> NIVEL 2
	"res://scenes/levels/nivel_3.tscn", # 2 -> NIVEL 3
	"res://scenes/levels/nivel_4.tscn", # 3 -> NIVEL 4
]

func _on_boton_siguiente_pressed() -> void:
	get_tree().paused = false
	pantalla_resultados.hide()

	# BUGFIX: Solo avanzamos de nivel si GANAMOS. Si perdimos, repetimos el mismo.
	if ultimo_resultado_gano:
		nivel_actual += 1 # Suma 1. Así que del 0 pasará al 1.

	var contenedor = %ContenedorNivel
	# Guardamos la posición del nivel viejo (por si el de juego.tscn está corrido)
	var posicion_nivel_anterior := Vector2.ZERO
	for hijo in contenedor.get_children():
		if hijo is Node2D:
			posicion_nivel_anterior = hijo.position
		hijo.queue_free()

	if nivel_actual < RUTAS_NIVELES.size() and ResourceLoader.exists(RUTAS_NIVELES[nivel_actual]):
		var nuevo_nivel = load(RUTAS_NIVELES[nivel_actual]).instantiate()
		# Si es un reintento, lo ponemos exactamente donde estaba el anterior
		if not ultimo_resultado_gano:
			nuevo_nivel.position = posicion_nivel_anterior
		contenedor.add_child(nuevo_nivel)
		_musica_del_nivel() # Cada nivel con su canción
	else:
		print("¡JUEGO COMPLETADO!")
		get_tree().change_scene_to_file("res://scenes/ui/menu_principal.tscn")

func _on_boton_menu_pressed() -> void:
	get_tree().paused = false 
	get_tree().change_scene_to_file("res://scenes/ui/menu_principal.tscn")

func _on_victoria() -> void:
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
const VOLUMEN_MUSICA: float = -8.0 # En decibeles: más negativo = más bajito
const FUNDIDO_MUSICA: float = 0.5  # Segundos que tarda en bajar la canción vieja al cambiar de nivel
var musica: AudioStreamPlayer
var ruta_sonando: String = ""

func _poner_musica() -> void:
	musica = AudioStreamPlayer.new()
	musica.volume_db = VOLUMEN_MUSICA
	# Sigue sonando aunque el juego esté en pausa (pantalla de resultados)
	musica.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(musica)
	_musica_del_nivel(false)

# Pone la canción que le toca al nivel actual. Si ya está sonando esa
# (por ejemplo, al reintentar el mismo nivel), la deja seguir sin cortarla.
func _musica_del_nivel(con_fundido: bool = true) -> void:
	var ruta: String = RUTAS_MUSICA[nivel_actual % RUTAS_MUSICA.size()]
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
