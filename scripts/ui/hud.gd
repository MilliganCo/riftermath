extends Control

signal combat_activity(strength: float)

var player: PlayerController
var capture: GestureCapture
var hits: int = 0
var kills: int = 0
var air_cuts: int = 0
var active_zone: String = ""
var _hurt_time: float = 0.0
var _hit_time: float = 0.0
var _damage: float = 0.0
var _lethal: bool = false
var _aim_name: String = ""
var _font: Font
var director: Node
var show_scoreboard: bool = false
var show_help: bool = false
var preview_ability: StringName = &"SCAR"
var style_points: float = 0.0
var last_ability: StringName = &""
var style_event: String = ""
var _style_time: float = 0.0
var notice: String = ""
var notice_remaining: float = 0.0
var context_hint: String = ""
var dialog_text: String = ""
var dialog_remaining: float = 0.0

const INK := Color("e8dcc5")
const CYAN := Color("77e0df")
const MUTED := Color("aaa08b")
const ORANGE := Color("ff8055")


func _ready() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono"])
	_font = font


func bind(controller: PlayerController, gesture: GestureCapture) -> void:
	player = controller
	capture = gesture
	player.damaged.connect(_on_player_damaged)


func register_fragment_cut() -> void:
	air_cuts += 1
	_hit_time = 0.22
	_damage = 0.0
	_lethal = false
	_award(35, "AIR CUT")
	_sound(&"air_cut")
	combat_activity.emit(0.12)


func register_cast(ability: StringName) -> void:
	if ability != last_ability:
		_award(12, "VARIETY")
	last_ability = ability
	preview_ability = ability
	_sound(RiftCaster.SOUNDS.get(ability, &"cast"))
	combat_activity.emit(0.10)


func register_parry() -> void:
	_award(90, "PARRY / REVERSED")
	_sound(&"parry")
	combat_activity.emit(0.22)


func register_recovery(health: float, energy: float) -> void:
	notice = "+%d INTEGRITY / +%d RIFT" % [int(health), int(energy)]
	notice_remaining = 1.2
	_sound(&"mend")


func _award(points: float, label: String) -> void:
	style_points = minf(1500, style_points + points)
	style_event = label
	_style_time = 2.0


func style_rank() -> String:
	return "SSS" if style_points >= 900 else ("SS" if style_points >= 650 else ("S" if style_points >= 440 else ("A" if style_points >= 270 else ("B" if style_points >= 140 else ("C" if style_points >= 50 else "D")))))


func _sound(cue: StringName) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_node("Audio"):
		scene.get_node("Audio").play_cue(cue)


func _on_player_damaged(_amount: float) -> void:
	_hurt_time = 0.30


func register_hit(amount: float, killed: bool) -> void:
	hits += 1
	kills += int(killed)
	_damage = amount
	_lethal = killed
	_hit_time = 0.30
	_award(amount * 0.4 + (60 if killed else 8) + (25 if not player.is_on_floor() else 0), "AIR SEVER" if killed and not player.is_on_floor() else ("SEVERED" if killed else "CONTACT"))
	_sound(&"kill" if killed else &"hit")
	combat_activity.emit(0.18 if killed else 0.08)


func _process(delta: float) -> void:
	_hit_time = maxf(0.0, _hit_time - delta)
	_hurt_time = maxf(0.0, _hurt_time - delta)
	_style_time = maxf(0.0, _style_time - delta)
	style_points = maxf(0, style_points - delta * (8.0 if _style_time <= 0 else 1.0))
	notice_remaining = maxf(0, notice_remaining - delta)
	dialog_remaining = maxf(0, dialog_remaining - delta)
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var from := player.camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - player.camera.global_basis.z * 80.0, 13)
	var result := player.get_world_3d().direct_space_state.intersect_ray(query)
	_aim_name = ""
	if not result.is_empty() and result["collider"] is EnemyController:
		var enemy := result["collider"] as EnemyController
		if not enemy.dead:
			_aim_name = "%s / %d HP" % [enemy.target_name, int(enemy.hp)]
	elif not result.is_empty() and result["collider"] is SeverableDebris:
		var piece := result["collider"] as SeverableDebris
		_aim_name = "FRAGMENT / CUT %d OF %d" % [piece.generation, SeverableDebris.MAX_GENERATION]
	elif not result.is_empty() and result["collider"] is CombatBot:
		var bot := result["collider"] as CombatBot
		_aim_name = "%s%s / %d HP  %s" % ["ALLY / " if bot.team_id == player.team_id else "", bot.bot_name, int(bot.hull.hp), bot.traits.hint()]
	elif not result.is_empty() and result["collider"] is QuestPylon:
		_aim_name = "ПЕЧАТЬ / " + String(result["collider"].required)


