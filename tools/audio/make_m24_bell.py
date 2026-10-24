#!/usr/bin/env python3
"""Render the Bell Warden's original tactile audio and wordless instrument voice.

CC0-1.0. No recordings, reference audio, TTS, actor models, downloaded samples,
or M23 sounds enter this signal chain. Requires NumPy and SciPy. The Bell voice
is a noisy subharmonic pressure source through inharmonic bronze resonators,
deliberately separate from the M23 glottal/vowel voice. All echoes are finite.

Run: python3 tools/audio/make_m24_bell.py
Audit existing production WAVs without rewriting: add --audit-only.
"""
from pathlib import Path
import argparse
import hashlib
import json
import math
import wave

import numpy as np
from scipy.signal import butter, iirpeak, lfilter, sosfilt

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/audio/m24'
RATE = 48000
SEED = 240024

# The actor owns timing: none of these events may be played in a windup.
SPECS = {
    'bell_impact': dict(durations=[1.20, 1.28, 1.16], gain=-8.0, peak=-5.5,
                        cooldown=.16, instances=2, role='actual floor impact; finite bronze ring and room reflections'),
    'bell_hit': dict(durations=[.29, .33, .27], gain=-9.0, peak=-6.0,
                     cooldown=.10, instances=2, role='accepted damage contact; muted bronze shell'),
    'bell_swing': dict(durations=[.31, .35, .29], gain=-11.0, peak=-7.0,
                       cooldown=.16, instances=1, role='rush movement/release only; displaced air and tabard drag'),
    'bell_takeoff': dict(durations=[.28, .31], gain=-11.5, peak=-6.5,
                         cooldown=.20, instances=1, role='feet leave floor; compact heavy push and cloth'),
    'bell_fall': dict(durations=[1.72], gain=-8.0, peak=-6.0,
                      cooldown=3.0, instances=1, role='death collapse; irregular shell knocks and fading bronze'),
    'bell_step': dict(durations=[.23, .26, .21, .24], gain=-14.0, peak=-7.0,
                      cooldown=.18, instances=1, role='planted moving foot only; stocky weight and short floor grit'),
    'bell_cloth': dict(durations=[.34, .39], gain=-17.0, peak=-9.0,
                       cooldown=.30, instances=1, role='actual dark-red tabard movement; optional, no idle chatter'),
    'bell_voice_strain': dict(durations=[.38, .43, .35], gain=-6.0, peak=-6.0,
                              cooldown=3.2, instances=1, voice=True, role='sparse exertion on alternate actual takeoffs only'),
    'bell_voice_hurt': dict(durations=[.44, .49, .40], gain=-5.5, peak=-6.0,
                            cooldown=2.2, instances=1, voice=True, role='sparse confirmed nonfatal hurt; never every hit'),
    'bell_voice_death': dict(durations=[1.48], gain=-5.0, peak=-6.5,
                             cooldown=5.0, instances=1, voice=True, role='single death exhalation; priority death replaces earlier boss bark'),
}


def db(value):
    return 20 * math.log10(max(float(value), 1e-12))


def smooth(x):
    x = np.clip(x, 0, 1)
    return x * x * (3 - 2 * x)


def noise(rng, count, low, high):
    x = sosfilt(butter(2, [low, high], fs=RATE, btype='bandpass', output='sos'),
                 rng.standard_normal(count))
    return x / max(float(np.sqrt(np.mean(x * x))), 1e-9)


def envelope(t, onset, decay, attack=.003):
    age = np.maximum(t - onset, 0)
    return (t >= onset) * smooth(age / attack) * np.exp(-age / decay)


def bronze(t, fundamental, decay, rng, onset=0., damping=1.):
    """Inharmonic shell modes; no pitched warning oscillator or note sequence."""
    age = np.maximum(t - onset, 0)
    x = np.zeros_like(t)
    for ratio, level, tail in [(1, 1, 1), (1.503, .52, .91), (2.739, .40, .69),
                                (4.083, .24, .49), (5.397, .14, .33), (8.921, .065, .20)]:
        detune = 1 + rng.uniform(-.003, .003)
        mode = np.sin(2 * np.pi * fundamental * ratio * detune * age)
        x += mode * level * envelope(t, onset, decay * tail / damping)
    return x


