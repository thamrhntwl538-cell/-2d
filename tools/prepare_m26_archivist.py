#!/usr/bin/env python3
"""Losslessly package user-supplied Archivist atlas cells for bounded runtime RAM.

This is technical sprite-sheet extraction. Pixels are neither redrawn nor resampled.
Each cropped cell can be reconstructed byte-for-byte to its original 1100x720 RGBA.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path
import zipfile

from PIL import Image

CELL = (1100, 720)
PIVOT = (380, 680)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def stored_file(pack: zipfile.ZipFile, name: str, data: bytes) -> None:
    entry = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
    entry.compress_type = zipfile.ZIP_STORED
    entry.external_attr = 0o644 << 16
    pack.writestr(entry, data)


def prepare(source: Path, output: Path) -> None:
    output.mkdir(parents=True, exist_ok=True)
    # Runtime reads the small PNG cells with ZIPReader, so giant atlas imports
    # and thousands of generated texture .import files are unnecessary.
    (output / '.gdignore').write_text('')
    manifest = {
        'format': 1, 'cell': list(CELL), 'pivot': list(PIVOT),
        'source': 'User uploads: Archivist_part1 through Archivist_part6',
        'pixel_processing': 'RGBA decode, alpha-bounds crop, lossless PNG only',
        'duration_authority': 'Original metadata duration, matching the HTML',
        'animations': {}, 'source_files': {},
    }
    for phase in (1, 2):
        meta_path = source / f'meta_p{phase}.json'
        meta_bytes = meta_path.read_bytes()
        meta = json.loads(meta_bytes)
        (output / meta_path.name).write_bytes(meta_bytes)
        manifest['source_files'][meta_path.name] = sha(meta_bytes)
        for name, spec in meta.items():
            sheet_path = source / f'p{phase}_all' / f'{name}.png'
            if not sheet_path.exists():
                continue
            sheet_bytes = sheet_path.read_bytes()
            manifest['source_files'][f'p{phase}_all/{name}.png'] = sha(sheet_bytes)
            source_image = Image.open(io.BytesIO(sheet_bytes))
            image = source_image.convert('RGBA')
            expected = (CELL[0] * spec['columns'], CELL[1] * spec['rows'])
            if image.size != expected:
                raise ValueError(f'{sheet_path}: dimensions {image.size} != {expected}')
            key = f'p{phase}/{name}'
            pack_name = f'p{phase}_{name}.zip'
            frames = []
            with zipfile.ZipFile(output / pack_name, 'w') as pack:
                for index in range(spec['frames']):
                    column, row = index % spec['columns'], index // spec['columns']
                    left, top = column * CELL[0], row * CELL[1]
                    cell = image.crop((left, top, left + CELL[0], top + CELL[1]))
                    bounds = cell.getchannel('A').getbbox()
                    # Transparent RGB can be nonzero in a Canvas export. Preserve
                    # all RGBA bytes, even outside alpha, when such pixels exist.
                    if bounds is not None:
                        restored = Image.new('RGBA', CELL)
                        restored.paste(cell.crop(bounds), bounds[:2])
                        if restored.tobytes() != cell.tobytes():
                            bounds = (0, 0, *CELL)
                    else:
                        bounds = (0, 0, 1, 1)
                        if cell.tobytes() != bytes(CELL[0] * CELL[1] * 4):
                            bounds = (0, 0, *CELL)
                    # Preserve an original indexed PNG palette and its tRNS
                    # table. Converting these already-paletted source cells to
                    # RGBA on disk would multiply download size needlessly.
                    native_cell = source_image.crop((left, top, left + CELL[0], top + CELL[1]))
                    cropped = native_cell.crop(bounds)
                    buffer = io.BytesIO()
                    cropped.save(buffer, format='PNG', compress_level=6)
                    png = buffer.getvalue()
                    decoded = Image.open(io.BytesIO(png)).convert('RGBA')
                    reconstructed = Image.new('RGBA', CELL)
                    reconstructed.paste(decoded, bounds[:2])
                    source_hash = sha(cell.tobytes())
                    if sha(reconstructed.tobytes()) != source_hash:
                        raise RuntimeError(f'Pixel mismatch: {key}/{index}')
                    frame_file = f'{index:03}.png'
                    stored_file(pack, frame_file, png)
                    frames.append({
                        'file': frame_file,
                        'rect': [bounds[0], bounds[1], bounds[2] - bounds[0], bounds[3] - bounds[1]],
                        'rgba_sha256': source_hash, 'png_sha256': sha(png),
                    })
                pack_spec = {'cell': list(CELL), 'pivot': list(PIVOT), 'frames': frames}
                stored_file(pack, 'frames.json', json.dumps(pack_spec, separators=(',', ':')).encode())
            manifest['animations'][key] = {
                'pack': pack_name, 'frames': spec['frames'],
                'pack_sha256': sha((output / pack_name).read_bytes()),
                'source_sheet_sha256': sha(sheet_bytes),
                'verified_reconstruction_frames': len(frames),
            }
            print(f'{key}: {len(frames)} pixel-exact cells, {(output / pack_name).stat().st_size:,} bytes', flush=True)
    manifest['verified_frames'] = sum(x['verified_reconstruction_frames'] for x in manifest['animations'].values())
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    (output / 'LICENSE.txt').write_text(
        'User-supplied Archivist sprite sheets and metadata.\n'
        'The project records their supplied provenance without asserting ownership or a new license.\n'
        'Frame packs preserve original decoded RGBA pixels exactly, without redrawing or resampling.\n'
    )
    print(f"DONE: {len(manifest['animations'])} animations, {manifest['verified_frames']} verified frames", flush=True)


def extend_existing(output: Path, extensions: Path) -> None:
    """Add exact HTML-rendered pixels only outside each original atlas cell.

    Original paletted PNGs remain byte-identical. Exterior PNGs are stored apart
    to avoid turning the original compact indexed source into huge RGBA files.
    Godot joins them into one texture before drawing, avoiding filtering seams.
    """
    manifest_path = output / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    exterior_provenance = json.loads((extensions / 'manifest.json').read_text())
    if exterior_provenance.get('frames_with_outer_edge_alpha', 0) != 0:
        raise RuntimeError('Exterior render still has clipped pixels at a canvas edge')
    exterior_frames = 0
    checked = 0
    for key, entry in manifest['animations'].items():
        phase, animation = key.split('/')
        directory = extensions / phase / animation
        report_path = directory / 'clip_report.json'
        if not report_path.is_file():
            raise FileNotFoundError(f'Exterior clip is not complete: {report_path}')
        clip_report = json.loads(report_path.read_text())
        default_origin = tuple(clip_report.get('origin', [-500, -250]))
        exterior_records = clip_report.get('frames', [])
        pack_path = output / entry['pack']
        temporary = pack_path.with_suffix('.zip.tmp')
        clip_added = 0
        with zipfile.ZipFile(pack_path) as source_pack, zipfile.ZipFile(temporary, 'w') as pack:
            specification = json.loads(source_pack.read('frames.json'))
            for item in source_pack.infolist():
                if item.filename != 'frames.json' and not item.filename.startswith('extra_'):
                    stored_file(pack, item.filename, source_pack.read(item.filename))
            for index, frame in enumerate(specification['frames']):
                exterior_record = exterior_records[index] if index < len(exterior_records) else {}
                origin = tuple(exterior_record.get('origin', default_origin))
                full_path = directory / f'{index:04}.png'
                expanded = Image.open(full_path).convert('RGBA')
                original_region = (-origin[0], -origin[1], -origin[0] + CELL[0], -origin[1] + CELL[1])
                center = expanded.crop(original_region)
                if sha(center.tobytes()) != frame['rgba_sha256']:
                    raise RuntimeError(f'Original source changed by exterior render: {key}/{index}')
                checked += 1
                expanded.paste((0, 0, 0, 0), original_region)
                bounds = expanded.getchannel('A').getbbox()
                frame.pop('extra_file', None)
                frame.pop('extra_rect', None)
                frame.pop('extra_png_sha256', None)
                if bounds is not None:
                    outside = expanded.crop(bounds)
                    buffer = io.BytesIO()
                    outside.save(buffer, format='PNG', compress_level=6)
                    png = buffer.getvalue()
                    filename = f'extra_{index:03}.png'
                    stored_file(pack, filename, png)
                    frame['extra_file'] = filename
                    frame['extra_rect'] = [bounds[0] + origin[0], bounds[1] + origin[1], bounds[2] - bounds[0], bounds[3] - bounds[1]]
                    frame['extra_png_sha256'] = sha(png)
                    clip_added += 1
            stored_file(pack, 'frames.json', json.dumps(specification, separators=(',', ':')).encode())
        temporary.replace(pack_path)
        entry['pack_sha256'] = sha(pack_path.read_bytes())
        entry['exterior_frames'] = clip_added
        exterior_frames += clip_added
        print(f'Exterior {key}: {clip_added} frames, center RGBA unchanged', flush=True)
    manifest['exterior_reconstruction'] = {
        'source': 'Exact uploaded HTML DR.render(all), T=f/fps; exterior of original cell only',
        'original_cell_rgba_rechecked': checked,
        'frames_with_exterior_pixels': exterior_frames,
        'runtime': 'Original source and exterior blitted into one texture without resampling',
        'source_html_sha256': exterior_provenance.get('source_html_sha256'),
        'frames_with_outer_edge_alpha': exterior_provenance.get('frames_with_outer_edge_alpha'),
        'enlarged_source_canvas_frames': exterior_provenance.get('enlarged_frame_count'),
    }
    temporary_manifest = manifest_path.with_suffix('.json.tmp')
    temporary_manifest.write_text(json.dumps(manifest, indent=2) + '\n')
    temporary_manifest.replace(manifest_path)
    print(f'EXTERIOR DONE: {exterior_frames} exterior frames, {checked} original cells unchanged', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--output', type=Path, default=Path('assets/minibosses/m26_imported'))
    parser.add_argument('--extensions', type=Path, help='Exact exterior render directory from the supplied HTML')
    parser.add_argument('--extend-existing', action='store_true', help='Keep existing source packs and only add exterior pixels')
    options = parser.parse_args()
    if not options.extend_existing:
        prepare(options.source, options.output)
    if options.extensions:
        extend_existing(options.output, options.extensions)
