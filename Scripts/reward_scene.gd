extends CenterContainer
class_name RewardScene

## Emitted once the player is done with all rewards and clicks Continue.
signal reward_scene_completed

# ------------------------------------------------------------------------------
#  Config
# ------------------------------------------------------------------------------

var victory_messages : Array[String] = [
	"Combat Cleared",
	"Threat Neutralized",
	"You Survived",
	"Area Secured",
	"Enemy Morale Depleted",
	"From the Debris, You Discover...",
]

enum REWARD_TYPE { Gold, CardDraft, Thingy }

## Inclusive range for the random gold reward.
## Set both values in the inspector on your reward_scene.tscn.
@export var gold_min : int = 10
@export var gold_max : int = 30

# ------------------------------------------------------------------------------
#  Scene refs  (match the existing node structure)
# ------------------------------------------------------------------------------

@onready var message_label : RichTextLabel = $PanelContainer/VBoxContainer/RichTextLabel
@onready var vbox          : VBoxContainer = $PanelContainer/VBoxContainer
@onready var options       : VBoxContainer = $PanelContainer/VBoxContainer/VBoxContainer
# ------------------------------------------------------------------------------
#  Runtime state  (set by RunManager before adding to tree)
# ------------------------------------------------------------------------------

## The RunManager that owns this scene.
var run : RunManager

## The Horde resource that was just defeated.
## RunManager sets this before instantiating the reward scene.
var current_horde : Horde = null

## Tracks resource paths of thingies already offered this reward screen
## so that two Thingy buttons never show the same item.
var _offered_thingy_paths : Array[String] = []

# ------------------------------------------------------------------------------
#  Lifecycle
# ------------------------------------------------------------------------------

func _ready() -> void:
	_display_victory_message()
	_display_rewards()

# ------------------------------------------------------------------------------
#  Internal helpers
# ------------------------------------------------------------------------------

func _display_victory_message() -> void:
	message_label.append_text(victory_messages.pick_random())

func _display_rewards() -> void:
	if current_horde == null or current_horde.rewards.is_empty():
		_add_card_draft_button()
		_add_continue_button()
		return

	for reward_type in current_horde.rewards:
		match reward_type:
			REWARD_TYPE.Gold:
				_add_gold_button()
			REWARD_TYPE.CardDraft:
				_add_card_draft_button()
			REWARD_TYPE.Thingy:
				_add_thingy_button()

	_add_continue_button()

# -- Gold ----------------------------------------------------------------------

func _add_gold_button() -> void:
	var amount : int = randi_range(gold_min, gold_max)

	var btn := Button.new()
	btn.text = "💰 Take %d Gold" % amount
	options.add_child(btn)

	btn.pressed.connect(func() -> void:
		run.award_gold(amount)
		btn.disabled = true
		btn.text = "💰 %d Gold (Claimed)" % amount
	)

# -- Card Draft ----------------------------------------------------------------

func _add_card_draft_button() -> void:
	var btn := Button.new()
	btn.text = "🃏 Draft a Card"
	options.add_child(btn)

	btn.pressed.connect(func() -> void:
		btn.disabled = true
		run.create_draft_screen()
		# Wait for the draft to finish before re-enabling (or just leave disabled).
		await run.current_draft_screen.draft_completed
		btn.text = "🃏 Card Drafted"
	)

# -- Thingy --------------------------------------------------------------------

func _add_thingy_button() -> void:
	# Pick a thingy that isn't already owned AND hasn't been offered on this
	# reward screen yet (handles multiple Thingy rewards from the same horde).
	var thingy : ThingyCondition = run.get_unique_thingy_condition(_offered_thingy_paths)

	if thingy == null:
		push_warning("RewardScene: no unique thingy available to offer.")
		return

	# Reserve this thingy so a second Thingy button picks a different one.
	if thingy.resource_path != "":
		_offered_thingy_paths.append(thingy.resource_path)

	# Use the thingy's display name if it has one, otherwise fall back to the
	# file name so the button always has a meaningful label.
	var display_name : String
	if thingy.get("condition_name") != null and thingy.condition_name != "":
		display_name = thingy.condition_name
	else:
		display_name = thingy.resource_path.get_file().get_basename()
	
	var hbox := HBoxContainer.new()
	hbox.alignment =BoxContainer.ALIGNMENT_CENTER
	var icon := ConditionIcon.new()
	icon.set_condition(thingy)
	var btn := Button.new()
	btn.text = "✨ Take %s" % display_name
	options.add_child(hbox)
	hbox.add_child(icon)
	hbox.add_child(btn)

	btn.pressed.connect(func() -> void:
		run.add_thingy_condition(thingy)
		btn.disabled = true
		btn.text = "✨ %s (Claimed)" % display_name
	)

# -- Continue ------------------------------------------------------------------

func _add_continue_button() -> void:
	var btn := Button.new()
	btn.text = "Continue →"
	vbox.add_child(btn)

	btn.pressed.connect(func() -> void:
		reward_scene_completed.emit()
		queue_free()
)
