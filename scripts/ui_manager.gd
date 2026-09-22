extends TextureRect

@onready var lista_visual: GridContainer = $ListaVisual
@onready var pantalla_resultados: ColorRect = %PantallaResultados
@onready var titulo_resultado: Label = %TituloResultado
@onready var boton_siguiente: Button = %BotonSiguiente

# Un Diccionario para guardar las etiquetas. 
# Funcionará así: {"Manzana": NodoLabel, "Leche": NodoLabel}
var etiquetas_items: Dictionary = {}

@onready var reloj_visual: Label = %RelojVisual

func _ready() -> void:
	# 1. Nos suscribimos a todas las señales
	GameManager.list_generated.connect(_on_lista_generada)
	GameManager.item_collected.connect(_on_item_recolectado)
	GameManager.time_updated.connect(_on_tiempo_actualizado)
	GameManager.game_over_reached.connect(_on_game_over)
	GameManager.game_won.connect(_on_victoria)
	
	GameManager.start_qte_ui.connect(%QTE_Minigame.start_qte)
	%QTE_Minigame.qte_finished.connect(GameManager.resolve_qte)
	
	GameManager.start_qte_colores.connect(%QTE_Colores.start_qte)
	%QTE_Colores.qte_finished.connect(GameManager.resolve_qte)
	
	# NUEVO: Si huyen, escondemos las dos pantallas a la fuerza y las desactivamos
	GameManager.qte_cancelled.connect(%QTE_Minigame.hide)
	GameManager.qte_cancelled.connect(func(): %QTE_Minigame.is_active = false)
	
	GameManager.qte_cancelled.connect(%QTE_Colores.hide)
	GameManager.qte_cancelled.connect(func(): %QTE_Colores.is_active = false)
	
	# NUEVA LÍNEA: Le decimos a la UI que lea la lista del GameManager directamente por si no escuchó el grito
	_on_lista_generada(GameManager.target_list)

# --- DIBUJAR LA LISTA DE ÍCONOS ---
func _on_lista_generada(target_list: Array[ItemData]) -> void:
	# Borramos lo viejo
	for hijo in lista_visual.get_children():
		hijo.queue_free()
	etiquetas_items.clear()
	
	for item in target_list:
		# ¡CAMBIO! Creamos un nodo de Imagen en lugar de Texto
		var nuevo_icono = TextureRect.new()
		
		# Le ponemos la fotito que cargaste en el archivo .tres
		nuevo_icono.texture = item.icon 
		
		# Configuramos el tamaño para que encaje en la libreta (ej: 32x32)
		nuevo_icono.custom_minimum_size = Vector2(32, 32)
		nuevo_icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		nuevo_icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# --- LE PONEMOS EL FILTRO GRIS ---
		var material_gris = ShaderMaterial.new()
		# IMPORTANTE: Asegúrate de que esta ruta sea donde guardaste tu shader
		material_gris.shader = load("res://scripts/escala_grises.gdshader") 
		nuevo_icono.material = material_gris
		# ---------------------------------
		
		# Lo añadimos a la libreta
		lista_visual.add_child(nuevo_icono)
		# Lo guardamos en el diccionario para buscarlo luego
		etiquetas_items[item.item_name] = nuevo_icono


# --- CUANDO AGARRAMOS LA FRUTA ---
func _on_item_recolectado(item: ItemData) -> void:
	if etiquetas_items.has(item.item_name):
		# Buscamos el ícono en la libreta
		var icono: TextureRect = etiquetas_items[item.item_name]
		
		# ¡MAGIA PURA! Le arrancamos el material gris. 
		# Al quedarse sin filtro, el color original de Nati vuelve a brillar instantáneamente.
		icono.material = null 
		
		# (Opcional) Podemos hacer que salte un poquito para festejar
		var salto = create_tween()
		salto.tween_property(icono, "scale", Vector2(1.2, 1.2), 0.1)
		salto.tween_property(icono, "scale", Vector2(1.0, 1.0), 0.1)

func mostrar_resultados(mensaje: String) -> void:
	# 1. Congelamos TODO el juego (físicas, jugador)
	get_tree().paused = true 
	
	# 2. Mostramos la pantalla oscura y cambiamos el texto
	titulo_resultado.text = mensaje
	pantalla_resultados.show()
	
	# 3. Le damos el foco al botón para el Arcade (Joystick)
	boton_siguiente.grab_focus()

# --- BOTONES DE LA PANTALLA DE RESULTADOS ---
# Variable para saber en qué nivel estamos
var nivel_actual: int = 1

func _on_boton_siguiente_pressed() -> void:
	# 1. Despausamos el juego y escondemos el cartel de victoria
	get_tree().paused = false
	pantalla_resultados.hide()
	
	# 2. Sumamos 1 al nivel actual
	nivel_actual += 1
	
	# 3. Borramos el nivel viejo de la pantalla (Sacamos el cartucho)
	var contenedor = %ContenedorNivel
	for hijo in contenedor.get_children():
		hijo.queue_free()
	
	# 4. Cargamos el archivo del nivel nuevo (Ej: "res://scenes/levels/nivel_2.tscn")
	var ruta_nivel = "res://scenes/levels/nivel_" + str(nivel_actual) + ".tscn"
	
	# Verificamos si ese nivel existe (por si ya ganaste el último nivel)
	if ResourceLoader.exists(ruta_nivel):
		# Lo fabricamos y lo metemos en el contenedor
		var nuevo_nivel = load(ruta_nivel).instantiate()
		contenedor.add_child(nuevo_nivel)
	else:
		print("¡JUEGO COMPLETADO! No hay más niveles.")
		# Aquí podrías volver al menú principal o mostrar una pantalla de Fin del Juego
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

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
