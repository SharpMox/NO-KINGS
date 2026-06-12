/* ============================================================
 *  pieces-codex.js
 *  Curated 38-piece working-set used by codex/promotion/fusion/inversion.
 *  Each entry has a primary medieval-fantasy `name` plus `original_name`
 *  carrying the Wikipedia source name. Two description fields are kept:
 *
 *    - description       — long-form encyclopedia prose, used by
 *                          fusion.html and inversion.html mini-cards.
 *    - description_codex — short Betza-atom breakdown, used by codex.html
 *                          (which surfaces it as the card body copy).
 *
 *  Codex-only invented pieces (kirin-plus, kirin-plus-plus, inv-sergeant,
 *  inv-arrow-pawn, inv-kirin-plus, inv-kirin-plus-plus) are inlined here so
 *  the codex stays self-sufficient when the encyclopedia drops them.
 *
 *  Editing this file does NOT affect encyclopedia/index.html — it has its
 *  own canonical dataset in pieces-encyclopedia.js.
 * ============================================================ */
var PIECES_CODEX = [
    {
      id: 'pawn',
      family: 'pawn-like',
      name: 'Pawn',
      original_name: 'Pawn',
      aliases: [],
      glyph: '♟',
      betza: 'mfWcfFimfnD',
      origin: 'Standard',
      description: 'Moves one square forward (no capture). Captures one square diagonally forward. May move two squares forward on its first move, and can capture en passant. Promotes upon reaching the last rank.',
      description_codex: 'fmW (forward move), fcF (forward capture), ifmW2 (initial forward).',
      behaviors: ['direction-restricted', 'promotes', 'capture-different'],
      moves: [
        { kind: 'rings', squares: [[0,1],[0,2]] },
        { kind: 'xs',    squares: [[1,1],[-1,1]] }
      ]
    },
    {
      id: 'berolina',
      family: 'pawn-like',
      name: 'Void Pawn',
      original_name: 'Berolina Pawn',
      aliases: ['Berlin Pawn'],
      letter: 'BP',
      betza: 'mfFcfWimfnA',
      origin: 'Modern',
      description: 'The Pawn’s mirror: moves one square diagonally forward (or two on its first move), captures one square straight forward. En passant and promotion apply as for the standard pawn.',
      description_codex: 'fmF (forward move), fcW (forward capture), ifmF2 (initial forward).',
      behaviors: ['direction-restricted', 'promotes', 'capture-different'],
      moves: [
        { kind: 'rings', squares: [[1,1],[-1,1],[2,2],[-2,2]] },
        { kind: 'xs',    squares: [[0,1]] }
      ]
    },
    {
      id: 'sergeant',
      family: 'pawn-like',
      name: 'Ranger',
      original_name: 'Sergeant',
      aliases: [],
      letter: 'SG',
      betza: 'mWcF',
      origin: 'Extended Pawn variant',
      description: 'Moves one square orthogonally in any of the four directions (move only) and captures one square diagonally in any of the four directions. Move-vs-capture asymmetry is its only pawn-like trait — it is fully symmetric in direction.',
      description_codex: 'mW (move), cF (capture).',
      behaviors: ['capture-different'],
      moves: [
        { kind: 'rings', squares: [[1,0],[-1,0],[0,1],[0,-1]] },
        { kind: 'xs',    squares: [[1,1],[-1,1],[1,-1],[-1,-1]] }
      ]
    },
    {
      id: 'inv-sergeant',
      family: 'pawn-like',
      name: 'Void Ranger',
      original_name: 'Inv Sergeant',
      aliases: [],
      letter: 'iSg',
      betza: 'mFcW',
      origin: 'Invented',
      description: 'Inversion of the Sergeant (mWcF): swap the move-direction set with the capture-direction set, then apply ortho ↔ diag rotation. Moves one diagonal step (Ferz, move-only) and captures one orthogonal step (Wazir, capture-only).',
      behaviors: ['pawn-like', 'color-bound'],
      moves: [
        { kind: 'rings', squares: [[1,1],[-1,1],[1,-1],[-1,-1]] },
        { kind: 'xs',    squares: [[1,0],[-1,0],[0,1],[0,-1]] }
      ]
    },
    {
      id: 'arrow-pawn',
      family: 'pawn-like',
      name: 'Archer',
      original_name: 'Arrow Pawn',
      aliases: ['Persson Pawn'],
      letter: 'AP',
      betza: 'mW2cF',
      origin: 'Arrow Pawn Chess (Persson, 1938)',
      description: 'Moves one or two squares orthogonally in any direction (move only), and captures one square diagonally in any direction. Unlike a standard pawn, it is not direction-restricted — only its move/capture asymmetry makes it pawn-like.',
      description_codex: 'mW2 (move up to 2), cF (capture).',
      behaviors: ['promotes', 'capture-different'],
      moves: [
        { kind: 'rings', squares: [[1,0],[2,0],[-1,0],[-2,0],[0,1],[0,2],[0,-1],[0,-2]] },
        { kind: 'xs',    squares: [[1,1],[-1,1],[1,-1],[-1,-1]] }
      ]
    },
    {
      id: 'inv-arrow-pawn',
      family: 'pawn-like',
      name: 'Void Archer',
      original_name: 'Inv Arrow Pawn',
      aliases: [],
      letter: 'iAP',
      betza: 'mF2cW',
      origin: 'Invented',
      description: 'Inversion of the Arrow Pawn (mW2cF). Moves one or two diagonal squares (move-only Bishop capped at 2) and captures one orthogonal step.',
      behaviors: ['pawn-like', 'color-bound'],
      moves: [
        { kind: 'rings', squares: [[1,1],[-1,1],[1,-1],[-1,-1],[2,2],[-2,2],[2,-2],[-2,-2]] },
        { kind: 'xs',    squares: [[1,0],[-1,0],[0,1],[0,-1]] }
      ]
    },
    {
      id: 'ferz',
      family: 'leapers',
      name: 'Seer',
      original_name: 'Ferz',
      aliases: ['Fers', 'Counsellor', 'Mantri'],
      letter: 'F',
      betza: 'F',
      origin: 'Shatranj',
      description: 'Steps one square diagonally. The historical Shatranj precursor to the modern Queen; colour-bound to its starting square colour.',
      description_codex: 'F (1-step diagonal).',
      behaviors: ['leaper', 'color-bound'],
      moves: [
        { kind: 'dots', squares: [[1,1],[-1,1],[1,-1],[-1,-1]] }
      ]
    },
    {
      id: 'elephant-modern',
      family: 'leapers',
      name: 'Mystic',
      original_name: 'Elephant (Modern)',
      aliases: ['Modern Elephant'],
      letter: 'EM',
      betza: 'FA',
      origin: 'Modern variants',
      description: 'Combines Ferz (1,1) and Alfil (2,2) — leaps one or two squares diagonally. Eight reachable squares, all on diagonals. Heavily colour-bound. Used in modern variants as a stronger fairy "Elephant".',
      description_codex: 'F + A (1-step + (2,2) leap diagonal).',
      behaviors: ['compound', 'leaper', 'color-bound'],
      moves: [
        { kind: 'dots', squares: [
          [1,1],[-1,1],[1,-1],[-1,-1],
          [2,2],[-2,2],[2,-2],[-2,-2]
        ] }
      ]
    },
    {
      id: 'high-priestess',
      family: 'leapers',
      name: 'High Priestess',
      original_name: 'High Priestess',
      aliases: [],
      letter: 'HP',
      betza: 'FAN',
      origin: 'Problem chess',
      description: 'Combines the Ferz (1,1), Alfil (2,2), and Knight (1,2) leaps — 16 reachable squares at short range. Not colour-bound, because the Knight component breaks the otherwise diagonal palette.',
      description_codex: 'F + A + N.',
      behaviors: ['compound', 'leaper'],
      moves: [
        { kind: 'dots', squares: [
          [1,1],[-1,1],[1,-1],[-1,-1],
          [2,2],[-2,2],[2,-2],[-2,-2],
          [1,2],[2,1],[-1,2],[-2,1],[1,-2],[2,-1],[-1,-2],[-2,-1]
        ] }
      ]
    },
    {
      id: 'wazir',
      family: 'leapers',
      name: 'Mage',
      original_name: 'Wazir',
      aliases: ['Vizir', 'Wezir'],
      letter: 'W',
      betza: 'W',
      origin: 'Shatranj',
      description: 'Steps one square orthogonally. A "short Rook" — the orthogonal counterpart of the Ferz.',
      description_codex: 'W (1-step orthogonal).',
      behaviors: ['leaper'],
      moves: [
        { kind: 'dots', squares: [[1,0],[-1,0],[0,1],[0,-1]] }
      ]
    },
    {
      id: 'war-machine',
      family: 'leapers',
      name: 'Sorcerer',
      original_name: 'War Machine',
      aliases: [],
      letter: 'WM',
      betza: 'WD',
      origin: 'Problem chess',
      description: 'Combines Wazir (1,0) and Dabbaba (2,0) — leaps one or exactly two squares orthogonally. Eight reachable squares, all on ranks and files.',
      description_codex: 'W + D (1-step + (0,2) leap orthogonal).',
      behaviors: ['compound', 'leaper'],
      moves: [
        { kind: 'dots', squares: [
          [1,0],[-1,0],[0,1],[0,-1],
          [2,0],[-2,0],[0,2],[0,-2]
        ] }
      ]
    },
    {
      id: 'champion',
      family: 'leapers',
      name: 'Archmage',
      original_name: 'Champion',
      aliases: [],
      letter: 'Ch',
      betza: 'WAD',
      origin: 'Omega Chess',
      description: 'Combines Wazir (1,0), Alfil (2,2), and Dabbaba (2,0) — 12 reachable squares: a one-step orthogonal "ring" plus all eight squares of the second ring at corner and edge positions. One of the two new pieces in Omega Chess.',
      description_codex: 'W + A + D.',
      behaviors: ['compound', 'leaper'],
      moves: [
        { kind: 'dots', squares: [
          [1,0],[-1,0],[0,1],[0,-1],
          [2,2],[-2,2],[2,-2],[-2,-2],
          [2,0],[-2,0],[0,2],[0,-2]
        ] }
      ]
    },
    {
      id: 'bishop',
      family: 'sliders',
      name: 'Bishop',
      original_name: 'Bishop',
      aliases: [],
      glyph: '♝',
      betza: 'B',
      origin: 'Standard',
      description: 'Slides any number of squares diagonally. Each bishop is locked to one square colour for the entire game — a King + 2 same-colour Bishops cannot deliver mate.',
      description_codex: 'B (diagonal slide).',
      behaviors: ['long-range', 'color-bound'],
      moves: [
        { kind: 'rays', dirs: [[1,1],[-1,1],[1,-1],[-1,-1]] }
      ]
    },
    {
      id: 'dragon-horse',
      family: 'compounds',
      name: 'Paladin',
      original_name: 'Dragon Horse',
      aliases: ['Promoted Bishop', 'Ryūma'],
      letter: '馬',
      betza: 'BW',
      origin: 'Shōgi',
      description: 'A Bishop that also steps one square orthogonally. Created when a Shōgi Bishop is promoted. No longer colour-bound.',
      description_codex: 'B + W (diagonal slide + 1-step orthogonal).',
      behaviors: ['compound', 'long-range'],
      moves: [
        { kind: 'rays', dirs: [[1,1],[-1,1],[1,-1],[-1,-1]] },
        { kind: 'dots', squares: [[1,0],[-1,0],[0,1],[0,-1]] }
      ]
    },
    {
      id: 'archbishop',
      family: 'compounds',
      name: 'Archbishop',
      original_name: 'Archbishop',
      aliases: ['Princess', 'Cardinal', 'Janus'],
      letter: 'AR',
      betza: 'BN',
      origin: 'Modern',
      description: 'Bishop + Knight combined. Crucially colour-complete: King + Archbishop alone can force mate, unlike King + Bishop or King + Knight on their own.',
      description_codex: 'B + N (diagonal slide + (1,2) leap).',
      behaviors: ['compound', 'long-range', 'leaper'],
      moves: [
        { kind: 'rays', dirs: [[1,1],[-1,1],[1,-1],[-1,-1]] },
        { kind: 'dots', squares: [[1,2],[2,1],[-1,2],[-2,1],[1,-2],[2,-1],[-1,-2],[-2,-1]] }
      ]
    },
    {
      id: 'rook',
      family: 'sliders',
      name: 'Rook',
      original_name: 'Rook',
      aliases: ['Castle'],
      glyph: '♜',
      betza: 'R',
      origin: 'Standard',
      description: 'Slides any number of squares along ranks or files. Participates with the King in castling.',
      description_codex: 'R (orthogonal slide).',
      behaviors: ['long-range'],
      moves: [
        { kind: 'rays', dirs: [[1,0],[-1,0],[0,1],[0,-1]] }
      ]
    },
    {
      id: 'dragon-king',
      family: 'compounds',
      name: 'Drake',
      original_name: 'Dragon King',
      aliases: ['Promoted Rook', 'Ryūō'],
      letter: '龍',
      betza: 'RF',
      origin: 'Shōgi',
      description: 'A Rook that also steps one square diagonally. Created when a Shōgi Rook is promoted in the opponent’s last three ranks.',
      description_codex: 'R + F (orthogonal slide + 1-step diagonal).',
      behaviors: ['compound', 'long-range'],
      moves: [
        { kind: 'rays', dirs: [[1,0],[-1,0],[0,1],[0,-1]] },
        { kind: 'dots', squares: [[1,1],[-1,1],[1,-1],[-1,-1]] }
      ]
    },
    {
      id: 'chancellor',
      family: 'compounds',
      name: 'Dragonlord',
      original_name: 'Chancellor',
      aliases: ['Marshall', 'Marshal', 'Empress', 'Concubine'],
      letter: 'CH',
      betza: 'RN',
      origin: 'Modern',
      description: 'Rook + Knight combined. Roughly equal in value to a Queen in most computer studies.',
      description_codex: 'R + N (orthogonal slide + (1,2) leap).',
      behaviors: ['compound', 'long-range', 'leaper'],
      moves: [
        { kind: 'rays', dirs: [[1,0],[-1,0],[0,1],[0,-1]] },
        { kind: 'dots', squares: [[1,2],[2,1],[-1,2],[-2,1],[1,-2],[2,-1],[-1,-2],[-2,-1]] }
      ]
    },
    {
      id: 'knight',
      family: 'leapers',
      name: 'Knight',
      original_name: 'Knight',
      aliases: ['Horse'],
      glyph: '♞',
      betza: 'N',
      origin: 'Standard',
      description: 'Leaps in an L: two squares in one direction, then one perpendicular. The only standard piece that ignores intervening pieces.',
      description_codex: 'N ((1,2) leap).',
      behaviors: ['leaper'],
      moves: [
        { kind: 'dots', squares: [[1,2],[2,1],[-1,2],[-2,1],[1,-2],[2,-1],[-1,-2],[-2,-1]] }
      ]
    },
    {
      id: 'gnu',
      family: 'leapers',
      name: 'Hippogriff',
      original_name: 'Gnu',
      aliases: ['Unicorn'],
      letter: 'GU',
      betza: 'NC',
      origin: 'Problem chess',
      description: 'Combines the Knight (1,2) and Camel (1,3) leaps — 16 reachable squares, all at short range.',
      description_codex: 'N + C ((1,2) + (1,3) leaps).',
      behaviors: ['compound', 'leaper'],
      moves: [
        { kind: 'dots', squares: [
          [1,2],[2,1],[-1,2],[-2,1],[1,-2],[2,-1],[-1,-2],[-2,-1],
          [1,3],[3,1],[-1,3],[-3,1],[1,-3],[3,-1],[-1,-3],[-3,-1]
        ] }
      ]
    },
    {
      id: 'buffalo',
      family: 'leapers',
      name: 'Behemoth',
      original_name: 'Buffalo',
      aliases: [],
      letter: 'BF',
      betza: 'CZN',
      origin: 'Problem chess',
      description: 'Camel + Zebra + Knight fused — 24 reachable squares. The largest of the standard short-range leaper compounds.',
      description_codex: 'C + Z + N ((1,3) + (2,3) + (1,2) leaps).',
      behaviors: ['compound', 'leaper'],
      moves: [
        { kind: 'dots', squares: [
          [1,3],[3,1],[-1,3],[-3,1],[1,-3],[3,-1],[-1,-3],[-3,-1],
          [2,3],[3,2],[-2,3],[-3,2],[2,-3],[3,-2],[-2,-3],[-3,-2],
          [1,2],[2,1],[-1,2],[-2,1],[1,-2],[2,-1],[-1,-2],[-2,-1]
        ] }
      ]
    },
    {
      id: 'kirin',
      family: 'leapers',
      name: 'Kirin',
      original_name: 'Kirin',
      aliases: [],
      letter: 'Ki',
      betza: 'FD',
      origin: 'Chu Shōgi',
      description: 'Combines Ferz (1,1) and Dabbaba (2,0) — four diagonal one-step plus four orthogonal two-square leaps. Colour-bound, since both components preserve square colour. Appears in Chu Shōgi.',
      description_codex: 'F + D (1-step diagonal + (0,2) leap).',
      behaviors: ['compound', 'leaper', 'color-bound'],
      moves: [
        { kind: 'dots', squares: [
          [1,1],[-1,1],[1,-1],[-1,-1],
          [2,0],[-2,0],[0,2],[0,-2]
        ] }
      ]
    },
    {
      id: 'kirin-plus',
      family: 'leapers',
      name: 'Sacred Kirin',
      original_name: 'Kirin+',
      aliases: [],
      letter: 'Ki+',
      betza: 'FDC',
      origin: 'Invented',
      description: 'Promoted form of the Kirin. Adds the Camel (1,3) L-leap to the Kirin\'s Ferz and Dabbaba moves — sixteen reachable squares. Stays fully colour-bound: every component has an even dx+dy (1+1, 2+0, 1+3), so the piece never changes square colour.',
      behaviors: ['compound', 'leaper', 'color-bound'],
      moves: [
        { kind: 'dots', squares: [
          [1,1],[-1,1],[1,-1],[-1,-1],
          [2,0],[-2,0],[0,2],[0,-2],
          [1,3],[-1,3],[1,-3],[-1,-3],[3,1],[-3,1],[3,-1],[-3,-1]
        ] }
      ]
    },
    {
      id: 'inv-kirin-plus',
      family: 'leapers',
      name: 'Void Kirin',
      original_name: 'Inv Kirin+',
      aliases: [],
      letter: 'iKi+',
      betza: 'WNH',
      origin: 'Invented',
      description: 'Inversion of Kirin+ (FDC). Strictly colour-changing — every destination has the opposite square colour from the start. Combines Wazir (1,0) at the closest ring, Knight (1,2) inside, and Threeleaper (3,0) as the four diamond-point cardinal leaps.',
      behaviors: ['compound', 'leaper', 'color-changing'],
      moves: [
        { kind: 'dots', squares: [
          [1,0],[-1,0],[0,1],[0,-1],
          [1,2],[-1,2],[1,-2],[-1,-2],[2,1],[-2,1],[2,-1],[-2,-1],
          [3,0],[-3,0],[0,3],[0,-3]
        ] }
      ]
    },
    {
      id: 'kirin-plus-plus',
      family: 'leapers',
      name: 'Celestial Kirin',
      original_name: 'Kirin++',
      aliases: [],
      letter: 'Ki++',
      betza: 'FADCG + 4L',
      origin: 'Invented',
      description: 'Final form of the Kirin promotion chain. Twenty-eight leap targets: Ferz (1,1), Alfil (2,2), Dabbaba (2,0), Camel (1,3), Tripper (3,3), and Fourleaper (4,0). Every component is colour-bound.',
      behaviors: ['compound', 'leaper', 'color-bound'],
      moves: [
        { kind: 'dots', squares: [
          [1,1],[-1,1],[1,-1],[-1,-1],
          [2,2],[-2,2],[2,-2],[-2,-2],
          [2,0],[-2,0],[0,2],[0,-2],
          [1,3],[-1,3],[1,-3],[-1,-3],[3,1],[-3,1],[3,-1],[-3,-1],
          [3,3],[-3,3],[3,-3],[-3,-3],
          [4,0],[-4,0],[0,4],[0,-4]
        ] }
      ]
    },
    {
      id: 'inv-kirin-plus-plus',
      family: 'leapers',
      name: 'Void Celestial Kirin',
      original_name: 'Inv Kirin++',
      aliases: [],
      letter: 'iKi++',
      betza: 'WNH + Giraffe + Zebra',
      origin: 'Invented',
      description: 'Extends Inv Kirin+ outward with two more colour-changing rings: Giraffe (1,4) near the outer cardinal extremes, and Zebra (2,3) filling the gaps between H and Giraffe. All 32 leap targets are strictly colour-changing.',
      behaviors: ['compound', 'leaper', 'color-changing'],
      moves: [
        { kind: 'dots', squares: [
          [1,0],[-1,0],[0,1],[0,-1],
          [1,2],[-1,2],[1,-2],[-1,-2],[2,1],[-2,1],[2,-1],[-2,-1],
          [3,0],[-3,0],[0,3],[0,-3],
          [1,4],[-1,4],[1,-4],[-1,-4],[4,1],[-4,1],[4,-1],[-4,-1],
          [2,3],[3,2],[-2,3],[-3,2],[2,-3],[3,-2],[-2,-3],[-3,-2]
        ] }
      ]
    },
    {
      id: 'alibaba',
      family: 'leapers',
      name: 'Wanderer',
      original_name: 'Alibaba',
      aliases: [],
      letter: 'AD',
      betza: 'AD',
      origin: 'Problem chess',
      description: 'Combines the Alfil (2,2) and Dabbaba (2,0) leaps into a single piece — eight reachable squares forming the "second ring" along ranks, files, and diagonals. The single-leap counterpart of the Alibabarider. Heavily colour-bound, since both components preserve square colour.',
      description_codex: 'A + D ((2,2) leap + (0,2) leap).',
      behaviors: ['compound', 'leaper', 'color-bound'],
      moves: [
        { kind: 'dots', squares: [
          [2,2],[-2,2],[2,-2],[-2,-2],
          [2,0],[-2,0],[0,2],[0,-2]
        ] }
      ]
    },
    {
      id: 'bodyguard',
      family: 'sliders',
      name: 'Praetorian',
      original_name: 'Bodyguard',
      aliases: ['Hia'],
      letter: 'BG',
      betza: 'Q2',
      origin: 'Hiashatar (Mongolian decimal chess)',
      description: 'Slides like a Queen but only one or two squares in any of the eight directions. Has a defensive aura in Hiashatar: any opposing sliding piece must stop the moment it moves within a King\'s-move radius of the Bodyguard, so it cannot pass by without being challenged.',
      description_codex: 'Q2 (Q slide capped at 2 squares).',
      behaviors: ['direction-restricted'],
      moves: [
        { kind: 'rays', dirs: [[1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,1],[1,-1],[-1,-1]], maxRange: 2 }
      ]
    },
    {
      id: 'queen',
      family: 'sliders',
      name: 'Queen',
      original_name: 'Queen',
      aliases: [],
      glyph: '♛',
      betza: 'Q',
      origin: 'Standard',
      description: 'Slides any number of squares along ranks, files, or diagonals. The most powerful standard piece — Rook + Bishop combined.',
      description_codex: 'Q = R + B.',
      behaviors: ['long-range', 'compound'],
      moves: [
        { kind: 'rays', dirs: [[1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,1],[1,-1],[-1,-1]] }
      ]
    },
    {
      id: 'squirrel',
      family: 'leapers',
      name: 'Faerie',
      original_name: 'Squirrel',
      aliases: [],
      letter: 'Sq',
      betza: 'NAD',
      origin: 'Problem chess',
      description: 'Combines Knight (1,2), Alfil (2,2), and Dabbaba (2,0) leaps. Reaches every square exactly two squares away from the piece (the full "second ring" at Chebyshev distance 2) — 16 squares in total: eight knight-leap targets, four diagonal corners, and four orthogonal edge-midpoints.',
      description_codex: 'N + A + D.',
      behaviors: ['compound', 'leaper'],
      moves: [
        { kind: 'dots', squares: [
          [1,2],[2,1],[-1,2],[-2,1],[1,-2],[2,-1],[-1,-2],[-2,-1],
          [2,2],[-2,2],[2,-2],[-2,-2],
          [2,0],[-2,0],[0,2],[0,-2]
        ] }
      ]
    },
    {
      id: 'crown-princess',
      family: 'compounds',
      name: 'Crown Princess',
      original_name: 'Crown Princess',
      aliases: ['Popess'],
      letter: 'CP',
      betza: 'BNW',
      origin: 'Modern variants',
      description: 'Archbishop + Wazir — combines Bishop slides, Knight leaps, and one-step orthogonal moves. A short-step extension of the Princess/Archbishop, similar in spirit to Dragon Horse but with the Knight added.',
      description_codex: 'B + N + W.',
      behaviors: ['compound', 'long-range', 'leaper'],
      moves: [
        { kind: 'rays', dirs: [[1,1],[-1,1],[1,-1],[-1,-1]] },
        { kind: 'dots', squares: [
          [1,2],[2,1],[-1,2],[-2,1],[1,-2],[2,-1],[-1,-2],[-2,-1],
          [1,0],[-1,0],[0,1],[0,-1]
        ] }
      ]
    },
    {
      id: 'amazon',
      family: 'compounds',
      name: 'Amazon',
      original_name: 'Amazon',
      aliases: ['Angel', 'Commander', 'Wyvern'],
      letter: 'A',
      betza: 'QN',
      origin: 'Modern',
      description: 'Queen + Knight combined — slides along all 8 lines and also leaps in an L. The strongest single fairy piece in common use.',
      description_codex: 'Q + N.',
      behaviors: ['compound', 'long-range', 'leaper'],
      moves: [
        { kind: 'rays', dirs: [[1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,1],[1,-1],[-1,-1]] },
        { kind: 'dots', squares: [[1,2],[2,1],[-1,2],[-2,1],[1,-2],[2,-1],[-1,-2],[-2,-1]] }
      ]
    },
    {
      id: 'gryphon',
      family: 'others',
      name: 'Gryphon',
      original_name: 'Gryphon',
      aliases: ['Aanca', 'Eagle (Grant Acedrex)'],
      letter: 'GP',
      betza: 't[FR]',
      origin: 'Grant Acedrex (1283)',
      description: 'A bent slider: takes one diagonal step (Ferz), then continues as a Rook outwards — moving orthogonally away from its starting square. The pivot square is itself a valid stopping square. Originated in Grant Acedrex, the 13th-century Castilian variant.',
      description_codex: 't[FR] (1 F step, then R outward).',
      behaviors: ['long-range'],
      moves: [
        { kind: 'bent-rider', pivot: [1,  1],  dir: [0,  1] },
        { kind: 'bent-rider', pivot: [1,  1],  dir: [1,  0] },
        { kind: 'bent-rider', pivot: [-1, 1],  dir: [0,  1] },
        { kind: 'bent-rider', pivot: [-1, 1],  dir: [-1, 0] },
        { kind: 'bent-rider', pivot: [1, -1],  dir: [0, -1] },
        { kind: 'bent-rider', pivot: [1, -1],  dir: [1,  0] },
        { kind: 'bent-rider', pivot: [-1,-1],  dir: [0, -1] },
        { kind: 'bent-rider', pivot: [-1,-1],  dir: [-1, 0] }
      ]
    },
    {
      id: 'manticore',
      family: 'others',
      name: 'Manticore',
      original_name: 'Manticore',
      aliases: ['Anchorite', 'Acromantula', 'Rhinoceros', 'Spider', 'Unicorn'],
      letter: 'MN',
      betza: 't[WB]',
      origin: 'Modern variants (Betza, Gilman, Cazaux)',
      description: 'A bent slider: takes one orthogonal step (Wazir), then continues as a Bishop outwards. The orthogonal counterpart of the Gryphon. Pivot square is itself a valid stopping square.',
      description_codex: 't[WB] (1 W step, then B outward).',
      behaviors: ['long-range'],
      moves: [
        { kind: 'bent-rider', pivot: [0,  1],  dir: [1,  1] },
        { kind: 'bent-rider', pivot: [0,  1],  dir: [-1, 1] },
        { kind: 'bent-rider', pivot: [1,  0],  dir: [1,  1] },
        { kind: 'bent-rider', pivot: [1,  0],  dir: [1, -1] },
        { kind: 'bent-rider', pivot: [0, -1],  dir: [1, -1] },
        { kind: 'bent-rider', pivot: [0, -1],  dir: [-1,-1] },
        { kind: 'bent-rider', pivot: [-1, 0],  dir: [-1, 1] },
        { kind: 'bent-rider', pivot: [-1, 0],  dir: [-1,-1] }
      ]
    },
    {
      id: 'godzilla',
      family: 'others',
      name: 'Godzilla',
      original_name: 'Godzilla',
      aliases: [],
      letter: 'GZ',
      betza: 't[FR]t[WB]',
      origin: 'Modern variants',
      description: 'A double bent-rider that combines the Gryphon (Ferz + outward Rook) and the Manticore (Wazir + outward Bishop) into a single piece. Sixteen bent paths radiating from the centre — eight Gryphon-style (diagonal pivot, orthogonal slide) and eight Manticore-style (orthogonal pivot, diagonal slide).',
      description_codex: 't[FR] + t[WB] (two bent riders).',
      behaviors: ['compound', 'long-range'],
      moves: [
        { kind: 'bent-rider', pivot: [1,  1],  dir: [0,  1] },
        { kind: 'bent-rider', pivot: [1,  1],  dir: [1,  0] },
        { kind: 'bent-rider', pivot: [-1, 1],  dir: [0,  1] },
        { kind: 'bent-rider', pivot: [-1, 1],  dir: [-1, 0] },
        { kind: 'bent-rider', pivot: [1, -1],  dir: [0, -1] },
        { kind: 'bent-rider', pivot: [1, -1],  dir: [1,  0] },
        { kind: 'bent-rider', pivot: [-1,-1],  dir: [0, -1] },
        { kind: 'bent-rider', pivot: [-1,-1],  dir: [-1, 0] },
        { kind: 'bent-rider', pivot: [0,  1],  dir: [1,  1] },
        { kind: 'bent-rider', pivot: [0,  1],  dir: [-1, 1] },
        { kind: 'bent-rider', pivot: [1,  0],  dir: [1,  1] },
        { kind: 'bent-rider', pivot: [1,  0],  dir: [1, -1] },
        { kind: 'bent-rider', pivot: [0, -1],  dir: [1, -1] },
        { kind: 'bent-rider', pivot: [0, -1],  dir: [-1,-1] },
        { kind: 'bent-rider', pivot: [-1, 0],  dir: [-1, 1] },
        { kind: 'bent-rider', pivot: [-1, 0],  dir: [-1,-1] }
      ]
    },
    {
      id: 'banshee',
      family: 'compounds',
      name: 'Banshee',
      original_name: 'Banshee',
      aliases: [],
      letter: 'Bn',
      betza: 'BNN',
      origin: 'Problem chess',
      description: 'Combines Bishop and Nightrider — slides diagonally any distance AND makes any number of knight leaps in a straight line. The diagonal counterpart of the Raven (Rook + Nightrider).',
      description_codex: 'B + NN (diagonal slide + N rider).',
      behaviors: ['long-range', 'compound', 'leaper'],
      moves: [
        { kind: 'rays', dirs: [[1,1],[-1,1],[1,-1],[-1,-1]] },
        { kind: 'rider', step: [1,  2], dots: [[1,2], [2,4]] },
        { kind: 'rider', step: [2,  1], dots: [[2,1], [4,2]] },
        { kind: 'rider', step: [-1, 2], dots: [[-1,2],[-2,4]] },
        { kind: 'rider', step: [-2, 1], dots: [[-2,1],[-4,2]] },
        { kind: 'rider', step: [1, -2], dots: [[1,-2],[2,-4]] },
        { kind: 'rider', step: [2, -1], dots: [[2,-1],[4,-2]] },
        { kind: 'rider', step: [-1,-2], dots: [[-1,-2],[-2,-4]] },
        { kind: 'rider', step: [-2,-1], dots: [[-2,-1],[-4,-2]] }
      ]
    },
    {
      id: 'raven',
      family: 'compounds',
      name: 'Raven',
      original_name: 'Raven',
      aliases: ['Waran'],
      letter: 'Rv',
      betza: 'RNN',
      origin: 'Problem chess',
      description: 'Combines Rook slides with Nightrider chains — orthogonal sliding plus any number of knight leaps in a straight line. The rook counterpart of the Banshee (BNN).',
      description_codex: 'R + NN (orthogonal slide + N rider).',
      behaviors: ['compound', 'long-range', 'leaper'],
      moves: [
        { kind: 'rays', dirs: [[1,0],[-1,0],[0,1],[0,-1]] },
        { kind: 'rider', step: [1,  2], dots: [[1,2], [2,4]] },
        { kind: 'rider', step: [2,  1], dots: [[2,1], [4,2]] },
        { kind: 'rider', step: [-1, 2], dots: [[-1,2],[-2,4]] },
        { kind: 'rider', step: [-2, 1], dots: [[-2,1],[-4,2]] },
        { kind: 'rider', step: [1, -2], dots: [[1,-2],[2,-4]] },
        { kind: 'rider', step: [2, -1], dots: [[2,-1],[4,-2]] },
        { kind: 'rider', step: [-1,-2], dots: [[-1,-2],[-2,-4]] },
        { kind: 'rider', step: [-2,-1], dots: [[-2,-1],[-4,-2]] }
      ]
    },
    {
      id: 'amazonrider',
      family: 'compounds',
      name: 'Valkyrie',
      original_name: 'Amazonrider',
      aliases: [],
      letter: 'Am',
      betza: 'QNN',
      origin: 'Problem chess',
      description: 'Combines the Queen and Nightrider — slides any distance along all 8 queen lines AND any number of knight leaps in a straight line. One of the most powerful long-range fairy pieces.',
      description_codex: 'Q + NN.',
      behaviors: ['long-range', 'compound', 'leaper'],
      moves: [
        { kind: 'rays', dirs: [[1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,1],[1,-1],[-1,-1]] },
        { kind: 'rider', step: [1,  2], dots: [[1,2], [2,4]] },
        { kind: 'rider', step: [2,  1], dots: [[2,1], [4,2]] },
        { kind: 'rider', step: [-1, 2], dots: [[-1,2],[-2,4]] },
        { kind: 'rider', step: [-2, 1], dots: [[-2,1],[-4,2]] },
        { kind: 'rider', step: [1, -2], dots: [[1,-2],[2,-4]] },
        { kind: 'rider', step: [2, -1], dots: [[2,-1],[4,-2]] },
        { kind: 'rider', step: [-1,-2], dots: [[-1,-2],[-2,-4]] },
        { kind: 'rider', step: [-2,-1], dots: [[-2,-1],[-4,-2]] }
      ]
    }
  ];

if (typeof module !== "undefined" && module.exports) module.exports = PIECES_CODEX;
