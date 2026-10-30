@tool
extends Area2D

var player_in_range: bool = false
var de_adorno: bool = false # Modo 2 jugadores: no se paga acá
var jugadores_cerca: Array[Node] = [] # Los que están frente al mostrador (en el modo 2 jugadores pueden ser los dos)

# --- QUÉ CAJERO ES (se elige en el Inspector y se ve en el editor) ---
const RUTAS_VARIANTES: Array[String] = [
	"res://assets/empleados/empleado_1.tres", # Variante 1: rubio
	"res://assets/empleados/empleado_2.tres", # Variante 2: castaño
]
@export_enum("Variante 1 (rubio)", "Variante 2 (castaño)") var variante: int = 0:
	set(valor):
		variante = valor
		if is_node_ready(): _aplicar_variante()

# --- AVISO DEL CAJERO (aparece cuando completás la lista) ---
const RUTA_SONIDO_CAJA: String = "res://assets/audio/SonidoCaja.wav"
@export var texto_aviso: String = "¡POR ACÁ!"
@export var posicion_aviso: Vector2 = Vector2(-8, -42) # Arriba de la cabeza del cajero

var aviso: PanelContainer # El globo de diálogo "¡POR ACÁ!"
var sonido_caja: AudioStreamPlayer
var tween_aparecer: Tween
var tween_rebote: Tween

func _ready() -> void:
	_aplicar_variante()
	if Engine.is_editor_hint(): return # En el editor solo mostramos el dibujo del cajero

	# Modo 2 jugadores (ROBO): la caja es de adorno; para ganar hay que escaparse por la puerta (salida_coop.gd)
	if get_tree().get_first_node_in_group("PantallaDividida") != null:
		de_adorno = true
		var flecha = get_node_or_null("%FlechaGuia")
		if flecha: flecha.queue_free()
		var zona = get_node_or_null("%ZonaVisual")
		if zona: zona.hide()
		return

	# Nos avisa cuando el jugador está frente a la caja
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Armamos el cartel y el sonido por código (no hace falta tocar la escena)
	_crear_aviso()

	# Escuchamos al GameManager
	GameManager.lista_lista_para_pagar.connect(_mostrar_aviso) # Lista completa -> ¡llamamos al jugador!
	GameManager.lista_incompleta.connect(_ocultar_aviso)       # Le robaron algo -> escondemos
	GameManager.game_won.connect(_ocultar_aviso)               # Ya pagó -> escondemos

func _crear_aviso() -> void:
	# 1. El cartel: un globo de diálogo blanco con borde negro y letras negras
	var estilo = StyleBoxFlat.new()
	estilo.bg_color = Color.WHITE
	estilo.border_color = Color.BLACK
	estilo.set_border_width_all(1)
	estilo.content_margin_left = 4
	estilo.content_margin_right = 4
	estilo.content_margin_top = 0
	estilo.content_margin_bottom = 1
	estilo.anti_aliasing = false # Bordes pixelados, como el resto del juego

	aviso = PanelContainer.new()
	aviso.add_theme_stylebox_override("panel", estilo)
	aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aviso.z_index = 20 # Siempre por encima de góndolas y personajes
	aviso.hide()
	add_child(aviso)

	var texto = Label.new()
	texto.text = texto_aviso
	texto.add_theme_font_size_override("font_size", 16)
	texto.add_theme_color_override("font_color", Color.BLACK)
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aviso.add_child(texto)

	# Lo centramos arriba del cajero (el tamaño se calcula recién cuando está en el árbol)
	aviso.size = aviso.get_minimum_size()
	aviso.pivot_offset = aviso.size / 2.0 # Para que crezca desde el centro
	aviso.position = (posicion_aviso - aviso.size / 2.0).round()

	# La "colita" del globo, apuntando al cajero (triángulo negro con uno blanco adentro)
	var abajo_centro = Vector2(round(aviso.size.x / 2.0), aviso.size.y - 1)
	var colita_borde = Polygon2D.new()
	colita_borde.polygon = PackedVector2Array([Vector2(-4, 0), Vector2(4, 0), Vector2(0, 5)])
	colita_borde.color = Color.BLACK
	colita_borde.position = abajo_centro
	aviso.add_child(colita_borde)
	var colita = Polygon2D.new()
	colita.polygon = PackedVector2Array([Vector2(-3, 0), Vector2(3, 0), Vector2(0, 3)])
	colita.color = Color.WHITE
	colita.position = abajo_centro
	aviso.add_child(colita)

	# 2. El sonido: AudioStreamPlayer normal (no 2D) para que se escuche aunque estés lejos
	sonido_caja = AudioStreamPlayer.new()
	sonido_caja.volume_db = -4.0
	if ResourceLoader.exists(RUTA_SONIDO_CAJA):
		sonido_caja.stream = load(RUTA_SONIDO_CAJA)
	add_child(sonido_caja)

func _mostrar_aviso() -> void:
	if sonido_caja.stream:
		sonido_caja.play()

	_frenar_animaciones_aviso()
	var pos_y_base = posicion_aviso.y - aviso.size.y / 2.0
	aviso.position.y = pos_y_base
	aviso.scale = Vector2.ZERO
	aviso.show()

	# Animación 1: aparece con un "pop" (crece pasándose un poquito y vuelve)
	tween_aparecer = create_tween()
	tween_aparecer.tween_property(aviso, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Animación 2: rebota para arriba y abajo para siempre
	tween_rebote = create_tween().set_loops()
	tween_rebote.tween_property(aviso, "position:y", pos_y_base - 4.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween_rebote.tween_property(aviso, "position:y", pos_y_base, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _ocultar_aviso() -> void:
	_frenar_animaciones_aviso()
	aviso.hide()

func _frenar_animaciones_aviso() -> void:
	if tween_aparecer: tween_aparecer.kill()
	if tween_rebote: tween_rebote.kill()

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		if not jugadores_cerca.has(body): jugadores_cerca.append(body)
		player_in_range = true

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		jugadores_cerca.erase(body)
		player_in_range = not jugadores_cerca.is_empty()

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or de_adorno: return
	# Si un jugador que está frente al mostrador aprieta SU botón de agarrar
	# (modo de un jugador: "interact"; modo 2 jugadores: "p1_interact" o "p2_interact")
	for jugador in jugadores_cerca:
		if is_instance_valid(jugador) and event.is_action_pressed(str(jugador.get("prefijo_acciones")) + "interact"):
			# Le decimos al GameManager que evalúe la lista
			GameManager.intentar_pagar()
			return

# Pone el dibujo del cajero elegido (quieto, mirando para adelante)
func _aplicar_variante() -> void:
	var sprite = get_node_or_null("SpriteCajero") as AnimatedSprite2D
	if sprite == null: return
	var ruta = RUTAS_VARIANTES[clampi(variante, 0, RUTAS_VARIANTES.size() - 1)]
	if not ResourceLoader.exists(ruta): return
	sprite.sprite_frames = load(ruta)
	sprite.play("idle_down")
