extends "res://tools/capture_m29_world.gd"
## Native post-draw instrumentation. Resume the process phase before a direct
## Input.action_press after a viewport still, just as polled OS input arrives.
## Without this boundary a process-only consumer can miss a synthetic press
## tagged to the already-finished render frame. Gameplay code is untouched.
func photograph(tag: String, scope: String) -> void:
	await super.photograph(tag,scope)
	await frames(1)

func source_hashes() -> Dictionary:
	var hashes:=super.source_hashes()
	hashes["tools/capture_m29_native.gd"]=FileAccess.get_sha256("res://tools/capture_m29_native.gd")
	return hashes
