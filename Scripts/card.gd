extends Control
class_name Card

@export var data : CardData
signal card_hovered(card : Card)
@onready var title = $BlankCard/title
@onready var description : RichTextLabel = $BlankCard/description
@onready var cost = $BlankCard/cost
@onready var blank_card = $BlankCard

var player_reference : Character = null

## Title tint for cards retuned by the Workshop (data.modified). Change to taste.
const TITLE_COLOR_MODIFIED : Color = Color(1.0, 0.84, 0.30)   # warm gold

## Tints for cards the Auditor has amended (data.audited). Crimson title reads as
## a malus (vs the Workshop's gold), and the frame gets a red wash. Change to taste.
const TITLE_COLOR_AUDITED : Color = Color(0.86, 0.28, 0.28)   # crimson
const FRAME_TINT_AUDITED  : Color = Color(1.0, 0.70, 0.70)    # red wash on the card frame

## Signature of the last-rendered dynamic card text. When a value that feeds the
## description changes (block, enemies, here, stats, etc.) this string changes and
## we re-render. Mirrors the poll-every-frame approach ConditionIcon uses.
var _last_card_signature : String = ""

# ── Cost modification ─────────────────────────────────────────────────────────
## Set a specific cost, ignoring modifiers. -1 = inactive (use base cost + modifiers).
var cost_override: int = -1
## Relative adjustments from multiple independent sources (conditions, cards, etc.).
var cost_modifiers: Array[int] = []

func get_cost() -> int:
	if cost_override >= 0:
		return cost_override
	var total = data.card_cost
	for mod in cost_modifiers:
		total += mod
	return max(0, total)

func set_cost_override(new_cost: int) -> void:
	cost_override = new_cost
	cost.text = str(get_cost())

func clear_cost_override() -> void:
	cost_override = -1
	cost.text = str(get_cost())

func add_cost_modifier(amount: int) -> void:
	cost_modifiers.append(amount)
	cost.text = str(get_cost())

func remove_cost_modifier(amount: int) -> void:
	cost_modifiers.erase(amount)
	cost.text = str(get_cost())
# ─────────────────────────────────────────────────────────────────────────────

# Visual selection for card targeting
var is_selected_for_targeting: bool = false
var selection_highlight: ColorRect

func _on_mouse_entered() -> void:
	card_hovered.emit(self)

func _on_mouse_exited() -> void:
	card_hovered.emit(null)

func set_data(card_data : CardData):
	data = card_data
	title.text = data.card_name
	_apply_title_style()
	cost.text = str(get_cost())

	if description is RichTextLabel:
		description.bbcode_enabled = true

	refresh_description()


	_connect_to_player_stats()

	# Re-render this card whenever ANY card is played. A once-per-turn buff like
	# Cool Head spends in the middle of a turn (after the first strike resolves),
	# and the spend is announced by Global.card_played. The per-frame signature
	# poll *should* catch the resulting text change, but it depends on this card's
	# _process running every frame; hooking card_played guarantees the whole hand
	# re-evaluates the instant a buff is armed or spent, so no card is left showing
	# a stale buffed number. Connections are auto-cleared when the card is freed.
	if not Global.card_played.is_connected(_on_any_card_played):
		Global.card_played.connect(_on_any_card_played)


## Tints the title and frame to signal the card's state. Audited (a malus from
## the Auditor) takes precedence over the Workshop's modified glow. self_modulate
## on the frame sprite tints only the frame art, never the text children, so the
## card stays readable. Called from set_data and again whenever a flag flips on a
## card that's already on screen (the Auditor calls this after amending).
func _apply_title_style() -> void:
	if not title or not data:
		return
	if data.audited:
		title.add_theme_color_override("default_color", TITLE_COLOR_AUDITED)
	elif data.modified:
		title.add_theme_color_override("default_color", TITLE_COLOR_MODIFIED)
	else:
		title.remove_theme_color_override("default_color")

	if blank_card:
		blank_card.self_modulate = FRAME_TINT_AUDITED if data.audited else Color.WHITE


