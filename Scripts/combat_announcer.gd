extends Node
class_name CombatAnnouncer

## Spawns a full-screen title that fades in, holds, then fades out.
## Call show_announcement() then free the node — it cleans itself up.

@export var font_size      : int   = 64
@export var hold_duration  : float = 1.2
@export var fade_duration  : float = 1.0
@export var subtitle_size  : int   = 32

func show_announcement(title: String, subtitle: String = "") -> void:
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
	label.text                = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	vbox.add_child(label)

	# Optional subtitle (e.g. "Act 2")
	var sub_label : Label = null
	if subtitle != "":
		sub_label = Label.new()
		sub_label.text                = subtitle
		sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_label.add_theme_font_size_override("font_size", subtitle_size)
		sub_label.modulate = Color(0.85, 0.85, 0.85, 0.0)
		vbox.add_child(sub_label)

	# Tween: fade in → hold → fade out
	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(bg,    "color",      Color(0, 0, 0, 0.55), fade_duration)
	tween.tween_property(label, "modulate:a", 1.0,                  fade_duration)
	if sub_label:
		tween.tween_property(sub_label, "modulate:a", 1.0, fade_duration)

	tween.set_parallel(false)
	tween.tween_interval(hold_duration)
	tween.set_parallel(true)

	tween.tween_property(bg,    "color",      Color(0, 0, 0, 0.0), fade_duration)
	tween.tween_property(label, "modulate:a", 0.0,                  fade_duration)
	if sub_label:
		tween.tween_property(sub_label, "modulate:a", 0.0, fade_duration)

	tween.set_parallel(false)
	await tween.finished
	canvas.queue_free()
