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
      description_codex: 'Moves one square forward. Captures one square diagonally forward. May move two squares forward on its first move; may capture en passant. Promotes to Ranger.',
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
      letter: 'vP',
      betza: 'mfFcfWimfnA',
      origin: 'Modern',
      description: 'The Pawn’s mirror: moves one square diagonally forward (or two on its first move), captures one square straight forward. En passant and promotion apply as for the standard pawn.',
      description_codex: 'Moves one square diagonally forward. Captures one square straight forward. May move two squares diagonally forward on its first move.',
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
      letter: 'Rg',
      betza: 'mWcF',
      origin: 'Extended Pawn variant',
      description: 'Moves one square orthogonally in any of the four directions (move only) and captures one square diagonally in any of the four directions. Move-vs-capture asymmetry is its only pawn-like trait — it is fully symmetric in direction.',
      description_codex: 'Moves one square orthogonally. Captures one square diagonally. Promotes from Pawn to Archer.',
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
      letter: 'vRg',
      betza: 'mFcW',
      origin: 'Invented',
      description: 'Inversion of the Sergeant (mWcF): swap the move-direction set with the capture-direction set, then apply ortho ↔ diag rotation. Moves one diagonal step (Ferz, move-only) and captures one orthogonal step (Wazir, capture-only).',
      description_codex: 'Moves one square diagonally. Captures one square orthogonally.',
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
      letter: 'Ar',
      betza: 'mW2cF',
      origin: 'Arrow Pawn Chess (Persson, 1938)',
      description: 'Moves one or two squares orthogonally in any direction (move only), and captures one square diagonally in any direction. Unlike a standard pawn, it is not direction-restricted — only its move/capture asymmetry makes it pawn-like.',
      description_codex: 'Moves one or two squares orthogonally. Captures one square diagonally. Promotes from Ranger.',
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
      letter: 'vAr',
      betza: 'mF2cW',
      origin: 'Invented',
      description: 'Inversion of the Arrow Pawn (mW2cF). Moves one or two diagonal squares (move-only Bishop capped at 2) and captures one orthogonal step.',
      description_codex: 'Moves one or two squares diagonally. Captures one square orthogonally.',
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
      letter: 'Se',
      betza: 'F',
      origin: 'Shatranj',
      description: 'Steps one square diagonally. The historical Shatranj precursor to the modern Queen; colour-bound to its starting square colour.',
      description_codex: 'Steps one square diagonally. Promotes to Mystic. Fuses with Rook to form Hydra.',
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
      letter: 'My',
      betza: 'FA',
      origin: 'Modern variants',
      description: 'Combines Ferz (1,1) and Alfil (2,2) — leaps one or two squares diagonally. Eight reachable squares, all on diagonals. Heavily colour-bound. Used in modern variants as a stronger fairy "Elephant".',
      description_codex: 'Leaps one or two squares diagonally — eight reachable squares. Promotes from Seer to Shaman. Fuses with Knight to form Shaman.',
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
      name: 'Shaman',
      original_name: 'High Priestess',
      aliases: [],
      letter: 'Sh',
      betza: 'FAN',
      origin: 'Problem chess',
      description: 'Combines the Ferz (1,1), Alfil (2,2), and Knight (1,2) leaps — 16 reachable squares at short range. Not colour-bound, because the Knight component breaks the otherwise diagonal palette.',
      description_codex: 'Leaps one or two squares diagonally, or makes a two-by-one L-shaped jump. Promotes from Mystic. Formed by fusing Knight and Mystic. Fuses with several partners to form Archbishop, Consul, and Praetor.',
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
      letter: 'Mg',
      betza: 'W',
      origin: 'Shatranj',
      description: 'Steps one square orthogonally. A "short Rook" — the orthogonal counterpart of the Ferz.',
      description_codex: 'Steps one square orthogonally. Promotes to Sorcerer. Fuses with Archbishop to form Praetor, or with Bishop to form Kraken.',
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
      letter: 'So',
      betza: 'WD',
      origin: 'Problem chess',
      description: 'Combines Wazir (1,0) and Dabbaba (2,0) — leaps one or exactly two squares orthogonally. Eight reachable squares, all on ranks and files.',
      description_codex: 'Leaps one or two squares orthogonally — eight reachable squares. Promotes from Mage to Archmage. Fuses with Duchess to form Archmage.',
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
      letter: 'Am',
      betza: 'WAD',
      origin: 'Omega Chess',
      description: 'Combines Wazir (1,0), Alfil (2,2), and Dabbaba (2,0) — 12 reachable squares: a one-step orthogonal "ring" plus all eight squares of the second ring at corner and edge positions. One of the two new pieces in Omega Chess.',
      description_codex: 'Leaps one or two squares orthogonally, or two squares diagonally. Promotes from Sorcerer. Formed by fusing Duchess and Sorcerer.',
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
      description_codex: 'Slides any distance diagonally. Promotes to Cardinal. Fuses with several partners to form Archbishop, Queen, and Consul, among others.',
      behaviors: ['long-range', 'color-bound'],
      moves: [
        { kind: 'rays', dirs: [[1,1],[-1,1],[1,-1],[-1,-1]] }
      ]
    },
    {
      id: 'dragon-horse',
      family: 'compounds',
      name: 'Cardinal',
      original_name: 'Dragon Horse',
      aliases: ['Promoted Bishop', 'Ryūma'],
      letter: '馬',
      betza: 'BW',
      origin: 'Shōgi',
      description: 'A Bishop that also steps one square orthogonally. Created when a Shōgi Bishop is promoted. No longer colour-bound.',
      description_codex: 'Slides any distance diagonally; also steps one square orthogonally. Promotes from Bishop to Archbishop. Fuses with several partners to form Queen, Consul, and Praetor.',
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
      // 'Princess' and 'Cardinal' dropped: both are now live display names
      // (bodyguard and dragon-horse). The encyclopedia keeps them — it carries
      // the Wikipedia naming, where they remain genuine Archbishop aliases.
      aliases: ['Janus'],
      letter: 'Ab',
      betza: 'BN',
      origin: 'Modern',
      description: 'Bishop + Knight combined. Crucially colour-complete: King + Archbishop alone can force mate, unlike King + Bishop or King + Knight on their own.',
      description_codex: 'Slides any distance diagonally; also makes a two-by-one L-shaped jump. Promotes from Cardinal. Formed by fusing Bishop + Knight or Bishop + Shaman. Fuses with several partners to form Consul, Praetor, and Djinn.',
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
      description_codex: 'Slides any distance along ranks and files. Promotes to Drakehold. Fuses with several partners to form Drakehold, Dragonlord, and Queen, among others.',
      behaviors: ['long-range'],
      moves: [
        { kind: 'rays', dirs: [[1,0],[-1,0],[0,1],[0,-1]] }
      ]
    },
    {
      id: 'dragon-king',
      family: 'compounds',
      name: 'Drakehold',
      original_name: 'Dragon King',
      aliases: ['Promoted Rook', 'Ryūō'],
      letter: '龍',
      betza: 'RF',
      origin: 'Shōgi',
      description: 'A Rook that also steps one square diagonally. Created when a Shōgi Rook is promoted in the opponent’s last three ranks.',
      description_codex: 'Slides any distance orthogonally; also steps one square diagonally. Promotes from Rook to Dragonlord. Formed by fusing Rook and Long Ma. Fuses with several partners to form Queen and Consul.',
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
      letter: 'Dr',
      betza: 'RN',
      origin: 'Modern',
      description: 'Rook + Knight combined. Roughly equal in value to a Queen in most computer studies.',
      description_codex: 'Slides any distance orthogonally; also makes a two-by-one L-shaped jump. Promotes from Drakehold. Formed by fusing Knight and Rook. Fuses with several partners to form Consul and Lich.',
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
      description_codex: 'Makes a two-by-one L-shaped jump — two squares in one direction and one perpendicular. Promotes to Pegasus. Fuses with several partners to form Shaman, Faerie, and Archbishop, among others.',
      behaviors: ['leaper'],
      moves: [
        { kind: 'dots', squares: [[1,2],[2,1],[-1,2],[-2,1],[1,-2],[2,-1],[-1,-2],[-2,-1]] }
      ]
    },
    {
      id: 'gnu',
      family: 'leapers',
      name: 'Pegasus',
      original_name: 'Gnu',
      aliases: ['Unicorn'],
      letter: 'Pg',
      betza: 'NC',
      origin: 'Problem chess',
      description: 'Combines the Knight (1,2) and Camel (1,3) leaps — 16 reachable squares, all at short range.',
      description_codex: 'Makes a two-by-one or three-by-one L-shaped jump. Promotes from Knight to Hippogriff.',
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
      name: 'Hippogriff',
      original_name: 'Buffalo',
      aliases: [],
      letter: 'Hp',
      betza: 'CZN',
      origin: 'Problem chess',
      description: 'Camel + Zebra + Knight fused — 24 reachable squares. The largest of the standard short-range leaper compounds.',
      description_codex: 'Makes a two-by-one, three-by-one, or three-by-two L-shaped jump. Promotes from Pegasus.',
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
      name: 'Long Ma',
      original_name: 'Kirin',
      aliases: [],
      letter: 'Lm',
      betza: 'FD',
      origin: 'Chu Shōgi',
      description: 'Combines Ferz (1,1) and Dabbaba (2,0) — four diagonal one-step plus four orthogonal two-square leaps. Colour-bound, since both components preserve square colour. Appears in Chu Shōgi.',
      description_codex: 'Steps one square diagonally, or leaps two squares orthogonally. Promotes to Qi Lin. Fuses with Rook to form Drakehold.',
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
      name: 'Qi Lin',
      original_name: 'Kirin+',
      aliases: [],
      letter: 'Ql',
      betza: 'FDC',
      origin: 'Invented',
      description: 'Promoted form of the Long Ma. Adds the Camel (1,3) L-leap to the Long Ma\'s Ferz and Dabbaba moves — sixteen reachable squares. Stays fully colour-bound: every component has an even dx+dy (1+1, 2+0, 1+3), so the piece never changes square colour.',
      description_codex: 'Steps one square diagonally, leaps two squares orthogonally, or makes a three-by-one L-shaped jump. Promotes from Long Ma to Ying Long.',
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
      name: 'Void Qi Lin',
      original_name: 'Inv Kirin+',
      aliases: [],
      letter: 'vQl',
      betza: 'WNH',
      origin: 'Invented',
      description: 'Inversion of Kirin+ (FDC). Strictly colour-changing — every destination has the opposite square colour from the start. Combines Wazir (1,0) at the closest ring, Knight (1,2) inside, and Threeleaper (3,0) as the four diamond-point cardinal leaps.',
      description_codex: 'Steps one square orthogonally, makes a two-by-one L-shaped jump, or leaps three squares orthogonally.',
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
      name: 'Ying Long',
      original_name: 'Kirin++',
      aliases: [],
      letter: 'Yl',
      betza: 'FADCG + 4L',
      origin: 'Invented',
      description: 'Final form of the Long Ma promotion chain. Twenty-eight leap targets: Ferz (1,1), Alfil (2,2), Dabbaba (2,0), Camel (1,3), Tripper (3,3), and Fourleaper (4,0). Every component is colour-bound.',
      description_codex: 'Reaches 28 colour-bound squares — leaping one or two squares diagonally, two squares orthogonally, a three-by-one or three-by-three jump, or four squares orthogonally. Promotes from Qi Lin.',
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
      name: 'Void Ying Long',
      original_name: 'Inv Kirin++',
      aliases: [],
      letter: 'vYl',
      betza: 'WNH + Giraffe + Zebra',
      origin: 'Invented',
      description: 'Extends Inv Kirin+ outward with two more colour-changing rings: Giraffe (1,4) near the outer cardinal extremes, and Zebra (2,3) filling the gaps between H and Giraffe. All 32 leap targets are strictly colour-changing.',
      description_codex: 'Reaches 32 colour-switching squares — leaping one square orthogonally, a two-by-one or two-by-three jump, three squares orthogonally, or a four-by-one jump.',
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
      name: 'Duchess',
      original_name: 'Alibaba',
      aliases: [],
      letter: 'Du',
      betza: 'AD',
      origin: 'Problem chess',
      description: 'Combines the Alfil (2,2) and Dabbaba (2,0) leaps into a single piece — eight reachable squares forming the "second ring" along ranks, files, and diagonals. The single-leap counterpart of the Alibabarider. Heavily colour-bound, since both components preserve square colour.',
      description_codex: 'Leaps two squares diagonally, or two squares orthogonally. Promotes to Princess. Fuses with Sorcerer to form Archmage, or with Knight to form Faerie.',
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
      name: 'Princess',
      original_name: 'Bodyguard',
      aliases: ['Hia'],
      letter: 'Pr',
      betza: 'Q2',
      origin: 'Hiashatar (Mongolian decimal chess)',
      description: 'Slides like a Queen but only one or two squares in any of the eight directions. Has a defensive aura in Hiashatar: any opposing sliding piece must stop the moment it moves within a King\'s-move radius of the Bodyguard, so it cannot pass by without being challenged.',
      description_codex: 'Moves one or two squares in any of the eight directions. Promotes from Duchess to Queen.',
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
      description_codex: 'Slides any distance in any of the eight directions. Promotes from Princess. Formed by several fusions, including Bishop + Rook and Bishop + Drakehold. Fuses with several partners to form Consul.',
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
      letter: 'Fa',
      betza: 'NAD',
      origin: 'Problem chess',
      description: 'Combines Knight (1,2), Alfil (2,2), and Dabbaba (2,0) leaps. Reaches every square exactly two squares away from the piece (the full "second ring" at Chebyshev distance 2) — 16 squares in total: eight knight-leap targets, four diagonal corners, and four orthogonal edge-midpoints.',
      description_codex: 'Jumps two squares orthogonally, two squares diagonally, or makes a two-by-one L-shaped jump. Formed by fusing Knight and Duchess.',
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
      name: 'Praetor',
      original_name: 'Crown Princess',
      aliases: ['Popess'],
      letter: 'Pt',
      betza: 'BNW',
      origin: 'Modern variants',
      description: 'Archbishop + Wazir — combines Bishop slides, Knight leaps, and one-step orthogonal moves. A short-step extension of the Archbishop, similar in spirit to Dragon Horse but with the Knight added.',
      description_codex: 'Slides any distance diagonally, steps one square orthogonally, or makes a two-by-one L-shaped jump. Formed by several fusions, including Knight + Cardinal and Mage + Archbishop.',
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
      name: 'Consul',
      original_name: 'Amazon',
      aliases: ['Angel', 'Commander', 'Wyvern'],
      letter: 'Co',
      betza: 'QN',
      origin: 'Modern',
      description: 'Queen + Knight combined — slides along all 8 lines and also leaps in an L. The strongest single fairy piece in common use.',
      description_codex: 'Slides any distance in any of the eight directions; also makes a two-by-one L-shaped jump. Formed by several fusions, including Bishop + Dragonlord and Knight + Queen. Fuses with Knight to form Valkyrie.',
      behaviors: ['compound', 'long-range', 'leaper'],
      moves: [
        { kind: 'rays', dirs: [[1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,1],[1,-1],[-1,-1]] },
        { kind: 'dots', squares: [[1,2],[2,1],[-1,2],[-2,1],[1,-2],[2,-1],[-1,-2],[-2,-1]] }
      ]
    },
    {
      id: 'gryphon',
      family: 'others',
      name: 'Hydra',
      original_name: 'Gryphon',
      aliases: ['Aanca', 'Eagle (Grant Acedrex)'],
      letter: 'Hy',
      betza: 't[FR]',
      origin: 'Grant Acedrex (1283)',
      description: 'A bent slider: takes one diagonal step (Ferz), then continues as a Rook outwards — moving orthogonally away from its starting square. The pivot square is itself a valid stopping square. Originated in Grant Acedrex, the 13th-century Castilian variant.',
      description_codex: 'Steps one square diagonally, then continues sliding outward orthogonally for any distance. Formed by fusing Seer and Rook. Fuses with Kraken to form Leviathan.',
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
      name: 'Kraken',
      original_name: 'Manticore',
      aliases: ['Anchorite', 'Acromantula', 'Rhinoceros', 'Spider', 'Unicorn'],
      letter: 'Kr',
      betza: 't[WB]',
      origin: 'Modern variants (Betza, Gilman, Cazaux)',
      description: 'A bent slider: takes one orthogonal step (Wazir), then continues as a Bishop outwards. The orthogonal counterpart of the Hydra. Pivot square is itself a valid stopping square.',
      description_codex: 'Steps one square orthogonally, then continues sliding outward diagonally for any distance. Formed by fusing Mage and Bishop. Fuses with Hydra to form Leviathan.',
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
      name: 'Leviathan',
      original_name: 'Godzilla',
      aliases: [],
      letter: 'Lv',
      betza: 't[FR]t[WB]',
      origin: 'Modern variants',
      description: 'A double bent-rider that combines the Hydra (Ferz + outward Rook) and the Kraken (Wazir + outward Bishop) into a single piece. Sixteen bent paths radiating from the centre — eight Hydra-style (diagonal pivot, orthogonal slide) and eight Kraken-style (orthogonal pivot, diagonal slide).',
      description_codex: 'Either steps one square diagonally and continues orthogonally outward, or steps one square orthogonally and continues diagonally outward. Formed by fusing Kraken and Hydra.',
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
      name: 'Djinn',
      original_name: 'Banshee',
      aliases: [],
      letter: 'Dj',
      betza: 'BNN',
      origin: 'Problem chess',
      description: 'Combines Bishop and Nightrider — slides diagonally any distance AND makes any number of knight leaps in a straight line. The diagonal counterpart of the Lich (Rook + Nightrider).',
      description_codex: 'Slides any distance diagonally, or rides any number of two-by-one L-shaped jumps in a single line. Formed by fusing Archbishop and Knight.',
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
      name: 'Lich',
      original_name: 'Raven',
      aliases: ['Waran'],
      letter: 'Li',
      betza: 'RNN',
      origin: 'Problem chess',
      description: 'Combines Rook slides with Nightrider chains — orthogonal sliding plus any number of knight leaps in a straight line. The rook counterpart of the Djinn (BNN).',
      description_codex: 'Slides any distance orthogonally, or rides any number of two-by-one L-shaped jumps in a single line. Formed by fusing Dragonlord and Knight.',
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
      letter: 'Vk',
      betza: 'QNN',
      origin: 'Problem chess',
      description: 'Combines the Queen and Nightrider — slides any distance along all 8 queen lines AND any number of knight leaps in a straight line. One of the most powerful long-range fairy pieces.',
      description_codex: 'Slides any distance in any of the eight directions, or rides any number of two-by-one L-shaped jumps in a single line. Formed by fusing Consul and Knight.',
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
