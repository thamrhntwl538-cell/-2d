# M25 — Bell resonance and phase two

The smaller arena, complete travelling crests and distinct second phase are live in the Godot scene. The same approved Bell atlas and hero atlas remain byte-identical. Root integration uses the M24 implementation paths so previous saves, reward receipts, review launch and library return stay compatible.

| Passing scope | Result | Evidence |
|---|---|---|
| Actual-input native fight | 9 / 0 failures | Full18HP win through both phase2 patterns, four nonimmune wave jumps, all eight released waves finish at the arena boundaries, hero4/6; genuine native mixer audio |
| Wave and phase contracts | 63 / 0 failures | Native original hero hurtboxes: twelve endpoint cases, both edge campers, running at330px/s against520/620px/s waves, original ballistic jumps over primary/echo, one grounded half-health transition, old-wave preservation, committed targets, pause and death cleanup |
| Save/reward/controller integration | 40 / 0 failures | Controller trial/return, exact normal inventory, physical45-coin collection, one capacity receipt, repeated callback rejection, prior file restoration |
| Presentation and containment | 21 / 0 failures | Narrow physical gates, player interior margin, impact callback/debris bounds/expiry, short post-contact shake, clean combat canvas, exploration UI restoration, unchanged source atlases |
| Actual launch and controls | 19 / 0 failures | F5 review, keyboard/controller pages, A trial, ordinary movement entry, map/journal blocked during combat, actual pause/resume and retained clean HUD |
| Silent hero | 37 / 0 failures | Three actual strike serials produce three sword effects and no hero_attack, native PCM silence for vocal calls, retained enemy/UI/nonvocal cues, no clipping in contact/score mix |
| Character rig | 2,562 samples |21 poses,61 times,2 facings; fixed limb lengths and planted foot support |
| Floor effect lifecycle | 9 / 0 failures | Separate injected rendering probe: no pre-impact content/collisions, pause freeze, per-effect caps, full expiry and clear |

These counts are separate overlapping runs, not unique tests added together. The mechanics and presentation fixtures explicitly position actors or step clocks. The storage fixture explicitly sets phase2 and deals lethal damage to validate the reward transaction; it is not combat proof. The independent real-Input demo records the genuine18HP fight through both phases without positive damage injection. See `previews/m25/demo_capture_metadata.json` for its final result, event coverage and wave endpoints.

The phase-one crossing hit caps health at9. The Bell completes its current committed airborne/ground action and transforms on the floor; old waves continue travelling. Protection lasts through that body transition and old-wave clearance. Phase two starts vulnerable at9HP, with no health refill. Its double rush and high leap with second floor pulse replace the old repeated-hop variation.

Combat retains only the top-left player vitals. Opponent health, title cards, location text, top buttons and footer are hidden. Explicit Esc/Start pause remains available. The continuous M24 score does not restart or predict individual attacks. Hero vocal events and recursive layers are filtered; sword, contact, movement, enemy voices, UI and music are retained.

Use Godot4.7.2 Standard, import first and use a separate XDG_DATA_HOME for checks:

```sh
godot --headless --audio-driver Dummy --fixed-fps 60 --path . --script res://tools/test_m25_bell_contracts.gd
godot --headless --audio-driver Dummy --fixed-fps 60 --path . --script res://tools/test_m25_character.gd
godot --audio-driver Dummy --fixed-fps 60 --path . --script res://tools/test_m25_startup.gd
godot --audio-driver Dummy --fixed-fps 60 --path . --script res://tools/test_m25_presentation.gd
godot --audio-driver Dummy --fixed-fps 60 --path . --script res://tools/test_m25_integration.gd
godot --audio-driver Dummy --fixed-fps 60 --path . --script res://tools/test_m25_silent_hero.gd
```

Fixed60 native runs use software OpenGL; they do not establish hardware performance or human difficulty/enjoyment. The old M24 acceptance documents describe the prior milestone; the M25 wave/phase/mute contracts supersede its old threshold and voice expectations. No fifteen-room rerun is claimed for this focused miniboss change.
