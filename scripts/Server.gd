extends Node

@onready var Multiplayer = get_parent().get_parent() # because the parent is just a container
@onready var Client = get_parent().get_node("Client")

var pStates = {}
var tickRate:int = 20 # 20 times per second

# Called when the node enters the scene tree for the first time.
func _ready():
	$ProcessingTimer.start(1.0 / tickRate)

func send_world_state(worldState:Dictionary):
	Multiplayer._send_p2p_packet("all", Steam.P2P_SEND_UNRELIABLE, Multiplayer.Packet.WORLDSTATE, worldState)
	
func update_remote_playerstate(recievedState:Dictionary, playerID:int):
	if(pStates.has(playerID)):
		if pStates[playerID]["T"] < recievedState["T"]:
			# in case the playerstate we've recieved is older than the playerstate that we already have
			pStates[playerID] = recievedState
	else:
		pStates[playerID] = recievedState
