#!/usr/bin/env python3
"""Validate exported M13 motion, including the three user-reported regressions."""
import hashlib
import json
import math
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
rig = json.loads((root / 'WARDEN_M13_RIG_AUDIT.json').read_text())
errors = []
bounds = {}
max_errors = dict(torso=0.0, shoulders=0.0, arm=0.0, leg=0.0, head_lead=0.0)

for frame in rig['frames']:
    j = frame['joints']
    for key, length in [('torso', 94), ('shoulders', 88)]:
        max_errors[key] = max(max_errors[key], abs(math.dist(*j[key]) - length))
    for group, names, lengths in [
        ('arm', ['near_arm', 'far_arm'], [44, 42]),
        ('leg', ['near_leg', 'far_leg'], [54, 40, 12]),
    ]:
        for name in names:
            for i, length in enumerate(lengths):
                max_errors[group] = max(max_errors[group], abs(math.dist(j[name][i], j[name][i+1]) - length))
    across = [(j['shoulders'][1][i] - j['shoulders'][0][i]) / 88 for i in range(2)]
    offset = [j['lantern'][0][i] - j['torso'][0][i] for i in range(2)]
    projected_lead = sum(offset[i] * across[i] for i in range(2))
    perpendicular_lead = offset[0] * across[1] - offset[1] * across[0]
    max_errors['head_lead'] = max(max_errors['head_lead'], abs(projected_lead - 16), abs(perpendicular_lead))
    if j['lantern'][1] != [64, 86]:
        errors.append(frame['file'] + ': changed lantern size')
    path = root / frame['file'].removeprefix('res://')
    image = Image.open(path).convert('RGBA')
    alpha = image.getchannel('A')
    box = alpha.point(lambda a: 255 if a > 100 else 0).getbbox()
    if image.size != (512, 512) or box is None:
        errors.append(path.name + ': invalid canvas or empty frame')
    if box and (min(box[:2]) <= 1 or max(box[2:]) >= 511):
        errors.append(path.name + ': clipped silhouette')
    if alpha.getpixel((0, 0)) or alpha.getpixel((511, 511)):
        errors.append(path.name + ': opaque background')
    bounds[path.stem] = box
    for side in ['near', 'far']:
        if frame['contacts'][side] and abs(j[side + '_leg'][-1][1] - 456) > 0.001:
            errors.append(path.name + ': support foot off the floor')
        if side in frame['foot_targets']:
            target = frame['foot_targets'][side]
            if math.dist(j[side + '_leg'][-1], target[:2]) > 0.001:
                errors.append(path.name + ': foot target unreachable')

for key, deviation in max_errors.items():
    if deviation > 0.001:
        errors.append(f'{key}: model drift {deviation}')
if bounds['idle_00'][1:] != (171, bounds['idle_00'][2], 456):
    errors.append('Standing height or floor baseline changed')

run = sorted((f for f in rig['frames'] if f['motion'] == 'run'), key=lambda f: f['sample'])
support_pairs = 0
max_world_slip = 0.0
max_arm_step = 0.0
max_wrist_step = 0.0
dt = (6 / 13) / len(run)
for i, frame in enumerate(run):
    following = run[(i + 1) % len(run)]
    for side in ['near', 'far']:
        if frame['contacts'][side] and following['contacts'][side]:
            support_pairs += 1
            x0 = frame['joints'][side + '_leg'][-1][0]
            x1 = following['joints'][side + '_leg'][-1][0]
            max_world_slip = max(max_world_slip, abs((x1-x0) * .4 + 300 * dt))
        a, b = frame['joints'][side + '_arm'], following['joints'][side + '_arm']
        max_wrist_step = max(max_wrist_step, math.dist(a[-1], b[-1]))
        for k in range(2):
            angle_a = math.atan2(a[k+1][1]-a[k][1], a[k+1][0]-a[k][0])
            angle_b = math.atan2(b[k+1][1]-b[k][1], b[k+1][0]-b[k][0])
            step = abs((angle_b-angle_a+math.pi) % (2*math.pi)-math.pi)
            max_arm_step = max(max_arm_step, math.degrees(step))
if support_pairs < 8 or max_world_slip > .001:
    errors.append(f'Run support slips: pairs={support_pairs}, displacement={max_world_slip}')
if max_arm_step > 12 or max_wrist_step > 8:
    errors.append(f'Run arm arc snaps: rotation={max_arm_step}, wrist_step={max_wrist_step}')
if len(run) != 48 or len(rig['frames']) != 107:
    errors.append('Missing authored frames')

report = {
    'passed': not errors,
    'frame_count': len(rig['frames']),
    'source_canvas': [512, 512],
    'idle_visible_height_px': 285,
    'lantern_local_size_px': [64, 86],
    'head_forward_offset_px': 16,
    'max_rig_segment_error_px': max_errors,
    'run_cycle_seconds': 6 / 13,
    'run_frames': len(run),
    'tested_support_pairs': support_pairs,
    'max_support_slip_world_units_per_exported_step': max_world_slip,
    'max_run_arm_angle_step_degrees': max_arm_step,
    'max_run_wrist_step_source_px': max_wrist_step,
    'atlas_sha256': hashlib.sha256((root/'art_source/m12/warden_parts.png').read_bytes()).hexdigest(),
    'errors': errors,
    'bounds': bounds,
    'note': 'Support displacement checks steady 300-unit/s running. Displayed frames still have normal raster sampling.',
}
(root/'WARDEN_M13_ASSET_QA.json').write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps({k: v for k, v in report.items() if k != 'bounds'}, indent=2))
raise SystemExit(0 if not errors else 1)
