extends CharacterBody2D

const MAX_SPEED = 200
const ACCELERATION = 2500
const FRICTION = 2500
var networked:bool = false
@onready var _animated_sprite = $AnimatedSprite2D
# Get the gravity from the project settings to be synced with RigidBody nodes.
#var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# TODO: make the button for example O hide and show UI, and have a UI with different sliders,
# toggles and stuff and also a "HOST" button which will open a room for friends to join in :)

func _movement(delta):

	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	input_vector.y = Input.get_action_strength("down") - Input.get_action_strength("up")
	input_vector = input_vector.normalized()
	
	for key in ["right", "left", "down", "up"]:
		if Input.is_action_pressed(key):
			_animated_sprite.play("walk_"+key)
	
	if input_vector != Vector2.ZERO:
#		animationPlayer.play("Run")
		velocity = velocity.move_toward(input_vector * MAX_SPEED, ACCELERATION * delta)
	else:
#		animationPlayer.play("Idle")
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	move_and_slide() 
	add_player_state()

func add_player_state():
	var player_state = {"T": Time.get_ticks_msec(), "P": get_global_position()}
	WorldState.add_player_state(player_state)

func _physics_process(delta):
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
#	var direction = Input.get_axis("ui_left", "ui_right")
#	if direction:
#		velocity.x = direction * SPEED
#	else:
#		velocity.x = move_toward(velocity.x, 0, SPEED)
#
#	move_and_slide()
	if(not networked):
		_movement(delta)
