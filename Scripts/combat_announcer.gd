extends Node
class_name CombatAnnouncer

## Spawns a full-screen title that fades in, holds, then flies toward the
## win-condition bar (shrinking as it goes) to reinforce that the bar is
## tracking the win condition.

@export var font_size      : int   = 64
@export var hold_duration  : float = 1.2
@export var fade_duration  : float = 1.5
@export var subtitle_size  : int   = 32
var run_manager : RunManager

func show_announcement(title: String, subtitle: String = "") -> void:
	add_to_group("active_announcement")
	var canvas := CanvasLayer.new()
	canvas.layer = 100   # On top of everything
	add_child(canvas)

	# Dark vignette so text is readable over any background
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)

	# Centre container
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical   = Control.GROW_DIRECTION_BOTH
	vbox.alignment       = BoxContainer.ALIGNMENT_CENTER
	canvas.add_child(vbox)

	# Main title label
	var label := Label.new()
	label.text                 = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	vbox.add_child(label)

	# Optional subtitle (e.g. "Act 2")
	var sub_label : Label = null
	if subtitle != "":
		sub_label = Label.new()
		sub_label.text                 = subtitle
		sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_label.add_theme_font_size_override("font_size", subtitle_size)
		sub_label.modulate = Color(0.85, 0.85, 0.85, 0.0)
		vbox.add_child(sub_label)

	# ── Phase 1: fade in ──────────────────────────────────────────────────────
	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(bg,    "color",      Color(0, 0, 0, 0.55), fade_duration)
	tween.tween_property(label, "modulate:a", 1.0,                  fade_duration)
	if sub_label:
		tween.tween_property(sub_label, "modulate:a", 1.0, fade_duration)

	# ── Phase 2: hold ─────────────────────────────────────────────────────────
	tween.set_parallel(false)
	tween.tween_interval(hold_duration)

	# ── Phase 3: fly toward the win-condition bar ─────────────────────────────
	# The label is inside a CanvasLayer, so its coordinate space is screen-space.
	# get_global_rect().get_center() gives the bar's true screen-space centre,
	# which is the correct target regardless of what CanvasLayer the bar lives in.
	var bar      := run_manager.range_manager.win_condition_bar
	var bar_pos  : Vector2 = bar.get_global_rect().get_center()

	tween.set_parallel(true)

	tween.tween_property(label, "global_position", bar_pos,       fade_duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(label, "scale",           Vector2.ZERO,  fade_duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(bg,    "color",      Color(0, 0, 0, 0.0), fade_duration)
	tween.tween_property(label, "modulate:a", 0.0,                  fade_duration)
	if sub_label:
		tween.tween_property(sub_label, "global_position", bar_pos,      fade_duration) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(sub_label, "scale",           Vector2.ZERO, fade_duration) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(sub_label, "modulate:a", 0.0, fade_duration)

	tween.set_parallel(false)
	await tween.finished
	canvas.queue_free()
	remove_from_group("active_announcement")
