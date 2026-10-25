The Archivist - sound effects v2 (soft). 43 files, 48 kHz, 24-bit stereo WAV.
Design: no white-noise hiss, rounded attacks, dark short plate reverb, modal book/wood bodies, soft bass harmonics so low thumps stay audible on small speakers.
sfx_map.json: for every animation event (names match meta_p1.json / meta_p2.json from the sprite sheets) which sound(s) to play.
  offset = seconds relative to the event (whooshes start early so their peak lands on the hit; tome_land plays 0.24 s after tome_N_fall)
  volume = relative gain, stop_on = event that ends a looping sound
  p2_swap = in Phase 2 use the fire version of that sound
Loops (seamless): idle_breath, wall_close_loop, fire_loop.
guard_hit_block has no animation event: play it when the player hits the boss while the cover is closed.
Sounds are synthesized, so they are royalty free.
