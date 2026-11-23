extends CanvasLayer

const Rules = preload("res://scripts/army_rules.gd")
const Groups = preload("res://scripts/groups.gd")

var _blue_fill: ColorRect
var _red_fill: ColorRect
var _blue_text: Label
var _red_text: Label
var _stats: RichTextLabel
var _banner: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)
	layer = 20
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_make_bar(root, 0.0, 28.0, Color(0, 0, 0, 0.55))
	_make_bar(root, 1.0, -308.0, Color(0, 0, 0, 0.55))
	_blue_fill = _make_bar(root, 0.0, 28.0, Color("3c9dff"))
	_red_fill = _make_bar(root, 1.0, -308.0, Color("e25b55"))
	_blue_text = _make_label(root, 0.0, 28.0, 6.0, 320.0, 22.0, 16)
	_red_text = _make_label(root, 1.0, -348.0, 6.0, 320.0, 22.0, 16)

	var panel := ColorRect.new()
	panel.color = Color(0, 0, 0, 0.58)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 12.0
	panel.offset_top = -248.0
	panel.offset_right = 760.0
	panel.offset_bottom = -10.0
	root.add_child(panel)

	_stats = RichTextLabel.new()
	_stats.bbcode_enabled = true
	_stats.scroll_active = false
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD
	_stats.add_theme_font_size_override("normal_font_size", 16)
	_stats.add_theme_color_override("default_color", Color.WHITE)
	_stats.anchor_top = 1.0
	_stats.anchor_bottom = 1.0
	_stats.offset_left = 24.0
	_stats.offset_top = -238.0
	_stats.offset_right = 744.0
	_stats.offset_bottom = -18.0
	root.add_child(_stats)

	_banner = _make_label(root, 0.5, -340.0, 58.0, 680.0, 88.0, 20)
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD


func _process(_delta: float) -> void:
	var battle = get_parent()
	var blue = _king(0)
	var red = _king(1)
	if blue != null:
		_set_fill(_blue_fill, 28.0, blue.hp / blue.max_hp)
		_blue_text.text = "Blue King  %d" % roundi(blue.hp)
	if red != null:
		_set_fill(_red_fill, -308.0, red.hp / red.max_hp)
		_red_text.text = "Red King  %d" % roundi(red.hp)
	var player = _player()
	if player != null:
		_stats.text = _stats_text(player)
	if battle != null and battle.finished:
		var winner := "Blue" if int(battle.winner_id) == 0 else "Red"
		_banner.text = "%s victory\nPress R to play again" % winner
	elif player != null and player.toast_left > 0.0:
		_banner.text = str(player.toast)
	else:
		_banner.text = "2v2. You and ALLY against GUARD and SIEGE.\nDestroy the red King. Feed the army, or the soldiers starve."


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("restart"):
		return
	var battle = get_parent()
	if battle == null or not battle.finished:
		return
	get_tree().paused = false
	get_tree().reload_current_scene()


func _stats_text(player) -> String:
	var state := Rules.spirit_state(player.spirit, player.fed)
	var upkeep := Rules.upkeep_rate(player.spirit)
	var revive_deaths := int(player.deaths) if not player.alive else int(player.deaths) + 1
	var store_line := "Not in a friendly store. Pouch food is the only ration."
	if player.nearby_storage != null:
		store_line = "Inside %s. Stored food %d. The army eats the pouch first, then this store." % [str(player.nearby_storage.storage_name), roundi(float(player.nearby_storage.food))]
	var slot_line := "Stone markers are the only build sites."
	if player.nearby_slot != null:
		var slot = player.nearby_slot
		if slot.structure != null:
			slot_line = "Slot %d: %s, %d HP." % [int(slot.slot_index), str(slot.structure.kind), roundi(float(slot.structure.hp))]
		else:
			slot_line = "Empty slot %d.  1 Barricade %d mat    2 Spikes %d    3 Catapult %d    4 Campsite %d food" % [
				int(slot.slot_index),
				roundi(Rules.BARRICADE_COST),
				roundi(Rules.TRAP_COST),
				roundi(Rules.CATAPULT_COST),
				roundi(Rules.CAMPSITE_COST),
			]
	var head := "Soldiers %d/100" % roundi(player.soldiers)
	if not player.alive:
		head = "CAPTAIN DOWN"
	return "[b]%s[/b]    Spirit %d (%s)    Upkeep %.2f food/s\nPouch  food %d/%d    materials %d/%d\n%s\nRevive cost %d food (24 × 1.5^deaths). Training is 8 food for 10 soldiers, from castle food.\nE drops pouch food at your castle or campsite. With empty hands at your castle, E trains. K dashes. J or left click attacks.\n%s" % [
		head,
		roundi(player.spirit),
		state,
		upkeep,
		roundi(player.carried_food),
		roundi(Rules.CARRY_FOOD_MAX),
		roundi(player.carried_materials),
		roundi(Rules.CARRY_MAT_MAX),
		store_line,
		roundi(Rules.revive_cost(revive_deaths)),
		slot_line,
	]


func _player():
	for captain in Groups.get_all(get_tree(), "captains"):
		if not captain.ai_controlled:
			return captain
	return null


func _king(team_id: int):
	for king in Groups.get_all(get_tree(), "kings"):
		if int(king.team_id) == team_id:
			return king
	return null


func _make_label(parent: Control, anchor_x: float, x: float, y: float, w: float, h: float, size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.anchor_left = anchor_x
	label.anchor_right = anchor_x
	label.offset_left = x
	label.offset_top = y
	label.offset_right = x + w
	label.offset_bottom = y + h
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	parent.add_child(label)
	return label


func _make_bar(parent: Control, anchor_x: float, x: float, color: Color) -> ColorRect:
	var bar := ColorRect.new()
	bar.color = color
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.anchor_left = anchor_x
	bar.anchor_right = anchor_x
	bar.offset_left = x
	bar.offset_top = 30.0
	bar.offset_right = x + 280.0
	bar.offset_bottom = 46.0
	parent.add_child(bar)
	return bar


func _set_fill(fill: ColorRect, left: float, pct: float) -> void:
	fill.offset_left = left
	fill.offset_right = left + 280.0 * clampf(pct, 0.0, 1.0)
