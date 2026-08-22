extends Node3D
class_name Main

#@onready var anchor_manager: OpenXRFbSpatialAnchorManager = $XROrigin3D/OpenXRFbSpatialAnchorManager
@onready var scene_manager: OpenXRFbSceneManager = $XROrigin3D/OpenXRFbSceneManager
@onready var xr_origin = $XROrigin3D
@onready var xr_camera = $XROrigin3D/XRCamera3D
@onready var ctrl_right: XRController3D = $XROrigin3D/XRController3D_right
@onready var ctrl_left: XRController3D = $XROrigin3D/XRController3D_left
@onready var node_right: Node3D = $XROrigin3D/XRController3D_right/ZForward/RightTransform

@onready var screen_rect_mesh = $ActiveScreenRect
@onready var cursor_left: MeshInstance3D = $CursorLeft
@onready var cursor_right: MeshInstance3D = $CursorRight
@onready var udp := PacketPeerUDP.new()
@onready var outAddress := ""
@onready var outPort := 0
@onready var myIP : PackedByteArray
const broadcastAddress := "224.0.0.1"
var RECONNECT_TIME := 5.
var READDRESS_TIME := 15.
var lastAddressRequest := 0.
var lastReconnect := 0.
const SEND_PORT := 45128
const RECEIVE_PORT := 45129
const DEFAULT_ADDRESS := "" 

static var screens : Array[Rectangle3D] = [] 

func addScreen(screen: Array) -> void:
	print("MR DEBUG: addScreen")	
	for s in screens:
		if screen[0].is_equal_approx(s.bottomLeft) and screen[1].is_equal_approx(s.rightward) and screen[2].is_equal_approx(s.upward): 
			print("MR DEBUG: duplicate")	
			return
	var rect := Rectangle3D.new()
	rect.bottomLeft = screen[0]
	rect.rightward = screen[1]
	rect.upward = screen[2]
	rect.visible = true
	add_child(rect)
	screens.append(rect)

var xr_interface: OpenXRInterface
var active_screen_plane: Plane
var active_screen_transform: Transform3D
var active_screen_size: Vector2
var screen_found: bool = false

var mat_blue: StandardMaterial3D
var mat_red: StandardMaterial3D

func _ready():
	if OS.get_name() == "Android":
		var permissions = OS.get_granted_permissions()
		if not permissions.has("com.oculus.permission.USE_SCENE"):
			print("MR DEBUG: Requesting USE_SCENE permission...")
			OS.request_permission("com.oculus.permission.USE_SCENE")	
		else:
			print("MR DEBUG: Have USE_SCENE permission.")
	
	# Generate Materials programmatically
	mat_blue = StandardMaterial3D.new()
	mat_blue.albedo_color = Color.BLUE
	mat_blue.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	cursor_left.material_override = mat_blue
	cursor_left.visible = false
	
	mat_red = StandardMaterial3D.new()
	mat_red.albedo_color = Color.RED
	mat_red.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	cursor_right.material_override = mat_red
	cursor_right.visible = false

	# Activate MR immediately on start
	print("MR DEBUG: hello")
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface:
		if xr_interface.is_initialized():
			xr_interface.session_begun.connect(_on_openxr_session_begun)
		else:
			print("MR DEBUG: CRITICAL - OpenXR interface found, but failed to initialize!")
	else:
		print("MR DEBUG: CRITICAL - No OpenXR interface found in XRServer!")
	ctrl_left.button_pressed.connect(_on_button_pressed)
	
	_multicast()
				
	_transmit(DEFAULT_ADDRESS, SEND_PORT)

func _multicast() -> void:
	var godot_singleton = Engine.get_singleton("AndroidRuntime")
	if not godot_singleton:
		print("MR DEBUG no Android singleton")
		return
	var godot_activity = godot_singleton.getActivity()
	if godot_activity:
		print("MR DEBUG godot_activity")
		var context_class = JavaClassWrapper.wrap("android.content.Context")
		var wifi_manager = godot_activity.getSystemService(context_class.WIFI_SERVICE)
		if wifi_manager:
			var lock = wifi_manager.createMulticastLock("godot_quest_lock")
			lock.setReferenceCounted(false)
			lock.acquire()
			print("MR DEBUG acquiring multicast")
	else:
		print("MR DEBUG no godot_activity")
	

func get_network_data():
	var ip_addresses := IP.get_local_addresses()
	
	for ip in ip_addresses:
		# Exclude loopback (127.0.0.1), IPv6 addresses, and non-LAN addresses
		if ip.is_valid_ip_address() and not ip.begins_with("127.") and not ip.contains(":"):
			# Common local subnet prefixes
			if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
				print("MR DEBUG ip ", ip)
				var parts := ip.split(".")
				var bytes := PackedByteArray()
				for part in parts:
					bytes.append(part.to_int())
				myIP = bytes
				return
				
	myIP = PackedByteArray()

func _transmit(address: String, port: int) -> void:
	lastReconnect = Time.get_unix_time_from_system()
	outAddress = address
	outPort = port
	print("MR DEBUG setting up network")
	get_network_data()
	if myIP.size() == 4:
		udp.bind(RECEIVE_PORT)
		if outAddress == "":
			print("MR DEBUG enabling broadcast")
			udp.set_broadcast_enabled(true)
		else:
			print("MR DEBUG disabling broadcast")
			udp.set_broadcast_enabled(false)
		var a := broadcastAddress if outAddress == "" else outAddress
		#var resolved := IP.resolve_hostname(a, IP.TYPE_IPV4)
		print("MR DEBUG sending to ", a, " ", outPort)
		udp.set_dest_address(a, outPort)
	
