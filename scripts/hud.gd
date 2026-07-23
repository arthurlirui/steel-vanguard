extends CanvasLayer
## HUD — on-screen UI: health, score, lives, weapon, grenades, touch controls.

var health_bar: ProgressBar
var health_label: Label
var score_label: Label
var lives_label: Label
var weapon_label: Label
var weapon_ammo_label: Label
var grenade_label: Label
var pow_label: Label
var level_label: Label
var enemies_label: Label
var pause_button: Button

# Touch controls
var joystick_bg: ColorRect
var joystick_knob: ColorRect
var joystick_active: bool = false
var joystick_pos: Vector2 = Vector2.ZERO
var joystick_dir: Vector2 = Vector2.ZERO
var joystick_origin: Vector2 = Vector2.ZERO
var btn_jump: ColorRect
var btn_shoot: ColorRect
var btn_grenade: ColorRect
var btn_vehicle: ColorRect
var btn_weapon: ColorRect
var is_touch: bool = false

# Game over / victory overlay
var overlay_panel: Panel
var overlay_label: Label
var overlay_button: Button

# Pause overlay
var pause_panel: Panel
var pause_resume_button: Button

func _ready() -> void:
	layer = 10
	# Keep the HUD responsive while the scene tree is paused (pause overlay).
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_touch = DisplayServer.is_touchscreen_available()
	_create_top_hud()
	if is_touch:
		_create_touch_controls()
	_connect_signals()
	_refresh_all()

func _connect_signals() -> void:
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.weapon_changed.connect(_on_weapon_changed)
	GameManager.ammo_changed.connect(_on_ammo_changed)
	GameManager.grenade_count_changed.connect(_on_grenade_changed)
	GameManager.pow_rescued.connect(_on_pow_changed)
	GameManager.level_changed.connect(_on_level_changed)
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.enemies_remaining_changed.connect(_on_enemies_remaining_changed)

# Input handling (restart / pause) lives in the single _unhandled_input below.

func _create_top_hud() -> void:
	var top_panel := Panel.new()
	top_panel.position = Vector2(0, 0)
	top_panel.size = Vector2(1080, 140)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.1, 0.85)
	bg.border_width_bottom = 3
	bg.border_color = Color(0.3, 0.5, 0.8)
	top_panel.add_theme_stylebox("panel", bg)
	add_child(top_panel)

	health_bar = ProgressBar.new()
	health_bar.position = Vector2(20, 20)
	health_bar.size = Vector2(300, 24)
	health_bar.min_value = 0
	health_bar.max_value = 100
	health_bar.value = 100
	health_bar.show_percentage = false
	top_panel.add_child(health_bar)

	health_label = Label.new()
	health_label.position = Vector2(330, 20)
	health_label.text = "HP: 100"
	health_label.add_theme_font_size_override("font_size", 20)
	top_panel.add_child(health_label)

	score_label = Label.new()
	score_label.position = Vector2(20, 55)
	score_label.text = "SCORE: 0"
	score_label.add_theme_font_size_override("font_size", 22)
	top_panel.add_child(score_label)

	lives_label = Label.new()
	lives_label.position = Vector2(250, 55)
	lives_label.text = "LIVES: 3"
	lives_label.add_theme_font_size_override("font_size", 22)
	top_panel.add_child(lives_label)

	level_label = Label.new()
	level_label.position = Vector2(420, 55)
	level_label.text = "LV: 1"
	level_label.add_theme_font_size_override("font_size", 22)
	top_panel.add_child(level_label)

	weapon_label = Label.new()
	weapon_label.position = Vector2(600, 20)
	weapon_label.text = "WPN: Pistol"
	weapon_label.add_theme_font_size_override("font_size", 22)
	top_panel.add_child(weapon_label)

	weapon_ammo_label = Label.new()
	weapon_ammo_label.position = Vector2(600, 50)
	weapon_ammo_label.text = "AMMO: INF"
	weapon_ammo_label.add_theme_font_size_override("font_size", 18)
	top_panel.add_child(weapon_ammo_label)

	grenade_label = Label.new()
	grenade_label.position = Vector2(850, 20)
	grenade_label.text = "GRENADES: 10"
	grenade_label.add_theme_font_size_override("font_size", 20)
	top_panel.add_child(grenade_label)

	pow_label = Label.new()
	pow_label.position = Vector2(850, 50)
	pow_label.text = "POW: 0"
	pow_label.add_theme_font_size_override("font_size", 18)
	top_panel.add_child(pow_label)

	enemies_label = Label.new()
	enemies_label.position = Vector2(20, 90)
	enemies_label.text = "ENEMIES: 0/0"
	enemies_label.add_theme_font_size_override("font_size", 18)
	top_panel.add_child(enemies_label)

	pause_button = Button.new()
	pause_button.text = "II"
	pause_button.position = Vector2(1010, 20)
	pause_button.size = Vector2(50, 50)
	pause_button.add_theme_font_size_override("font_size", 22)
	pause_button.pressed.connect(_on_pause_button_pressed)
	top_panel.add_child(pause_button)

