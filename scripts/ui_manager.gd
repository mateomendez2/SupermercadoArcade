extends TextureRect

@onready var lista_visual: GridContainer = $ListaVisual
@onready var pantalla_resultados: ColorRect = %PantallaResultados
@onready var titulo_resultado: Label = %TituloResultado
@onready var boton_siguiente: Button = %BotonSiguiente

# Un Diccionario para guardar las etiquetas. 
# Funcionará así: {"Manzana": NodoLabel, "Leche": NodoLabel}
var etiquetas_items: Dictionary = {}

@onready var reloj_visual: Label = %RelojVisual

@onready var libreta: TextureRect = %Libreta

# Variables para que la libreta recuerde a dónde volver
var pos_original_libreta: Vector2
var escala_original_libreta: Vector2

func _ready() -> void:
	# Guardamos dónde estaba la libreta originalmente
	pos_original_libreta = libreta.position
	escala_original_libreta = libreta.scale
	# Ponemos el "Pivote" en el centro para que cuando crezca, crezca desde el medio
	libreta.pivot_offset = libreta.size / 2.0 
	
	# ... (siguen tus conexiones de señales de siempre) ...
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
		
		# Lo añadimos a la libreta
		lista_visual.add_child(nuevo_icono)
		etiquetas_items[item.item_name] = nuevo_icono
	
	# ¡NUEVA LÍNEA AL FINAL DE LA FUNCIÓN!
	animar_presentacion_libreta()

# --- CUANDO AGARRAMOS LA FRUTA ---
func _on_item_recolectado(item: ItemData) -> void:
	if etiquetas_items.has(item.item_name):
		var icono: TextureRect = etiquetas_items[item.item_name]
		
		# ¡NUEVO! Le ponemos el filtro gris porque ya lo tachamos
		var material_gris = ShaderMaterial.new()
		material_gris.shader = load("res://scripts/escala_grises.gdshader") 
		icono.material = material_gris
		
		# Saltito de festejo (opcional, si lo tenías)
		var salto = create_tween()
		salto.tween_property(icono, "scale", Vector2(1.2, 1.2), 0.1)
		salto.tween_property(icono, "scale", Vector2(1.0, 1.0), 0.1)

# --- NUEVO: CUANDO NOS ROBAN LA FRUTA ---
func _on_item_perdido(item: ItemData) -> void:
	if etiquetas_items.has(item.item_name):
		var icono: TextureRect = etiquetas_items[item.item_name]
		
		# ¡NUEVO! Le quitamos el filtro gris para que vuelva a estar a color (pendiente)
		icono.material = null
		
		# Efecto de error en rojo
		var parpadeo = create_tween()
		parpadeo.tween_property(icono, "modulate", Color.RED, 0.1)
		parpadeo.tween_property(icono, "modulate", Color.WHITE, 0.1)


func mostrar_resultados(mensaje: String) -> void:
	get_tree().paused = true 
	titulo_resultado.text = mensaje
	pantalla_resultados.show()
	boton_siguiente.grab_focus()

# Cambiamos esto a 0, porque arrancamos en el Tutorial
var nivel_actual: int = 0 

func _on_boton_siguiente_pressed() -> void:
	get_tree().paused = false
	pantalla_resultados.hide()
	
	nivel_actual += 1 # Suma 1. Así que del 0 pasará al 1.
	
	var contenedor = %ContenedorNivel
	for hijo in contenedor.get_children():
		hijo.queue_free()
	
	# La matemática del archivo
	var ruta_nivel = ""
	if nivel_actual == 1:
		ruta_nivel = "res://scenes/levels/nivel_1.tscn"
	elif nivel_actual == 2:
		ruta_nivel = "res://scenes/levels/nivel_2.tscn"
	# Si llegas a hacer más niveles (3, 4), puedes copiarlos aquí siguiendo la lógica
	
	if ruta_nivel != "" and ResourceLoader.exists(ruta_nivel):
		var nuevo_nivel = load(ruta_nivel).instantiate()
		contenedor.add_child(nuevo_nivel)
	else:
		print("¡JUEGO COMPLETADO!")
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

# --- ANIMACIÓN DE INTRODUCCIÓN DE LA LIBRETA ---
func animar_presentacion_libreta() -> void:
	# 1. Calculamos el centro exacto de tu monitor
	var centro_pantalla = (get_viewport_rect().size / 2.0) - (libreta.size / 2.0)
	
	# 2. Teletransportamos la libreta al centro y la hacemos gigante AL INSTANTE
	libreta.position = centro_pantalla
	libreta.scale = Vector2(2.0, 2.0)
	
	# 3. Armamos la coreografía ESTRICTA
	var anim_intro = create_tween()
	
	# PASO A: Congelada en el medio (Por ejemplo, 2.5 segundos)
	anim_intro.tween_interval(2.5)
	
	# PASO B: Encadenamos el movimiento para que no arranque hasta que termine el intervalo
	anim_intro.chain()
	
	# PASO C: El viaje a la esquina de forma paralela (Lento y suave en 1.0 seg)
	anim_intro.set_parallel(true)
	anim_intro.tween_property(libreta, "position", pos_original_libreta, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	anim_intro.tween_property(libreta, "scale", escala_original_libreta, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