## Resolve the player once, preferring the cached reference. Returns null if the
## player isn't in the scene yet (e.g. previews outside combat).
func _get_player() -> Character:
	if player_reference and is_instance_valid(player_reference):
		return player_reference
	return get_tree().get_first_node_in_group("player")


## Cheap-to-compute string that uniquely reflects the current dynamic card text.
## Used to decide whether a re-render is actually needed this frame.
func _compute_card_signature(player) -> String:
	if not data:
		return ""
	var sig := ""
	for action in data.actions:
		if action == null:
			continue
		sig += action.get_card_text(player) + "|"
	return sig


## Poll for value changes every frame. block has no signal, and enemies/here come
## from the RangeManager rather than player stats, so signal-driven refresh can't
## catch them. Re-render only when the resulting text actually changes.
func _process(_delta: float) -> void:
	if not data:
		return
	var player = _get_player()
	if not player:
		return
	var sig := _compute_card_signature(player)
	if sig != _last_card_signature:
		refresh_description()


## Any card was just played — a once-per-turn buff may have armed or spent, so
## re-render this card's face. DEFERRED on purpose: Cool Head (and any other
## buff) also listens to card_played to spend itself, and handler order isn't
## guaranteed — cards were usually connected first, so a direct refresh here would
## render the buff while it's still live. call_deferred pushes this to the end of
## the frame, after every card_played handler (including the spend) has run, so
## get_card_text reflects the post-spend value. refresh_description also updates
## _last_card_signature, keeping the per-frame poll in sync.
func _on_any_card_played(_card_data) -> void:
	call_deferred("refresh_description")


func refresh_description():
	var swag = preload("res://Art/swag.png")
	var marbles = preload("res://Art/marbles.png")
	var guts = preload("res://Art/guts.png")
	var hustle = preload("res://Art/hustle.png")
	var heat = preload("res://Art/heat.png")
	var mojo = preload("res://Art/marbles.png")
	if not data:
		return


	var player = _get_player()
	if not player:
		return

	# Record the signature we're rendering so _process won't re-render until a
	# value actually changes.
	_last_card_signature = _compute_card_signature(player)

	var desc = ""
	var action_count = data.actions.size()

	for i in range(action_count):
		var action : Action = data.actions[i]

		# Add the action description (actions now handle their own range display)
		desc += action.get_card_text(player)

		# Add newline between actions (but not after the last one)
		if i < action_count - 1:
			desc += "\n"

	desc += _shared_range_suffix()

	var regex = RegEx.new()
	regex.compile("§([+\\-]?\\d+)§")
	desc = regex.sub(desc, "[color=green]$1[/color]", true)
	regex.compile("‡([+\\-]?\\d+)‡")
	desc = regex.sub(desc, "[color=white]$1[/color]", true)
	desc = desc.replace("swag", "[img=16x16]res://Art/swag.png[/img]")
	desc = desc.replace("marbles", "[img=16x16]res://Art/marbles.png[/img]")
	desc = desc.replace("guts", "[img=16x16]res://Art/guts.png[/img]")
	desc = desc.replace("hustle", "[img=16x16]res://Art/hustle.png[/img]")
	desc = desc.replace("heat", "[img=16x16]res://Art/heat.png[/img]")
	desc = desc.replace("mojo", "[img=16x16]res://Art/mojo.png[/img]")



	description.parse_bbcode(desc)

	# ── Keyword tags ──────────────────────────────────────────────────────
	# Prepend / append keyword lines so they always appear regardless of actions
	var keyword_prefix := ""
	var keyword_suffix := ""
	if data.audited:
		keyword_prefix += "[b][color=#db4747]Audited[/color][/b]\n"
	if data.volatile:
		keyword_prefix += "[b][color=orange]Volatile[/color][/b]\n"
	if data.fickle:
		keyword_prefix += "[b][color=purple]Fickle[/color][/b]\n"
	if data.exhaust:
		keyword_suffix += "\n[b][color=red]Exhaust[/color][/b]"

	if keyword_prefix != "" or keyword_suffix != "":
		var full = keyword_prefix + desc + keyword_suffix
		description.parse_bbcode(full)

	# Shrink the font if needed so long descriptions never spawn a scrollbar.
	_fit_description_to_box()