func _create_touch_controls() -> void:
	var js_size := 240.0
	joystick_origin = Vector2(160, 1750)
	joystick_bg = ColorRect.new()
	joystick_bg.color = Color(1, 1, 1, 0.15)
	joystick_bg.size = Vector2(js_size, js_size)
	joystick_bg.position = joystick_origin - Vector2(js_size * 0.5, js_size * 0.5)
	joystick_bg.z_index = 100
	add_child(joystick_bg)

	joystick_knob = ColorRect.new()
	joystick_knob.color = Color(1, 1, 1, 0.4)
	joystick_knob.size = Vector2(80, 80)
	joystick_knob.position = joystick_origin - Vector2(40, 40)
	joystick_knob.z_index = 101
	add_child(joystick_knob)

	_create_touch_button("btn_jump", "JUMP", Vector2(900, 1700), Color(0.3, 0.7, 1.0, 0.5))
	_create_touch_button("btn_shoot", "FIRE", Vector2(780, 1780), Color(1.0, 0.3, 0.3, 0.5))
	_create_touch_button("btn_grenade", "GRENADE", Vector2(950, 1820), Color(0.3, 0.8, 0.3, 0.5))
	_create_touch_button("btn_vehicle", "VEHICLE", Vector2(700, 1700), Color(0.8, 0.6, 0.2, 0.5))
	_create_touch_button("btn_weapon", "WPN", Vector2(840, 1620), Color(0.7, 0.5, 0.9, 0.5))

func _create_touch_button(btn_name: String, label_text: String, pos: Vector2, color: Color) -> void:
	var btn := ColorRect.new()
	btn.name = btn_name
	btn.color = color
	btn.size = Vector2(120, 120)
	btn.position = pos - Vector2(60, 60)
	btn.z_index = 100
	add_child(btn)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.position = Vector2(0, 45)
	lbl.size = Vector2(120, 30)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	btn.add_child(lbl)
	match btn_name:
		"btn_jump": btn_jump = btn
		"btn_shoot": btn_shoot = btn
		"btn_grenade": btn_grenade = btn
		"btn_vehicle": btn_vehicle = btn
		"btn_weapon": btn_weapon = btn

func _input(event: InputEvent) -> void:
	if not is_touch:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)

# R key restart and pause toggle. process_mode is ALWAYS, so these still
# receive input while the tree is paused.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
	# R key restart — only outside active play (GAME_OVER / VICTORY / PAUSED),
	# so it can't be triggered by accident mid-level.
	if Input.is_action_just_pressed("restart"):
		var st: int = GameManager.current_state
		if st == GameManager.GameState.GAME_OVER or st == GameManager.GameState.VICTORY or st == GameManager.GameState.PAUSED:
			GameManager.restart_game()
			get_viewport().set_input_as_handled()

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if event.position.distance_to(joystick_origin) < 120:
			joystick_active = true
			joystick_pos = event.position
			_update_joystick()
		_check_button(event.position, true)
	else:
		if joystick_active:
			joystick_active = false
			joystick_dir = Vector2.ZERO
			_update_joystick()
		_check_button(event.position, false)