func _sendData(hand: String, x: float, y: float, buttons: int) -> void:
	if myIP.size() != 4:
		if Time.get_unix_time_from_system() >= lastReconnect + RECONNECT_TIME:
			print("MR DEBUG reconnecting")
			_transmit(outAddress, outPort)
			if myIP.size() != 4:
				return
			
	var out := "QuestLightGun %d:%d:%d:%d %s %.5f %.5f %d" % [myIP[0],myIP[1],myIP[2],myIP[3], hand, x, y, buttons]
	udp.put_packet(out.to_utf8_buffer())

func _on_openxr_session_begun():
	get_viewport().use_xr = true

	# Clear the background to allow Passthrough to show
	get_viewport().transparent_bg = true

	# for your specific app session.
	if get_viewport().world_3d.fallback_environment:
		get_viewport().world_3d.fallback_environment.background_mode = Environment.BG_CLEAR_COLOR
	if get_viewport().world_3d.environment:
		get_viewport().world_3d.environment.background_mode = Environment.BG_CLEAR_COLOR
		
	xr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
	
	if xr_interface.is_passthrough_supported():
		print("MR DEBUG: Passthrough is supported! Starting...")
		xr_interface.start_passthrough()
		# New: Request scene anchors
		var xr_tracker = XRServer.find_interface("OpenXR")
		# Ensure we connect the signal BEFORE requesting data
		#if not XRServer.tracker_added.is_connected(_on_tracker_added):
		#		XRServer.tracker_added.connect(_on_tracker_added)

		#scene_manager.visible = true
		#anchor_manager.visible = true
		#await xr_interface.session_running
				#_setup_scene_manager()
		
		# This is the "Wake Up" call to Meta for the scene data
		# If your Godot version uses a specific Meta plugin, this might be 
		# xr_interface.request_scene_anchors() or similar.
		# But for generic OpenXR:
	else:
		print("MR DEBUG: FAILED - Headset or settings denied passthrough.")
	
func _on_button_pressed(name: String):
	if name == "menu_button":
		print("DEBUG: Button pressed. Requesting scene capture NOW.")
		_clear_screens()
		scene_manager.request_scene_capture()
		#scene_manager.create_scene_anchors()
				
func _scene_data_missing() -> void:
	print("MR DEBUG: missing")
	_clear_screens()
	scene_manager.create_scene_anchors()
	
func _clear_screens() -> void:
	for s in screens:
		remove_child(s)
	screens.clear()

func _scene_capture_completed(success: bool) -> void:
	if not success:
		return
	print("MR DEBUG: scene capture completed successful ",scene_manager.get_anchor_uuids().size())
	get_tree().reload_current_scene() 
	if scene_manager.are_scene_anchors_created():
		print("MR DEBUG: removing scene anchors")
		#scene_manager.remove_scene_anchors()
	print("MR DEBUG: creating scene anchors")
	#scene_manager.create_scene_anchors()

func _process(_delta):
	if udp.get_available_packet_count()>0:
		var packet = udp.get_packet().get_string_from_utf8()
		if packet.begins_with("QuestLightGunRequest "):
			var s := packet.split(" ")
			if s.size() > 1:
				var a := s[1] 
				if a != outAddress:
					print("MR DEBUG: readdressing to ",a)
					_transmit(a, SEND_PORT)
			lastAddressRequest = Time.get_unix_time_from_system()
	if outAddress != DEFAULT_ADDRESS and Time.get_unix_time_from_system() > lastAddressRequest + READDRESS_TIME:
		print("MR DEBUG: readdressing to multicast")
		_transmit(DEFAULT_ADDRESS, SEND_PORT)
		
	if not screens:
		return
	#_process_controller(ctrl_left, "L", cursor_left)
	_process_controller(ctrl_right, node_right, "R", cursor_right)

func _process_controller(ctrl: XRController3D, node: Node3D, hand_id: String, cursor: MeshInstance3D):
	var ray_origin = node.global_position
	var ray_dir = node.global_basis.z 
	
	var best := [0,INF,Vector2(0.,0.)]
	
	for s in screens:
		var intersect := s.intersectRay(ray_origin,ray_dir)
		if intersect.size() > 0:
			if intersect[1] < best[1]:
				best = intersect
				
	var msg = "LightGunData "+hand_id+" "
	var x := -100000.
	var y := -100000.
	if best[1] < INF:
		x = best[2].x
		y = best[2].y
		msg += "%.5f,%.5f " % [x,y]
		cursor.global_position = best[0]
		cursor.visible = true
	else:
		msg += "NaN,NaN "
		cursor.visible = false
		
	# Handle Button Presses & Circle Fill
	var buttons_pressed := 0
	
	if ctrl.is_button_pressed("trigger"):
		buttons_pressed |= 1
	if ctrl.is_button_pressed("grip"):
		buttons_pressed |= 2
	if ctrl.is_button_pressed("ax_button"):
		buttons_pressed |= 4
	if ctrl.is_button_pressed("by_button"):
		buttons_pressed |= 8
	if ctrl.is_button_pressed("menu"):
		buttons_pressed |= 16
	if ctrl.is_button_pressed("primary_click"):
		buttons_pressed |= 32
	if ctrl.is_button_pressed("primary_touch"):
		buttons_pressed |= 64
	if ctrl.is_button_pressed("select_button"):
		buttons_pressed |= 128

	msg += str(buttons_pressed)
	print(msg)
	_sendData(hand_id, x, y, buttons_pressed)

func _scene_anchor_created(scene_node: Node3D, entity: OpenXRFbSpatialEntity) -> void:
	return
