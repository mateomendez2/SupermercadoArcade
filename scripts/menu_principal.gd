extends Control

@onready var texto_comenzar: Label = $TextoComenzar

# --- MÚSICA DEL MENÚ ---
const RUTA_MUSICA_MENU: String = "res://assets/audio/MusicaMenu.ogg"
const VOLUMEN_MUSICA_MENU: float = -8.0
var musica: AudioStreamPlayer

func _ready() -> void:
	# --- EFECTO VISUAL: TEXTO PARPADEANTE (Blinking) ---
	var parpadeo = create_tween().set_loops()
	
	# Desaparece en medio segundo, y vuelve a aparecer en medio segundo
	parpadeo.tween_property(texto_comenzar, "modulate:a", 0.0, 0.5)
	parpadeo.tween_property(texto_comenzar, "modulate:a", 1.0, 0.5)

	# Música del menú en loop (se corta sola al entrar al juego, porque se cambia de escena)
	if ResourceLoader.exists(RUTA_MUSICA_MENU):
		musica = AudioStreamPlayer.new()
		var cancion: AudioStream = load(RUTA_MUSICA_MENU)
		cancion.loop = true
		musica.stream = cancion
		musica.volume_db = VOLUMEN_MUSICA_MENU
		add_child(musica)
		musica.play(GameManager.posicion_musica_menu) # Sigue desde donde iba (si volvemos de la pantalla de niveles)
		GameManager.posicion_musica_menu = 0.0

# --- ESCUCHAMOS EL TABLERO ARCADE ---
func _unhandled_input(event: InputEvent) -> void:
	# Si apretó la "E" o cualquiera de los botones de Acción del Joystick
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		
		# Consumimos el botón para que no haga "eco" en la pantalla siguiente
		get_viewport().set_input_as_handled()
		
		# Pasamos a la pantalla de elegir modo (1 o 2 jugadores). La música sigue desde donde iba
		if musica:
			GameManager.posicion_musica_menu = musica.get_playback_position()
		get_tree().change_scene_to_file("res://scenes/ui/seleccion_modo.tscn")
