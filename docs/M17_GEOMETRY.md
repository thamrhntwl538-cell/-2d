# M17 native geometry

The fifteen room definitions live in `scripts/stage/m17_layouts.gd`; room IDs are1–15. The scene stubs in `scenes/stage_01/m17_rooms` carry identity and remain editable. The controller builds native collision-bearing paper surfaces from each definition. Scene stubs contain no duplicate collisions.

Coordinates are world pixels with the origin at the top-left. Object, portal, spawn and QA route positions are foot positions. Platform rectangles use their top-left corner and collision surface y. The preserved M13 player uses speed300, jump790, gravity2050, collider30×58 and a visible height near114.

Mandatory rising steps use120px rise,220–240px landing width, and50px edge gaps. QA routes walk near the takeoff edge before jumping90–102px into the next platform; they do not attempt centre-to-centre jumps. Every first120-high step on a walking floor is a solid pedestal; subsequent surfaces are one-way. Continuous lower catch floors make failed ascent reversible.

The archive has four real floor heights:2700,1980,1260,540. Upper landings leave stairwell openings above the penultimate steps so the standing lantern does not overlap an overhead floor. Floor3 includes a separate optional right-hand gallery reached from a lower step. Three zigzag flights contain six120px jumps each, for18ordinary jumps. Its checkpoint and first shortcut are on floor2, its optional overlay puzzle on floor3, and INPUT/workshop doors on floor4. A grounded arrival rectangle records reaching the top.

The ink, output and balance stair geometry is conditional on the respective committed puzzle flags. Their triggers are several hundred pixels outside the first moving surface. Raised exits cannot be reached directly with a152px jump from the bottom floor. The controller must commit final geometry only after clearance and fold animation completion.

Each room supplies `qa_paths[name]` with footpoint arrays and `qa_actions[name]` with explicit `walk`, `jump`, `drop` and `interact` records. `main` begins at the named `left` spawn and ends at the forward portal without activating that portal. This supports actual-input engine traversal without room teleporting. Optional fixture routes are separately named.

Workshop presses use visible timing rectangles and stable waiting pockets; `disabled_by=workshop_main_passage_open` permanently restores the service passage after the player reaches its latch. Room13 separates the approach shortcut from the guardian court and post-seal checkpoint. Preview travel can cross combat requirements without awarding combat accomplishments.

The frozen definitions contain85platforms and38objects. They were structurally checked for surface-supported objects, portals and spawns. A native Godot static audit found zero core/lantern overlaps at declared spawns, objects, exits and QA footpoints using a44×112px upright core; the cape is outside that audit scope. The lab wraith nook and PROCESS turret gallery are optional branches; the main PROCESS exit stays on the lower protected floor. Final jump and timing validation belongs to the native Godot QA run; these dimensions alone are not a claim of tested playability.
