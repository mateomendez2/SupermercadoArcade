extends Panel

@onready var lista_visual: VBoxContainer = $ListaVisual
@onready var pantalla_resultados: ColorRect = %PantallaResultados
@onready var titulo_resultado: Label = %TituloResultado
@onready var boton_siguiente: Button = %BotonSiguiente

# Un Diccionario para guardar las etiquetas. 
# Funcionará así: {"Manzana": NodoLabel, "Leche": NodoLabel}
var etiquetas_items: Dictionary = {}

@onready var reloj_visual: Label = %RelojVisual

func _ready() -> void:
	# 1. Nos suscribimos a las señales
	GameManager.list_generated.connect(_on_lista_generada)
	GameManager.item_collected.connect(_on_item_recolectado)
	
	# 2. AHORA que ya estamos escuchando, le decimos al Gestor que arme la lista
	GameManager.generate_random_list(3)
	
	# Conectamos la señal global con la función de la barrita
	GameManager.start_qte_ui.connect(%QTE_Minigame.start_qte)
	# Cuando la barrita termine, le avisa al GameManager
	%QTE_Minigame.qte_finished.connect(GameManager.resolve_qte)
	
	GameManager.game_won.connect(_on_victoria)
	
	GameManager.time_updated.connect(_on_tiempo_actualizado)
	GameManager.game_over_reached.connect(_on_game_over)
	
	GameManager.generate_random_list(3)

# 1. Cuando arranca el nivel y el GameManager elige los 3 objetos al azar:
func _on_lista_generada(target_list: Array[ItemData]) -> void:
	
	# Primero, borramos cualquier texto viejo por si reiniciamos el nivel
	for hijo in lista_visual.get_children():
		hijo.queue_free()
	etiquetas_items.clear()
	
	# Creamos un texto nuevo por cada ítem que nos pide el juego
	for item in target_list:
		var nuevo_texto = Label.new()
		nuevo_texto.text = "[ ] " + item.item_name # Arrancan con una cajita vacía
		
		# Lo añadimos a la pantalla
		lista_visual.add_child(nuevo_texto)
		
		# Lo guardamos en el diccionario para poder tacharlo después
		etiquetas_items[item.item_name] = nuevo_texto

# 2. Cuando el jugador agarra el objeto correcto de la góndola:
func _on_item_recolectado(item: ItemData) -> void:
	
	# Buscamos la etiqueta de ese ítem en nuestro diccionario
	if etiquetas_items.has(item.item_name):
		var etiqueta: Label = etiquetas_items[item.item_name]
		
		# Le ponemos una X y lo pintamos de verde (¡Game Feel!)
		etiqueta.text = "[X] " + item.item_name
		etiqueta.modulate = Color.GREEN
		

func mostrar_resultados(mensaje: String) -> void:
	# 1. Congelamos TODO el juego (físicas, jugador)
	get_tree().paused = true 
	
	# 2. Mostramos la pantalla oscura y cambiamos el texto
	titulo_resultado.text = mensaje
	pantalla_resultados.show()
	
	# 3. Le damos el foco al botón para el Arcade (Joystick)
	boton_siguiente.grab_focus()

# --- BOTONES DE LA PANTALLA DE RESULTADOS ---
func _on_boton_siguiente_pressed() -> void:
	get_tree().paused = false 
	get_tree().reload_current_scene()

func _on_boton_menu_pressed() -> void:
	get_tree().paused = false 
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

# Esta función actualiza los números en pantalla todo el tiempo
func _on_tiempo_actualizado(tiempo: int) -> void:
	reloj_visual.text = "TIEMPO: " + str(tiempo)

# Cuando ganamos
func _on_victoria() -> void:
	reloj_visual.modulate = Color.GREEN # Pintamos el reloj de verde
	mostrar_resultados("¡NIVEL COMPLETADO!")

# Cuando perdemos por tiempo
func _on_game_over() -> void:
	reloj_visual.modulate = Color.RED # Pintamos el reloj de rojo
	mostrar_resultados("¡SE ACABÓ EL TIEMPO!")
