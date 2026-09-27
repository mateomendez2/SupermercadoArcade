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
	
	# ¡NUEVA LÍNEA! Escuchamos cuando nos roban algo
	GameManager.item_dropped.connect(_on_item_perdido)
	
	GameManager.time_updated.connect(_on_tiempo_actualizado)
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
	
	GameManager.qte_cancelled.connect(%QTE_Minigame.hide)
	GameManager.qte_cancelled.connect(func(): %QTE_Minigame.is_active = false)
	
	GameManager.qte_cancelled.connect(%QTE_Colores.hide)
	GameManager.qte_cancelled.connect(func(): %QTE_Colores.is_active = false)
	
	_on_lista_generada(GameManager.target_list)

# --- DIBUJAR LA LISTA DE ÍCONOS ---
func _on_lista_generada(target_list: Array[ItemData]) -> void:
	# Borramos lo viejo
	for hijo in lista_visual.get_children():
		hijo.queue_free()
	etiquetas_items.clear()
	
	for item in target_list:
		var nuevo_icono = TextureRect.new()
		nuevo_icono.texture = item.icon 
		
		nuevo_icono.custom_minimum_size = Vector2(32, 32)
		nuevo_icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		nuevo_icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# --- LE PONEMOS EL FILTRO GRIS ---
		var material_gris = ShaderMaterial.new()
		material_gris.shader = load("res://scripts/escala_grises.gdshader") 
		nuevo_icono.material = material_gris
		
		lista_visual.add_child(nuevo_icono)
		etiquetas_items[item.item_name] = nuevo_icono

# --- CUANDO AGARRAMOS LA FRUTA ---
func _on_item_recolectado(item: ItemData) -> void:
	if etiquetas_items.has(item.item_name):
		var icono: TextureRect = etiquetas_items[item.item_name]
		
		# ¡MAGIA PURA! Le arrancamos el material gris. 
		icono.material = null 
		
		# Saltito de festejo
		var salto = create_tween()
		salto.tween_property(icono, "scale", Vector2(1.2, 1.2), 0.1)
		salto.tween_property(icono, "scale", Vector2(1.0, 1.0), 0.1)

# --- NUEVO: CUANDO NOS ROBAN LA FRUTA ---
func _on_item_perdido(item: ItemData) -> void:
	if etiquetas_items.has(item.item_name):
		var icono: TextureRect = etiquetas_items[item.item_name]
		
		# Le volvemos a poner la capa gris
		var material_gris = ShaderMaterial.new()
		material_gris.shader = load("res://scripts/escala_grises.gdshader") 
		icono.material = material_gris
		
		# Efecto visual de error: Parpadea en rojo súper rápido
		var parpadeo = create_tween()
		parpadeo.tween_property(icono, "modulate", Color.RED, 0.1)
		parpadeo.tween_property(icono, "modulate", Color.WHITE, 0.1)


func mostrar_resultados(mensaje: String) -> void:
	get_tree().paused = true 
	titulo_resultado.text = mensaje
	pantalla_resultados.show()
	boton_siguiente.grab_focus()

# --- BOTONES DE LA PANTALLA DE RESULTADOS ---
var nivel_actual: int = 1

func _on_boton_siguiente_pressed() -> void:
	get_tree().paused = false
	pantalla_resultados.hide()
	
	nivel_actual += 1
	
	var contenedor = %ContenedorNivel
	for hijo in contenedor.get_children():
		hijo.queue_free()
	
	var ruta_nivel = "res://scenes/levels/nivel_" + str(nivel_actual) + ".tscn"
	
	if ResourceLoader.exists(ruta_nivel):
		var nuevo_nivel = load(ruta_nivel).instantiate()
		contenedor.add_child(nuevo_nivel)
	else:
		print("¡JUEGO COMPLETADO! No hay más niveles.")
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_boton_menu_pressed() -> void:
	get_tree().paused = false 
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_tiempo_actualizado(tiempo: int) -> void:
	reloj_visual.text = "TIEMPO: " + str(tiempo)

func _on_victoria() -> void:
	reloj_visual.modulate = Color.GREEN 
	mostrar_resultados("¡NIVEL COMPLETADO!")

func _on_game_over() -> void:
	reloj_visual.modulate = Color.RED 
	mostrar_resultados("¡SE ACABÓ EL TIEMPO!")
