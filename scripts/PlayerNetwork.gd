#extends CharacterBody2D
#
#var MAX_SPEED = 400
#var ACCELERATION = 2500
#var FRICTION = 2500
##var velocity = Vector2()
#var input_vector = Vector2.ZERO
#
#func _ready(): # once node entered tree
#	randomize()
#	var rng = RandomNumberGenerator.new()
#	rng.randomize()
#	var randx = rng.randf_range(150.0, 750.0)
#	var randy = rng.randf_range(125.0, 450.0)
#	print("random start: (" + str(randx) + "," + str(randy) + ")")
#	position = Vector2(randx, randy)
#
#func _physics_process(delta):
#	if input_vector != Vector2.ZERO:
#		for key in ["right", "left", "down", "up"]:
#			if Input.is_action_pressed(key):
#				_animated_sprite.play("walk_"+key)
#		velocity = velocity.move_toward(input_vector * MAX_SPEED, ACCELERATION * delta)
#
#		if not Global.isPlayerHost:
#			var sendVector = PoolByteArray()
#			sendVector.append(256)
#			sendVector.append_array(var2bytes({"message":input_vector, "from":Global.my_steam_id}))
#			$"../Multiplayer"._send_P2P_Packet(sendVector, 1, 0)
#
#	else:
#		animationPlayer.play("Idle")
#		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
#
#	velocity = move_and_slide(velocity)
#
#func update_vector(vector):
#	input_vector = vector
