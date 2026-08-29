extends Control

# Referenciamos el botón (Asegúrate de que la ruta sea correcta según tu árbol)
@onready var boton_jugar: Button = $VBoxContainer/BotonJugar

func _ready() -> void:
	# Apenas arranca la pantalla, forzamos a que este botón esté seleccionado
	boton_jugar.grab_focus()

func _on_jugar_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main.tscn")

func _on_salir_pressed() -> void:
	get_tree().quit()
