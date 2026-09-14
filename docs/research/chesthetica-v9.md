# CHESTHETICA v9.01 and NO-KINGS

Research note for NO-78 (filed 2026-09-13). The issue text was not readable from the
repo or `~/Documents`; the only local trace is the filing line in
`~/Documents/handoff-nokings-2026-09-13-evening.md:18`. So why Max wants it looked at
is inferred: probably whether an automatic chess-problem composer could produce
composed positions (King waves, a puzzle mode) or a beauty score for NO-KINGS. Read
the recommendation with that inference in mind.

## What it is

CHESTHETICA is Azlan Iqbal's (Universiti Tenaga Nasional, Malaysia) program that
composes "chess constructs", orthodox forced-mate problems, from scratch. Three-movers
first, later four- and five-movers and study-like positions. It also scores their
beauty with his computational aesthetics model, which is where the program started
in 2006, as the evaluator behind his 2008 PhD ("A Discrete Computational Aesthetics
Model for a Zero-Sum Perfect Information Game", [chessprogramming.org/Azlan_Iqbal]).
Composing arrived with the "Digital Synaptic Neural Substrate" (DSNS) module in the
v9 line ([ChessBase, 2014-11-07], "presently in version 9.45").

v9.01 itself is not documented in any primary source I found. The v9 timeline that is:
v9.22 is the build the DSNS paper ran on ([arXiv:1507.07058], section 4.2); v9.45 in
Nov 2014; v9.47 to 9.53 by Feb 2015 ([ChessBase, 2015-02-06]); v10.13 by May 2016
([ChessBase, 2016-05-31]); v10.43 in Apr 2017, which added composing from a
user-chosen piece set ([ChessBase, 2017-04-07]). So 9.01 is an early-2014 build from
before the paper, presumably the first DSNS-composing generation. That is an
inference, not a citation. The official site `chesthetica.com` does not resolve
(DNS failure on 2026-09-14, with and without `www`).

## Method in five lines

1. Describe each object in a sample (chess problems, tournament games, or
   photographs) as a "DSNS string" of 10 numbers: white and black piece counts,
   their Shannon values and difference, move count, year, first and last piece to
   move, sparsity ([arXiv:1507.07058], section 4.3).
2. Pick two strings, compute a "deviation" (sum of absolute differences plus a
   "summative division" term), then search for two new strings with the same
   deviation. A cross-domain pair (chess plus photo) merges two deviations digit by
   digit (sections 3.1 and 3.2).
3. Turn the new strings into a board. Fix piece counts and material from them, place
   the kings, then drop random pieces on random squares under legality,
   material-difference and sparsity constraints (Appendix A, steps 2 to 19).
4. Ask a mate solver (ChestUCI v5.2, 5-second limit) whether a forced mate-in-3
   exists. If so, strip every non-king piece the mate survives without (three
   passes), then re-add pieces until the chosen composition conventions hold (no
   cooks, no duals, no check or capture in the key, no key restricting the enemy
   king). Store as PGN (Appendix A, steps 20 to 23).
5. Score with the separate aesthetics model: formalised themes from the chess
   literature plus some randomness, giving a 0 to 5 number to three decimals that
   can differ between runs on the same line. The author says it cannot be used as a
   hill-climbing heuristic (section 4.2 and footnote 16; [IEEE TCIAIG 4(3), 2012]
   for the model).

The composer is "limited to orthodox mate-in-3 problems in standard international
chess" (Appendix A, first paragraph). No variant, fairy piece or non-8x8 board
appears in any source read.

## Licence and availability

Closed. "Chesthetica is not open source" ([ChessBase, 2015-09-07], author's reply in
the comments) and "there are no plans at the moment to make Chesthetica available to
the public" ([ChessBase, 2016-05-31]). The DSNS method sits under Malaysian patent
application PI 2014703983, filed 2014-12-24 ([arXiv:1507.07058], footnote 9).

No binary, no API, no source. Platform is never stated beyond "a simple notebook
computer" ([ChessBase, 2017-04-07]). A search-engine summary claimed free Android and
iOS apps; no primary source backs that, and the only Iqbal app article found is for an
unrelated variant (Switch-Side Chain-Chess). Unverified, so ignore it.

Only the output is public: daily YouTube uploads, "a periodically-updated PGN of the
compositions" ([ChessBase, 2016-05-31]), and Kindle books (Chesthetica's Book of Chess
Constructs vols 1 to 7, 2017 to 2023; Chess Compositions in the Age of AI vols 1 to 3,
2024 to 2026). The paper cites a downloadable "Chesthetica Endgame" evaluator (Iqbal,
2012); I did not locate it, and it scores, it does not compose.

## Applicability to NO-KINGS

It does not fit, on four independent grounds. Any one would be enough.

1. We cannot run it. Nothing is obtainable; the only route is a licence from the
   author, who has said no plans exist.