def cloth(t, rng, strength=1.):
    # Several irregular fold scrapes, with rough slow amplitude modulation.
    n = noise(rng, len(t), 480, 6200)
    rough = sosfilt(butter(1, 85, fs=RATE, output='sos'), rng.standard_normal(len(t)))
    rough /= max(float(np.std(rough)), 1e-9)
    env = np.zeros_like(t)
    for onset, decay, level in [(0, .045, .7), (.047, .064, 1), (.123, .043, .43)]:
        env += envelope(t, onset, decay, .007) * level
    return n * env * (0.62 + .19 * np.tanh(rough)) * strength


def voice(t, family, rng, variant):
    """Breathy pressure in a black core, sympathetically exciting a bronze body."""
    u = t / t[-1]
    if family == 'bell_voice_strain':
        f0 = np.interp(u, [0, .25, .60, 1], [63, 77, 69, 49])
        amp = smooth(t / .020) * smooth((t[-1] - t) / .10) * np.exp(-t / .25)
        breath = .53
    elif family == 'bell_voice_hurt':
        f0 = np.interp(u, [0, .18, .55, 1], [79, 86, 61, 43])
        amp = smooth(t / .008) * smooth((t[-1] - t) / .14) * np.exp(-t / .34)
        breath = .66
    else:
        f0 = np.interp(u, [0, .12, .45, .78, 1], [67, 74, 53, 37, 29])
        amp = smooth(t / .023) * smooth((t[-1] - t) / .32) * np.exp(-t / .78)
        breath = .83
    f0 *= 1 + variant * .023 + .018 * np.sin(2 * np.pi * 5.7 * t)
    # Uneven subharmonics and turbulent flow, without a speech formant model.
    phase = np.cumsum(2 * np.pi * f0 / RATE)
    pulse = np.tanh(1.4 * np.sin(phase) + .7 * np.sin(phase * .5 + .4))
    turbulent = noise(rng, len(t), 125, 3100)
    pressure = (pulse * .62 + turbulent * breath) * amp
    x = pressure * .28
    for hz, q, level in [(171, 3.3, .85), (297, 4.2, 1.0), (473, 5.6, .53), (821, 6.2, .21)]:
        b, a = iirpeak(hz * (1 + variant * .012), q, fs=RATE)
        resonated = lfilter(b, a, pressure)
        x += resonated * level * 2.4
    # Small low bronze sympathy, not the bright contact shell used by effects.
    x += .065 * bronze(t, 86 + variant * 2, .24 if family != 'bell_voice_death' else .58, rng, damping=1.9)
    return np.tanh(x * 1.12)


def synth(family, duration, variant):
    rng = np.random.default_rng(SEED + list(SPECS).index(family) * 1009 + variant * 137)
    t = np.arange(round(duration * RATE)) / RATE
    low = noise(rng, len(t), 45, 230)
    grit = noise(rng, len(t), 850, 7400)
    shift = 1 + (variant - 1) * .027
    if family == 'bell_impact':
        x = .56 * bronze(t, 117 * shift, .32, rng)
        x += .37 * low * envelope(t, 0, .047)
        x += .21 * grit * envelope(t, 0, .016)
        x += .105 * bronze(t, 114 * shift, .17, rng, .071, 1.2)
    elif family == 'bell_hit':
        x = .59 * bronze(t, 257 * shift, .067, rng, damping=1.2)
        x += .34 * grit * envelope(t, 0, .012)
        x += .15 * low * envelope(t, 0, .022)
    elif family == 'bell_swing':
        air = noise(rng, len(t), 110, 2800)
        curve = smooth(t / .028) * np.exp(-t / .065)
        x = .67 * air * curve + cloth(t, rng, .17)
        x += .08 * bronze(t, 98 * shift, .055, rng, .014, 1.6)
    elif family == 'bell_takeoff':
        x = .47 * low * envelope(t, 0, .039)
        x += .18 * bronze(t, 88 * shift, .054, rng, damping=1.5)
        x += cloth(t, rng, .21)
    elif family == 'bell_fall':
        x = .46 * bronze(t, 97, .36, rng)
        for onset, weight, fundamental in [(0, .40, 94), (.114, .25, 133), (.267, .17, 102)]:
            x += low * envelope(t, onset, .046) * weight
            x += bronze(t, fundamental, .29, rng, onset) * weight * .7
            x += grit * envelope(t, onset, .016) * weight * .37
        x += cloth(t, rng, .14)
    elif family == 'bell_step':
        x = .49 * low * envelope(t, 0, .026)
        x += .17 * bronze(t, 83 * shift, .029, rng, damping=1.7)
        x += .13 * grit * envelope(t, .011, .022)
        x += cloth(t, rng, .075)
    elif family == 'bell_cloth':
        x = cloth(t, rng) + .04 * low * envelope(t, .023, .047)
    else:
        x = voice(t, family, rng, variant)
    # Remove subsonic drift. Conservative soft boundaries include zero samples.
    x = sosfilt(butter(2, 38, fs=RATE, btype='highpass', output='sos'), x)
    x *= smooth(t / .0025) * smooth((duration - t - 1 / RATE) / .025)
    stereo = np.column_stack([x, x]) * .94
    for channel, taps in [(0, [(.023, .075), (.067, .037), (.121, .012)]),
                          (1, [(.031, .069), (.083, .032), (.139, .010)])]:
        for delay, gain in taps:
            offset = round(delay * RATE)
            if offset < len(x):
                stereo[offset:, channel] += x[:-offset] * gain
    # The final envelope also catches every reflected tail.
    stereo *= smooth((duration - t - 1 / RATE) / .020)[:, None]
    stereo -= np.mean(stereo, axis=0)
    stereo *= smooth(t / .0015)[:, None] * smooth((duration - t - 1 / RATE) / .015)[:, None]
    stereo *= 10 ** (SPECS[family]['peak'] / 20) / max(float(np.max(np.abs(stereo))), 1e-9)
    return stereo


