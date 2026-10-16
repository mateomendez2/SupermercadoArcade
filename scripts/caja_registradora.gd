extends Area2D

var player_in_range: bool = false

# --- AVISO DEL CAJERO (aparece cuando completás la lista) ---
const RUTA_SONIDO_CAJA: String = "res://assets/audio/SonidoCaja.wav"
@export var texto_aviso: String = "¡POR ACÁ!"
@export var posicion_aviso: Vector2 = Vector2(-8, -42) # Arriba de la cabeza del cajero

var aviso: Label
var sonido_caja: AudioStreamPlayer
var tween_aparecer: Tween
var tween_rebote: Tween

func _ready() -> void:
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
	# 1. El cartel: un texto con el mismo estilo que el reloj (amarillo con borde naranja)
	aviso = Label.new()
	aviso.text = texto_aviso
	aviso.add_theme_font_size_override("font_size", 16)
	aviso.add_theme_color_override("font_color", Color(0.98, 1.0, 0.59))
	aviso.add_theme_color_override("font_outline_color", Color(0.75, 0.21, 0.05))
	aviso.add_theme_constant_override("outline_size", 4)
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.z_index = 20 # Siempre por encima de góndolas y personajes
	aviso.hide()
	add_child(aviso)

	# Lo centramos arriba del cajero (el tamaño se calcula recién cuando está en el árbol)
	aviso.size = aviso.get_minimum_size()
	aviso.pivot_offset = aviso.size / 2.0 # Para que crezca desde el centro
	aviso.position = posicion_aviso - aviso.size / 2.0

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
		player_in_range = true
		print("Presiona E para pagar.")

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_in_range = false

func _unhandled_input(event: InputEvent) -> void:
	# Si el jugador aprieta "E" y está frente al mostrador...
	if player_in_range and event.is_action_pressed("interact"):
		# Le decimos al GameManager que evalúe la lista
		GameManager.intentar_pagar()
