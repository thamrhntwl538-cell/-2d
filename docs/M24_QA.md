# M24 — Bell Warden acceptance

The reference-faithful character is the same layered asset in review and gameplay. The approved hero PNG remains byte-identical. This milestone implements the first of four planned minibosses; the Sleeping Shelf main encounter is reserved for later work.

| Passing scope | Result | Evidence |
|---|---|---|
| Actual-input native fight | 16 checks / 0 failures | Complete 18 HP win, four hero health remaining, movement/jump/sword/spell, live-wave pause and real reward callback |
| Unreactive pressure and retry | 12 checks / 0 failures | Repeated centre chase/upslash loses with Bell 1 HP remaining; actual death restores safe rest/full-health inactive actor |
| Collision contracts | 20 checks / 0 failures | Explicit fixture positions/time: safe ascent/rest, fixed old landing target, front parry, wave swept contact/clearance/pause/terrain |
| Save/reward/controller integration | 40 checks / 0 failures | Separate trial file, controller entry/return,45 physical coins once, upgrade receipt, normal save migration, old story preservation, exact prior file restoration |
| Native launch/navigation | 13 checks / 0 failures | F5 review, real keys/controller pages, A enters trial, actual walking starts encounter and original score |
| Character rig | 1,464 pose samples | Fixed textured thigh/shin/level foot, both facings; maximum stance slip below 0.000006 px |
| Environment | 24 checks / 0 failures | Native floor/headspace, no visual collision subtree, original platforms and objects retained |
| Sound | 45 checks / 0 failures | Original events, actual nonzero Master PCM, bounded voices/priority/positional footsteps/pause/cleanup |
| Music | 24 checks / 0 failures | Actual imported playback, continuous section, mute/duck/end lifecycle, no preattack mix cue |

Counts describe separate overlapping runs, not unique assertions added together. The native bot uses ordinary Input actions and reads public actor state. It does not inject damage, teleport the player or freeze combat. Fixed60 simulation was used for the final native runs because software OpenGL renders slowly; this is not a hardware performance benchmark or a human difficulty/enjoyment test. A prior realtime software-rendered driver missed physics opportunities and lost; no boss HP inflation was used to compensate.

The storage fixture deliberately applies lethal damage to check its transaction, and is explicitly separate from the genuine Input-only win.40 storage checks include6 per-coin duplicate-claim checks. The movie's first 4seconds are a declared anatomy fixture; the subsequent encounter is genuine automated Input gameplay. The film retains damage and ends with actual victory; music and voices are recorded from the native mixer.

## Fixed issues

- Replaced the obsolete detached head/wire legs with the faithful bronze-bell/torso/tabard/textured-leg rig. Fixed limb lengths and world-planted walking soles avoid stretch/sliding. The rush is an 8 px airborne bound with tucked feet.
- Parked the 3 old bindery presses and removed their collision hazards from this M24 room instance; original M23 layouts are unchanged. The old 'watch presses' objective is replaced locally.
- Opening/returning from an isolated trial preserves health, energy, normal inventory and actual saved bench, without granting a final-boss victory. Completed old previews reopen for new Bell content while story receipts remain intact.
- The shared empty-energy orb used a degenerate polygon at zero. It now omits zero-area fills while retaining its vessel/health art; native death/retry and focused zero-energy checks close without polygon errors.

## Reproduction

Use Godot 4.7.2 Standard, import assets first and select separate XDG_DATA_HOME for tests.

```sh
godot --headless --audio-driver Dummy --fixed-fps 60 --path . --script res://tools/test_m24_bell.gd
godot --headless --audio-driver Dummy --fixed-fps 60 --path . --script res://tools/test_m24_bell.gd -- --cheap
godot --headless --audio-driver Dummy --fixed-fps 60 --path . --script res://tools/test_m24_bell.gd -- --contracts
godot --headless --audio-driver Dummy --fixed-fps 60 --path . --script res://tools/test_m24_integration.gd
godot --audio-driver Dummy --fixed-fps 60 --path . --script res://tools/test_m24_startup.gd
```

Portable results: M24_COMBAT_QA.json, M24_INTEGRATION_QA.json, M24_CHARACTER_QA.json, M24_ENVIRONMENT_REPORT.json, M24_AUDIO.json, and assets/audio/m24/music/*qa.json. Native logs contain only the expected virtual-display V-Sync warning. No subjective listening claim is made.
