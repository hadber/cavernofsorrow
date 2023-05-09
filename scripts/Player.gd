extends CharacterBody2D

const MAX_SPEED: int = 200
const ACCELERATION: int = 2500
const FRICTION: int = 2500
var networked: bool = false
var my_color: Color

@onready var _animated_sprite = $AnimatedSprite2D
# Get the gravity from the project settings to be synced with RigidBody nodes.
#var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func set_color(a_new_color):
	my_color = a_new_color
	self.modulate = my_color

func spawn_me(where:Vector2):
	position = where

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
	if(not networked):
		_movement(delta)

func remote_movement(where:Vector2):
	position = where
