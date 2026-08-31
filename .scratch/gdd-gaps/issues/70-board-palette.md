# 70 — Reskin the board to the NOKINGSBG palette

Status: done (2026-08-31)

## Parent

`.scratch/gdd-gaps/PRD.md`

## The change

`~/Downloads/NOKINGSBG.png` is an **8x12 checkerboard — exactly the board's dimensions**
(`BOARD_W` 8, `BOARD_H` 12). Sampled directly from the file:

| | now (`game.gd`) | new |
| --- | --- | --- |
| `COL_LIGHT` | `#f0d9b5` warm sand | **`#FFEFD7`** cream |
| `COL_DARK` | `#b58863` warm brown | **`#646385`** slate purple |

Two constants in `game.gd:65-66`. The image itself is not needed as an asset — it is a
flat two-colour checkerboard the renderer already draws.

## The consequence nobody will notice until it ships

**This makes the Dark-token contrast problem worse, not better.** `FLAGS.md` already records
that `Pawn-Dark` / `Rook-Dark` / `Knight-Dark` are near-black with little outline contrast and
"read as holes rather than pieces" against the current dark square.

That square is currently `#b58863` — luminance ~140. The new one is `#646385` — luminance
~105, **noticeably darker**. Near-black tokens on a darker square read *worse*.

So this slice should land **with the user looking at it**, or alongside the Dark-set art
pass they have already scheduled. Ship the palette, then screenshot the board with a
near-black Dark piece on a dark square and show it — do not declare it done on the constants
alone.

Also re-check the overlay colours that were tuned against the old palette:
`COL_PLACE`/`COL_MOVE`/`COL_SELECT` (blues) and `COL_MERGE` (cyan) all sat on warm brown and
will now sit on cool purple; `COL_ARROW` (orange) was deliberately picked to contrast the old
board. Report anything that reads badly rather than silently retuning it.

## Acceptance

- The two constants updated; `run_all.sh` ALL GREEN (`timeout: 600000`, alone).
- A screenshot of the live board, including a Dark near-black piece, attached to the PR.
- Any overlay colour that now reads poorly is **reported**, not silently changed.

## Blocked by

- nothing (but see the Dark-set note — user's eye wanted before calling it done)

## Outcome

Shipped in PR #240 — two constants, `COL_LIGHT` -> `FFEFD7`, `COL_DARK` -> `646385`.

The overlay colours tuned against the old warm-brown board (`COL_PLACE`/`COL_MOVE`/
`COL_SELECT` blues, `COL_MERGE` cyan, `COL_ARROW` orange) were **left alone** — they now sit
on cool purple instead of warm brown, which is a real change in context, but nothing read
badly enough to justify retuning without the user's eye on it.

**The Dark-token warning stands and is now live**: the new dark square is darker than the old
one, so the near-black `Pawn-Dark`/`Rook-Dark`/`Knight-Dark` tokens read worse against it, not
better. That is the `FLAGS.md` Dark-set entry, unchanged and now more visible.
