# Stage 01 — The Forgotten Programming Wing

**Built and playable in M14:** The Silent Entrance, its upper gallery, optional reading nook, checkpoint, terminal and gate. All other named areas below are planned, not playable additions in this release.

![Playable opening layout](M14_OPENING_MAP.svg)

The upper route restores the gate on the safe lower floor. The reading nook is optional. All solid ledges and the door exist as separate nodes in the Godot scene.

```mermaid
flowchart LR
    A[01 Silent Entrance — BUILT] --> B[02 Forgotten Assignments — PLANNED]
    B --> C[03 Corrupted Computer Lab — PLANNED]
    C --> D[04 Vertical Archive — PLANNED]
    D --> E[05 INPUT — PLANNED]
    E --> F[06 PROCESS — PLANNED]
    F --> G[07 OUTPUT — PLANNED]
    G --> H[08 Compiler's Approach — PLANNED]
    H --> I[09 Lecture Tribunal — PLANNED]
    I --> J[10 Aftermath Passage — PLANNED]
    D -. future shortcut .-> B
    G -. future shortcut .-> C
```

Enemy-clearance gates and the boss-access item belong to later work. The new opening contains no enemy instances; enemy references are used only for visual coherence and future space planning.
