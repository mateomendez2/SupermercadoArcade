extends Control

@onready var texto_comenzar: Label = $TextoComenzar

func _ready() -> void:
	# --- EFECTO VISUAL: TEXTO PARPADEANTE (Blinking) ---
	var parpadeo = create_tween().set_loops()
	
	# Desaparece en medio segundo, y vuelve a aparecer en medio segundo
	parpadeo.tween_property(texto_comenzar, "modulate:a", 0.0, 0.5)
	parpadeo.tween_property(texto_comenzar, "modulate:a", 1.0, 0.5)

# --- ESCUCHAMOS EL TABLERO ARCADE ---
func _unhandled_input(event: InputEvent) -> void:
	# Si apretó la "E" o cualquiera de los botones de Acción del Joystick
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		
		# Consumimos el botón para que no haga "eco" en el Nivel 1
		get_viewport().set_input_as_handled()
		
		# ¡Arrancamos el juego!
		get_tree().change_scene_to_file("res://scenes/ui/main.tscn")
