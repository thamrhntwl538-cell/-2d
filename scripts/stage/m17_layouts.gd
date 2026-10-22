extends RefCounted
## M17 — Fifteen approved Folding Library environments.
## Room IDs are 1..15. Geometry uses world pixels; all positions are feet/surface tops.
## Controller builds native collision-bearing paper surfaces from these definitions.
## Combat requirements remain genuine; combat_preview is traversal metadata only.

static func count() -> int:
	return 15

static func room(id: int) -> Dictionary:
	return all_rooms()[clampi(id, 1, count()) - 1]

static func all_rooms() -> Array[Dictionary]:
	return [
		{
			"id": 1,
			"title": "First Page",
			"title_ar": "بهو الصفحة الأولى",
			"theme": "library",
			"size": Vector2(2800, 1440),
			"floor_y": 1260,
			"scene": "res://scenes/stage_01/m17_rooms/01.tscn",
			"spawns": {
				"default": Vector2(180, 1260),
				"left": Vector2(180, 1260),
				"right": Vector2(2640, 1020)
			},
			"platforms": [
				{
					"id": "ground",
					"rect": Rect2(0, 1260, 2800, 140),
					"one_way": false
				},
				{
					"id": "tutorial_1",
					"rect": Rect2(1960, 1140, 240, 120),
					"one_way": false
				},
				{
					"id": "tutorial_2",
					"rect": Rect2(2250, 1020, 240, 54),
					"one_way": true
				},
				{
					"id": "exit_gallery",
					"rect": Rect2(2250, 1020, 550, 60),
					"one_way": true
				}
			],
			"objects": [
				{
					"id": "bench_1",
					"kind": "bench",
					"pos": Vector2(330, 1260),
					"text_key": "bench"
				},
				{
					"id": "weapon_pickup",
					"kind": "weapon",
					"pos": Vector2(650, 1260),
					"flag": "weapon_owned"
				},
				{
					"id": "entrance_note",
					"kind": "note",
					"pos": Vector2(1180, 1260),
					"note_id": "entrance_notice",
					"text_key": "note_entrance"
				}
			],
			"exits": [
				{
					"id": "to_2",
					"pos": Vector2(2690, 1020),
					"target": 2,
					"spawn": "left",
					"requires": ["weapon_owned"],
					"combat_preview": false
				}
			],
			"hazards": [],
			"qa_paths": {
				"main": [Vector2(330, 1260), Vector2(650, 1260), Vector2(1180, 1260), Vector2(1936, 1260), Vector2(1992, 1140), Vector2(2180, 1140), Vector2(2282, 1020), Vector2(2470, 1020), Vector2(2690, 1020)],
				"bench": [Vector2(330, 1260)]
			},
			"qa_actions": {
				"main": [
					{
						"type": "walk",
						"target": Vector2(330, 1260)
					},
					{
						"type": "interact",
						"id": "bench_1"
					},
					{
						"type": "walk",
						"target": Vector2(650, 1260)
					},
					{
						"type": "interact",
						"id": "weapon_pickup"
					},
					{
						"type": "walk",
						"target": Vector2(1180, 1260)
					},
					{
						"type": "interact",
						"id": "entrance_note"
					},
					{
						"type": "walk",
						"target": Vector2(1936, 1260)
					},
					{
						"type": "jump",
						"target": Vector2(1992, 1140)
					},
					{
						"type": "walk",
						"target": Vector2(2180, 1140)
					},
					{
						"type": "jump",
						"target": Vector2(2282, 1020)
					},
					{
						"type": "walk",
						"target": Vector2(2470, 1020)
					},
					{
						"type": "walk",
						"target": Vector2(2690, 1020)
					}
				],
				"bench": [
					{
						"type": "walk",
						"target": Vector2(330, 1260)
					}
				]
			},
			"arrival_flags": [],
			"encounter_reservations": []
		},
		{
			"id": 2,
			"title": "Assignment Hall",
			"title_ar": "ممر الواجبات",
			"theme": "assignments",
			"size": Vector2(3600, 1440),
			"floor_y": 1260,
			"scene": "res://scenes/stage_01/m17_rooms/02.tscn",
			"spawns": {
				"default": Vector2(180, 1260),
				"left": Vector2(180, 1260),
				"right": Vector2(3420, 900),
				"archive": Vector2(2660, 900)
			},
			"platforms": [
				{
					"id": "ground",
					"rect": Rect2(0, 1260, 3600, 140),
					"one_way": false
				},
				{
					"id": "assignment_1",
					"rect": Rect2(1500, 1140, 240, 120),
					"one_way": false
				},
				{
					"id": "assignment_2",
					"rect": Rect2(1790, 1020, 240, 54),
					"one_way": true
				},
				{
					"id": "assignment_3",
					"rect": Rect2(2080, 900, 240, 54),
					"one_way": true
				},
				{
					"id": "upper_gallery",
					"rect": Rect2(2080, 900, 1520, 64),
					"one_way": true
				}
			],
			"objects": [
				{
					"id": "assignment_note",
					"kind": "note",
					"pos": Vector2(950, 1260),
					"note_id": "late_assignment",
					"text_key": "note_assignments"
				},
				{
					"id": "secret_2",
					"kind": "note",
					"pos": Vector2(2900, 900),
					"note_id": "S01",
					"secret": "S01",
					"text_key": "secret_2"
				}
			],
			"exits": [
				{
					"id": "to_1",
					"pos": Vector2(110, 1260),
					"target": 1,
					"spawn": "right",
					"requires": [],
					"combat_preview": false
				},
				{
					"id": "to_3",
					"pos": Vector2(3490, 900),
					"target": 3,
					"spawn": "left",
					"requires": ["encounter_assignments_cleared"],
					"combat_preview": true
				},
				{
					"id": "shortcut_2_6",
					"pos": Vector2(2600, 900),
					"target": 6,
					"spawn": "archive_return",
					"requires": ["archive_return_open"],
					"combat_preview": false
				}
			],
			"hazards": [],
			"qa_paths": {
				"main": [Vector2(950, 1260), Vector2(1476, 1260), Vector2(1532, 1140), Vector2(1720, 1140), Vector2(1822, 1020), Vector2(2010, 1020), Vector2(2112, 900), Vector2(2300, 900), Vector2(2900, 900), Vector2(3490, 900)],
				"shortcut": [Vector2(950, 1260), Vector2(1476, 1260), Vector2(1532, 1140), Vector2(1720, 1140), Vector2(1822, 1020), Vector2(2010, 1020), Vector2(2112, 900), Vector2(2300, 900), Vector2(2600, 900)],
				"secret": [Vector2(950, 1260), Vector2(1476, 1260), Vector2(1532, 1140), Vector2(1720, 1140), Vector2(1822, 1020), Vector2(2010, 1020), Vector2(2112, 900), Vector2(2300, 900), Vector2(2900, 900)]
			},
			"qa_actions": {
				"main": [
					{
						"type": "walk",
						"target": Vector2(950, 1260)
					},
					{
						"type": "interact",
						"id": "assignment_note"
					},
					{
						"type": "walk",
						"target": Vector2(1476, 1260)
					},
					{
						"type": "jump",
						"target": Vector2(1532, 1140)
					},
					{
						"type": "walk",
						"target": Vector2(1720, 1140)
					},
					{
						"type": "jump",
						"target": Vector2(1822, 1020)
					},
					{
						"type": "walk",
						"target": Vector2(2010, 1020)
					},
					{
						"type": "jump",
						"target": Vector2(2112, 900)
					},
					{
						"type": "walk",
						"target": Vector2(2300, 900)
					},
					{
						"type": "walk",
						"target": Vector2(2900, 900)
					},
					{
						"type": "interact",
						"id": "secret_2"
					},
					{
						"type": "walk",
						"target": Vector2(3490, 900)
					}
				],
				"shortcut": [
					{
						"type": "walk",
						"target": Vector2(950, 1260)
					},
					{
						"type": "interact",
						"id": "assignment_note"
					},
					{
						"type": "walk",
						"target": Vector2(1476, 1260)
					},
					{
						"type": "jump",
						"target": Vector2(1532, 1140)
					},
					{
						"type": "walk",
						"target": Vector2(1720, 1140)
					},
					{
						"type": "jump",
						"target": Vector2(1822, 1020)
					},
					{
						"type": "walk",
						"target": Vector2(2010, 1020)
					},
					{
						"type": "jump",
						"target": Vector2(2112, 900)
					},
					{
						"type": "walk",
						"target": Vector2(2300, 900)
					},
					{
						"type": "walk",
						"target": Vector2(2600, 900)
					}
				],
				"secret": [
					{
						"type": "walk",
						"target": Vector2(950, 1260)
					},
					{
						"type": "interact",
						"id": "assignment_note"
					},
					{
						"type": "walk",
						"target": Vector2(1476, 1260)
					},
					{
						"type": "jump",
						"target": Vector2(1532, 1140)
					},
					{
						"type": "walk",
						"target": Vector2(1720, 1140)
					},
					{
						"type": "jump",
						"target": Vector2(1822, 1020)
					},
					{
						"type": "walk",
						"target": Vector2(2010, 1020)
					},
					{
						"type": "jump",
						"target": Vector2(2112, 900)
					},
					{
						"type": "walk",
						"target": Vector2(2300, 900)
					},
					{
						"type": "walk",
						"target": Vector2(2900, 900)
					},
					{
						"type": "interact",
						"id": "secret_2"
					}
				]
			},
			"arrival_flags": [],
			"encounter_reservations": [
				{
					"id": "larva_intro",
					"type": "Glitch Larva",
					"rect": Rect2(550, 1100, 700, 160)
				}
			]
		},
		{
			"id": 3,
			"title": "Ink Lab",
			"title_ar": "مختبر المخطوطات",
			"theme": "lab",
			"size": Vector2(3400, 1440),
			"floor_y": 1260,
			"scene": "res://scenes/stage_01/m17_rooms/03.tscn",
			"spawns": {
				"default": Vector2(180, 1260),
				"left": Vector2(180, 1260),
				"right": Vector2(3200, 780),
				"output": Vector2(2700, 780)
			},
			"platforms": [
				{
					"id": "ground",
					"rect": Rect2(0, 1260, 3400, 140),
					"one_way": false
				},
				{
					"id": "lab_optional_1",
					"rect": Rect2(300, 1140, 240, 120),
					"one_way": false
				},
				{
					"id": "lab_optional_2",
					"rect": Rect2(590, 1020, 240, 54),
					"one_way": true
				},
				{
					"id": "lab_optional_3",
					"rect": Rect2(880, 900, 240, 54),
					"one_way": true
				},
				{
					"id": "wraith_nook",
					"rect": Rect2(880, 900, 320, 60),
					"one_way": true
				},
				{
					"id": "ink_fold_1",
					"rect": Rect2(1200, 1140, 240, 120),
					"one_way": false,
					"requires": "ink_route_solved"
				},
				{
					"id": "ink_fold_2",
					"rect": Rect2(1490, 1020, 240, 54),
					"one_way": true,
					"requires": "ink_route_solved"
				},
				{
					"id": "ink_fold_3",
					"rect": Rect2(1780, 900, 240, 54),
					"one_way": true,
					"requires": "ink_route_solved"
				},
				{
					"id": "ink_fold_4",
					"rect": Rect2(2070, 780, 240, 54),
					"one_way": true,
					"requires": "ink_route_solved"
				},
				{
					"id": "ink_upper_landing",
					"rect": Rect2(2070, 780, 1330, 64),
					"one_way": true,
					"requires": "ink_route_solved"
				}
			],
			"objects": [
				{
					"id": "ink_console",
					"kind": "ink_control",
					"pos": Vector2(850, 1260),
					"flag": "ink_route_solved",
					"text_key": "ink_control"
				},
				{
					"id": "lab_note",
					"kind": "note",
					"pos": Vector2(650, 1260),
					"note_id": "ink_log",
					"text_key": "note_lab"
				}
			],
			"exits": [
				{
					"id": "to_2",
					"pos": Vector2(110, 1260),
					"target": 2,
					"spawn": "right",
					"requires": [],
					"combat_preview": false
				},
				{
					"id": "to_4",
					"pos": Vector2(3280, 780),
					"target": 4,
					"spawn": "left",
					"requires": ["ink_route_solved"],
					"combat_preview": false
				},
				{
					"id": "shortcut_3_9",
					"pos": Vector2(2700, 780),
					"target": 9,
					"spawn": "lab_return",
					"requires": ["output_open"],
					"combat_preview": false
				}
			],
			"hazards": [],
			"qa_paths": {
				"main": [Vector2(276, 1260), Vector2(332, 1140), Vector2(520, 1140), Vector2(650, 1260), Vector2(850, 1260), Vector2(1176, 1260), Vector2(1232, 1140), Vector2(1420, 1140), Vector2(1522, 1020), Vector2(1710, 1020), Vector2(1812, 900), Vector2(2000, 900), Vector2(2102, 780), Vector2(2290, 780), Vector2(3280, 780)],
				"ink": [Vector2(276, 1260), Vector2(332, 1140), Vector2(520, 1140), Vector2(650, 1260), Vector2(850, 1260)],
				"gallery": [Vector2(276, 1260), Vector2(332, 1140), Vector2(520, 1140), Vector2(622, 1020), Vector2(810, 1020), Vector2(912, 900), Vector2(1100, 900)],
				"shortcut": [Vector2(276, 1260), Vector2(332, 1140), Vector2(520, 1140), Vector2(650, 1260), Vector2(850, 1260), Vector2(1176, 1260), Vector2(1232, 1140), Vector2(1420, 1140), Vector2(1522, 1020), Vector2(1710, 1020), Vector2(1812, 900), Vector2(2000, 900), Vector2(2102, 780), Vector2(2290, 780), Vector2(2700, 780)]
			},
			"qa_actions": {
				"main": [
					{
						"type": "walk",
						"target": Vector2(276, 1260)
					},
					{
						"type": "jump",
						"target": Vector2(332, 1140)
					},
					{
						"type": "walk",
						"target": Vector2(520, 1140)
					},
					{
						"type": "drop",
						"target": Vector2(650, 1260)
					},
					{
						"type": "interact",
						"id": "lab_note"
					},
					{
						"type": "walk",
						"target": Vector2(850, 1260)
					},
					{
						"type": "interact",
						"id": "ink_console"
					},
					{
						"type": "walk",
						"target": Vector2(1176, 1260)
					},
					{
						"type": "jump",
						"target": Vector2(1232, 1140)
					},
					{
						"type": "walk",
						"target": Vector2(1420, 1140)
					},
					{
						"type": "jump",
						"target": Vector2(1522, 1020)
					},
					{
						"type": "walk",
						"target": Vector2(1710, 1020)
					},
					{
						"type": "jump",
						"target": Vector2(1812, 900)
					},
					{
						"type": "walk",
						"target": Vector2(2000, 900)
					},
					{
						"type": "jump",
						"target": Vector2(2102, 780)
					},
					{
						"type": "walk",
						"target": Vector2(2290, 780)
					},
					{
						"type": "walk",
						"target": Vector2(3280, 780)
					}
				],
				"ink": [
					{
						"type": "walk",
						"target": Vector2(276, 1260)
					},
					{
						"type": "jump",
						"target": Vector2(332, 1140)
					},
					{
						"type": "walk",
						"target": Vector2(520, 1140)
					},
					{
						"type": "drop",
						"target": Vector2(650, 1260)
					},
					{
						"type": "walk",
						"target": Vector2(850, 1260)
					},
					{
						"type": "interact",
						"id": "ink_console"
					}
				],
				"gallery": [
					{
						"type": "walk",
						"target": Vector2(276, 1260)
					},
					{
						"type": "jump",
						"target": Vector2(332, 1140)
					},
					{
						"type": "walk",
						"target": Vector2(520, 1140)
					},
					{
						"type": "jump",
						"target": Vector2(622, 1020)
					},
					{
						"type": "walk",
						"target": Vector2(810, 1020)
					},
					{
						"type": "jump",
						"target": Vector2(912, 900)
					},
					{
						"type": "walk",
						"target": Vector2(1100, 900)
					}
				],
				"shortcut": [
					{
						"type": "walk",
						"target": Vector2(276, 1260)
					},
					{
						"type": "jump",
						"target": Vector2(332, 1140)
					},
					{
						"type": "walk",
						"target": Vector2(520, 1140)
					},
					{
						"type": "drop",
						"target": Vector2(650, 1260)
					},
					{
						"type": "interact",
						"id": "lab_note"
					},
					{
						"type": "walk",
						"target": Vector2(850, 1260)
					},
					{
						"type": "interact",
						"id": "ink_console"
					},
					{
						"type": "walk",
						"target": Vector2(1176, 1260)
					},
					{
						"type": "jump",
						"target": Vector2(1232, 1140)
					},
					{
						"type": "walk",
						"target": Vector2(1420, 1140)
					},
					{
						"type": "jump",
						"target": Vector2(1522, 1020)
					},
					{
						"type": "walk",
						"target": Vector2(1710, 1020)
					},
					{
						"type": "jump",
						"target": Vector2(1812, 900)
					},
					{
						"type": "walk",
						"target": Vector2(2000, 900)
					},
					{
						"type": "jump",
						"target": Vector2(2102, 780)
					},
					{
						"type": "walk",
						"target": Vector2(2290, 780)
					},
					{
						"type": "walk",
						"target": Vector2(2700, 780)
					}
				]
			},
			"arrival_flags": [],
			"encounter_reservations": [
				{
					"id": "wraith_gallery",
					"type": "Popup Wraith",
					"rect": Rect2(860, 620, 360, 280),
					"optional": true,
					"target_floor_y": 900
				}
			]
		},
		{
			"id": 4,
			"title": "Black Flame Alcove",
			"title_ar": "ركن الشعلة السوداء",
			"theme": "alcove",
			"size": Vector2(2600, 1440),
			"floor_y": 1260,
			"scene": "res://scenes/stage_01/m17_rooms/04.tscn",
			"spawns": {
				"default": Vector2(180, 1260),
				"left": Vector2(180, 1260),
				"right": Vector2(2420, 1260),
				"margins": Vector2(1900, 1260)
			},
			"platforms": [
				{
					"id": "ground",
					"rect": Rect2(0, 1260, 2600, 140),
					"one_way": false
				}
			],
			"objects": [
				{
					"id": "black_flame",
					"kind": "dialogue",
					"pos": Vector2(1040, 1260),
					"flag": "black_flame_warning_seen",
					"text_key": "black_flame"
				},
				{
					"id": "alcove_note",
					"kind": "note",
					"pos": Vector2(1540, 1260),
					"note_id": "margin_warning",
					"text_key": "note_alcove"
				}
			],
			"exits": [
				{
					"id": "to_3",
					"pos": Vector2(110, 1260),
					"target": 3,
					"spawn": "right",
					"requires": [],
					"combat_preview": false
				},
				{
					"id": "to_5",
					"pos": Vector2(2050, 1260),
					"target": 5,
					"spawn": "left",
					"requires": [],
					"combat_preview": false
				},
				{
					"id": "to_6",
					"pos": Vector2(2490, 1260),
					"target": 6,
					"spawn": "left",
					"requires": [],
					"combat_preview": false
				}
			],
			"hazards": [],
			"qa_paths": {
				"main": [Vector2(1040, 1260), Vector2(1540, 1260), Vector2(2490, 1260)],
				"dialogue": [Vector2(1040, 1260)],
				"optional": [Vector2(2050, 1260)],
				"to_optional": [Vector2(2050, 1260)]
			},
			"qa_actions": {
				"main": [
					{
						"type": "walk",
						"target": Vector2(1040, 1260)
					},
					{
						"type": "interact",
						"id": "black_flame"
					},
					{
						"type": "walk",
						"target": Vector2(1540, 1260)
					},
					{
						"type": "interact",
						"id": "alcove_note"
					},
					{
						"type": "walk",
						"target": Vector2(2490, 1260)
					}
				],
				"dialogue": [
					{
						"type": "walk",
						"target": Vector2(1040, 1260)
					},
					{
						"type": "interact",
						"id": "black_flame"
					}
				],
				"optional": [
					{
						"type": "walk",
						"target": Vector2(2050, 1260)
					}
				],
				"to_optional": [
					{
						"type": "walk",
						"target": Vector2(2050, 1260)
					}
				]
			},
			"arrival_flags": [],
			"encounter_reservations": []
		},
		{
			"id": 5,
			"title": "Erased Margins",
			"title_ar": "الهوامش المحذوفة",
			"theme": "margins",
			"size": Vector2(2800, 1440),
			"floor_y": 1260,
			"scene": "res://scenes/stage_01/m17_rooms/05.tscn",
			"spawns": {
				"default": Vector2(180, 1260),
				"left": Vector2(180, 1260),
				"right": Vector2(2600, 780)
			},
			"platforms": [
				{
					"id": "ground",
					"rect": Rect2(0, 1260, 2800, 140),
					"one_way": false
				},
				{
					"id": "margin_1",
					"rect": Rect2(500, 1140, 220, 120),
					"one_way": false
				},
				{
					"id": "margin_2",
					"rect": Rect2(770, 1020, 220, 54),
					"one_way": true
				},
				{
					"id": "margin_3",
					"rect": Rect2(1040, 900, 220, 54),
					"one_way": true
				},
				{
					"id": "margin_4",
					"rect": Rect2(1310, 780, 220, 54),
					"one_way": true
				},
				{
					"id": "margin_reading",
					"rect": Rect2(1310, 780, 1490, 60),
					"one_way": true
				}
			],
			"objects": [
				{
					"id": "secret_5",
					"kind": "note",
					"pos": Vector2(2260, 780),
					"note_id": "S02",
					"secret": "S02",
					"text_key": "secret_5"
				}
			],
			"exits": [
				{
					"id": "to_4",
					"pos": Vector2(110, 1260),
					"target": 4,
					"spawn": "margins",
					"requires": [],
					"combat_preview": false
				},
				{
					"id": "to_6",
					"pos": Vector2(2690, 780),
					"target": 6,
					"spawn": "margins",
					"requires": [],
					"combat_preview": false
				}
			],
			"hazards": [],
			"qa_paths": {
				"main": [Vector2(476, 1260), Vector2(532, 1140), Vector2(700, 1140), Vector2(802, 1020), Vector2(970, 1020), Vector2(1072, 900), Vector2(1240, 900), Vector2(1342, 780), Vector2(1510, 780), Vector2(2260, 780), Vector2(2690, 780)],
				"secret": [Vector2(476, 1260), Vector2(532, 1140), Vector2(700, 1140), Vector2(802, 1020), Vector2(970, 1020), Vector2(1072, 900), Vector2(1240, 900), Vector2(1342, 780), Vector2(1510, 780), Vector2(2260, 780)]
			},
			"qa_actions": {
				"main": [
					{
						"type": "walk",
						"target": Vector2(476, 1260)
					},
					{
						"type": "jump",
						"target": Vector2(532, 1140)
					},
					{
						"type": "walk",
						"target": Vector2(700, 1140)
					},
					{
						"type": "jump",
						"target": Vector2(802, 1020)
					},
					{
						"type": "walk",
						"target": Vector2(970, 1020)
					},
					{
						"type": "jump",
						"target": Vector2(1072, 900)
					},
					{
						"type": "walk",
						"target": Vector2(1240, 900)
					},
					{
						"type": "jump",
						"target": Vector2(1342, 780)
					},
					{
						"type": "walk",
						"target": Vector2(1510, 780)
					},
					{
						"type": "walk",
						"target": Vector2(2260, 780)
					},
					{
						"type": "interact",
						"id": "secret_5"
					},
					{
						"type": "walk",
						"target": Vector2(2690, 780)
					}
				],
				"secret": [
					{
						"type": "walk",
						"target": Vector2(476, 1260)
					},
					{
						"type": "jump",
						"target": Vector2(532, 1140)
					},
					{
						"type": "walk",
						"target": Vector2(700, 1140)
					},
					{
						"type": "jump",
						"target": Vector2(802, 1020)
					},
					{
						"type": "walk",
						"target": Vector2(970, 1020)
					},
					{
						"type": "jump",
						"target": Vector2(1072, 900)
					},
					{
						"type": "walk",
						"target": Vector2(1240, 900)
					},
					{
						"type": "jump",
						"target": Vector2(1342, 780)
					},
					{
						"type": "walk",
						"target": Vector2(1510, 780)
					},
					{
						"type": "walk",
						"target": Vector2(2260, 780)
					},
					{
						"type": "interact",
						"id": "secret_5"
					}
				]
			},
			"arrival_flags": [],
			"encounter_reservations": [
				{
					"id": "weaver_intro",
					"type": "Margin Weaver",
					"rect": Rect2(1550, 600, 600, 180),
					"optional": true
				}
			]
		},
		{
			"id": 6,
			"title": "Folded Archive",
			"title_ar": "الأرشيف المطوي",
			"theme": "archive",
			"size": Vector2(3000, 2880),
			"floor_y": 2700,
			"scene": "res://scenes/stage_01/m17_rooms/06.tscn",
			"spawns": {
				"default": Vector2(180, 2700),
				"left": Vector2(180, 2700),
				"right": Vector2(2800, 540),
				"archive_return": Vector2(2310, 1980),
				"margins": Vector2(180, 2700),
				"workshop": Vector2(2380, 540)
			},
			"platforms": [
				{
					"id": "ground",
					"rect": Rect2(0, 2700, 3000, 140),
					"one_way": false
				},
				{
					"id": "floor_2",
					"rect": Rect2(1650, 1980, 1250, 60),
					"one_way": true
				},
				{
					"id": "floor_3",
					"rect": Rect2(100, 1260, 1150, 60),
					"one_way": true
				},
				{
					"id": "floor_3_secret_gallery",
					"rect": Rect2(1550, 1260, 1350, 60),
					"one_way": true
				},
				{
					"id": "floor_4",
					"rect": Rect2(1650, 540, 1250, 60),
					"one_way": true
				},
				{
					"id": "archive_flight_1_1",
					"rect": Rect2(300, 2580, 220, 120),
					"one_way": false
				},
				{
					"id": "archive_flight_1_2",
					"rect": Rect2(570, 2460, 220, 54),
					"one_way": true
				},
				{
					"id": "archive_flight_1_3",
					"rect": Rect2(840, 2340, 220, 54),
					"one_way": true
				},
				{
					"id": "archive_flight_1_4",
					"rect": Rect2(1110, 2220, 220, 54),
					"one_way": true
				},
				{
					"id": "archive_flight_1_5",
					"rect": Rect2(1380, 2100, 220, 54),
					"one_way": true
				},
				{
					"id": "archive_flight_1_6",
					"rect": Rect2(1650, 1980, 220, 54),
					"one_way": true
				},
				{
					"id": "archive_flight_2_1",
					"rect": Rect2(2380, 1860, 220, 120),
					"one_way": false
				},
				{
					"id": "archive_flight_2_2",
					"rect": Rect2(2110, 1740, 220, 54),
					"one_way": true
				},
				{
					"id": "archive_flight_2_3",
					"rect": Rect2(1840, 1620, 220, 54),
					"one_way": true
				},
				{
					"id": "archive_flight_2_4",
					"rect": Rect2(1570, 1500, 220, 54),
					"one_way": true
				},
				{
					"id": "archive_flight_2_5",
					"rect": Rect2(1300, 1380, 220, 54),
					"one_way": true
				},
				{
					"id": "archive_flight_2_6",
					"rect": Rect2(1030, 1260, 220, 54),
					"one_way": true
				},
				{
					"id": "archive_secret_step_1",
					"rect": Rect2(2420, 1140, 220, 120),
					"one_way": false,
					"requires": "secret_S03_open"
				},
				{
					"id": "archive_secret_step_2",
					"rect": Rect2(2690, 1020, 220, 54),
					"one_way": true,
					"requires": "secret_S03_open"
				},
				{
					"id": "archive_flight_3_1",
					"rect": Rect2(300, 1140, 220, 120),
					"one_way": false
				},
				{
					"id": "archive_flight_3_2",
					"rect": Rect2(570, 1020, 220, 54),
					"one_way": true
				},
				{
					"id": "archive_flight_3_3",
					"rect": Rect2(840, 900, 220, 54),
					"one_way": true
				},
				{
					"id": "archive_flight_3_4",
					"rect": Rect2(1110, 780, 220, 54),
					"one_way": true
				},
				{
					"id": "archive_flight_3_5",
					"rect": Rect2(1380, 660, 220, 54),
					"one_way": true
				},
				{
					"id": "archive_flight_3_6",
					"rect": Rect2(1650, 540, 220, 54),
					"one_way": true
				}
			],
			"objects": [
				{
					"id": "archive_water_note",
					"kind": "note",
					"pos": Vector2(1950, 1980),
					"note_id": "archive_water",
					"text_key": "archive_water"
				},
				{
					"id": "bench_6",
					"kind": "bench",
					"pos": Vector2(1750, 1980),
					"text_key": "bench"
				},
				{
					"id": "archive_return_latch",
					"kind": "shortcut",
					"pos": Vector2(2150, 1980),
					"flag": "archive_return_open",
					"text_key": "shortcut_archive"
				},
				{
					"id": "archive_note",
					"kind": "note",
					"pos": Vector2(850, 1260),
					"note_id": "archive_door",
					"text_key": "archive_door"
				},
				{
					"id": "archive_overlay",
					"kind": "secret_overlay",
					"pos": Vector2(2230, 1260),
					"flag": "secret_S03_open",
					"text_key": "overlay_control"
				},
				{
					"id": "secret_6",
					"kind": "note",
					"pos": Vector2(2800, 1020),
					"note_id": "S03",
					"secret": "S03",
					"requires": ["secret_S03_open"],
					"text_key": "secret_6"
				},
				{
					"id": "archive_upper_note",
					"kind": "note",
					"pos": Vector2(1900, 540),
					"note_id": "archive_return",
					"text_key": "archive_return"
				}
			],
			"exits": [
				{
					"id": "to_4",
					"pos": Vector2(110, 2700),
					"target": 4,
					"spawn": "right",
					"requires": [],
					"combat_preview": false
				},
				{
					"id": "to_5",
					"pos": Vector2(700, 2700),
					"target": 5,
					"spawn": "right",
					"requires": [],
					"combat_preview": false
				},
				{
					"id": "to_7",
					"pos": Vector2(2820, 540),
					"target": 7,
					"spawn": "left",
					"requires": ["archive_upper_landing_reached"],
					"combat_preview": false
				},
				{
					"id": "shortcut_6_2",
					"pos": Vector2(2310, 1980),
					"target": 2,
					"spawn": "archive",
					"requires": ["archive_return_open"],
					"combat_preview": false
				},
				{
					"id": "shortcut_6_12",
					"pos": Vector2(2410, 540),
					"target": 12,
					"spawn": "archive",
					"requires": ["workshop_archive_return_open"],
					"combat_preview": false
				}
			],
			"hazards": [],
			"qa_paths": {
				"main": [Vector2(276, 2700), Vector2(332, 2580), Vector2(500, 2580), Vector2(602, 2460), Vector2(770, 2460), Vector2(872, 2340), Vector2(1040, 2340), Vector2(1142, 2220), Vector2(1310, 2220), Vector2(1412, 2100), Vector2(1580, 2100), Vector2(1682, 1980), Vector2(1850, 1980), Vector2(1950, 1980), Vector2(1750, 1980), Vector2(2150, 1980), Vector2(2356, 1980), Vector2(2412, 1860), Vector2(2400, 1860), Vector2(2298, 1740), Vector2(2130, 1740), Vector2(2028, 1620), Vector2(1860, 1620), Vector2(1758, 1500), Vector2(1590, 1500), Vector2(1488, 1380), Vector2(1320, 1380), Vector2(1218, 1260), Vector2(1050, 1260), Vector2(850, 1260), Vector2(544, 1260), Vector2(488, 1140), Vector2(500, 1140), Vector2(602, 1020), Vector2(770, 1020), Vector2(872, 900), Vector2(1040, 900), Vector2(1142, 780), Vector2(1310, 780), Vector2(1412, 660), Vector2(1580, 660), Vector2(1682, 540), Vector2(1850, 540), Vector2(1900, 540), Vector2(2820, 540)],
				"bench": [Vector2(276, 2700), Vector2(332, 2580), Vector2(500, 2580), Vector2(602, 2460), Vector2(770, 2460), Vector2(872, 2340), Vector2(1040, 2340), Vector2(1142, 2220), Vector2(1310, 2220), Vector2(1412, 2100), Vector2(1580, 2100), Vector2(1682, 1980), Vector2(1850, 1980), Vector2(1750, 1980)],
				"shortcut": [Vector2(276, 2700), Vector2(332, 2580), Vector2(500, 2580), Vector2(602, 2460), Vector2(770, 2460), Vector2(872, 2340), Vector2(1040, 2340), Vector2(1142, 2220), Vector2(1310, 2220), Vector2(1412, 2100), Vector2(1580, 2100), Vector2(1682, 1980), Vector2(1850, 1980), Vector2(2150, 1980), Vector2(2310, 1980)],
				"secret": [Vector2(276, 2700), Vector2(332, 2580), Vector2(500, 2580), Vector2(602, 2460), Vector2(770, 2460), Vector2(872, 2340), Vector2(1040, 2340), Vector2(1142, 2220), Vector2(1310, 2220), Vector2(1412, 2100), Vector2(1580, 2100), Vector2(1682, 1980), Vector2(1850, 1980), Vector2(2356, 1980), Vector2(2412, 1860), Vector2(2400, 1860), Vector2(2298, 1740), Vector2(2130, 1740), Vector2(2028, 1620), Vector2(1860, 1620), Vector2(1758, 1500), Vector2(1590, 1500), Vector2(1488, 1380), Vector2(1320, 1380), Vector2(1218, 1260), Vector2(1050, 1260), Vector2(850, 1260), Vector2(1230, 1260), Vector2(1400, 1380), Vector2(1500, 1380), Vector2(1582, 1260), Vector2(2230, 1260), Vector2(2396, 1260), Vector2(2452, 1140), Vector2(2620, 1140), Vector2(2722, 1020), Vector2(2800, 1020)],
				"secret_return": [Vector2(2710, 1020), Vector2(2600, 1140), Vector2(2440, 1140), Vector2(2360, 1260), Vector2(1580, 1260), Vector2(1460, 1380), Vector2(1320, 1380), Vector2(1220, 1260), Vector2(850, 1260)]
			},
			"qa_actions": {
				"main": [
					{
						"type": "walk",
						"target": Vector2(276, 2700)
					},
					{
						"type": "jump",
						"target": Vector2(332, 2580)
					},
					{
						"type": "walk",
						"target": Vector2(500, 2580)
					},
					{
						"type": "jump",
						"target": Vector2(602, 2460)
					},
					{
						"type": "walk",
						"target": Vector2(770, 2460)
					},
					{
						"type": "jump",
						"target": Vector2(872, 2340)
					},
					{
						"type": "walk",
						"target": Vector2(1040, 2340)
					},
					{
						"type": "jump",
						"target": Vector2(1142, 2220)
					},
					{
						"type": "walk",
						"target": Vector2(1310, 2220)
					},
					{
						"type": "jump",
						"target": Vector2(1412, 2100)
					},
					{
						"type": "walk",
						"target": Vector2(1580, 2100)
					},
					{
						"type": "jump",
						"target": Vector2(1682, 1980)
					},
					{
						"type": "walk",
						"target": Vector2(1850, 1980)
					},
					{
						"type": "walk",
						"target": Vector2(1950, 1980)
					},
					{
						"type": "interact",
						"id": "archive_water_note"
					},
					{
						"type": "walk",
						"target": Vector2(1750, 1980)
					},
					{
						"type": "interact",
						"id": "bench_6"
					},
					{
						"type": "walk",
						"target": Vector2(2150, 1980)
					},
					{
						"type": "interact",
						"id": "archive_return_latch"
					},
					{
						"type": "walk",
						"target": Vector2(2356, 1980)
					},
					{
						"type": "jump",
						"target": Vector2(2412, 1860)
					},
					{
						"type": "walk",
						"target": Vector2(2400, 1860)
					},
					{
						"type": "jump",
						"target": Vector2(2298, 1740)
					},
					{
						"type": "walk",
						"target": Vector2(2130, 1740)
					},
					{
						"type": "jump",
						"target": Vector2(2028, 1620)
					},
					{
						"type": "walk",
						"target": Vector2(1860, 1620)
					},
					{
						"type": "jump",
						"target": Vector2(1758, 1500)
					},
					{
						"type": "walk",
						"target": Vector2(1590, 1500)
					},
					{
						"type": "jump",
						"target": Vector2(1488, 1380)
					},
					{
						"type": "walk",
						"target": Vector2(1320, 1380)
					},
					{
						"type": "jump",
						"target": Vector2(1218, 1260)
					},
					{
						"type": "walk",
						"target": Vector2(1050, 1260)
					},
					{
						"type": "walk",
						"target": Vector2(850, 1260)
					},
					{
						"type": "interact",
						"id": "archive_note"
					},
					{
						"type": "walk",
						"target": Vector2(544, 1260)
					},
					{
						"type": "jump",
						"target": Vector2(488, 1140)
					},
					{
						"type": "walk",
						"target": Vector2(500, 1140)
					},
					{
						"type": "jump",
						"target": Vector2(602, 1020)
					},
					{
						"type": "walk",
						"target": Vector2(770, 1020)
					},
					{
						"type": "jump",
						"target": Vector2(872, 900)
					},
					{
						"type": "walk",
						"target": Vector2(1040, 900)
					},
					{
						"type": "jump",
						"target": Vector2(1142, 780)
					},
					{
						"type": "walk",
						"target": Vector2(1310, 780)
					},
					{
						"type": "jump",
						"target": Vector2(1412, 660)
					},
					{
						"type": "walk",
						"target": Vector2(1580, 660)
					},
					{
						"type": "jump",
						"target": Vector2(1682, 540)
					},
					{
						"type": "walk",
						"target": Vector2(1850, 540)
					},
					{
						"type": "walk",
						"target": Vector2(1900, 540)
					},
					{
						"type": "interact",
						"id": "archive_upper_note"
					},
					{
						"type": "walk",
						"target": Vector2(2820, 540)
					}
				],
				"bench": [
					{
						"type": "walk",
						"target": Vector2(276, 2700)
					},
					{
						"type": "jump",
						"target": Vector2(332, 2580)
					},
					{
						"type": "walk",
						"target": Vector2(500, 2580)
					},
					{
						"type": "jump",
						"target": Vector2(602, 2460)
					},
					{
						"type": "walk",
						"target": Vector2(770, 2460)
					},
					{
						"type": "jump",
						"target": Vector2(872, 2340)
					},
					{
						"type": "walk",
						"target": Vector2(1040, 2340)
					},
					{
						"type": "jump",
						"target": Vector2(1142, 2220)
					},
					{
						"type": "walk",
						"target": Vector2(1310, 2220)
					},
					{
						"type": "jump",
						"target": Vector2(1412, 2100)
					},
					{
						"type": "walk",
						"target": Vector2(1580, 2100)
					},
					{
						"type": "jump",
						"target": Vector2(1682, 1980)
					},
					{
						"type": "walk",
						"target": Vector2(1850, 1980)
					},
					{
						"type": "walk",
						"target": Vector2(1750, 1980)
					},
					{
						"type": "interact",
						"id": "bench_6"
					}
				],
				"shortcut": [
					{
						"type": "walk",
						"target": Vector2(276, 2700)
					},
					{
						"type": "jump",
						"target": Vector2(332, 2580)
					},
					{
						"type": "walk",
						"target": Vector2(500, 2580)
					},
					{
						"type": "jump",
						"target": Vector2(602, 2460)
					},
					{
						"type": "walk",
						"target": Vector2(770, 2460)
					},
					{
						"type": "jump",
						"target": Vector2(872, 2340)
					},
					{
						"type": "walk",
						"target": Vector2(1040, 2340)
					},
					{
						"type": "jump",
						"target": Vector2(1142, 2220)
					},
					{
						"type": "walk",
						"target": Vector2(1310, 2220)
					},
					{
						"type": "jump",
						"target": Vector2(1412, 2100)
					},
					{
						"type": "walk",
						"target": Vector2(1580, 2100)
					},
					{
						"type": "jump",
						"target": Vector2(1682, 1980)
					},
					{
						"type": "walk",
						"target": Vector2(1850, 1980)
					},
					{
						"type": "walk",
						"target": Vector2(2150, 1980)
					},
					{
						"type": "interact",
						"id": "archive_return_latch"
					},
					{
						"type": "walk",
						"target": Vector2(2310, 1980)
					}
				],
				"secret": [
					{
						"type": "walk",
						"target": Vector2(276, 2700)
					},
					{
						"type": "jump",
						"target": Vector2(332, 2580)
					},
					{
						"type": "walk",
						"target": Vector2(500, 2580)
					},
					{
						"type": "jump",
						"target": Vector2(602, 2460)
					},
					{
						"type": "walk",
						"target": Vector2(770, 2460)
					},
					{
						"type": "jump",
						"target": Vector2(872, 2340)
					},
					{
						"type": "walk",
						"target": Vector2(1040, 2340)
					},
					{
						"type": "jump",
						"target": Vector2(1142, 2220)
					},
					{
						"type": "walk",
						"target": Vector2(1310, 2220)
					},
					{
						"type": "jump",
						"target": Vector2(1412, 2100)
					},
					{
						"type": "walk",
						"target": Vector2(1580, 2100)
					},
					{
						"type": "jump",
						"target": Vector2(1682, 1980)
					},
					{
						"type": "walk",
						"target": Vector2(1850, 1980)
					},
					{
						"type": "walk",
						"target": Vector2(2356, 1980)
					},
					{
						"type": "jump",
						"target": Vector2(2412, 1860)
					},
					{
						"type": "walk",
						"target": Vector2(2400, 1860)
					},
					{
						"type": "jump",
						"target": Vector2(2298, 1740)
					},
					{
						"type": "walk",
						"target": Vector2(2130, 1740)
					},
					{
						"type": "jump",
						"target": Vector2(2028, 1620)
					},
					{
						"type": "walk",
						"target": Vector2(1860, 1620)
					},
					{
						"type": "jump",
						"target": Vector2(1758, 1500)
					},
					{
						"type": "walk",
						"target": Vector2(1590, 1500)
					},
					{
						"type": "jump",
						"target": Vector2(1488, 1380)
					},
					{
						"type": "walk",
						"target": Vector2(1320, 1380)
					},
					{
						"type": "jump",
						"target": Vector2(1218, 1260)
					},
					{
						"type": "walk",
						"target": Vector2(1050, 1260)
					},
					{
						"type": "walk",
						"target": Vector2(850, 1260)
					},
					{
						"type": "interact",
						"id": "archive_note"
					},
					{
						"type": "walk",
						"target": Vector2(1230, 1260)
					},
					{
						"type": "drop",
						"target": Vector2(1400, 1380)
					},
					{
						"type": "walk",
						"target": Vector2(1500, 1380)
					},
					{
						"type": "jump",
						"target": Vector2(1582, 1260)
					},
					{
						"type": "walk",
						"target": Vector2(2230, 1260)
					},
					{
						"type": "interact",
						"id": "archive_overlay"
					},
					{
						"type": "walk",
						"target": Vector2(2396, 1260)
					},
					{
						"type": "jump",
						"target": Vector2(2452, 1140)
					},
					{
						"type": "walk",
						"target": Vector2(2620, 1140)
					},
					{
						"type": "jump",
						"target": Vector2(2722, 1020)
					},
					{
						"type": "walk",
						"target": Vector2(2800, 1020)
					},
					{
						"type": "interact",
						"id": "secret_6"
					}
				],
				"secret_return": [
					{
						"type": "walk",
						"target": Vector2(2710, 1020)
					},
					{
						"type": "drop",
						"target": Vector2(2600, 1140)
					},
					{
						"type": "walk",
						"target": Vector2(2440, 1140)
					},
					{
						"type": "drop",
						"target": Vector2(2360, 1260)
					},
					{
						"type": "walk",
						"target": Vector2(1580, 1260)
					},
					{
						"type": "drop",
						"target": Vector2(1460, 1380)
					},
					{
						"type": "walk",
						"target": Vector2(1320, 1380)
					},
					{
						"type": "jump",
						"target": Vector2(1220, 1260)
					},
					{
						"type": "walk",
						"target": Vector2(850, 1260)
					}
				]
			},
			"arrival_flags": [
				{
					"flag": "archive_upper_landing_reached",
					"rect": Rect2(100, 515, 2800, 40)
				}
			],
			"encounter_reservations": [
				{
					"id": "thief_optional",
					"type": "Reference Thief",
					"rect": Rect2(2100, 1050, 600, 210),
					"optional": true
				}
			],
			"floors": [2700, 1980, 1260, 540],
			"main_ascent_jump_count": 18
		},
		{
			"id": 7,
			"title": "INPUT",
			"title_ar": "غرفة الإدخال",
			"theme": "input",
			"size": Vector2(2900, 1440),
			"floor_y": 1260,
			"scene": "res://scenes/stage_01/m17_rooms/07.tscn",
			"spawns": {
				"default": Vector2(180, 1260),
				"left": Vector2(180, 1260),
				"right": Vector2(2700, 900)
			},
			"platforms": [
				{
					"id": "ground",
					"rect": Rect2(0, 1260, 2900, 140),
					"one_way": false
				},
				{
					"id": "input_1",
					"rect": Rect2(950, 1140, 240, 120),
					"one_way": false
				},
				{
					"id": "input_2",
					"rect": Rect2(1240, 1020, 240, 54),
					"one_way": true
				},
				{
					"id": "square_shelf",
					"rect": Rect2(1240, 1020, 600, 60),
					"one_way": true
				},
				{
					"id": "circle_shelf",
					"rect": Rect2(1890, 900, 1010, 60),
					"one_way": true
				}
			],
			"objects": [
				{
					"id": "book_triangle",
					"kind": "book",
					"pos": Vector2(700, 1260),
					"book_id": "TRIANGLE",
					"flag": "book_triangle_owned",
					"text_key": "book_triangle"
				},
				{
					"id": "book_square",
					"kind": "book",
					"pos": Vector2(1450, 1020),
					"book_id": "SQUARE",
					"flag": "book_square_owned",
					"text_key": "book_square"
				},
				{
					"id": "book_circle",
					"kind": "book",
					"pos": Vector2(2350, 900),
					"book_id": "CIRCLE",
					"flag": "book_circle_owned",
					"text_key": "book_circle"
				}
			],
			"exits": [
				{
					"id": "to_6",
					"pos": Vector2(110, 1260),
					"target": 6,
					"spawn": "right",
					"requires": [],
					"combat_preview": false
				},
				{
					"id": "to_8",
					"pos": Vector2(2790, 900),
					"target": 8,
					"spawn": "left",
					"requires": ["books_collected"],
					"combat_preview": false
				}
			],
			"hazards": [],
			"qa_paths": {
				"main": [Vector2(700, 1260), Vector2(926, 1260), Vector2(982, 1140), Vector2(1170, 1140), Vector2(1272, 1020), Vector2(1460, 1020), Vector2(1450, 1020), Vector2(1820, 1020), Vector2(1922, 900), Vector2(2350, 900), Vector2(2790, 900)],
				"books": [Vector2(700, 1260), Vector2(926, 1260), Vector2(982, 1140), Vector2(1170, 1140), Vector2(1272, 1020), Vector2(1460, 1020), Vector2(1450, 1020), Vector2(1820, 1020), Vector2(1922, 900), Vector2(2350, 900)]
			},
			"qa_actions": {
				"main": [
					{
						"type": "walk",
						"target": Vector2(700, 1260)
					},
					{
						"type": "interact",
						"id": "book_triangle"
					},
					{
						"type": "walk",
						"target": Vector2(926, 1260)
					},
					{
						"type": "jump",
						"target": Vector2(982, 1140)
					},
					{
						"type": "walk",
						"target": Vector2(1170, 1140)
					},
					{
						"type": "jump",
						"target": Vector2(1272, 1020)
					},
					{
						"type": "walk",
						"target": Vector2(1460, 1020)
					},
					{
						"type": "walk",
						"target": Vector2(1450, 1020)
					},
					{
						"type": "interact",
						"id": "book_square"
					},
					{
						"type": "walk",
						"target": Vector2(1820, 1020)
					},
					{
						"type": "jump",
						"target": Vector2(1922, 900)
					},
					{
						"type": "walk",
						"target": Vector2(2350, 900)
					},
					{
						"type": "interact",
						"id": "book_circle"
					},
					{
						"type": "walk",
						"target": Vector2(2790, 900)
					}
				],
				"books": [
					{
						"type": "walk",
						"target": Vector2(700, 1260)
					},
					{
						"type": "interact",
						"id": "book_triangle"
					},
					{
						"type": "walk",
						"target": Vector2(926, 1260)
					},
					{
						"type": "jump",
						"target": Vector2(982, 1140)
					},
					{
						"type": "walk",
						"target": Vector2(1170, 1140)
					},
					{
						"type": "jump",
						"target": Vector2(1272, 1020)
					},
					{
						"type": "walk",
						"target": Vector2(1460, 1020)
					},
					{
						"type": "walk",
						"target": Vector2(1450, 1020)
					},
					{
						"type": "interact",
						"id": "book_square"
					},
					{
						"type": "walk",
						"target": Vector2(1820, 1020)
					},
					{
						"type": "jump",
						"target": Vector2(1922, 900)
					},
					{
						"type": "walk",
						"target": Vector2(2350, 900)
					},
					{
						"type": "interact",
						"id": "book_circle"
					}
				]
			},
			"arrival_flags": [],
			"encounter_reservations": []
		},
		{
			"id": 8,
			"title": "PROCESS",
			"title_ar": "قاعة الترتيب",
			"theme": "process",
			"size": Vector2(3200, 1440),
			"floor_y": 1260,
			"scene": "res://scenes/stage_01/m17_rooms/08.tscn",
			"spawns": {
				"default": Vector2(180, 1260),
				"left": Vector2(180, 1260),
				"right": Vector2(3010, 1260)
			},
			"platforms": [
				{
					"id": "ground",
					"rect": Rect2(0, 1260, 3200, 140),
					"one_way": false
				},
				{
					"id": "side_gallery_1",
					"rect": Rect2(1840, 1140, 240, 120),
					"one_way": false
				},
				{
					"id": "side_gallery_2",
					"rect": Rect2(2130, 1020, 240, 54),
					"one_way": true
				},
				{
					"id": "side_gallery_3",
					"rect": Rect2(2420, 900, 240, 54),
					"one_way": true
				},
				{
					"id": "turret_gallery",
					"rect": Rect2(2420, 900, 780, 60),
					"one_way": true
				}
			],
			"objects": [
				{
					"id": "process_table",
					"kind": "process_control",
					"pos": Vector2(1280, 1260),
					"flag": "book_order_verified",
					"requires": ["books_collected"],
					"text_key": "process_control"
				},
				{
					"id": "process_note",
					"kind": "note",
					"pos": Vector2(670, 1260),
					"note_id": "process_guide",
					"text_key": "note_process"
				}
			],
			"exits": [
				{
					"id": "to_7",
					"pos": Vector2(110, 1260),
					"target": 7,
					"spawn": "right",
					"requires": [],
					"combat_preview": false
				},
				{
					"id": "to_9",
					"pos": Vector2(3090, 1260),
					"target": 9,
					"spawn": "left",
					"requires": ["book_order_verified"],
					"combat_preview": false
				}
			],
			"hazards": [],
			"qa_paths": {
				"main": [Vector2(670, 1260), Vector2(1280, 1260), Vector2(1816, 1260), Vector2(1872, 1140), Vector2(2060, 1140), Vector2(2170, 1260), Vector2(3090, 1260)],
				"process": [Vector2(1280, 1260)],
				"gallery": [Vector2(1280, 1260), Vector2(1816, 1260), Vector2(1872, 1140), Vector2(2060, 1140), Vector2(2162, 1020), Vector2(2350, 1020), Vector2(2452, 900), Vector2(2640, 900), Vector2(2850, 900)]
			},
			"qa_actions": {
				"main": [
					{
						"type": "walk",
						"target": Vector2(670, 1260)
					},
					{
						"type": "interact",
						"id": "process_note"
					},
					{
						"type": "walk",
						"target": Vector2(1280, 1260)
					},
					{
						"type": "interact",
						"id": "process_table"
					},
					{
						"type": "walk",
						"target": Vector2(1816, 1260)
					},
					{
						"type": "jump",
						"target": Vector2(1872, 1140)
					},
					{
						"type": "walk",
						"target": Vector2(2060, 1140)
					},
					{
						"type": "drop",
						"target": Vector2(2170, 1260)
					},
					{
						"type": "walk",
						"target": Vector2(3090, 1260)
					}
				],
				"process": [
					{
						"type": "walk",
						"target": Vector2(1280, 1260)
					},
					{
						"type": "interact",
						"id": "process_table"
					}
				],
				"gallery": [
					{
						"type": "walk",
						"target": Vector2(1280, 1260)
					},
					{
						"type": "interact",
						"id": "process_table"
					},
					{
						"type": "walk",
						"target": Vector2(1816, 1260)
					},
					{
						"type": "jump",
						"target": Vector2(1872, 1140)
					},
					{
						"type": "walk",
						"target": Vector2(2060, 1140)
					},
					{
						"type": "jump",
						"target": Vector2(2162, 1020)
					},
					{
						"type": "walk",
						"target": Vector2(2350, 1020)
					},
					{
						"type": "jump",
						"target": Vector2(2452, 900)
					},
					{
						"type": "walk",
						"target": Vector2(2640, 900)
					},
					{
						"type": "walk",
						"target": Vector2(2850, 900)
					}
				]
			},
			"arrival_flags": [],
			"encounter_reservations": [
				{
					"id": "turret_intro",
					"type": "Syntax Turret",
					"rect": Rect2(2650, 720, 450, 180),
					"optional": true,
					"target_floor_y": 900
				}
			]
		},
		{
			"id": 9,
			"title": "OUTPUT",
			"title_ar": "جسر الإخراج",
			"theme": "output",
			"size": Vector2(3200, 1440),
			"floor_y": 1260,
			"scene": "res://scenes/stage_01/m17_rooms/09.tscn",
			"spawns": {
				"default": Vector2(180, 1260),
				"left": Vector2(180, 1260),
				"right": Vector2(3010, 780),
				"lab_return": Vector2(2440, 780)
			},
			"platforms": [
				{
					"id": "ground",
					"rect": Rect2(0, 1260, 3200, 140),
					"one_way": false
				},
				{
					"id": "page_stair_1",
					"rect": Rect2(1100, 1140, 240, 120),
					"one_way": false,
					"requires": "output_open"
				},
				{
					"id": "page_stair_2",
					"rect": Rect2(1390, 1020, 240, 54),
					"one_way": true,
					"requires": "output_open"
				},
				{
					"id": "page_stair_3",
					"rect": Rect2(1680, 900, 240, 54),
					"one_way": true,
					"requires": "output_open"
				},
				{
					"id": "page_stair_4",
					"rect": Rect2(1970, 780, 240, 54),
					"one_way": true,
					"requires": "output_open"
				},
				{
					"id": "output_upper",
					"rect": Rect2(1970, 780, 1230, 64),
					"one_way": true,
					"requires": "output_open"
				}
			],
			"objects": [
				{
					"id": "output_console",
					"kind": "output_control",
					"pos": Vector2(750, 1260),
					"flag": "output_open",
					"requires": ["book_order_verified"],
					"text_key": "output_control"
				},
				{
					"id": "secret_9",
					"kind": "note",
					"pos": Vector2(2640, 1260),
					"note_id": "S04",
					"secret": "S04",
					"requires": ["output_open"],
					"text_key": "secret_9"
				}
			],
			"exits": [
				{
					"id": "to_8",
					"pos": Vector2(110, 1260),
					"target": 8,
					"spawn": "right",
					"requires": [],
					"combat_preview": false
				},
				{
					"id": "to_10",
					"pos": Vector2(3090, 780),
					"target": 10,
					"spawn": "left",
					"requires": ["output_open"],
					"combat_preview": false
				},
				{
					"id": "shortcut_9_3",
					"pos": Vector2(2440, 780),
					"target": 3,
					"spawn": "output",
					"requires": ["output_open"],
					"combat_preview": false
				}
			],
			"hazards": [],
			"qa_paths": {
				"main": [Vector2(750, 1260), Vector2(1076, 1260), Vector2(1132, 1140), Vector2(1320, 1140), Vector2(1422, 1020), Vector2(1610, 1020), Vector2(1712, 900), Vector2(1900, 900), Vector2(2002, 780), Vector2(2190, 780), Vector2(3090, 780)],
				"output": [Vector2(750, 1260), Vector2(1076, 1260), Vector2(1132, 1140), Vector2(1320, 1140), Vector2(1422, 1020), Vector2(1610, 1020), Vector2(1712, 900), Vector2(1900, 900), Vector2(2002, 780), Vector2(2190, 780)],
				"shortcut": [Vector2(750, 1260), Vector2(1076, 1260), Vector2(1132, 1140), Vector2(1320, 1140), Vector2(1422, 1020), Vector2(1610, 1020), Vector2(1712, 900), Vector2(1900, 900), Vector2(2002, 780), Vector2(2190, 780), Vector2(2440, 780)],
				"secret": [Vector2(750, 1260), Vector2(1076, 1260), Vector2(1132, 1140), Vector2(1320, 1140), Vector2(1430, 1260), Vector2(2640, 1260)]
			},
			"qa_actions": {
				"main": [
					{
						"type": "walk",
						"target": Vector2(750, 1260)
					},
					{
						"type": "interact",
						"id": "output_console"
					},
					{
						"type": "walk",
						"target": Vector2(1076, 1260)
					},
					{
						"type": "jump",
						"target": Vector2(1132, 1140)
					},
					{
						"type": "walk",
						"target": Vector2(1320, 1140)
					},
					{
						"type": "jump",
						"target": Vector2(1422, 1020)
					},
					{
						"type": "walk",
						"target": Vector2(1610, 1020)
					},
					{
						"type": "jump",
						"target": Vector2(1712, 900)
					},
					{
						"type": "walk",
						"target": Vector2(1900, 900)
					},
					{
						"type": "jump",
						"target": Vector2(2002, 780)
					},
					{
						"type": "walk",
						"target": Vector2(2190, 780)
					},
					{
						"type": "walk",
						"target": Vector2(3090, 780)
					}
				],
				"output": [
					{
						"type": "walk",
						"target": Vector2(750, 1260)
					},
					{
						"type": "interact",
						"id": "output_console"
					},
					{
						"type": "walk",
						"target": Vector2(1076, 1260)
					},
					{
						"type": "jump",
						"target": Vector2(1132, 1140)
					},
					{
						"type": "walk",
						"target": Vector2(1320, 1140)
					},
					{
						"type": "jump",
						"target": Vector2(1422, 1020)
					},
					{
						"type": "walk",
						"target": Vector2(1610, 1020)
					},
					{
						"type": "jump",
						"target": Vector2(1712, 900)
					},
					{
						"type": "walk",
						"target": Vector2(1900, 900)
					},
					{
						"type": "jump",
						"target": Vector2(2002, 780)
					},
					{
						"type": "walk",
						"target": Vector2(2190, 780)
					}
				],
				"shortcut": [
					{
						"type": "walk",
						"target": Vector2(750, 1260)
					},
					{
						"type": "interact",
						"id": "output_console"
					},
					{
						"type": "walk",
						"target": Vector2(1076, 1260)
					},
					{
						"type": "jump",
						"target": Vector2(1132, 1140)
					},
					{
						"type": "walk",
						"target": Vector2(1320, 1140)
					},
					{
						"type": "jump",
						"target": Vector2(1422, 1020)
					},
					{
						"type": "walk",
						"target": Vector2(1610, 1020)
					},
					{
						"type": "jump",
						"target": Vector2(1712, 900)
					},
					{
						"type": "walk",
						"target": Vector2(1900, 900)
					},
					{
						"type": "jump",
						"target": Vector2(2002, 780)
					},
					{
						"type": "walk",
						"target": Vector2(2190, 780)
					},
					{
						"type": "walk",
						"target": Vector2(2440, 780)
					}
				],
				"secret": [
					{
						"type": "walk",
						"target": Vector2(750, 1260)
					},
					{
						"type": "interact",
						"id": "output_console"
					},
					{
						"type": "walk",
						"target": Vector2(1076, 1260)
					},
					{
						"type": "jump",
						"target": Vector2(1132, 1140)
					},
					{
						"type": "walk",
						"target": Vector2(1320, 1140)
					},
					{
						"type": "drop",
						"target": Vector2(1430, 1260)
					},
					{
						"type": "walk",
						"target": Vector2(2640, 1260)
					},
					{
						"type": "interact",
						"id": "secret_9"
					}
				]
			},
			"arrival_flags": [],
			"encounter_reservations": []
		},
		{
			"id": 10,
			"title": "Balance Hall",
			"title_ar": "قاعة الأثقال",
			"theme": "balance",
			"size": Vector2(3400, 1440),
			"floor_y": 1260,
			"scene": "res://scenes/stage_01/m17_rooms/10.tscn",
			"spawns": {
				"default": Vector2(180, 1260),
				"left": Vector2(180, 1260),
				"right": Vector2(3200, 900),
				"guard_return": Vector2(680, 1260)
			},
			"platforms": [
				{
					"id": "ground",
					"rect": Rect2(0, 1260, 3400, 140),
					"one_way": false
				},
				{
					"id": "balance_bridge_1",
					"rect": Rect2(1340, 1140, 240, 120),
					"one_way": false,
					"requires": "balance_bridge_locked"
				},
				{
					"id": "balance_bridge_2",
					"rect": Rect2(1630, 1020, 240, 54),
					"one_way": true,
					"requires": "balance_bridge_locked"
				},
				{
					"id": "balance_bridge_3",
					"rect": Rect2(1920, 900, 240, 54),
					"one_way": true,
					"requires": "balance_bridge_locked"
				},
				{
					"id": "balance_upper",
					"rect": Rect2(1920, 900, 1480, 64),
					"one_way": true,
					"requires": "balance_bridge_locked"
				}
			],
			"objects": [
				{
					"id": "bench_10",
					"kind": "bench",
					"pos": Vector2(330, 1260),
					"text_key": "bench"
				},
				{
					"id": "balance_note",
					"kind": "note",
					"pos": Vector2(630, 1260),
					"note_id": "balance_record",
					"text_key": "balance_record"
				},
				{
					"id": "balance_console",
					"kind": "balance_control",
					"pos": Vector2(1000, 1260),
					"flag": "balance_bridge_locked",
					"text_key": "balance_control"
				}
			],
			"exits": [
				{
					"id": "to_9",
					"pos": Vector2(110, 1260),
					"target": 9,
					"spawn": "right",
					"requires": [],
					"combat_preview": false
				},
				{
					"id": "to_11",
					"pos": Vector2(3290, 900),
					"target": 11,
					"spawn": "left",
					"requires": ["balance_bridge_locked"],
					"combat_preview": false
				},
				{
					"id": "shortcut_10_13",
					"pos": Vector2(670, 1260),
					"target": 13,
					"spawn": "balance_return",
					"requires": ["guard_approach_return_open"],
					"combat_preview": false
				}
			],
			"hazards": [],
			"qa_paths": {
				"main": [Vector2(330, 1260), Vector2(630, 1260), Vector2(1000, 1260), Vector2(1316, 1260), Vector2(1372, 1140), Vector2(1560, 1140), Vector2(1662, 1020), Vector2(1850, 1020), Vector2(1952, 900), Vector2(2140, 900), Vector2(3290, 900)],
				"balance": [Vector2(1000, 1260)],
				"bench": [Vector2(330, 1260)],
				"shortcut": [Vector2(670, 1260)]
			},
			"qa_actions": {
				"main": [
					{
						"type": "walk",
						"target": Vector2(330, 1260)
					},
					{
						"type": "interact",
						"id": "bench_10"
					},
					{
						"type": "walk",
						"target": Vector2(630, 1260)
					},
					{
						"type": "interact",
						"id": "balance_note"
					},
					{
						"type": "walk",
						"target": Vector2(1000, 1260)
					},
					{
						"type": "interact",
						"id": "balance_console"
					},
					{
						"type": "walk",
						"target": Vector2(1316, 1260)
					},
					{
						"type": "jump",
						"target": Vector2(1372, 1140)
					},
					{
						"type": "walk",
						"target": Vector2(1560, 1140)
					},
					{
						"type": "jump",
						"target": Vector2(1662, 1020)
					},
					{
						"type": "walk",
						"target": Vector2(1850, 1020)
					},
					{
						"type": "jump",
						"target": Vector2(1952, 900)
					},
					{
						"type": "walk",
						"target": Vector2(2140, 900)
					},
					{
						"type": "walk",
						"target": Vector2(3290, 900)
					}
				],
				"balance": [
					{
						"type": "walk",
						"target": Vector2(1000, 1260)
					},
					{
						"type": "interact",
						"id": "balance_console"
					}
				],
				"bench": [
					{
						"type": "walk",
						"target": Vector2(330, 1260)
					}
				],
				"shortcut": [
					{
						"type": "walk",
						"target": Vector2(670, 1260)
					}
				]
			},
			"arrival_flags": [],
			"encounter_reservations": []
		},
		{
			"id": 11,
			"title": "Silent Lecture",
			"title_ar": "مدرجات المحاضرة الصامتة",
			"theme": "lecture",
			"size": Vector2(3800, 1440),
			"floor_y": 1260,
			"scene": "res://scenes/stage_01/m17_rooms/11.tscn",
			"spawns": {
				"default": Vector2(180, 1260),
				"left": Vector2(180, 1260),
				"right": Vector2(3600, 900)
			},
			"platforms": [
				{
					"id": "ground",
					"rect": Rect2(0, 1260, 3800, 140),
					"one_way": false
				},
				{
					"id": "lecture_main_1",
					"rect": Rect2(600, 1140, 240, 120),
					"one_way": false
				},
				{
					"id": "lecture_main_2",
					"rect": Rect2(890, 1020, 240, 54),
					"one_way": true
				},
				{
					"id": "lecture_main_3",
					"rect": Rect2(1180, 900, 240, 54),
					"one_way": true
				},
				{
					"id": "lecture_lower",
					"rect": Rect2(1180, 900, 2620, 64),
					"one_way": true
				},
				{
					"id": "projector_1",
					"rect": Rect2(1960, 780, 240, 120),
					"one_way": false
				},
				{
					"id": "projector_2",
					"rect": Rect2(2250, 660, 240, 54),
					"one_way": true
				},
				{
					"id": "projector_3",
					"rect": Rect2(2540, 540, 240, 54),
					"one_way": true
				},
				{
					"id": "projector_nook",
					"rect": Rect2(2540, 540, 700, 60),
					"one_way": true
				}
			],
			"objects": [
				{
					"id": "lecture_note",
					"kind": "note",
					"pos": Vector2(1450, 900),
					"note_id": "lecture_echo",
					"text_key": "note_lecture"
				},
				{
					"id": "secret_11",
					"kind": "note",
					"pos": Vector2(3010, 540),
					"note_id": "S05",
					"secret": "S05",
					"text_key": "secret_11"
				}
			],
			"exits": [
				{
					"id": "to_10",
					"pos": Vector2(110, 1260),
					"target": 10,
					"spawn": "right",
					"requires": [],
					"combat_preview": false
				},
				{
					"id": "to_12",
					"pos": Vector2(3690, 900),
					"target": 12,
					"spawn": "left",
					"requires": [],
					"combat_preview": false
				}
			],
			"hazards": [],
			"qa_paths": {
				"main": [Vector2(576, 1260), Vector2(632, 1140), Vector2(820, 1140), Vector2(922, 1020), Vector2(1110, 1020), Vector2(1212, 900), Vector2(1400, 900), Vector2(1450, 900), Vector2(1936, 900), Vector2(1992, 780), Vector2(2180, 780), Vector2(2320, 900), Vector2(3690, 900)],
				"secret": [Vector2(576, 1260), Vector2(632, 1140), Vector2(820, 1140), Vector2(922, 1020), Vector2(1110, 1020), Vector2(1212, 900), Vector2(1400, 900), Vector2(1450, 900), Vector2(1936, 900), Vector2(1992, 780), Vector2(2180, 780), Vector2(2282, 660), Vector2(2470, 660), Vector2(2572, 540), Vector2(2760, 540), Vector2(3010, 540)]
			},
			"qa_actions": {
				"main": [
					{
						"type": "walk",
						"target": Vector2(576, 1260)
					},
					{
						"type": "jump",
						"target": Vector2(632, 1140)
					},
					{
						"type": "walk",
						"target": Vector2(820, 1140)
					},
					{
						"type": "jump",
						"target": Vector2(922, 1020)
					},
					{
						"type": "walk",
						"target": Vector2(1110, 1020)
					},
					{
						"type": "jump",
						"target": Vector2(1212, 900)
					},
					{
						"type": "walk",
						"target": Vector2(1400, 900)
					},
					{
						"type": "walk",
						"target": Vector2(1450, 900)
					},
					{
						"type": "interact",
						"id": "lecture_note"
					},
					{
						"type": "walk",
						"target": Vector2(1936, 900)
					},
					{
						"type": "jump",
						"target": Vector2(1992, 780)
					},
					{
						"type": "walk",
						"target": Vector2(2180, 780)
					},
					{
						"type": "drop",
						"target": Vector2(2320, 900)
					},
					{
						"type": "walk",
						"target": Vector2(3690, 900)
					}
				],
				"secret": [
					{
						"type": "walk",
						"target": Vector2(576, 1260)
					},
					{
						"type": "jump",
						"target": Vector2(632, 1140)
					},
					{
						"type": "walk",
						"target": Vector2(820, 1140)
					},
					{
						"type": "jump",
						"target": Vector2(922, 1020)
					},
					{
						"type": "walk",
						"target": Vector2(1110, 1020)
					},
					{
						"type": "jump",
						"target": Vector2(1212, 900)
					},
					{
						"type": "walk",
						"target": Vector2(1400, 900)
					},
					{
						"type": "walk",
						"target": Vector2(1450, 900)
					},
					{
						"type": "interact",
						"id": "lecture_note"
					},
					{
						"type": "walk",
						"target": Vector2(1936, 900)
					},
					{
						"type": "jump",
						"target": Vector2(1992, 780)
					},
					{
						"type": "walk",
						"target": Vector2(2180, 780)
					},
					{
						"type": "jump",
						"target": Vector2(2282, 660)
					},
					{
						"type": "walk",
						"target": Vector2(2470, 660)
					},
					{
						"type": "jump",
						"target": Vector2(2572, 540)
					},
					{
						"type": "walk",
						"target": Vector2(2760, 540)
					},
					{
						"type": "walk",
						"target": Vector2(3010, 540)
					},
					{
						"type": "interact",
						"id": "secret_11"
					}
				]
			},
			"arrival_flags": [],
			"encounter_reservations": [
				{
					"id": "loop_runner_intro",
					"type": "Loop Runner",
					"rect": Rect2(1250, 720, 550, 180)
				},
				{
					"id": "familiar_mix",
					"type": "familiar",
					"rect": Rect2(2850, 720, 650, 180)
				}
			]
		},
		{
			"id": 12,
			"title": "Bindery",
			"title_ar": "مشغل التجليد",
			"theme": "bindery",
			"size": Vector2(4000, 1440),
			"floor_y": 1260,
			"scene": "res://scenes/stage_01/m17_rooms/12.tscn",
			"spawns": {
				"default": Vector2(180, 1260),
				"left": Vector2(180, 1260),
				"right": Vector2(3820, 1260),
				"archive": Vector2(3310, 1260)
			},
			"platforms": [
				{
					"id": "ground",
					"rect": Rect2(0, 1260, 4000, 140),
					"one_way": false
				}
			],
			"objects": [
				{
					"id": "workshop_service_latch",
					"kind": "shortcut",
					"pos": Vector2(2850, 1260),
					"flag": "workshop_main_passage_open",
					"text_key": "workshop_service"
				},
				{
					"id": "workshop_archive_latch",
					"kind": "shortcut",
					"pos": Vector2(3160, 1260),
					"flag": "workshop_archive_return_open",
					"requires": ["workshop_main_passage_open"],
					"text_key": "shortcut_workshop"
				},
				{
					"id": "popup_book",
					"kind": "secret_pop",
					"pos": Vector2(3520, 1260),
					"flag": "secret_S06_open",
					"text_key": "popup_control"
				},
				{
					"id": "secret_12",
					"kind": "note",
					"pos": Vector2(3790, 1260),
					"note_id": "S06",
					"secret": "S06",
					"requires": ["secret_S06_open"],
					"text_key": "secret_12"
				}
			],
			"exits": [
				{
					"id": "to_11",
					"pos": Vector2(110, 1260),
					"target": 11,
					"spawn": "right",
					"requires": [],
					"combat_preview": false
				},
				{
					"id": "to_13",
					"pos": Vector2(3890, 1260),
					"target": 13,
					"spawn": "left",
					"requires": ["workshop_main_passage_open"],
					"combat_preview": false
				},
				{
					"id": "shortcut_12_6",
					"pos": Vector2(3330, 1260),
					"target": 6,
					"spawn": "workshop",
					"requires": ["workshop_archive_return_open"],
					"combat_preview": false
				}
			],
			"hazards": [
				{
					"id": "press_1",
					"rect": Rect2(1050, 980, 180, 280),
					"period": 6.2,
					"telegraph": 1.5,
					"active": 0.85,
					"phase_offset": 0.0,
					"offset": 0.0,
					"disabled_by": "workshop_main_passage_open",
					"type": "press",
					"safe_wait_x": 900
				},
				{
					"id": "press_2",
					"rect": Rect2(1730, 980, 180, 280),
					"period": 6.2,
					"telegraph": 1.5,
					"active": 0.85,
					"phase_offset": 1.7,
					"offset": 1.7,
					"disabled_by": "workshop_main_passage_open",
					"type": "press",
					"safe_wait_x": 1580
				},
				{
					"id": "press_3",
					"rect": Rect2(2410, 980, 180, 280),
					"period": 6.2,
					"telegraph": 1.5,
					"active": 0.85,
					"phase_offset": 3.4,
					"offset": 3.4,
					"disabled_by": "workshop_main_passage_open",
					"type": "press",
					"safe_wait_x": 2260
				}
			],
			"qa_paths": {
				"main": [Vector2(1300, 1260), Vector2(1980, 1260), Vector2(2660, 1260), Vector2(2850, 1260), Vector2(3160, 1260), Vector2(3890, 1260)],
				"service": [Vector2(1300, 1260), Vector2(1980, 1260), Vector2(2660, 1260), Vector2(2850, 1260), Vector2(3160, 1260)],
				"shortcut": [Vector2(1300, 1260), Vector2(1980, 1260), Vector2(2660, 1260), Vector2(2850, 1260), Vector2(3160, 1260), Vector2(3330, 1260)],
				"secret": [Vector2(1300, 1260), Vector2(1980, 1260), Vector2(2660, 1260), Vector2(2850, 1260), Vector2(3160, 1260), Vector2(3520, 1260), Vector2(3790, 1260)]
			},
			"qa_actions": {
				"main": [
					{
						"type": "press_cross",
						"id": "press_1",
						"target": Vector2(1300, 1260)
					},
					{
						"type": "press_cross",
						"id": "press_2",
						"target": Vector2(1980, 1260)
					},
					{
						"type": "press_cross",
						"id": "press_3",
						"target": Vector2(2660, 1260)
					},
					{
						"type": "walk",
						"target": Vector2(2850, 1260)
					},
					{
						"type": "interact",
						"id": "workshop_service_latch"
					},
					{
						"type": "walk",
						"target": Vector2(3160, 1260)
					},
					{
						"type": "interact",
						"id": "workshop_archive_latch"
					},
					{
						"type": "walk",
						"target": Vector2(3890, 1260)
					}
				],
				"service": [
					{
						"type": "press_cross",
						"id": "press_1",
						"target": Vector2(1300, 1260)
					},
					{
						"type": "press_cross",
						"id": "press_2",
						"target": Vector2(1980, 1260)
					},
					{
						"type": "press_cross",
						"id": "press_3",
						"target": Vector2(2660, 1260)
					},
					{
						"type": "walk",
						"target": Vector2(2850, 1260)
					},
					{
						"type": "interact",
						"id": "workshop_service_latch"
					},
					{
						"type": "walk",
						"target": Vector2(3160, 1260)
					},
					{
						"type": "interact",
						"id": "workshop_archive_latch"
					}
				],
				"shortcut": [
					{
						"type": "press_cross",
						"id": "press_1",
						"target": Vector2(1300, 1260)
					},
					{
						"type": "press_cross",
						"id": "press_2",
						"target": Vector2(1980, 1260)
					},
					{
						"type": "press_cross",
						"id": "press_3",
						"target": Vector2(2660, 1260)
					},
					{
						"type": "walk",
						"target": Vector2(2850, 1260)
					},
					{
						"type": "interact",
						"id": "workshop_service_latch"
					},
					{
						"type": "walk",
						"target": Vector2(3160, 1260)
					},
					{
						"type": "interact",
						"id": "workshop_archive_latch"
					},
					{
						"type": "walk",
						"target": Vector2(3330, 1260)
					}
				],
				"secret": [
					{
						"type": "press_cross",
						"id": "press_1",
						"target": Vector2(1300, 1260)
					},
					{
						"type": "press_cross",
						"id": "press_2",
						"target": Vector2(1980, 1260)
					},
					{
						"type": "press_cross",
						"id": "press_3",
						"target": Vector2(2660, 1260)
					},
					{
						"type": "walk",
						"target": Vector2(2850, 1260)
					},
					{
						"type": "interact",
						"id": "workshop_service_latch"
					},
					{
						"type": "walk",
						"target": Vector2(3160, 1260)
					},
					{
						"type": "interact",
						"id": "workshop_archive_latch"
					},
					{
						"type": "walk",
						"target": Vector2(3520, 1260)
					},
					{
						"type": "interact",
						"id": "popup_book"
					},
					{
						"type": "walk",
						"target": Vector2(3790, 1260)
					},
					{
						"type": "interact",
						"id": "secret_12"
					}
				]
			},
			"arrival_flags": [],
			"encounter_reservations": []
		},
		{
			"id": 13,
			"title": "Corrector's Walk",
			"title_ar": "رواق المصحّح",
			"theme": "corrector",
			"size": Vector2(3600, 1440),
			"floor_y": 1260,
			"scene": "res://scenes/stage_01/m17_rooms/13.tscn",
			"spawns": {
				"default": Vector2(180, 1260),
				"left": Vector2(180, 1260),
				"right": Vector2(3420, 1260),
				"balance_return": Vector2(730, 1260)
			},
			"platforms": [
				{
					"id": "ground",
					"rect": Rect2(0, 1260, 3600, 140),
					"one_way": false
				}
			],
			"objects": [
				{
					"id": "guard_return_latch",
					"kind": "shortcut",
					"pos": Vector2(460, 1260),
					"flag": "guard_approach_return_open",
					"text_key": "shortcut_guard"
				},
				{
					"id": "seal_socket",
					"kind": "combat_socket",
					"pos": Vector2(2670, 1260),
					"flag": "seal_registered",
					"requires": ["guard_clear", "compiler_seal_owned"],
					"combat_preview": true,
					"text_key": "seal_socket"
				},
				{
					"id": "bench_13",
					"kind": "bench",
					"pos": Vector2(3020, 1260),
					"requires": ["guard_clear", "compiler_seal_owned"],
					"combat_preview": true,
					"text_key": "bench"
				}
			],
			"exits": [
				{
					"id": "to_12",
					"pos": Vector2(110, 1260),
					"target": 12,
					"spawn": "right",
					"requires": [],
					"combat_preview": false
				},
				{
					"id": "shortcut_13_10",
					"pos": Vector2(730, 1260),
					"target": 10,
					"spawn": "guard_return",
					"requires": ["guard_approach_return_open"],
					"combat_preview": false
				},
				{
					"id": "to_14",
					"pos": Vector2(3490, 1260),
					"target": 14,
					"spawn": "left",
					"requires": ["guard_clear", "compiler_seal_owned", "seal_registered"],
					"combat_preview": true
				}
			],
			"hazards": [],
			"qa_paths": {
				"main": [Vector2(460, 1260), Vector2(2670, 1260), Vector2(3020, 1260), Vector2(3490, 1260)],
				"shortcut": [Vector2(460, 1260), Vector2(730, 1260)],
				"bench": [Vector2(460, 1260), Vector2(2670, 1260), Vector2(3020, 1260)]
			},
			"qa_actions": {
				"main": [
					{
						"type": "walk",
						"target": Vector2(460, 1260)
					},
					{
						"type": "interact",
						"id": "guard_return_latch"
					},
					{
						"type": "walk",
						"target": Vector2(2670, 1260)
					},
					{
						"type": "interact",
						"id": "seal_socket"
					},
					{
						"type": "walk",
						"target": Vector2(3020, 1260)
					},
					{
						"type": "interact",
						"id": "bench_13"
					},
					{
						"type": "walk",
						"target": Vector2(3490, 1260)
					}
				],
				"shortcut": [
					{
						"type": "walk",
						"target": Vector2(460, 1260)
					},
					{
						"type": "interact",
						"id": "guard_return_latch"
					},
					{
						"type": "walk",
						"target": Vector2(730, 1260)
					}
				],
				"bench": [
					{
						"type": "walk",
						"target": Vector2(460, 1260)
					},
					{
						"type": "interact",
						"id": "guard_return_latch"
					},
					{
						"type": "walk",
						"target": Vector2(2670, 1260)
					},
					{
						"type": "interact",
						"id": "seal_socket"
					},
					{
						"type": "walk",
						"target": Vector2(3020, 1260)
					},
					{
						"type": "interact",
						"id": "bench_13"
					}
				]
			},
			"arrival_flags": [],
			"encounter_reservations": [
				{
					"id": "seal_guard",
					"type": "Broken TA",
					"rect": Rect2(1000, 1000, 1400, 260)
				}
			],
			"subareas": {
				"approach": Rect2(0, 950, 950, 310),
				"guardian": Rect2(950, 950, 1550, 310),
				"after_seal": Rect2(2500, 950, 1100, 310)
			}
		},
		{
			"id": 14,
			"title": "Compiler Tribunal",
			"title_ar": "قاعة المحاكمة",
			"theme": "tribunal",
			"size": Vector2(4200, 1620),
			"floor_y": 1440,
			"scene": "res://scenes/stage_01/m17_rooms/14.tscn",
			"spawns": {
				"default": Vector2(180, 1440),
				"left": Vector2(180, 1440),
				"right": Vector2(4020, 1440)
			},
			"platforms": [
				{
					"id": "ground",
					"rect": Rect2(0, 1440, 4200, 140),
					"one_way": false
				}
			],
			"objects": [
				{
					"id": "tribunal_note",
					"kind": "note",
					"pos": Vector2(620, 1440),
					"note_id": "tribunal_register",
					"text_key": "note_tribunal"
				}
			],
			"exits": [
				{
					"id": "to_13",
					"pos": Vector2(110, 1440),
					"target": 13,
					"spawn": "right",
					"requires": ["seal_registered"],
					"combat_preview": true
				},
				{
					"id": "to_15",
					"pos": Vector2(4090, 1440),
					"target": 15,
					"spawn": "left",
					"requires": ["boss_defeated"],
					"combat_preview": true
				}
			],
			"hazards": [],
			"qa_paths": {
				"main": [Vector2(620, 1440), Vector2(4090, 1440)]
			},
			"qa_actions": {
				"main": [
					{
						"type": "walk",
						"target": Vector2(620, 1440)
					},
					{
						"type": "interact",
						"id": "tribunal_note"
					},
					{
						"type": "walk",
						"target": Vector2(4090, 1440)
					}
				]
			},
			"arrival_flags": [],
			"encounter_reservations": [
				{
					"id": "dr_compiler",
					"type": "Dr. Compiler",
					"rect": Rect2(950, 1050, 2300, 390),
					"boss": true
				}
			]
		},
		{
			"id": 15,
			"title": "Next Page",
			"title_ar": "الصفحة التالية",
			"theme": "threshold",
			"size": Vector2(2800, 1440),
			"floor_y": 1260,
			"scene": "res://scenes/stage_01/m17_rooms/15.tscn",
			"spawns": {
				"default": Vector2(180, 1260),
				"left": Vector2(180, 1260),
				"right": Vector2(2620, 1260)
			},
			"platforms": [
				{
					"id": "ground",
					"rect": Rect2(0, 1260, 2800, 140),
					"one_way": false
				}
			],
			"objects": [
				{
					"id": "last_lecture_note",
					"kind": "note",
					"pos": Vector2(1280, 1260),
					"note_id": "next_lecture",
					"text_key": "note_threshold"
				}
			],
			"exits": [
				{
					"id": "to_14",
					"pos": Vector2(110, 1260),
					"target": 14,
					"spawn": "right",
					"requires": ["boss_defeated"],
					"combat_preview": true
				},
				{
					"id": "to_world2",
					"pos": Vector2(2670, 1260),
					"target": 16,
					"spawn": "arrival",
					"requires": ["boss_defeated"],
					"combat_preview": true
				}
			],
			"hazards": [],
			"qa_paths": {
				"main": [Vector2(1280, 1260), Vector2(2670, 1260)]
			},
			"qa_actions": {
				"main": [
					{
						"type": "walk",
						"target": Vector2(1280, 1260)
					},
					{
						"type": "interact",
						"id": "last_lecture_note"
					},
					{
						"type": "walk",
						"target": Vector2(2670, 1260)
					}
				]
			},
			"arrival_flags": [],
			"encounter_reservations": []
		}
	]
