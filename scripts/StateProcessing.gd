extends Node

func _ready():
	get_parent().get_node("ProcessingTimer").timeout.connect(_process_state)

func _process_state():
	if not get_parent().pStates.is_empty():
		var worldState = get_parent().pStates.duplicate(true)
		for player in worldState.keys():
			worldState[player].erase("T")
		worldState["T"] = Time.get_ticks_msec()# .get_system_time_msecs()
		
		get_parent().send_world_state(worldState)
