"""Original muted sole/paper contacts, deterministic and reproducible.

No sampled game audio is used. The smooth attacks and low-pass noise avoid
the old bright click; surface variations share a small dry physical contact.
"""
from pathlib import Path
import hashlib
import json
import wave

import numpy as np
from scipy.signal import butter, sosfilt

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/audio/m28"
RATE = 48000


def contact(surface: str, variant: int) -> np.ndarray:
    rng = np.random.default_rng(28000 + variant + (100 if surface == "paper" else 0))
    duration = 0.145 + variant * 0.006
    t = np.arange(int(RATE * duration)) / RATE
    attack = (1 - np.exp(-t / 0.004)) ** 2
    body = np.sin(2 * np.pi * (185 + variant * 13) * t) * np.exp(-t / 0.017)
    sole = np.sin(2 * np.pi * (390 + variant * 19) * t + 0.25) * np.exp(-t / 0.012)
    noise = rng.normal(size=len(t))
    noise = sosfilt(butter(2, [220, 2350 if surface == "paper" else 1700], fs=RATE, btype="bandpass", output="sos"), noise)
    noise *= np.exp(-t / (0.026 if surface == "paper" else 0.018))
    sound = attack * (0.57 * body + 0.12 * sole + (0.55 if surface == "paper" else 0.32) * noise)
    sound -= np.mean(sound)
    # Final bounded fade prevents a discontinuity at either file boundary.
    fade = min(500, len(sound) // 4)
    sound[:fade] *= np.linspace(0, 1, fade)
    sound[-fade:] *= np.linspace(1, 0, fade)
    sound *= 0.42 / max(float(np.max(np.abs(sound))), 1e-9)
    return sound


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    entries = []
    for surface in ("stone", "paper"):
        for variant in range(1, 4):
            sound = contact(surface, variant)
            path = OUT / f"soft_step_{surface}_{variant}.wav"
            with wave.open(str(path), "wb") as handle:
                handle.setnchannels(1)
                handle.setsampwidth(2)
                handle.setframerate(RATE)
                handle.writeframes(np.round(sound * 32767).astype("<i2").tobytes())
            entries.append({"path":str(path.relative_to(ROOT)), "sha256":hashlib.sha256(path.read_bytes()).hexdigest(), "seconds":len(sound)/RATE, "peak":float(np.max(np.abs(sound))), "rms":float(np.sqrt(np.mean(sound**2)))})
    (OUT / "provenance.json").write_text(json.dumps({"kind":"original procedural soft sole and paper contacts", "generator":"tools/build_m28_soft_steps.py", "sample_rate":RATE, "external_samples":False, "files":entries}, indent=2) + "\n")
    print(f"Generated {len(entries)} original soft step variants")


if __name__ == "__main__":
    main()