2. Wrong rules. It composes for 8x8 orthodox chess. NO-KINGS is 8x12
   (`game/scripts/tuning.gd:4-5`; the NO-78 brief's "standard 8x8" is out of date),
   with 39 pieces whose moves are leap, ride and bent sets with move-or-capture
   modes (`game/data/pieces.json`, `game/scripts/rules.gd:31`).
3. Wrong game shape. The player has no King; `find_king` only ever finds the enemy's
   (`rules.gd:177`, `rules.gd:237`). Turns are 2 player actions against 1 enemy
   action (`tuning.gd:9,76`), and pieces enter from Stock rather than a fixed
   position. "White to play and mate in 3" has no equivalent here.
4. Waves are rosters, not positions. The Wave Catalog is a list of piece ids spawned
   on the top row (`game/data/waves.gd`); the only position-level format in the game
   is the scenario config (`game/data/scenarios.gd:1-12`). There is no slot a
   composed FEN would plug into.

To USE it we would need a source licence, then a rewrite of the board model, move
generator, legality and mate solver for 8x12 fairy pieces and asymmetric turns. That
is everything except the DSNS string arithmetic. The aesthetics model would have to be
re-derived from nothing; its features are orthodox composition themes.

## Alternatives

Our own composer over `rules.gd`. Appendix A's loop is plain logic we already have
primitives for: random placement, `legal_moves` and `is_attacked` for legality,
`is_checkmate` for the terminal test, plus a small depth-limited search for "player
forces checkmate within N actions" under the 2-vs-1 turn rule. Output is a
`scenarios.gd` config (`board`, `stock`, `wave`), so it drops into the existing
sandbox and the `test_scenarios.gd` sweep unchanged. A few hundred lines in the
pure-logic idiom; the search is the one part with real design in it. The composition
conventions (no check or capture in the key, economy by piece-stripping) transfer as
ideas for free. But nothing in the GDD or `CONTEXT.md` asks for composed positions.
King waves are rosters. This is a feature proposal, not a fix.

Fairy-chess problem tools. Popeye is "free open-source cross-platform" and supports "a
great deal of fairy chess elements (piece types, conditions and stipulations)"
([github.com/thomas-maeder/popeye]). It solves, it does not compose, and neither our
8x12 board nor the 2-vs-1 turn is a Popeye stipulation. At best it could sanity-check
a hand-made orthodox-shaped position, which is not what we have.

The aesthetics score on its own. Even if a beauty number were wanted (a "stylish
mate" bonus, say), Iqbal's model is orthodox-theme-specific and varies run to run. A
NO-KINGS bonus is better built from our own observable events (captures in the mating
turn, pieces spent, Artefacts fired) through `Economy.earn`, where every other bonus
already routes.

## Recommendation: DROP

CHESTHETICA cannot be obtained, and if it could, only the idea of "random placement,
verify, strip to economy" survives the move to an 8x12 fairy board with no player
King and asymmetric turns. That idea is cheap to re-implement over `rules.gd` if a
composed-position mode is ever specced. Until the GDD asks for one there is nothing to
build. Close NO-78 with this note; open a Linear issue for an own composer only when a
puzzle or composed-King-wave mode is designed.

## Sources

- [arXiv:1507.07058] Iqbal, Guid, Colton, Krivec, Azman, Haghighi, "The Digital
  Synaptic Neural Substrate: A New Approach to Computational Creativity", 2015/2016,
  https://arxiv.org/abs/1507.07058. Full PDF read: sections 3.1 to 3.4, 4.2, 4.3,
  Appendices A and C.
- [arXiv:1609.06953] "The DSNS: Size and Quality Matters", 2016,
  https://arxiv.org/abs/1609.06953.
- [arXiv:1309.3039] Iqbal, "How Relevant Are Chess Composition Conventions?",
  https://arxiv.org/abs/1309.3039.
- [arXiv:1709.00931] "A Computer Composes A Fabled Problem: Four Knights vs. Queen",
  2017, https://arxiv.org/abs/1709.00931.
- [IEEE TCIAIG 4(3), 2012] Iqbal, van der Heijden, Guid, Makhmali, "Evaluating the
  Aesthetics of Endgame Studies", https://ieeexplore.ieee.org/document/6177652/
  (page returned empty; title and venue from the search index).
- [ChessBase, 2014-11-07] https://en.chessbase.com/post/a-machine-that-composes-chess-problems
- [ChessBase, 2015-02-06] https://en.chessbase.com/post/computer-generated-chess-problems-for-everyone
- [ChessBase, 2015-09-07] https://en.chessbase.com/post/chesthetica-composes-longer-mates
- [ChessBase, 2016-05-31] https://en.chessbase.com/post/azlan-iqbal-studies-and-a-decade-in-development
- [ChessBase, 2017-04-07] https://en.chessbase.com/post/chesthetica-composes-custom-mates
- [chessprogramming.org/Azlan_Iqbal] https://www.chessprogramming.org/Azlan_Iqbal
- [github.com/thomas-maeder/popeye] https://github.com/thomas-maeder/popeye
- Repo: `game/scripts/tuning.gd`, `game/scripts/rules.gd`, `game/data/waves.gd`,
  `game/data/scenarios.gd`, `game/data/pieces.json`, `CONTEXT.md`.
