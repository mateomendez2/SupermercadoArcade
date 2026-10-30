extends Control

@onready var texto_comenzar: Label = $TextoComenzar

# --- MÚSICA DEL MENÚ ---
var musica: AudioStreamPlayer
# --- AL APRETAR: sonido de "elegir" y fundido a negro (como en las otras pantallas) ---
var SONIDO_ELEGIR: AudioStream = load("res://assets/audio/MenuElegir.wav")
const TIEMPO_FUNDIDO: float = 0.3
var empezando: bool = false
var sonido: AudioStreamPlayer
var fundido: ColorRect

func _ready() -> void:
	# --- EFECTO VISUAL: TEXTO PARPADEANTE (Blinking) ---
	var parpadeo = create_tween().set_loops()
	
	# Desaparece en medio segundo, y vuelve a aparecer en medio segundo
	parpadeo.tween_property(texto_comenzar, "modulate:a", 0.0, 0.5)
	parpadeo.tween_property(texto_comenzar, "modulate:a", 1.0, 0.5)

	# Música del menú en loop: es una sola para todas las pantallas del menú (vive en GameManager),
	# así sigue de corrido al pasar a las otras pantallas. Se apaga sola cuando arranca un nivel.
	musica = GameManager.musica_menu()

	sonido = AudioStreamPlayer.new()
	add_child(sonido)
	fundido = ColorRect.new()
	fundido.color = Color(0, 0, 0, 0)
	fundido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundido)
	fundido.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

# --- ESCUCHAMOS EL TABLERO ARCADE ---
func _unhandled_input(event: InputEvent) -> void:
	# Si apretó la "E" o cualquiera de los botones de Acción del Joystick
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		
		# Consumimos el botón para que no haga "eco" en la pantalla siguiente
		get_viewport().set_input_as_handled()
		if empezando: return
		empezando = true
		sonido.stream = SONIDO_ELEGIR
		sonido.play()
		# Fundido a negro y pasamos a la pantalla de elegir modo (1 o 2 jugadores). La música sigue de corrido
		var t = create_tween()
		t.tween_property(fundido, "color:a", 1.0, TIEMPO_FUNDIDO)
		await t.finished
		get_tree().change_scene_to_file("res://scenes/ui/seleccion_modo.tscn")
