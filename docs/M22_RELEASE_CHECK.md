# M22 — published archive check

Downloaded the complete GitHub ZIP from `m22-library-expansion`, gameplay commit `d726b048ea1adfdff310b6752a0feea7ad22239b`.

- ZIP: 225,052,835 bytes. CRC passed; all **1,511 Git blobs** matched the published tree.
- Extracted into a new directory and imported its assets with official **Godot 4.7.2 Standard**.
- First cold Linux/cloud headless editor import completed asset import and editor-layout loading, then exited with **SIGABRT / 134**. Its log contained no script/parse error. Repeating the import exited **0**. The cause of that editor shutdown has not been established.
- Native OpenGL startup of the downloaded project then exited **0**, with no failed checks, script errors or resource-leak warnings. The remaining driver warning concerns unsupported V-Sync control.
- Verified the M22 main scene, supported starting position, six health units, 99 energy, six-lantern/round-orb HUD script, physical-coin ledger, close background layers and real lights. The M20 hero PNG SHA-256 remains `6eca7436c7a8c39451256aa56db465d664df0d6dbb42d8e7f24122592b34bb66`; the M21 eye rig is present.

This report is a documentation-only addition after the tested gameplay commit. It does not change executable project files. The automated gameplay/UI results and their scope are in [M22_QA.md](M22_QA.md).
