extends RefCounted
## M15 environment-only Stage 01 layouts. Combat requirements are real state keys;
## preview_bypass is metadata for an explicitly labelled environment preview.
## Elevator position is its CENTRE; platform rectangles use a TOP-LEFT origin.
## Each scene contains editable collision-bearing academic platform instances.

static func count() -> int:
	return 10

static func room(index: int) -> Dictionary:
	return all_rooms()[clampi(index, 0, count() - 1)]

static func all_rooms() -> Array[Dictionary]:
	return [
		{
			"id": 0,
			"room_id": 0,
			"title": "The Silent Entrance",
			"arabic_title": "المدخل الصامت",
			"mood": "entrance",
			"size": Vector2(3840, 1440),
			"floor_y": 1260,
			"route_y": 1260,
			"scene": "res://scenes/stage_01/rooms/00_entrance.tscn",
			"spawn_left": Vector2(180, 1260),
			"spawn_right": Vector2(3660, 1260),
			"spawns": {
				"left": Vector2(180, 1260),
				"right": Vector2(3660, 1260)
			},
			"exits": [
				{
					"id": "to_assignments",
					"pos": Vector2(3740, 1260),
					"x": 3740,
					"y": 1260,
					"target": 1,
					"target_spawn": "left",
					"label": "Hall of Forgotten Assignments",
					"requires": "entrance_access",
					"preview_bypass": false,
					"arabic_label": "ردهة الواجبات المنسية"
				}
			],
			"interactables": [
				{
					"id": "entrance_access",
					"kind": "terminal",
					"pos": Vector2(2475, 780),
					"label": "RESTORE ACCESS",
					"flag": "entrance_access",
					"arabic_label": "إعادة الوصول"
				},
				{
					"id": "entrance_bench",
					"kind": "bench",
					"pos": Vector2(350, 1260),
					"label": "REST & SAVE",
					"arabic_label": "استراحة وحفظ"
				},
				{
					"id": "entrance_note",
					"kind": "note",
					"pos": Vector2(2410, 550),
					"label": "OFFICE HOURS",
					"text": "Office hours: indefinitely postponed.",
					"arabic_text": "الساعات المكتبية: مؤجلة إلى أجل غير مسمى.",
					"arabic_label": "الساعات المكتبية"
				}
			],
			"gates": [
				{
					"id": "entrance_gate",
					"pos": Vector2(3370, 1260),
					"requires": "entrance_access",
					"height": 286,
					"preview_bypass": false
				}
			],
			"encounter_zones": [],
			"hazards": [],
			"moving_platforms": [],
			"elevator": {},
			"platforms": [
				{
					"name": "Ground",
					"rect": Rect2(0, 1260, 3840, 100),
					"one_way": false
				},
				{
					"name": "FirstLedge",
					"rect": Rect2(690, 1140, 230, 120),
					"one_way": false
				},
				{
					"name": "SecondLedge",
					"rect": Rect2(970, 1020, 240, 63),
					"one_way": true
				},
				{
					"name": "ThirdLedge",
					"rect": Rect2(1260, 900, 240, 63),
					"one_way": true
				},
				{
					"name": "UpperStair",
					"rect": Rect2(1550, 780, 300, 70),
					"one_way": true
				},
				{
					"name": "Gallery",
					"rect": Rect2(1910, 780, 650, 70),
					"one_way": true
				},
				{
					"name": "NookStep",
					"rect": Rect2(2600, 660, 210, 60),
					"one_way": true
				},
				{
					"name": "ReadingNook",
					"rect": Rect2(2310, 550, 220, 60),
					"one_way": true
				}
			]
		},
		{
			"id": 1,
			"room_id": 1,
			"title": "The Hall of Forgotten Assignments",
			"arabic_title": "ردهة الواجبات المنسية",
			"mood": "corridor",
			"size": Vector2(2800, 1440),
			"floor_y": 1260,
			"route_y": 1260,
			"scene": "res://scenes/stage_01/rooms/01_corridor.tscn",
			"spawn_left": Vector2(180, 1260),
			"spawn_right": Vector2(2620, 1260),
			"spawns": {
				"left": Vector2(180, 1260),
				"right": Vector2(2620, 1260),
				"shortcut": Vector2(1320, 900)
			},
			"exits": [
				{
					"id": "to_entrance",
					"pos": Vector2(110, 1260),
					"x": 110,
					"y": 1260,
					"target": 0,
					"target_spawn": "right",
					"label": "Silent Entrance",
					"requires": "",
					"preview_bypass": false,
					"arabic_label": "المدخل الصامت"
				},
				{
					"id": "to_laboratory",
					"pos": Vector2(2690, 1260),
					"x": 2690,
					"y": 1260,
					"target": 2,
					"target_spawn": "left",
					"label": "Corrupted Computer Laboratory",
					"requires": "encounter:assignments",
					"preview_bypass": true,
					"arabic_label": "مختبر الحاسوب الفاسد"
				},
				{
					"id": "archive_shortcut",
					"pos": Vector2(1510, 900),
					"x": 1510,
					"y": 900,
					"target": 3,
					"target_spawn": "shortcut",
					"label": "Archive Shortcut",
					"requires": "archive_shortcut",
					"preview_bypass": false,
					"arabic_label": "الأرشيف الرأسي"
				}
			],
			"interactables": [
				{
					"id": "assignment_notice",
					"kind": "note",
					"pos": Vector2(1420, 900),
					"label": "LATE SUBMISSION",
					"text": "Late work is accepted only after the end of time.",
					"arabic_text": "يُقبل التسليم المتأخر بعد نهاية الزمن فقط.",
					"arabic_label": "تسليم متأخر"
				}
			],
			"gates": [
				{
					"id": "assignment_clearance_gate",
					"pos": Vector2(2440, 1260),
					"requires": "encounter:assignments",
					"height": 286,
					"preview_bypass": true
				}
			],
			"encounter_zones": [Rect2(1700, 1030, 600, 230)],
			"hazards": [],
			"moving_platforms": [],
			"elevator": {},
			"platforms": [
				{
					"name": "Ground",
					"rect": Rect2(0, 1260, 2800, 100),
					"one_way": false
				},
				{
					"name": "NoticeboardStep",
					"rect": Rect2(530, 1140, 230, 120),
					"one_way": false
				},
				{
					"name": "AssignmentBalconyStep",
					"rect": Rect2(810, 1020, 250, 63),
					"one_way": true
				},
				{
					"name": "ArchiveShortcutBalcony",
					"rect": Rect2(1120, 900, 520, 70),
					"one_way": true
				},
				{
					"name": "HighNoticeLedge",
					"rect": Rect2(1700, 780, 240, 60),
					"one_way": true
				}
			]
		},
		{
			"id": 2,
			"room_id": 2,
			"title": "The Corrupted Computer Laboratory",
			"arabic_title": "مختبر الحاسوب الفاسد",
			"mood": "lab",
			"size": Vector2(3200, 1800),
			"floor_y": 1620,
			"route_y": 1260,
			"scene": "res://scenes/stage_01/rooms/02_lab.tscn",
			"spawn_left": Vector2(180, 1260),
			"spawn_right": Vector2(3020, 1260),
			"spawns": {
				"left": Vector2(180, 1260),
				"right": Vector2(3020, 1260),
				"shortcut": Vector2(2320, 900)
			},
			"exits": [
				{
					"id": "to_assignments",
					"pos": Vector2(110, 1260),
					"x": 110,
					"y": 1260,
					"target": 1,
					"target_spawn": "right",
					"label": "Forgotten Assignments",
					"requires": "",
					"preview_bypass": false,
					"arabic_label": "ردهة الواجبات المنسية"
				},
				{
					"id": "to_archive",
					"pos": Vector2(3090, 1260),
					"x": 3090,
					"y": 1260,
					"target": 3,
					"target_spawn": "left",
					"label": "Vertical Archive",
					"requires": "",
					"preview_bypass": false,
					"arabic_label": "الأرشيف الرأسي"
				},
				{
					"id": "output_shortcut",
					"pos": Vector2(2470, 900),
					"x": 2470,
					"y": 900,
					"target": 6,
					"target_spawn": "shortcut",
					"label": "Output Service Link",
					"requires": "puzzle_complete",
					"preview_bypass": false,
					"arabic_label": "خزنة الإخراج"
				}
			],
			"interactables": [
				{
					"id": "lab_maintenance_note",
					"kind": "note",
					"pos": Vector2(450, 1620),
					"label": "MAINTENANCE LOG",
					"text": "The machines still wait for a student who never returned.",
					"arabic_text": "ما زالت الأجهزة تنتظر طالبًا لم يعد.",
					"arabic_label": "سجل الصيانة"
				},
				{
					"id": "lab_upper_terminal",
					"kind": "note",
					"pos": Vector2(2200, 900),
					"label": "LAST LOGIN",
					"text": "Last login: the same morning, again.",
					"arabic_text": "آخر تسجيل دخول: الصباح نفسه، مجددًا.",
					"arabic_label": "آخر تسجيل دخول"
				}
			],
			"gates": [],
			"encounter_zones": [Rect2(1900, 1030, 850, 230)],
			"hazards": [
				{
					"id": "unstable_power_bank",
					"pos": Vector2(2430, 1620),
					"width": 210,
					"height": 145,
					"period": 4.8,
					"active_seconds": 0.75,
					"telegraph_seconds": 1.2,
					"optional": true
				}
			],
			"moving_platforms": [],
			"elevator": {},
			"platforms": [
				{
					"name": "MaintenanceFloor",
					"rect": Rect2(0, 1620, 3200, 100),
					"one_way": false
				},
				{
					"name": "WestComputerWalkway",
					"rect": Rect2(0, 1260, 1100, 80),
					"one_way": false
				},
				{
					"name": "EastComputerWalkway",
					"rect": Rect2(1740, 1260, 1460, 80),
					"one_way": false
				},
				{
					"name": "LabUpperStep",
					"rect": Rect2(950, 1140, 250, 120),
					"one_way": false
				},
				{
					"name": "SuspendedDeskBridge",
					"rect": Rect2(1260, 1020, 240, 63),
					"one_way": true
				},
				{
					"name": "ArchiveSideLanding",
					"rect": Rect2(1550, 1140, 190, 63),
					"one_way": true
				},
				{
					"name": "UpperComputerDesk",
					"rect": Rect2(1580, 900, 350, 70),
					"one_way": true
				},
				{
					"name": "ServiceGallery",
					"rect": Rect2(1980, 900, 650, 70),
					"one_way": true
				},
				{
					"name": "MaintenanceReturnStep",
					"rect": Rect2(1210, 1500, 230, 120),
					"one_way": false
				},
				{
					"name": "MaintenanceReturnLedge",
					"rect": Rect2(1480, 1380, 230, 63),
					"one_way": true
				}
			]
		},
		{
			"id": 3,
			"room_id": 3,
			"title": "The Vertical Archive",
			"arabic_title": "الأرشيف الرأسي",
			"mood": "archive",
			"size": Vector2(2240, 2880),
			"floor_y": 2700,
			"route_y": 2700,
			"scene": "res://scenes/stage_01/rooms/03_archive.tscn",
			"spawn_left": Vector2(500, 2700),
			"spawn_right": Vector2(2020, 660),
			"spawns": {
				"left": Vector2(500, 2700),
				"right": Vector2(2020, 660),
				"shortcut": Vector2(600, 1980)
			},
			"exits": [
				{
					"id": "to_laboratory",
					"pos": Vector2(110, 2700),
					"x": 110,
					"y": 2700,
					"target": 2,
					"target_spawn": "right",
					"label": "Computer Laboratory",
					"requires": "",
					"preview_bypass": false,
					"arabic_label": "مختبر الحاسوب الفاسد"
				},
				{
					"id": "to_input",
					"pos": Vector2(2140, 660),
					"x": 2140,
					"y": 660,
					"target": 4,
					"target_spawn": "left",
					"label": "INPUT Chamber",
					"requires": "",
					"preview_bypass": false,
					"arabic_label": "غرفة الإدخال"
				},
				{
					"id": "assignment_shortcut",
					"pos": Vector2(550, 1980),
					"x": 550,
					"y": 1980,
					"target": 1,
					"target_spawn": "shortcut",
					"label": "Assignments Shortcut",
					"requires": "archive_shortcut",
					"preview_bypass": false,
					"arabic_label": "ردهة الواجبات المنسية"
				}
			],
			"interactables": [
				{
					"id": "archive_shortcut",
					"kind": "lever",
					"pos": Vector2(720, 1980),
					"label": "UNLOCK ARCHIVE SHORTCUT",
					"flag": "archive_shortcut",
					"arabic_label": "فتح اختصار الأرشيف"
				},
				{
					"id": "archive_upper_note",
					"kind": "note",
					"pos": Vector2(750, 660),
					"label": "CATALOGUE 000",
					"text": "A book is missing. Its absence has a catalogue number.",
					"arabic_text": "كتاب مفقود. ولغيابه رقم في الفهرس.",
					"arabic_label": "فهرس رقم صفر"
				},
				{
					"id": "archive_secret",
					"kind": "lever",
					"pos": Vector2(1830, 1260),
					"label": "OPEN SHELF PASSAGE",
					"flag": "archive_secret",
					"arabic_label": "فتح الممر خلف الرف"
				},
				{
					"id": "archive_hidden_note",
					"kind": "note",
					"pos": Vector2(2050, 1260),
					"label": "FORGOTTEN INDEX",
					"text": "The missing student has no name, only an unfinished assignment.",
					"arabic_text": "الطالب المفقود بلا اسم، ولا يبقى منه سوى واجب غير مكتمل.",
					"arabic_label": "الفهرس المنسي"
				}
			],
			"gates": [],
			"encounter_zones": [],
			"hazards": [],
			"moving_platforms": [],
			"elevator": {
				"id": "archive_lift",
				"pos": Vector2(1125, 2700),
				"width": 300,
				"stops": [2700, 1980, 1260, 660],
				"speed": 300,
				"required_main_route": true
			},
			"lift_calls": [
				{
					"id": "lift_call_0",
					"pos": Vector2(1125, 2700),
					"stop": 0
				},
				{
					"id": "lift_call_1_left",
					"pos": Vector2(820, 1980),
					"stop": 1
				},
				{
					"id": "lift_call_1_right",
					"pos": Vector2(1435, 1980),
					"stop": 1
				},
				{
					"id": "lift_call_2_left",
					"pos": Vector2(820, 1260),
					"stop": 2
				},
				{
					"id": "lift_call_2_right",
					"pos": Vector2(1435, 1260),
					"stop": 2
				},
				{
					"id": "lift_call_3_left",
					"pos": Vector2(820, 660),
					"stop": 3
				},
				{
					"id": "lift_call_3_right",
					"pos": Vector2(1435, 660),
					"stop": 3
				}
			],
			"secret_passages": [
				{
					"id": "archive_shelf_passage",
					"pos": Vector2(1900, 1260),
					"requires": "archive_secret",
					"label": "Forgotten Index"
				}
			],
			"platforms": [
				{
					"name": "Ground",
					"rect": Rect2(0, 2700, 2240, 100),
					"one_way": false
				},
				{
					"name": "LowerWestBalcony",
					"rect": Rect2(430, 1980, 430, 70),
					"one_way": true
				},
				{
					"name": "LowerEastBalcony",
					"rect": Rect2(1390, 1980, 710, 70),
					"one_way": true
				},
				{
					"name": "MiddleWestBalcony",
					"rect": Rect2(430, 1260, 430, 70),
					"one_way": true
				},
				{
					"name": "MiddleEastBalcony",
					"rect": Rect2(1390, 1260, 710, 70),
					"one_way": true
				},
				{
					"name": "UpperWestBalcony",
					"rect": Rect2(690, 660, 170, 70),
					"one_way": true
				},
				{
					"name": "UpperEastBalcony",
					"rect": Rect2(1390, 660, 850, 70),
					"one_way": true
				},
				{
					"name": "ArchiveStair01",
					"rect": Rect2(140, 2580, 240, 120),
					"one_way": false
				},
				{
					"name": "ArchiveStair02",
					"rect": Rect2(430, 2460, 240, 63),
					"one_way": true
				},
				{
					"name": "ArchiveStair03",
					"rect": Rect2(140, 2340, 240, 63),
					"one_way": true
				},
				{
					"name": "ArchiveStair04",
					"rect": Rect2(430, 2220, 240, 63),
					"one_way": true
				},
				{
					"name": "ArchiveStair05",
					"rect": Rect2(140, 2100, 240, 63),
					"one_way": true
				},
				{
					"name": "ArchiveStair06",
					"rect": Rect2(140, 1860, 240, 63),
					"one_way": true
				},
				{
					"name": "ArchiveStair07",
					"rect": Rect2(430, 1740, 240, 63),
					"one_way": true
				},
				{
					"name": "ArchiveStair08",
					"rect": Rect2(140, 1620, 240, 63),
					"one_way": true
				},
				{
					"name": "ArchiveStair09",
					"rect": Rect2(430, 1500, 240, 63),
					"one_way": true
				},
				{
					"name": "ArchiveStair10",
					"rect": Rect2(140, 1380, 240, 63),
					"one_way": true
				},
				{
					"name": "ArchiveStair11",
					"rect": Rect2(690, 1140, 170, 120),
					"one_way": false
				},
				{
					"name": "ArchiveStair12",
					"rect": Rect2(400, 1020, 240, 63),
					"one_way": true
				},
				{
					"name": "ArchiveStair13",
					"rect": Rect2(690, 900, 170, 63),
					"one_way": true
				},
				{
					"name": "ArchiveStair14",
					"rect": Rect2(400, 780, 240, 63),
					"one_way": true
				}
			]
		},
		{
			"id": 4,
			"room_id": 4,
			"title": "The INPUT Chamber",
			"arabic_title": "غرفة الإدخال",
			"mood": "input",
			"size": Vector2(2400, 1440),
			"floor_y": 1260,
			"route_y": 1260,
			"scene": "res://scenes/stage_01/rooms/04_input.tscn",
			"spawn_left": Vector2(500, 1260),
			"spawn_right": Vector2(2220, 1260),
			"spawns": {
				"left": Vector2(500, 1260),
				"right": Vector2(2220, 1260)
			},
			"exits": [
				{
					"id": "to_archive",
					"pos": Vector2(110, 1260),
					"x": 110,
					"y": 1260,
					"target": 3,
					"target_spawn": "right",
					"label": "Vertical Archive",
					"requires": "",
					"preview_bypass": false,
					"arabic_label": "الأرشيف الرأسي"
				},
				{
					"id": "to_process",
					"pos": Vector2(2290, 1260),
					"x": 2290,
					"y": 1260,
					"target": 5,
					"target_spawn": "left",
					"label": "PROCESS Hall",
					"requires": "input",
					"preview_bypass": false,
					"arabic_label": "قاعة المعالجة"
				}
			],
			"interactables": [
				{
					"id": "input",
					"kind": "puzzle_input",
					"pos": Vector2(780, 1260),
					"label": "INPUT",
					"flag": "input",
					"arabic_label": "الإدخال"
				},
				{
					"id": "input_upper_note",
					"kind": "note",
					"pos": Vector2(960, 900),
					"label": "A VALUE ENTERS",
					"text": "A value enters. The machine listens.",
					"arabic_text": "تدخل قيمة. وتنصت الآلة.",
					"arabic_label": "تدخل قيمة"
				}
			],
			"gates": [
				{
					"id": "input_gate",
					"pos": Vector2(2070, 1260),
					"requires": "input",
					"height": 286,
					"preview_bypass": false
				}
			],
			"encounter_zones": [],
			"hazards": [],
			"moving_platforms": [],
			"elevator": {},
			"platforms": [
				{
					"name": "Ground",
					"rect": Rect2(0, 1260, 2400, 100),
					"one_way": false
				},
				{
					"name": "InputStair",
					"rect": Rect2(150, 1140, 220, 120),
					"one_way": false
				},
				{
					"name": "InputUpperStep",
					"rect": Rect2(430, 1020, 240, 63),
					"one_way": true
				},
				{
					"name": "InputObservationGallery",
					"rect": Rect2(720, 900, 440, 70),
					"one_way": true
				}
			]
		},
		{
			"id": 5,
			"room_id": 5,
			"title": "The PROCESS Hall",
			"arabic_title": "قاعة المعالجة",
			"mood": "process",
			"size": Vector2(2800, 1440),
			"floor_y": 1260,
			"route_y": 1260,
			"scene": "res://scenes/stage_01/rooms/05_process.tscn",
			"spawn_left": Vector2(500, 1260),
			"spawn_right": Vector2(2620, 1260),
			"spawns": {
				"left": Vector2(500, 1260),
				"right": Vector2(2620, 1260)
			},
			"exits": [
				{
					"id": "to_input",
					"pos": Vector2(110, 1260),
					"x": 110,
					"y": 1260,
					"target": 4,
					"target_spawn": "right",
					"label": "INPUT Chamber",
					"requires": "",
					"preview_bypass": false,
					"arabic_label": "غرفة الإدخال"
				},
				{
					"id": "to_output",
					"pos": Vector2(2690, 1260),
					"x": 2690,
					"y": 1260,
					"target": 6,
					"target_spawn": "left",
					"label": "OUTPUT Vault",
					"requires": "process",
					"preview_bypass": false,
					"arabic_label": "خزنة الإخراج"
				}
			],
			"interactables": [
				{
					"id": "process",
					"kind": "puzzle_process",
					"pos": Vector2(1310, 1260),
					"label": "PROCESS",
					"flag": "process",
					"arabic_label": "المعالجة"
				}
			],
			"gates": [
				{
					"id": "process_gate",
					"pos": Vector2(2480, 1260),
					"requires": "process",
					"height": 286,
					"preview_bypass": false
				}
			],
			"encounter_zones": [],
			"hazards": [
				{
					"id": "logic_vent",
					"pos": Vector2(2090, 900),
					"width": 170,
					"height": 135,
					"period": 5.2,
					"active_seconds": 0.7,
					"telegraph_seconds": 1.4,
					"optional": true
				}
			],
			"moving_platforms": [
				{
					"id": "process_carriage",
					"pos": Vector2(1390, 1020),
					"width": 240,
					"points": [Vector2(1390, 1020), Vector2(1800, 1020)],
					"speed": 95
				}
			],
			"elevator": {},
			"platforms": [
				{
					"name": "Ground",
					"rect": Rect2(0, 1260, 2800, 100),
					"one_way": false
				},
				{
					"name": "ProcessStair",
					"rect": Rect2(150, 1140, 220, 120),
					"one_way": false
				},
				{
					"name": "ProcessUpperStep",
					"rect": Rect2(430, 1020, 240, 63),
					"one_way": true
				},
				{
					"name": "ProcessObservationDeck",
					"rect": Rect2(720, 900, 470, 70),
					"one_way": true
				},
				{
					"name": "EastMachineShelf",
					"rect": Rect2(1960, 900, 340, 70),
					"one_way": true
				}
			]
		},
		{
			"id": 6,
			"room_id": 6,
			"title": "The OUTPUT Vault",
			"arabic_title": "خزنة الإخراج",
			"mood": "output",
			"size": Vector2(2600, 1440),
			"floor_y": 1260,
			"route_y": 1260,
			"scene": "res://scenes/stage_01/rooms/06_output.tscn",
			"spawn_left": Vector2(500, 1260),
			"spawn_right": Vector2(2420, 1260),
			"spawns": {
				"left": Vector2(500, 1260),
				"right": Vector2(2420, 1260),
				"shortcut": Vector2(1710, 900)
			},
			"exits": [
				{
					"id": "to_process",
					"pos": Vector2(110, 1260),
					"x": 110,
					"y": 1260,
					"target": 5,
					"target_spawn": "right",
					"label": "PROCESS Hall",
					"requires": "",
					"preview_bypass": false,
					"arabic_label": "قاعة المعالجة"
				},
				{
					"id": "to_approach",
					"pos": Vector2(2490, 1260),
					"x": 2490,
					"y": 1260,
					"target": 7,
					"target_spawn": "left",
					"label": "Compiler Approach",
					"requires": "output",
					"preview_bypass": false,
					"arabic_label": "ممر الاقتراب من المترجم"
				},
				{
					"id": "laboratory_shortcut",
					"pos": Vector2(1870, 900),
					"x": 1870,
					"y": 900,
					"target": 2,
					"target_spawn": "shortcut",
					"label": "Laboratory Shortcut",
					"requires": "puzzle_complete",
					"preview_bypass": false,
					"arabic_label": "مختبر الحاسوب الفاسد"
				}
			],
			"interactables": [
				{
					"id": "output",
					"kind": "puzzle_output",
					"pos": Vector2(1210, 1260),
					"label": "OUTPUT",
					"flag": "output",
					"arabic_label": "الإخراج"
				}
			],
			"gates": [
				{
					"id": "output_gate",
					"pos": Vector2(2280, 1260),
					"requires": "output",
					"height": 286,
					"preview_bypass": false
				}
			],
			"encounter_zones": [],
			"hazards": [],
			"moving_platforms": [],
			"elevator": {},
			"core": {
				"pos": Vector2(1210, 730),
				"radius": 75
			},
			"platforms": [
				{
					"name": "Ground",
					"rect": Rect2(0, 1260, 2600, 100),
					"one_way": false
				},
				{
					"name": "OutputStair",
					"rect": Rect2(150, 1140, 220, 120),
					"one_way": false
				},
				{
					"name": "OutputUpperStep",
					"rect": Rect2(430, 1020, 240, 63),
					"one_way": true
				},
				{
					"name": "OutputGalleryWest",
					"rect": Rect2(720, 900, 370, 70),
					"one_way": true
				},
				{
					"name": "OutputGalleryLink",
					"rect": Rect2(1150, 900, 280, 70),
					"one_way": true
				},
				{
					"name": "LabShortcutGallery",
					"rect": Rect2(1490, 900, 600, 70),
					"one_way": true
				}
			]
		},
		{
			"id": 7,
			"room_id": 7,
			"title": "The Compiler's Approach",
			"arabic_title": "ممر الاقتراب من المترجم",
			"mood": "approach",
			"size": Vector2(3200, 1440),
			"floor_y": 1260,
			"route_y": 1260,
			"scene": "res://scenes/stage_01/rooms/07_approach.tscn",
			"spawn_left": Vector2(180, 1260),
			"spawn_right": Vector2(3020, 1260),
			"spawns": {
				"left": Vector2(180, 1260),
				"right": Vector2(3020, 1260)
			},
			"exits": [
				{
					"id": "to_output",
					"pos": Vector2(110, 1260),
					"x": 110,
					"y": 1260,
					"target": 6,
					"target_spawn": "right",
					"label": "OUTPUT Vault",
					"requires": "",
					"preview_bypass": false,
					"arabic_label": "خزنة الإخراج"
				},
				{
					"id": "to_tribunal",
					"pos": Vector2(3090, 1260),
					"x": 3090,
					"y": 1260,
					"target": 8,
					"target_spawn": "left",
					"label": "Lecture Tribunal",
					"requires": "compiler_seal",
					"preview_bypass": true,
					"arabic_label": "قاعة المحاكمة الأكاديمية"
				}
			],
			"interactables": [
				{
					"id": "approach_bench",
					"kind": "bench",
					"pos": Vector2(350, 1260),
					"label": "REST & SAVE",
					"arabic_label": "استراحة وحفظ"
				},
				{
					"id": "compiler_seal_socket",
					"kind": "seal_socket",
					"pos": Vector2(2850, 1260),
					"label": "COMPILER SEAL REQUIRED",
					"requires": "compiler_seal",
					"arabic_label": "مطلوب ختم المترجم"
				}
			],
			"gates": [
				{
					"id": "compiler_access_gate",
					"pos": Vector2(2860, 1260),
					"requires": "compiler_seal",
					"height": 310,
					"preview_bypass": true
				}
			],
			"encounter_zones": [Rect2(1540, 1010, 1000, 250)],
			"hazards": [],
			"moving_platforms": [],
			"elevator": {},
			"encounter_access_item": {
				"id": "compiler_seal",
				"award_requires": "encounter:approach",
				"drop_position": Vector2(2400, 1260),
				"automatic_award": false
			},
			"platforms": [
				{
					"name": "Ground",
					"rect": Rect2(0, 1260, 3200, 100),
					"one_way": false
				},
				{
					"name": "ScholarStep",
					"rect": Rect2(650, 1140, 230, 120),
					"one_way": false
				},
				{
					"name": "ScholarBalcony",
					"rect": Rect2(940, 1020, 300, 63),
					"one_way": true
				},
				{
					"name": "ExaminationGallery",
					"rect": Rect2(1300, 900, 340, 70),
					"one_way": true
				}
			]
		},
		{
			"id": 8,
			"room_id": 8,
			"title": "The Lecture Tribunal",
			"arabic_title": "قاعة المحاكمة الأكاديمية",
			"mood": "tribunal",
			"size": Vector2(4200, 1800),
			"floor_y": 1620,
			"route_y": 1620,
			"scene": "res://scenes/stage_01/rooms/08_tribunal.tscn",
			"spawn_left": Vector2(200, 1620),
			"spawn_right": Vector2(4000, 1620),
			"spawns": {
				"left": Vector2(200, 1620),
				"right": Vector2(4000, 1620)
			},
			"exits": [
				{
					"id": "to_approach",
					"pos": Vector2(110, 1620),
					"x": 110,
					"y": 1620,
					"target": 7,
					"target_spawn": "right",
					"label": "Compiler's Approach",
					"requires": "",
					"preview_bypass": false,
					"arabic_label": "ممر الاقتراب من المترجم"
				},
				{
					"id": "to_aftermath",
					"pos": Vector2(4090, 1620),
					"x": 4090,
					"y": 1620,
					"target": 9,
					"target_spawn": "left",
					"label": "Aftermath Passage",
					"requires": "boss_defeated",
					"preview_bypass": true,
					"arabic_label": "ممر ما بعد المحاكمة"
				}
			],
			"interactables": [
				{
					"id": "tribunal_relay",
					"kind": "arena_reaction",
					"pos": Vector2(2100, 1620),
					"label": "ACADEMIC CORE",
					"flag": "arena_charged",
					"arabic_label": "النواة الأكاديمية"
				}
			],
			"gates": [
				{
					"id": "aftermath_gate",
					"pos": Vector2(3810, 1620),
					"requires": "boss_defeated",
					"height": 330,
					"preview_bypass": true
				}
			],
			"encounter_zones": [Rect2(700, 1100, 2850, 520)],
			"hazards": [],
			"moving_platforms": [],
			"elevator": {},
			"arena": {
				"combat_rect": Rect2(700, 900, 2850, 720),
				"boss_spawn": Vector2(3000, 1620),
				"camera_focus": Vector2(2450, 1260),
				"phase_two_reaction": "cyan_window_pulse",
				"reaction_is_damage": false
			},
			"core": {
				"pos": Vector2(2100, 900),
				"radius": 110
			},
			"platforms": [
				{
					"name": "TribunalFloor",
					"rect": Rect2(0, 1620, 4200, 120),
					"one_way": false
				}
			]
		},
		{
			"id": 9,
			"room_id": 9,
			"title": "The Aftermath Passage",
			"arabic_title": "ممر ما بعد المحاكمة",
			"mood": "aftermath",
			"size": Vector2(2200, 1440),
			"floor_y": 1260,
			"route_y": 1260,
			"scene": "res://scenes/stage_01/rooms/09_aftermath.tscn",
			"spawn_left": Vector2(180, 1260),
			"spawn_right": Vector2(2020, 1260),
			"spawns": {
				"left": Vector2(180, 1260),
				"right": Vector2(2020, 1260)
			},
			"exits": [
				{
					"id": "to_tribunal",
					"pos": Vector2(110, 1260),
					"x": 110,
					"y": 1260,
					"target": 8,
					"target_spawn": "right",
					"label": "Lecture Tribunal",
					"requires": "",
					"preview_bypass": false,
					"arabic_label": "قاعة المحاكمة الأكاديمية"
				},
				{
					"id": "stage_02_threshold",
					"pos": Vector2(2090, 1260),
					"x": 2090,
					"y": 1260,
					"target": -1,
					"target_spawn": "left",
					"label": "Stage 02 Threshold",
					"requires": "boss_defeated",
					"preview_bypass": true,
					"arabic_label": "عتبة المرحلة الثانية"
				}
			],
			"interactables": [
				{
					"id": "aftermath_note",
					"kind": "note",
					"pos": Vector2(1100, 1260),
					"label": "THE NEXT LECTURE",
					"text": "For the first time, the bell sounds distant.",
					"arabic_text": "للمرة الأولى، يبدو صوت الجرس بعيدًا.",
					"arabic_label": "المحاضرة التالية"
				}
			],
			"gates": [],
			"encounter_zones": [],
			"hazards": [],
			"moving_platforms": [],
			"elevator": {},
			"ending_position": Vector2(2050, 1260),
			"platforms": [
				{
					"name": "Ground",
					"rect": Rect2(0, 1260, 2200, 100),
					"one_way": false
				}
			]
		}
	]