func _text(at: Vector2, text: String, font_size: int, color: Color = INK) -> void:
	draw_string(_font, at + Vector2(1, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.04, 0.025, 0.02, 0.8))
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw() -> void:
	if not is_instance_valid(player):
		return
	var center := size * 0.5
	var margin := 32.0
	_text(Vector2(margin, 44), "R I F T E R M A T H", 24)
	_text(Vector2(margin, 66), MatchDirector.MODE_NAMES[director.mode] if is_instance_valid(director) else "01 / SPATIAL RESEARCH FACILITY", 13, MUTED)
	_text(Vector2(size.x - 345, 43), String(preview_ability) + (" / DRAWING" if capture.active else " / READY"), 20, RiftCaster.tint_for(preview_ability))
	_text(Vector2(size.x - 345, 87), RiftCaster.EFFECTS.get(preview_ability, ""), 12, RiftCaster.tint_for(preview_ability))
	_text(Vector2(size.x - 300, 66), "HITS %02d  SEVERED %02d  CUTS %02d" % [hits, kills, air_cuts], 13, MUTED)
	if is_instance_valid(director):
		_text(Vector2(size.x * 0.5 - 170, 42), director.status_text(), 12 if director.mode == 3 else 14, INK)
		if director.mode == 3:
			_text(Vector2(size.x * 0.5 - 170, 65), director.navigation_hint(), 12, INK)
	else:
		_text(Vector2(size.x * 0.5 - 110, 42), active_zone + " / LIVE FIRE" if not active_zone.is_empty() else "SAFE / TRAINING", 15, ORANGE if not active_zone.is_empty() else CYAN)
	if _hurt_time > 0.0:
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color(1.0, 0.18, 0.10, _hurt_time * 2.0), false, 5.0)
	draw_circle(center, 1.6, CYAN)
	for offset in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(center + offset * 7, center + offset * 12, Color(CYAN, 0.7), 1.0, true)
	if _hit_time > 0.0:
		var color := ORANGE if _lethal else INK
		for sign_x in [-1.0, 1.0]:
			for sign_y in [-1.0, 1.0]:
				var axis := Vector2(sign_x, sign_y)
				draw_line(center + axis * 13, center + axis * 20, color, 2.0, true)
		_text(center + Vector2(28, -24), "%d%s" % [int(_damage), " / SEVERED" if _lethal else ""] if _damage > 0 else "AIR CUT", 17, color)
	if not _aim_name.is_empty():
		_text(center + Vector2(-80, 52), _aim_name, 13, ORANGE)
	if notice_remaining > 0:
		_text(center + Vector2(-95, 85), notice, 15, INK)
	if not context_hint.is_empty():
		_text(center + Vector2(-150, 112), context_hint, 16, INK)
	if dialog_remaining > 0:
		draw_rect(Rect2(250, 155, 930, 145), Color(0.025, 0.02, 0.015, 0.96))
		var dialogue := dialog_text.split("\n")
		for i in range(mini(4, dialogue.size())):
			_text(Vector2(275, 190 + i * 27), dialogue[i], 16, INK)
	_text(Vector2(margin, size.y - 120), "INTEGRITY %03d / %03d" % [int(player.hp), int(player.max_hp)], 18, ORANGE if player.hp < 40 else INK)
	_text(Vector2(size.x - 260, 108), "STYLE " + style_rank() + " / " + str(int(style_points)), 20, CYAN)
	if _style_time > 0:
		_text(Vector2(size.x - 260, 130), style_event, 13, MUTED)
	if not player.rune.is_empty():
		_text(Vector2(size.x - 260, 151), RiftRunes.NAMES.get(player.rune, ""), 12, INK)
	_text(Vector2(margin + 270, size.y - 120), "RIFT %03d / RMB PARRY" % int(player.energy), 14, CYAN)
	var state := "INCISION  /  %.2f s  /  %.1f m" % [capture.duration, GestureRecognizer.path_length(capture.points)] if capture.active else "HOLD LMB + DRAW   /   RELEASE TO RUPTURE"
	_text(Vector2(margin, size.y - 90), state, 16, CYAN)
	_text(Vector2(margin, size.y - 53), "%04.1f" % player.horizontal_speed(), 32)
	_text(Vector2(margin + 100, size.y - 53), "m/s  /  " + ("SLIDE" if player.sliding else ("AIR" if not player.is_on_floor() else "GROUND")), 14, MUTED)
	var dash_ready := 1.0 - player.dash_cooldown_remaining / player.dash_cooldown
	draw_rect(Rect2(margin, size.y - 38, 180, 3), Color("263b42"))
	draw_rect(Rect2(margin, size.y - 38, 180 * clampf(dash_ready, 0, 1), 3), CYAN)
	_text(Vector2(size.x - 430, size.y - 67), "WASD  MOVE     SPACE  JUMP x2", 14)
	_text(Vector2(size.x - 430, size.y - 44), "SHIFT DASH  CTRL SLIDE  R RESET  ESC CURSOR", 13, MUTED)
	if show_scoreboard and is_instance_valid(director) and director.mode != 3:
		draw_rect(Rect2(390, 125, 650, 400), Color(0.02, 0.03, 0.03, 0.94))
		var lines: PackedStringArray = director.board_text().split("\n")
		for i in range(lines.size()):
			_text(Vector2(420, 170 + i * 27), lines[i], 18)
	if show_help:
		draw_rect(Rect2(250, 120, 910, 260), Color(0.02, 0.03, 0.03, 0.96))
		_text(Vector2(280, 160), "DRAW / RELEASE   |   KEEP MOVING", 22, CYAN)
		var abilities := [&"SCAR", &"FANG", &"CHAINBREAK", &"HOLLOW", &"SIMPLEX", &"FOLD", &"HYPERCUT"]
		for i in range(abilities.size()):
			var ability: StringName = abilities[i]
			_text(Vector2(280 + (i / 4) * 440, 198 + (i % 4) * 30), String(ability) + " : " + RiftCaster.EFFECTS[ability], 15, RiftCaster.tint_for(ability))
		_text(Vector2(280, 326), "КОМБО: КРУГ + ТРЕУГОЛЬНИК ВНУТРЬ = ЗАМКНУТЫЙ КАРМАН", 14, RiftCaster.tint_for(&"HYPERCUT"))
		_text(Vector2(280, 356), "ПКМ PARRY / F7 16-32 COLORS / H CLOSE", 14, MUTED)
	if player.dead:
		_text(center - Vector2(180, 80), "SEVERED / RECONSTRUCTING", 23, INK)
	if not player.mouse_captured and player.allow_click_capture:
		draw_rect(Rect2(center - Vector2(270, 80), Vector2(540, 160)), Color(0.025, 0.06, 0.08, 0.95))
		_text(center + Vector2(-226, -20), "SIMULATION LIVE / CURSOR FREE", 22, CYAN)
		_text(center + Vector2(-226, 20), "CLICK OR ESC TO CAPTURE MOUSE", 16)
		_text(center + Vector2(-226, 48), "Draw a stroke. Release it into the target.", 13, MUTED)