func _handle_drag(event: InputEventScreenDrag) -> void:
	if joystick_active:
		joystick_pos = event.position
		var diff := joystick_pos - joystick_origin
		if diff.length() > 100:
			diff = diff.normalized() * 100
		joystick_dir = diff / 100
		_update_joystick()

func _update_joystick() -> void:
	joystick_knob.position = joystick_origin + joystick_dir * 100 - Vector2(40, 40)
	_simulate_move_input()

func _simulate_move_input() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_up")
	Input.action_release("crouch")
	if joystick_dir.x > 0.3:
		Input.action_press("move_right", joystick_dir.x)
	elif joystick_dir.x < -0.3:
		Input.action_press("move_left", -joystick_dir.x)
	if joystick_dir.y < -0.3:
		Input.action_press("move_up", -joystick_dir.y)
	elif joystick_dir.y > 0.3:
		Input.action_press("crouch", joystick_dir.y)

func _check_button(pos: Vector2, pressed: bool) -> void:
	if _is_in_rect(pos, btn_jump):
		_set_action("jump", pressed)
	elif _is_in_rect(pos, btn_shoot):
		_set_action("shoot", pressed)
	elif _is_in_rect(pos, btn_grenade):
		_set_action("grenade", pressed)
	elif _is_in_rect(pos, btn_vehicle):
		_set_action("enter_vehicle", pressed)
	elif _is_in_rect(pos, btn_weapon):
		_set_action("switch_weapon", pressed)

func _is_in_rect(pos: Vector2, rect: ColorRect) -> bool:
	if not rect:
		return false
	var r := Rect2(rect.global_position, rect.size)
	return r.has_point(pos)

func _set_action(action_name: String, pressed: bool) -> void:
	if pressed:
		Input.action_press(action_name)
	else:
		Input.action_release(action_name)

func _refresh_all() -> void:
	_on_score_changed(GameManager.score)
	_on_lives_changed(GameManager.lives)
	_on_health_changed(GameManager.player_health, GameManager.MAX_HEALTH)
	_on_weapon_changed(GameManager.current_weapon_id)
	_on_ammo_changed(GameManager.current_weapon_id, GameManager.get_current_ammo())
	_on_grenade_changed(GameManager.grenade_count)
	_on_pow_changed(GameManager.pow_rescued_count)
	_on_level_changed(GameManager.current_level)
	_on_enemies_remaining_changed(GameManager.enemies_killed, GameManager.total_enemies)

func _on_score_changed(new_score: int) -> void:
	if score_label:
		score_label.text = "SCORE: %d" % new_score

func _on_lives_changed(new_lives: int) -> void:
	if lives_label:
		lives_label.text = "LIVES: %d" % new_lives

func _on_health_changed(new_hp: int, max_hp: int) -> void:
	if health_bar:
		health_bar.value = float(new_hp) / float(max_hp) * 100
	if health_label:
		health_label.text = "HP: %d/%d" % [new_hp, max_hp]

func _on_weapon_changed(weapon_id: int) -> void:
	if weapon_label:
		weapon_label.text = "WPN: %s" % WeaponData.get_name(weapon_id)
	_on_ammo_changed(weapon_id, GameManager.weapon_ammo.get(weapon_id, 0))

func _on_ammo_changed(weapon_id: int, ammo: int) -> void:
	if weapon_id != GameManager.current_weapon_id:
		return
	if weapon_ammo_label:
		if ammo == -1:
			weapon_ammo_label.text = "AMMO: INF"
		else:
			weapon_ammo_label.text = "AMMO: %d" % ammo

