# inventory_ui.gd
extends CanvasLayer

var _grid: GridContainer
var _gold_label: Label
var _tooltip_panel: PanelContainer
var _player: Node = null
var _economy: Node = null

func _ready() -> void:
	_build_ui()
	
	_player = get_tree().get_first_node_in_group("player")
	if _player:
		_player.inventory_changed.connect(_update_inventory)
		_economy = _player.economy
		if _economy:
			_economy.gold_changed.connect(_on_gold_changed)
			_on_gold_changed(_economy.gold)
		_update_inventory()

func _process(_delta: float) -> void:
	# Hacer que el tooltip siga al ratón
	if _tooltip_panel and _tooltip_panel.visible:
		_tooltip_panel.global_position = get_viewport().get_mouse_position() + Vector2(15, 15)

func _build_ui() -> void:
	# Contenedor vertical principal (esquina superior derecha)
	var root_vbox = VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	root_vbox.position = Vector2(-220, 20)
	root_vbox.add_theme_constant_override("separation", 10)
	add_child(root_vbox)
	
	# --- PANEL DE ORO ---
	var gold_panel = PanelContainer.new()
	gold_panel.custom_minimum_size = Vector2(200, 0)
	root_vbox.add_child(gold_panel)
	
	var gold_style = StyleBoxFlat.new()
	gold_style.bg_color = Color(0.2, 0.15, 0.05, 0.85)
	gold_style.corner_radius_top_left = 8
	gold_style.corner_radius_top_right = 8
	gold_style.corner_radius_bottom_left = 8
	gold_style.corner_radius_bottom_right = 8
	gold_style.border_width_left = 2
	gold_style.border_width_top = 2
	gold_style.border_width_right = 2
	gold_style.border_width_bottom = 2
	gold_style.border_color = Color(0.8, 0.6, 0.2, 1.0)
	gold_panel.add_theme_stylebox_override("panel", gold_style)
	
	var gold_margin = MarginContainer.new()
	gold_margin.add_theme_constant_override("margin_left", 15)
	gold_margin.add_theme_constant_override("margin_top", 10)
	gold_margin.add_theme_constant_override("margin_right", 15)
	gold_margin.add_theme_constant_override("margin_bottom", 10)
	gold_panel.add_child(gold_margin)
	
	_gold_label = Label.new()
	_gold_label.text = "Oro: 0"
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_gold_label.add_theme_font_size_override("font_size", 20)
	gold_margin.add_child(_gold_label)
	
	# --- PANEL DE INVENTARIO ---
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 0)
	root_vbox.add_child(panel)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.75)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.4, 0.8)
	panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 5)
	_grid.add_theme_constant_override("v_separation", 5)
	margin.add_child(_grid)
	
	# --- TOOLTIP FLOTANTE ---
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE # No bloquear el ratón
	_tooltip_panel.visible = false
	add_child(_tooltip_panel)
	
	var t_style = StyleBoxFlat.new()
	t_style.bg_color = Color(0.05, 0.05, 0.1, 0.95)
	t_style.corner_radius_top_left = 4
	t_style.corner_radius_top_right = 4
	t_style.corner_radius_bottom_left = 4
	t_style.corner_radius_bottom_right = 4
	t_style.border_width_left = 1
	t_style.border_width_top = 1
	t_style.border_width_right = 1
	t_style.border_width_bottom = 1
	t_style.border_color = Color(0.5, 0.5, 0.6, 0.8)
	_tooltip_panel.add_theme_stylebox_override("panel", t_style)
	
	var t_margin = MarginContainer.new()
	t_margin.add_theme_constant_override("margin_left", 8)
	t_margin.add_theme_constant_override("margin_top", 4)
	t_margin.add_theme_constant_override("margin_right", 8)
	t_margin.add_theme_constant_override("margin_bottom", 4)
	_tooltip_panel.add_child(t_margin)
	
	var t_label = Label.new()
	t_label.text = "Right click to open"
	t_label.add_theme_color_override("font_color", Color(1, 1, 1))
	t_label.add_theme_font_size_override("font_size", 14)
	t_margin.add_child(t_label)

func _update_inventory() -> void:
	if not _player: return
	
	# Ocultar tooltip por si acaso estábamos encima de un slot que se va a borrar
	_tooltip_panel.visible = false
	
	for child in _grid.get_children():
		child.queue_free()
		
	for item_name in _player.inventory:
		var slot = _create_slot(item_name)
		_grid.add_child(slot)

func _create_slot(item_name: String) -> Control:
	var slot = PanelContainer.new()
	slot.custom_minimum_size = Vector2(50, 50)
	
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.2, 0.2, 0.25, 0.9)
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.border_color = Color(0.5, 0.5, 0.6, 0.8)
	slot.add_theme_stylebox_override("panel", s)
	
	var lbl = Label.new()
	if item_name == "barrel":
		lbl.text = "B"
		lbl.add_theme_color_override("font_color", Color(0.8, 0.6, 0.4))
	else:
		lbl.text = "?"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 24)
	slot.add_child(lbl)
	
	# Conectar eventos de ratón para este slot
	slot.mouse_entered.connect(_on_slot_mouse_entered)
	slot.mouse_exited.connect(_on_slot_mouse_exited)
	slot.gui_input.connect(_on_slot_gui_input.bind(item_name))
	
	return slot

func _on_gold_changed(amount: int) -> void:
	if _gold_label:
		_gold_label.text = "Oro: " + str(amount)

# --- Lógica del Tooltip y Clic Derecho ---
func _on_slot_mouse_entered() -> void:
	_tooltip_panel.visible = true

func _on_slot_mouse_exited() -> void:
	_tooltip_panel.visible = false

func _on_slot_gui_input(event: InputEvent, item_name: String) -> void:
	# Detectar clic derecho
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if item_name == "barrel":
			if _player and _player.has_method("open_barrel"):
				_player.open_barrel()
