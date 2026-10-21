#!/usr/bin/env python3
"""Read-only validation of the Godot-baked frames and recorded rigid joints.

Requires Pillow. Does not alter artwork or normalize any per-pose image scale.
Run after tools/bake_m12.gd. The gameplay test is a separate real Godot run.
"""
import json
import math
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
rig = json.loads((root / 'WARDEN_M12_RIG_AUDIT.json').read_text())
errors = []
bounds = {}
max_errors = dict(torso=0.0, shoulders=0.0, arm=0.0, leg=0.0)

for frame in rig['frames']:
    joints = frame['joints']
    for key, target in [('torso', 94), ('shoulders', 88)]:
        max_errors[key] = max(max_errors[key], abs(math.dist(*joints[key]) - target))
    for group, names, expected in [
        ('arm', ['far_arm', 'near_arm'], [44, 42]),
        ('leg', ['far_leg', 'near_leg'], [54, 40, 12]),
    ]:
        for name in names:
            points = joints[name]
            for i, length in enumerate(expected):
                max_errors[group] = max(max_errors[group], abs(math.dist(points[i], points[i+1]) - length))
    if joints['lantern'][1] != [64, 86]:
        errors.append(frame['file'] + ': changed head size')
    path = root / frame['file'].removeprefix('res://')
    image = Image.open(path).convert('RGBA')
    alpha = image.getchannel('A')
    box = alpha.point(lambda a: 255 if a > 100 else 0).getbbox()
    if image.size != (512, 512) or box is None:
        errors.append(str(path) + ': invalid canvas or empty frame')
    if box and (min(box[:2]) <= 1 or max(box[2:]) >= 511):
        errors.append(str(path) + ': clipped silhouette')
    if alpha.getpixel((0, 0)) or alpha.getpixel((511, 511)):
        errors.append(str(path) + ': opaque background')
    bounds[path.stem] = box
    if frame['motion'] in ['idle', 'stop', 'land']:
        for name in ['far_leg', 'near_leg']:
            if abs(joints[name][-1][1] - 456.0) > 0.001:
                errors.append(path.stem + ': planted sole drift')
        if abs(box[3] - 456) > 1:
            errors.append(path.stem + ': boot artwork below/above the floor')

for key, deviation in max_errors.items():
    if deviation > 0.001:
        errors.append(f'{key}: rigid length drift {deviation}')

idle = bounds['idle_00']
if idle[1] != 171 or idle[3] != 456:
    errors.append(f'Idle baseline/height changed: {idle}')

report = {
    'passed': not errors,
    'frame_count': len(rig['frames']),
    'source_canvas': [512, 512],
    'idle_visible_height_px': idle[3] - idle[1],
    'lantern_local_size_px': [64, 86],
    'max_rig_segment_error_px': max_errors,
    'errors': errors,
    'bounds': bounds,
    'note': 'Airborne/tucked silhouettes may be shorter; no image-level compensating scale is used.',
}
(root / 'WARDEN_M12_ASSET_QA.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({k: v for k, v in report.items() if k != 'bounds'}, indent=2))
raise SystemExit(0 if report['passed'] else 1)
