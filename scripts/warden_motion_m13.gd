extends RefCounted
const BaseLibrary = preload("res://scripts/warden_motion_m12.gd")

static func build() -> SpriteFrames:
	# Eight samples per original run key keep the original 6/13 second cadence.
	return BaseLibrary.build("res://assets/warden_m13", 8)
