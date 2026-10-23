# M23 — Dr. Compiler acceptance

**Final acceptance passes:** the short hero strike defeats all 48 boss HP through actual Input, and native arena review confirms the side profile, connected weapon grip and fixed-length boss arm. The approved hero PNG remains unchanged.

| Final run | Checks | Scope |
| --- | ---: | --- |
| Short-hero fight | 96 / 0 failures | Real-time headless native physics: ordinary trial entry, live-attack pause, full victory, protected phase transformation, actual journal/coin sounds, rewards and save isolation |
| Native arm/profile review | 60 / 0 failures | Ordinary entry/first-warning photos, then labelled configured arena fixtures for both facings, captured attack direction, real hand/weapon attachment and rendered bone lengths |

Raw results, artifact hashes and the frozen source hashes are in [M23_WORLD_QA.json](M23_WORLD_QA.json). These scopes overlap; counts are not a total of unique assertions. Both final logs exited cleanly. Native software OpenGL emitted only the expected unsupported V-Sync warning.

## Final fight

The actual M23 player/model loaded in the trial and defeated the complete 48-HP boss in **29.03 nominal seconds**, including the controlled phase-pause test. The hero finished with five of six HP after moving 2,917.11 world pixels, with two actual jump starts, four dash starts and four spell casts. Forward, upward and downward attacks were used. No positive damage was injected, the hero was not teleported during combat and the boss was not frozen for the fight.

Across 68 actual forward-contact samples, the farthest damaging edge reached **61.420 pixels** from the hero centre, confirming the shortened model-derived strike rather than the old 92-pixel reach. Attack duration, cooldown and contact timing remain 0.30 / 0.36 / 0.06–0.14 seconds. The separate [hero strike report](M23_HERO_STRIKE_QA.json) passes 139 native checks, including fitil scaling, contact boundaries and preservation of the original hero atlas and legacy sources.

At the real phase-II threshold, all prior damaging attacks disappeared. Actual map input froze the actor clock and visual progress during the two-second transformation. After resume, **15 real sword-contact frames caused no boss or hero damage** during that protected interval. The original phase-II score completed its crossfade. The fight subsequently observed the authored bolts, sweep, pillars and low-chain patterns and ended in a genuine victory.

The driver reads public AI state and captured-target data. This demonstrates a viable learned counter strategy, not a human assessment of difficulty, balance or enjoyment.

## Side profile and arm anatomy

The first two native photos follow an ordinary trial entrance with the normal 0.78× camera. The six enlarged arm/grip diagnostics configure hero positions and suspend controller/hero physics while the real boss runs its safe-facing and sweep clocks; their 1.6× camera is a review close-up, not gameplay scale.

Both sides track the hero between actions and retain the previous direction inside the 12-pixel deadzone. Warning and active sweep direction stay locked after the hero crosses; recovery safely turns toward the hero. The hand remains closed around the same handle/guard and the active blade is not duplicated. The original far arm stays readable.

The final near arm uses fixed shoulder/elbow/wrist bones and a rigid hand. Its world lengths are 43.1764 / 23.7686 / 19.0943 pixels for upper arm, forearm and palm. Across 24 mirrored rest, windup, release and recovery samples, hand/hilt gap is zero and maximum measured **rendered** bone-length error is 0.00000763 pixels. Independent [art-manifest evidence](../assets/bosses/m23/art_manifest.json) records 5,890 invariants over 392 poses and a separate 120-frame native transformation study. These are presentation checks, not another fight.

The sweep still uses its tested visible 384×96 damage field. The soft wash marks the full area; the blade/handle starts at the actual posed grip. No boss HP, damage or attack geometry was changed for the anatomy correction.

## Sound, rewards and saves

The actual final fight logged original boss intro, attack, hurt, phase and death voices; hero attack, hurt and spell voices; real release/impact, jump/dash, landing, stone-footstep and coin events. Actual journal input then opened and closed the reader, exercising its distinct sound aliases. The event pool stayed within 16 players. No subjective listening claim is made.

Separate reports provide 45 native [event-audio checks](M23_SOUNDSCAPE_QA.json), 75 objective [music/cue checks](../assets/audio/m23/audio_audit.json), and 746 objective [character/event asset checks](../assets/audio/m23/character_audio_audit.json). Native Master samples were non-silent; voice category limits, same-stream pause/resume, death tails and cleanup passed their focused fixture.

Victory produced six physical coin discs totalling 90. Actual movement/proximity collection paid once; duplicate callbacks did not duplicate payment. Capacity increased from four to five through one permanent receipt. Trial victory set only `trial_compiler_defeated`, with no fabricated guardian seal, story victory or World 02 departure. Normal save bytes were unchanged.

Earlier passing regression baselines are retained separately: 92 integration checks, 43 targeted menu/music/migration checks, and two 12-check pressure probes. They verify a real lethal loss and supported six-HP retry; preserved live projectiles during pause; controller mute without restarting the score; library → trial → return with exact inventory, health, energy and bench checkpoint; and migration of the completed M22 preview. The unchanged 15-room traversal was not repeated.

The unreactive centre-chase/upward-slash strategy lost after 20.00 seconds with 13 boss HP remaining. A separate blind initial-jump/downward-slash strategy lost after 22.22 seconds with eight boss HP remaining. Those are labelled pre-short-hero baselines, not fresh runs of the final strike. The earlier exploitable inner sweep gap was corrected without inflating HP or changing ordinary jump clearance.

A prior native OpenGL full fight verified phase/audio on the preceding hero and arm. Its raw **94 checks / three harness failures** remain visible: collection correctly used `coin`, while the test wrongly expected `pickup` and unexercised book events from opening a map. The corrected final 96/0 run actually checks `coin`, `journal_open` and `journal_close`. The earlier result is not counted as a passing 94-check suite. Its phase photos are archived under `previews/m23/archive_before_anatomy/`; current movie/profile images use the corrected arm.

The standalone trial deliberately starts fresh when entered again. Its isolated save does not replace normal library inventory. The [boss fixture report](M23_COMPILER_FOCUSED_QA.json) passes 69 checks and the [HUD report](M23_UI_QA.json) passes 47; neither is presented as an additional actual-input victory.

## Reproduction

Use Godot 4.7.2 from the extracted project and set a separate `XDG_DATA_HOME`. No source-workspace absolute path is required. The harness also restores the files it touches.

```sh
godot --headless --audio-driver Dummy --max-fps 60 --path . --script res://tools/test_m23_boss_world.gd -- --release-fight --short-hero
godot --audio-driver Dummy --rendering-method gl_compatibility --fixed-fps 60 --path . --script res://tools/capture_m23.gd -- --profile-review
```

Reports are written to `user://m23_boss_world_report.json` and `user://m23_visual_review.json`. Real-time pacing in the final headless run keeps audio-server completion synchronized with gameplay; native close-ups use a fixed simulation step.

The project opens `res://scenes/bosses/compiler_trial_m23.tscn` with F5. Return to Library loads `res://scenes/stage_01/folding_library_m23.tscn` and the normal saved checkpoint/inventory. Guardian eligibility is not invented by a trial victory.
