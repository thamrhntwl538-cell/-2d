# M22 verification

Verified with Godot 4.7.2. The approved M20 hero atlas remains byte-identical; the native eyes from M21 remain. The final interface uses six small lanterns for health and a round shared-energy display. Their appearance changes; the six-health/99-energy mechanics do not.

## Gameplay evidence

| Run | Result | What it proves |
| --- | --- | --- |
| Continuous world geometry, headless Godot | All15 rooms,14 actual portal transitions,58 successful held jumps | Actual Input movement and authored puzzle interactions through the complete world, including the18-jump Archive and new room13/15 book thresholds. No teleport between route steps. |
| Latest focused world integration | 77 checks,0 failures | Actual-input larva/wraith/turret victories from labelled encounter starts; fixed old-target wraith dodge; native turret bolts blocked by real cover; map pause clears bolts; physical coin collection; unclaimed reward disk reload; output-fold task coins; saved clears and wallet. |
| Latest journal/bookmark integration, headless | 24 checks,0 failures | Real D-pad/A selection, language preservation, controller pagination, actual world disk save/fresh-world restore, and compatibility with saves lacking the optional bookmark field. |
| Final native GL reading/journal integration | 48 checks,0 failures | Actual physical-leaf interaction after a supported nook start, Arabic/English reader, real controller selection, animated-close pause, and the same bookmark cases. |
| Optional room05 spatial-lamp route, native GL | 50 checks,0 failures;6 real jumps | One configured normal entrance followed by uninterrupted Input traversal, observation, harmless wrong attempt, correct lamp sequence,15 physical coins, reward reading/journal, save/reload, and a separately configured solved-lamp revisit. |

The original whole-world diagnostic also included one separate cover jump:59 successful jumps across that complete diagnostic, of which58 belong to the uninterrupted world route. Its four follow-ups were resolved in the focused runs: approach timing for observing a full larva cycle; missing controller A confirmation; a freed-projectile array error after repeated turret shots; and JSON number normalization in the save comparison. Its earlier wallet expectations predate the final physical-coin behavior. It is not presented as a clean final full-suite pass.

Independent focused suites additionally passed: puzzle state3743 checks over243 histories; native wraith55; native repeated-burst turret18; native currency42; native journal28; native menu confirmation7; native health/energy display24; and wallet-cap boundaries10. These runs overlap and are not added together as unique assertions. Reports distinguish configured fixtures from actual movement, positive hits and pickups.

## Visual evidence

The final review contains31 native JPGs and one short MP4. Two older `00_journal_preview_*` photos remain as explicitly superseded previews and are excluded from that final JPG count.

- `previews/m22/01_room_01.jpg` through `15_room_15.jpg`: all15 rooms at supported configured positions, fitted1.35 camera zoom, real lights, foreground and final HUD. These are visual fixtures, not traversal proof.
- `16_turret_gallery.jpg` and `17_wraith_warning.jpg`: real AI warnings on the actual optional gallery/balcony; attack states are not injected.
- `18_reading_ar.jpg` through `21_journal_en.jpg`: final native physical-reader and journal/controller views. The journal browser fixture supplies three existing official page IDs; it does not claim they were discovered during that short fixture.
- `25_hud_lanterns.jpg` through `27_hud_energy.jpg`: independent live-display diagnostics.
- `30_lantern_clue_ar.jpg` through `36_lantern_hud_environment.jpg`: spatial-puzzle, physical-coin and final environment evidence.
- `40_library_journal_combat.mp4`: native MovieWriter fixture with declared cuts; not an uninterrupted campaign recording.

All15 room images were reviewed in a contact sheet; key room and full-size reading/journal views were inspected. The actor, landing lips, furniture and interaction labels remain readable. Final integration/capture logs contain no script, parse, renderer or leak errors. Software GL reports only its expected unsupported-VSync warning.

## Limits

The full15-room traversal uses headless Godot physics. A native GL opening diagnostic reached room05 and was stopped because software rendering was slow; no completed native GL whole-world run is claimed. Final native room views, UI tests, independent enemy/currency tests and the short movie provide renderer evidence separately.

The guardian and Dr.Compiler are still future combat. Environment-preview traversal bypasses those eligibility gates without awarding a real victory, seal or departure. World02 is not implemented. Optional enemy victories use real AI and real attack inputs after configured starting positions; targets are not frozen and positive hits are not injected.

The bookmark test supplies two runtime-authored pages for an existing official collected page ID because the shipped leaf is short. Only its real ID and page index enter the save; fixture text and invented story IDs do not.

## Reproduction

Run commands from the extracted project root with Godot4.7.2. Use a separate empty `XDG_DATA_HOME`, `XDG_CONFIG_HOME` and `XDG_CACHE_HOME` for each QA run. The scripts also restore pre-existing save/settings bytes.

```sh
godot --headless --audio-driver Dummy --fixed-fps 60 --path . --script res://tools/test_m22_world.gd -- --native-focused
godot --headless --audio-driver Dummy --fixed-fps 60 --path . --script res://tools/test_m22_world.gd -- --ui-only
godot --audio-driver Dummy --rendering-method gl_compatibility --fixed-fps 60 --path . --script res://tools/test_m22_world.gd -- --ui-only
godot --audio-driver Dummy --rendering-method gl_compatibility --fixed-fps 60 --path . --script res://tools/capture_m22.gd
```

For the long actual-input world route, omit the final mode argument from the headless world command. The spatial-lamp route has its own `tools/test_m22_lantern_route.gd`. Native rendering commands require a working display. No workspace-specific absolute path is required.

Machine-readable evidence: `M22_ENGINE_QA.json`, `M22_VISUAL_REVIEW.json` and the independent reports named there.

Published ZIP integrity, cold-import outcome and native downloaded-project startup: [M22_RELEASE_CHECK.md](M22_RELEASE_CHECK.md).