## Builds the card's single range clause: " - Range: X". Actions that print their
## range inline (AttackAction) own that value, so we only emit a line for ranges
## NOT already shown inline — and identical ranges collapse to one entry. Result:
## an apply-condition card finally shows its range, while an attack + apply at the
## same range still show "Range" only once. Returns "" when there's nothing to add.
func _shared_range_suffix() -> String:
	if not data:
		return ""
	var inline_ranges := {}
	var pending_ranges := {}
	for action in data.actions:
		if action == null or not action.shows_range():
			continue
		if action.displays_range_inline():
			inline_ranges[action.max_range] = true
		else:
			pending_ranges[action.max_range] = true

	var extra := []
	for r in pending_ranges:
		if not inline_ranges.has(r):
			extra.append(r)
	if extra.is_empty():
		return ""

	extra.sort()
	var parts := []
	for r in extra:
		parts.append("‡%d‡" % r)   # white literal, matched by the ‡N‡ regex
	return " - Range: %s" % ", ".join(parts)


## Shrinks the description font until the text fits the label's box, so long
## descriptions (turrets, or cards the Auditor has amended) never spawn a
## scrollbar. Resets to the theme size first, so short cards are unaffected and
## a card whose text got shorter can grow back to full size.
func _fit_description_to_box() -> void:
	if not description:
		return
	description.scroll_active = false           # never show a scrollbar
	var box_h := description.size.y
	if box_h <= 1.0:
		return
	description.remove_theme_font_size_override("normal_font_size")
	var fsize := description.get_theme_font_size("normal_font_size")
	while fsize > 8 and description.get_content_height() > box_h:
		fsize -= 1
		description.add_theme_font_size_override("normal_font_size", fsize)


## Plain-text breakdown for the card-hover tooltip: formula explanations for each
## value, plus keyword-condition descriptions. card_handler calls this. Empty
## string => no tooltip is shown.
func get_card_tooltip_text() -> String:
	if not data:
		return ""
	var player = _get_player()
	if not player:
		return ""
	var lines : Array[String] = []
	for action in data.actions:
		if action == null:
			continue
		var t : String = action.get_tooltip_text(player)
		if t != "":
			lines.append(t)
	return "\n".join(lines)


func _ready():
	for each in data.actions:
		var player = _get_player()
		each.player = player

	# Create selection highlight for card targeting
	_create_selection_highlight()

func _connect_to_player_stats():
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		# Retry on next frame when player might be ready
		call_deferred("_connect_to_player_stats")
		return

	if not player.has_signal("stats_changed"):
		return

	# Disconnect first if already connected (to avoid duplicate connections)
	if player_reference and player_reference.stats_changed.is_connected(_on_player_stats_changed):
		player_reference.stats_changed.disconnect(_on_player_stats_changed)

	player.stats_changed.connect(_on_player_stats_changed)
	player_reference = player

func _on_player_stats_changed():
	# When player stats change, refresh this card's description
	refresh_description()

# ============================================================================
# CARD TARGETING VISUAL FEEDBACK
# ============================================================================

func _create_selection_highlight():
	"""Create a highlight overlay for when card is selected for targeting"""
	selection_highlight = ColorRect.new()
	selection_highlight.color = Color(1, 1, 0, 0.3)  # Yellow semi-transparent
	selection_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection_highlight.visible = false
	selection_highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(selection_highlight)
	selection_highlight.z_index = -1  # Behind card content

func set_selected(selected: bool):
	"""Toggle selection highlight - called by card_handler during targeting"""
	is_selected_for_targeting = selected
	if selection_highlight:
		selection_highlight.visible = selected

		if selected:
			# Add a pulse animation
			var tween = create_tween()
			tween.set_loops()
			tween.tween_property(selection_highlight, "color:a", 0.5, 0.5)
			tween.tween_property(selection_highlight, "color:a", 0.3, 0.5)

func set_selectable(selectable: bool):
	"""Visual feedback that card can be selected (optional)"""
	# You could add a subtle glow or border here if desired
	# For now, we just use the hover effect
	pass