func _on_grenade_changed(count: int) -> void:
	if grenade_label:
		grenade_label.text = "GRENADES: %d" % count

func _on_pow_changed(count: int) -> void:
	if pow_label:
		pow_label.text = "POW: %d" % count

func _on_level_changed(level_num: int) -> void:
	if level_label:
		level_label.text = "LV: %d" % level_num

func _on_enemies_remaining_changed(killed: int, total: int) -> void:
	if enemies_label:
		enemies_label.text = "ENEMIES: %d/%d" % [killed, total]

func _on_state_changed(new_state: GameManager.GameState) -> void:
	match new_state:
		GameManager.GameState.GAME_OVER:
			_hide_pause_overlay()
			_show_overlay("GAME OVER", "Restart")
		GameManager.GameState.VICTORY:
			_hide_pause_overlay()
			_show_overlay("VICTORY!", "Play Again")
		GameManager.GameState.PAUSED:
			_show_pause_overlay()
		_:
			_hide_pause_overlay()
			_hide_overlay()

func _show_overlay(title: String, btn_text: String) -> void:
	if overlay_panel:
		overlay_panel.queue_free()
	overlay_panel = Panel.new()
	overlay_panel.position = Vector2(190, 710)
	overlay_panel.size = Vector2(700, 400)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.1, 0.95)
	bg.border_width_all = 4
	bg.border_color = Color(0.5, 0.7, 1.0)
	overlay_panel.add_theme_stylebox("panel", bg)
	add_child(overlay_panel)

	overlay_label = Label.new()
	overlay_label.text = title
	overlay_label.position = Vector2(0, 80)
	overlay_label.size = Vector2(700, 80)
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_label.add_theme_font_size_override("font_size", 56)
	overlay_panel.add_child(overlay_label)

	overlay_button = Button.new()
	overlay_button.text = btn_text
	overlay_button.position = Vector2(250, 250)
	overlay_button.size = Vector2(200, 60)
	overlay_button.add_theme_font_size_override("font_size", 24)
	overlay_button.pressed.connect(_on_overlay_button)
	overlay_panel.add_child(overlay_button)

func _hide_overlay() -> void:
	if overlay_panel:
		overlay_panel.queue_free()
		overlay_panel = null

func _on_overlay_button() -> void:
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	GameManager.restart_game()

# ============================================================
# Pause
# ============================================================

func _on_pause_button_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	_toggle_pause()

func _toggle_pause() -> void:
	match GameManager.current_state:
		GameManager.GameState.PLAYING:
			GameManager.pause_game()
		GameManager.GameState.PAUSED:
			GameManager.resume_game()

func _show_pause_overlay() -> void:
	if pause_panel:
		return
	AudioManager.play_sfx(AudioManager.SFX_PAUSE)
	pause_panel = Panel.new()
	pause_panel.position = Vector2(290, 760)
	pause_panel.size = Vector2(500, 400)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.1, 0.9)
	bg.border_width_all = 4
	bg.border_color = Color(0.5, 0.7, 1.0)
	pause_panel.add_theme_stylebox("panel", bg)
	add_child(pause_panel)
	var title := Label.new()
	title.text = "PAUSED"
	title.position = Vector2(0, 80)
	title.size = Vector2(500, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	pause_panel.add_child(title)
	pause_resume_button = Button.new()
	pause_resume_button.text = "Resume"
	pause_resume_button.position = Vector2(150, 240)
	pause_resume_button.size = Vector2(200, 60)
	pause_resume_button.add_theme_font_size_override("font_size", 24)
	pause_resume_button.pressed.connect(_on_resume_button_pressed)
	pause_panel.add_child(pause_resume_button)

func _hide_pause_overlay() -> void:
	if pause_panel:
		pause_panel.queue_free()
		pause_panel = null

func _on_resume_button_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	GameManager.resume_game()