def filename(family, variant):
    return family + (f'_{variant + 1}' if variant else '') + '.wav'


def events():
    result = {}
    for name, spec in SPECS.items():
        vocal = spec.get('voice', False)
        result[name] = dict(files=['res://assets/audio/m24/' + filename(name, i)
                                   for i in range(len(spec['durations']))],
                            category='boss_voice' if vocal else 'effects',
                            volume_db=spec['gain'], cooldown=spec['cooldown'],
                            max_instances=spec['instances'], layers=[],
                            pitch_min=1.0 if vocal else .985,
                            pitch_max=1.0 if vocal else 1.015,
                            spatial=not vocal, timing=spec['role'])
        if name == 'bell_voice_death':
            result[name]['preempt_category'] = True
    return result


def read_pcm(path):
    with wave.open(str(path), 'rb') as f:
        info = dict(rate=f.getframerate(), channels=f.getnchannels(),
                    sample_width=f.getsampwidth(), frames=f.getnframes())
        x = np.frombuffer(f.readframes(f.getnframes()), '<i2').reshape(-1, info['channels']).astype(float) / 32768
    return x, info


def measure(path, spec, expected_duration):
    x, info = read_pcm(path)
    peak = float(np.max(np.abs(x)))
    mono = x.mean(axis=1)
    spectrum = np.abs(np.fft.rfft(mono * np.hanning(len(mono)))) ** 2
    frequencies = np.fft.rfftfreq(len(mono), 1 / RATE)
    centroid = float(np.sum(spectrum * frequencies) / max(float(spectrum.sum()), 1e-12))
    result = dict(file=str(path.relative_to(ROOT)), seconds=len(x) / RATE,
                  rate=info['rate'], channels=info['channels'], pcm_bits=info['sample_width'] * 8,
                  peak_dbfs=db(peak), rms_dbfs=db(np.sqrt(np.mean(x * x))),
                  dc_peak=float(np.max(np.abs(x.mean(axis=0)))),
                  first_last_16_peak=float(np.max(np.abs(np.vstack([x[:16], x[-16:]])))),
                  clipping_samples=int(np.sum(np.abs(x) >= .99997)),
                  spectral_centroid_hz=centroid,
                  sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    result['passed'] = bool(info['rate'] == RATE and info['channels'] == 2 and info['sample_width'] == 2
                        and abs(result['seconds'] - expected_duration) < 1 / RATE
                        and result['clipping_samples'] == 0 and result['dc_peak'] < .002
                        and result['first_last_16_peak'] < .003 and -40 < result['rms_dbfs'] < -8
                        and abs(result['peak_dbfs'] - spec['peak']) < .02 and np.isfinite(x).all())
    return result, x


def audit():
    records, signals, variants = [], {}, []
    for family, spec in SPECS.items():
        family_signals = []
        for i, duration in enumerate(spec['durations']):
            record, signal = measure(OUT / filename(family, i), spec, duration)
            records.append(record)
            signals[(family, i)] = signal
            family_signals.append(signal.mean(axis=1))
        for i, left in enumerate(family_signals):
            for j, right in enumerate(family_signals[i + 1:], i + 1):
                count = min(len(left), len(right))
                correlation = abs(float(np.dot(left[:count], right[:count]) /
                                  max(np.linalg.norm(left[:count]) * np.linalg.norm(right[:count]), 1e-12)))
                variants.append(dict(event=family, variants=[i + 1, j + 1], zero_lag_correlation=correlation,
                                     passed=correlation < .985))
    mixes = []
    # Objective recommended-gain headroom, including concurrent body contacts.
    for name, members in [('landing_exertion', ['bell_impact', 'bell_voice_strain']),
                           ('hurt_contact', ['bell_hit', 'bell_voice_hurt']),
                           ('death_collapse', ['bell_fall', 'bell_hit', 'bell_voice_death']),
                           ('body_load', ['bell_step', 'bell_cloth', 'bell_takeoff', 'bell_swing', 'bell_impact'])]:
        count = max(len(signals[(event, 0)]) for event in members)
        mixed = np.zeros((count, 2))
        for event in members:
            sample = signals[(event, 0)] * 10 ** (SPECS[event]['gain'] / 20)
            mixed[:len(sample)] += sample
        peak = float(np.max(np.abs(mixed)))
        mixes.append(dict(name=name, events=members, peak_dbfs=db(peak), clipping_samples=int(np.sum(abs(mixed) >= 1)), passed=peak < .85))
    m23_manifest = ROOT / 'assets/audio/m23/event_manifest.json'
    report = dict(version=2, original=True, license='CC0-1.0', rate=RATE, channels=2,
                  pcm_bits=16, files=records, variant_checks=variants, proposed_gain_mixes=mixes,
                  event_count=len(SPECS), file_count=len(records),
                  m23_event_manifest_sha256=hashlib.sha256(m23_manifest.read_bytes()).hexdigest(),
                  no_external_or_reference_samples=True, no_predictive_warning_audio=True,
                  no_speech_or_tts=True, human_listening_claim=False,
                  scope='Objective production PCM, event map, duration, level, DC, soft boundaries, variants and proposed-gain sum. Native output is verified separately.',
                  passed=all(r['passed'] for r in records + variants + mixes))
    (OUT / 'audit.json').write_text(json.dumps(report, indent=2) + '\n')
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--audit-only', action='store_true')
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    if not args.audit_only:
        for family, spec in SPECS.items():
            for i, duration in enumerate(spec['durations']):
                x = synth(family, duration, i)
                with wave.open(str(OUT / filename(family, i)), 'wb') as f:
                    f.setnchannels(2)
                    f.setsampwidth(2)
                    f.setframerate(RATE)
                    f.writeframes(np.rint(x * 32767).astype('<i2').tobytes())
        manifest = dict(version=2, original=True, license='CC0-1.0', events=events(),
                        timing_policy='Actor plays only actual movement, release, contact, hurt or death. Windup/intro/drawback/crouch/spring contain no audio cue. No autonomous idle voice.',
                        overlap_policy='Inherited 16-player pool, boss_voice category exclusion and priority death preemption. Finite samples; zero loops; per-event cooldowns; no automatic layers.')
        (OUT / 'events.json').write_text(json.dumps(manifest, indent=2) + '\n')
        (OUT / 'LICENSE.txt').write_text(
            'Bell Warden original sound effects and wordless instrument voice\n'
            'Copyright waived under CC0 1.0 Universal (CC0-1.0).\n'
            'https://creativecommons.org/publicdomain/zero/1.0/\n\n'
            'All m24 root WAV assets and tools/audio/make_m24_bell.py are original procedural works by LAST LECTURE build. '
            'No external samples, reference recordings, voice models, TTS or cloned voices were used. '
            'No M23 audio was sampled or modified. Voice uses an independently synthesized breath/pressure source and bronze resonators. '
            'Music under music/ has its own manifest and licensing notice.\n')
    report = audit()
    print(json.dumps(dict(files=report['file_count'], events=report['event_count'], passed=bool(report['passed']),
                          clipping_samples=sum(x['clipping_samples'] for x in report['files']),
                          largest_variant_correlation=max(x['zero_lag_correlation'] for x in report['variant_checks']))))
    if not report['passed']:
        for item in report['files'] + report['variant_checks'] + report['proposed_gain_mixes']:
            if not item['passed']:
                print(json.dumps(item))
        raise SystemExit(1)


if __name__ == '__main__':
    main()
