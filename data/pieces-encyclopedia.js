/* ============================================================
 *  pieces-encyclopedia.js
 *  Canonical 100-piece fairy-chess dataset (Wikipedia names).
 *  Loaded by encyclopedia/index.html as window.PIECES_ENCYCLOPEDIA.
 * ============================================================ */
var PIECES_ENCYCLOPEDIA = [
    {
      id: 'king',
      family: 'leapers',
      name: 'King',
      aliases: [],
      glyph: '♚',
      betza: 'K',
      origin: 'Standard',
      description: 'Moves one square in any of 8 directions. The royal piece — losing it ends the game. Castling allows a special two-square move with a friendly rook.',
      behaviors: ['royal'],
      moves: [
        { kind: 'dots', squares: [[1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,1],[1,-1],[-1,-1]] }
      ]
    },
    {
      id: 'queen',
      family: 'sliders',
      name: 'Queen',
      aliases: [],
      glyph: '♛',
      betza: 'Q',
      origin: 'Standard',
      description: 'Slides any number of squares along ranks, files, or diagonals. The most powerful standard piece — Rook + Bishop combined.',
      behaviors: ['long-range', 'compound'],
      moves: [
        { kind: 'rays', dirs: [[1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,1],[1,-1],[-1,-1]] }
      ]
    },
    {
      id: 'rook',
      family: 'sliders',
      name: 'Rook',
      aliases: ['Castle'],
      glyph: '♜',
      betza: 'R',
      origin: 'Standard',
      description: 'Slides any number of squares along ranks or files. Participates with the King in castling.',
      behaviors: ['long-range'],
      moves: [
        { kind: 'rays', dirs: [[1,0],[-1,0],[0,1],[0,-1]] }
      ]
    },
    {
      id: 'bishop',
      family: 'sliders',
      name: 'Bishop',
      aliases: [],
      glyph: '♝',
      betza: 'B',
      origin: 'Standard',
      description: 'Slides any number of squares diagonally. Each bishop is locked to one square colour for the entire game — a King + 2 same-colour Bishops cannot deliver mate.',
      behaviors: ['long-range', 'color-bound'],
      moves: [
        { kind: 'rays', dirs: [[1,1],[-1,1],[1,-1],[-1,-1]] }
      ]
    },
    {
      id: 'knight',
      family: 'leapers',
      name: 'Knight',
      aliases: ['Horse'],
      glyph: '♞',
      betza: 'N',
      origin: 'Standard',
      description: 'Leaps in an L: two squares in one direction, then one perpendicular. The only standard piece that ignores intervening pieces.',
      behaviors: ['leaper'],
      moves: [
        { kind: 'dots', squares: [[1,2],[2,1],[-1,2],[-2,1],[1,-2],[2,-1],[-1,-2],[-2,-1]] }
      ]
    },
    {
      id: 'pawn',
      family: 'pawn-like',
      name: 'Pawn',
      aliases: [],
      glyph: '♟',
      betza: 'mfWcfFimfnD',
      origin: 'Standard',
      description: 'Moves one square forward (no capture). Captures one square diagonally forward. May move two squares forward on its first move, and can capture en passant. Promotes upon reaching the last rank.',
      behaviors: ['direction-restricted', 'promotes', 'capture-different'],
      moves: [
        { kind: 'rings', squares: [[0,1],[0,2]] },
        { kind: 'xs',    squares: [[1,1],[-1,1]] }
      ]
    },
    {
      id: 'amazon',
      family: 'compounds',
      name: 'Amazon',
      aliases: ['Angel', 'Commander', 'Wyvern'],
      letter: 'A',
      betza: 'QN',
      origin: 'Modern',
      description: 'Queen + Knight combined — slides along all 8 lines and also leaps in an L. The strongest single fairy piece in common use.',
      behaviors: ['compound', 'long-range', 'leaper'],
      moves: [
        { kind: 'rays', dirs: [[1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,1],[1,-1],[-1,-1]] },
        { kind: 'dots', squares: [[1,2],[2,1],[-1,2],[-2,1],[1,-2],[2,-1],[-1,-2],[-2,-1]] }
      ]
    },
    {
      id: 'archbishop',
      family: 'compounds',
      name: 'Archbishop',
      aliases: ['Princess', 'Cardinal', 'Janus'],
      letter: 'AR',
      betza: 'BN',
      origin: 'Modern',
      description: 'Bishop + Knight combined. Crucially colour-complete: King + Archbishop alone can force mate, unlike King + Bishop or King + Knight on their own.',
      behaviors: ['compound', 'long-range', 'leaper'],
      moves: [
        { kind: 'rays', dirs: [[1,1],[-1,1],[1,-1],[-1,-1]] },
        { kind: 'dots', squares: [[1,2],[2,1],[-1,2],[-2,1],[1,-2],[2,-1],[-1,-2],[-2,-1]] }
      ]
    },
    {
      id: 'chancellor',
      family: 'compounds',
      name: 'Chancellor',
      aliases: ['Marshall', 'Marshal', 'Empress', 'Concubine'],
      letter: 'CH',
      betza: 'RN',
      origin: 'Modern',
      description: 'Rook + Knight combined. Roughly equal in value to a Queen in most computer studies.',
      behaviors: ['compound', 'long-range', 'leaper'],
      moves: [
        { kind: 'rays', dirs: [[1,0],[-1,0],[0,1],[0,-1]] },
        { kind: 'dots', squares: [[1,2],[2,1],[-1,2],[-2,1],[1,-2],[2,-1],[-1,-2],[-2,-1]] }
      ]
    },
    {
      id: 'wazir',
      family: 'leapers',
      name: 'Wazir',
      aliases: ['Vizir', 'Wezir'],
      letter: 'W',
      betza: 'W',
      origin: 'Shatranj',
      description: 'Steps one square orthogonally. A "short Rook" — the orthogonal counterpart of the Ferz.',
      behaviors: ['leaper'],
      moves: [
        { kind: 'dots', squares: [[1,0],[-1,0],[0,1],[0,-1]] }
      ]
    },
    {
      id: 'ferz',
      family: 'leapers',
      name: 'Ferz',
      aliases: ['Fers', 'Counsellor', 'Mantri'],
      letter: 'F',
      betza: 'F',
      origin: 'Shatranj',
      description: 'Steps one square diagonally. The historical Shatranj precursor to the modern Queen; colour-bound to its starting square colour.',
      behaviors: ['leaper', 'color-bound'],
      moves: [
        { kind: 'dots', squares: [[1,1],[-1,1],[1,-1],[-1,-1]] }
      ]
    },
    {
      id: 'alfil',
      family: 'leapers',
      name: 'Alfil',
      aliases: ['Elephant', 'Pil', 'Gaja'],
      letter: 'AL',
      betza: 'A',
      origin: 'Shatranj',
      description: 'Leaps exactly two squares diagonally, jumping over any intervening piece. Reaches only 8 of 64 squares on a standard board — heavily colour-bound.',
      behaviors: ['leaper', 'color-bound'],
      moves: [
        { kind: 'dots', squares: [[2,2],[-2,2],[2,-2],[-2,-2]] }
      ]
    },
    {
      id: 'dabbaba',
      family: 'leapers',
      name: 'Dabbaba',
      aliases: ['Dabbabah', 'War Engine'],
      letter: 'D',
      betza: 'D',
      origin: 'Shatranj',
      description: 'Leaps exactly two squares orthogonally, jumping over any intervening piece. Also reaches only one quarter of the board.',
      behaviors: ['leaper', 'color-bound'],
      moves: [
        { kind: 'dots', squares: [[2,0],[-2,0],[0,2],[0,-2]] }
      ]
    },
    {
      id: 'camel',
      family: 'leapers',
      name: 'Camel',
      aliases: [],
      letter: 'C',
      betza: 'C',
      origin: 'Tamerlane chess',
      description: 'A long knight: leaps (1,3) — one square in one direction, three perpendicular. Colour-bound, unlike the standard Knight.',
      behaviors: ['leaper', 'color-bound'],
      moves: [
        { kind: 'dots', squares: [[1,3],[3,1],[-1,3],[-3,1],[1,-3],[3,-1],[-1,-3],[-3,-1]] }
      ]
    },
    {
      id: 'zebra',
      family: 'leapers',
      name: 'Zebra',
      aliases: [],
      letter: 'Z',
      betza: 'Z',
      origin: 'Problem chess',
      description: 'Leaps (2,3). Not colour-bound — alternates square colours on each move, like the Knight.',
      behaviors: ['leaper'],
      moves: [
        { kind: 'dots', squares: [[2,3],[3,2],[-2,3],[-3,2],[2,-3],[3,-2],[-2,-3],[-3,-2]] }
      ]
    },
    {
      id: 'nightrider',
      family: 'leap-riders',
      name: 'Nightrider',
      aliases: ['Knightrider'],
      letter: 'NN',
      betza: 'NN',
      origin: 'Problem chess',
      description: 'Makes any number of Knight leaps in a single straight line. Blocked if any square along the line is occupied. Invented by T. R. Dawson in 1925 — the archetypal fairy "rider".',
      behaviors: ['long-range', 'leaper'],
      moves: [
        { kind: 'rider', step: [1, 2],  dots: [[1,2], [2,4]] },
        { kind: 'rider', step: [2, 1],  dots: [[2,1], [4,2]] },
        { kind: 'rider', step: [-1, 2], dots: [[-1,2],[-2,4]] },
        { kind: 'rider', step: [-2, 1], dots: [[-2,1],[-4,2]] },
        { kind: 'rider', step: [1, -2], dots: [[1,-2],[2,-4]] },
        { kind: 'rider', step: [2, -1], dots: [[2,-1],[4,-2]] },
        { kind: 'rider', step: [-1,-2], dots: [[-1,-2],[-2,-4]] },
        { kind: 'rider', step: [-2,-1], dots: [[-2,-1],[-4,-2]] }
      ]
    },
    {
      id: 'grasshopper',
      family: 'hoppers',
      name: 'Grasshopper',
      aliases: [],
      letter: 'G',
      betza: 'gQ',
      origin: 'Problem chess',
      description: 'Moves along Queen lines, but must jump over exactly one piece (the "hurdle") and land on the square immediately beyond. Cannot move at all without a hurdle. Invented by T. R. Dawson in 1913.',
      behaviors: ['hopper', 'long-range'],
      moves: [
        { kind: 'hop', hurdle: [0,2],   target: [0,3]  },
        { kind: 'hop', hurdle: [3,0],   target: [4,0]  },
        { kind: 'hop', hurdle: [-2,-2], target: [-3,-3] }
      ]
    },
    {
      id: 'equihopper',
      family: 'hoppers',
      name: 'Equihopper',
      aliases: [],
      letter: 'EQ',
      betza: '',
      origin: 'Problem chess',
      description: 'Jumps over a single piece to land an equal distance beyond — the hurdle must sit at the exact midpoint of the leap. Travels in any straight line. Invented by M. Niemeijer in 1928.',
      behaviors: ['hopper'],
      moves: [
        { kind: 'hop', hurdle: [1,1],  target: [2,2]  },
        { kind: 'hop', hurdle: [2,0],  target: [4,0]  },
        { kind: 'hop', hurdle: [-1,2], target: [-2,4] }
      ]
    },
    {
      id: 'locust',
      family: 'hoppers',
      name: 'Locust',
      aliases: [],
      letter: 'L',
      betza: '',
      origin: 'Problem chess',
      description: 'Captures by leaping over an adjacent enemy and landing on the square immediately beyond — the captured piece is the hurdle. Cannot move at all without a capture. Travels along Queen lines.',
      behaviors: ['hopper', 'capture-only'],
      moves: [
        { kind: 'capture-hop', hurdle: [0,1],  target: [0,2]  },
        { kind: 'capture-hop', hurdle: [1,1],  target: [2,2]  },
        { kind: 'capture-hop', hurdle: [-1,0], target: [-2,0] }
      ]
    },
    {
      id: 'mann',
      family: 'leapers',
      name: 'Mann',
      aliases: ['Commoner', 'Centurion'],
      letter: 'M',
      betza: 'K',
      origin: 'Courier chess',
      description: 'Moves like a King (one square in any direction) but is not royal — it can be captured without ending the game.',
      behaviors: ['leaper'],
      moves: [
        { kind: 'dots', squares: [[1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,1],[1,-1],[-1,-1]] }
      ]
    },
    {
      id: 'berolina',
      family: 'pawn-like',
      name: 'Berolina Pawn',
      aliases: ['Berlin Pawn'],
      letter: 'BP',
      betza: 'mfFcfWimfnA',
      origin: 'Modern',
      description: 'The Pawn’s mirror: moves one square diagonally forward (or two on its first move), captures one square straight forward. En passant and promotion apply as for the standard pawn.',
      behaviors: ['direction-restricted', 'promotes', 'capture-different'],
      moves: [
        { kind: 'rings', squares: [[1,1],[-1,1],[2,2],[-2,2]] },
        { kind: 'xs',    squares: [[0,1]] }
      ]
    },
    {
      id: 'dragon-king',
      family: 'compounds',
      name: 'Dragon King',
      aliases: ['Promoted Rook', 'Ryūō'],
      letter: '龍',
      betza: 'RF',
      origin: 'Shōgi',
      description: 'A Rook that also steps one square diagonally. Created when a Shōgi Rook is promoted in the opponent’s last three ranks.',
      behaviors: ['compound', 'long-range'],
      moves: [
        { kind: 'rays', dirs: [[1,0],[-1,0],[0,1],[0,-1]] },
        { kind: 'dots', squares: [[1,1],[-1,1],[1,-1],[-1,-1]] }
      ]
    },
    {
      id: 'dragon-horse',
      family: 'compounds',
      name: 'Dragon Horse',
      aliases: ['Promoted Bishop', 'Ryūma'],
      letter: '馬',
      betza: 'BW',
      origin: 'Shōgi',
      description: 'A Bishop that also steps one square orthogonally. Created when a Shōgi Bishop is promoted. No longer colour-bound.',
      behaviors: ['compound', 'long-range'],
      moves: [
        { kind: 'rays', dirs: [[1,1],[-1,1],[1,-1],[-1,-1]] },
        { kind: 'dots', squares: [[1,0],[-1,0],[0,1],[0,-1]] }
      ]
    },
    {
      id: 'gold-general',
      family: 'leapers',
      name: 'Gold General',
      aliases: ['Kinshō', 'Gold'],
      letter: '金',
      betza: 'WfF',
      origin: 'Shōgi',
      description: 'Steps one square in six directions — all 4 orthogonals plus the two forward diagonals. Cannot step diagonally backward. The promoted form of Silver, Knight, Lance and Pawn all also move this way.',
      behaviors: ['leaper', 'direction-restricted'],
      moves: [
        { kind: 'dots', squares: [[1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,1]] }
      ]
    },
    {
      id: 'cannon',
      family: 'hoppers',
      name: 'Cannon',
      aliases: ['Pao', 'Pào'],
      letter: '炮',
      betza: 'mRcpR',
      origin: 'Xiangqi',
      description: 'Moves like a Rook (any number along rank or file) without capturing. To capture, it must jump over exactly one intervening piece (the "screen") of either colour and take the first piece beyond it.',
      behaviors: ['long-range', 'hopper', 'capture-different'],
      moves: [
        { kind: 'rays',        dirs: [[1,0],[-1,0],[0,1],[0,-1]] },
        { kind: 'capture-hop', hurdle: [3,0], target: [4,0] }
      ]
    },
    {
      id: 'giraffe',
      family: 'leapers',
      name: 'Giraffe',
      aliases: ['Zarafa'],
      letter: 'GR',
      betza: '(1,4)',
      origin: 'Tamerlane chess',
      description: 'A long L-leaper: jumps one square in one direction and four perpendicular. Used in Tamerlane chess. Eight reachable squares, colour-alternating like the Knight.',
      behaviors: ['leaper'],
      moves: [
        { kind: 'dots', squares: [[1,4],[4,1],[-1,4],[-4,1],[1,-4],[4,-1],[-1,-4],[-4,-1]] }
      ]
    },
    {
      id: 'threeleaper',
      family: 'leapers',
      name: 'Threeleaper',
      aliases: [],
      letter: 'TL',
      betza: 'H',
      origin: 'Problem chess',
      description: 'Leaps exactly three squares orthogonally, ignoring intervening pieces. Reaches only four squares from any given starting point.',
      behaviors: ['leaper'],
      moves: [
        { kind: 'dots', squares: [[3,0],[-3,0],[0,3],[0,-3]] }
      ]
    },
    {
      id: 'antelope',
      family: 'leapers',
      name: 'Antelope',
      aliases: [],
      letter: 'AN',
      betza: '(3,4)',
      origin: 'Problem chess',
      description: 'Leaps (3,4) — three squares in one direction and four perpendicular. Eight reachable squares, colour-alternating.',
      behaviors: ['leaper'],
      moves: [
        { kind: 'dots', squares: [[3,4],[4,3],[-3,4],[-4,3],[3,-4],[4,-3],[-3,-4],[-4,-3]] }
      ]
    },
    {
      id: 'silver-general',
      family: 'leapers',
      name: 'Silver General',
      aliases: ['Ginshō', 'Silver'],
      letter: '銀',
      betza: 'FfW',
      origin: 'Shōgi',
      description: 'Steps one square in five directions: straight forward plus all four diagonals. Cannot move sideways or straight backward. Promotes to a Gold General.',
      behaviors: ['leaper', 'direction-restricted', 'promotes'],
      moves: [
        { kind: 'dots', squares: [[0,1],[1,1],[-1,1],[1,-1],[-1,-1]] }
      ]
    },
    {
      id: 'mao',
      family: 'leapers',
      name: 'Mao',
      aliases: ['Xiangqi Horse'],
      letter: '馬',
      betza: '',
      origin: 'Xiangqi',
      description: 'The Xiangqi horse: reaches the same eight squares as a Knight, but each leap can be blocked by a piece sitting on the first orthogonal step toward the destination. Unlike the Western Knight, the Mao does not truly jump.',
      behaviors: ['leaper', 'direction-restricted'],
      moves: [
        { kind: 'dots', squares: [[1,2],[2,1],[-1,2],[-2,1],[1,-2],[2,-1],[-1,-2],[-2,-1]] }
      ]
    },
    {
      id: 'camelrider',
      family: 'leap-riders',
      name: 'Camelrider',
      aliases: [],
      letter: 'CR',
      betza: 'CC',
      origin: 'Problem chess',
      description: 'Makes any number of Camel (1,3) leaps in a single straight line. Like the Nightrider but using Camel steps. Colour-bound, because each individual Camel leap preserves colour.',
      behaviors: ['long-range', 'leaper', 'color-bound'],
      moves: [
        { kind: 'rider', step: [1,  3],  dots: [[1,3]] },
        { kind: 'rider', step: [3,  1],  dots: [[3,1]] },
        { kind: 'rider', step: [-1, 3],  dots: [[-1,3]] },
        { kind: 'rider', step: [-3, 1],  dots: [[-3,1]] },
        { kind: 'rider', step: [1, -3],  dots: [[1,-3]] },
        { kind: 'rider', step: [3, -1],  dots: [[3,-1]] },
        { kind: 'rider', step: [-1,-3],  dots: [[-1,-3]] },
        { kind: 'rider', step: [-3,-1],  dots: [[-3,-1]] }
      ]
    },
    {
      id: 'lance',
      family: 'sliders',
      name: 'Lance',
      aliases: ['Kyōsha', 'Spear'],
      letter: '香',
      betza: 'fR',
      origin: 'Shōgi',
      description: 'Slides forward any number of squares — a forward-only Rook. Cannot move sideways or backward. Promotes to a Gold General on reaching the opponent’s last three ranks.',
      behaviors: ['long-range', 'direction-restricted', 'promotes'],
      moves: [
        { kind: 'rays', dirs: [[0, 1]] }
      ]
    },
    {
      id: 'reflecting-bishop',
      family: 'sliders',
      name: 'Reflecting Bishop',
      aliases: ['Reflector Bishop'],
      letter: 'RB',
      betza: '',
      origin: 'Problem chess',
      description: 'Slides diagonally like a Bishop, but its ray reflects off the edges of the board and continues — turning 90° at each reflection. Every individual step is still diagonal and reflection preserves square-colour parity, so the Reflecting Bishop remains colour-bound like the standard Bishop. The diagram places the piece off-centre at (-2, 0) and traces each of its four diagonal rays six squares forward so the bounces off the board edges are visible.',
      behaviors: ['long-range', 'color-bound'],
      piece_at: [-2, 0],
      moves: [
        { kind: 'reflecting-ray', from: [-2, 0], dir: [ 1,  1], maxSteps: 6 },
        { kind: 'reflecting-ray', from: [-2, 0], dir: [-1,  1], maxSteps: 6 },
        { kind: 'reflecting-ray', from: [-2, 0], dir: [ 1, -1], maxSteps: 6 },
        { kind: 'reflecting-ray', from: [-2, 0], dir: [-1, -1], maxSteps: 6 }
      ]
    },
    {
      id: 'lion',
      family: 'hoppers',
      name: 'Lion',
      aliases: [],
      letter: 'LN',
      betza: '',
      origin: 'Problem chess',
      description: 'A Grasshopper-class hopper that jumps along Queen lines over a single hurdle, but lands on ANY empty square past the hurdle — not just the immediate one. (Distinct from the larger Shōgi/Chu Shōgi Lion, which is a different piece.)',
      behaviors: ['hopper', 'long-range'],
      moves: [
        { kind: 'hop', hurdle: [0,1], target: [0,2] },
        { kind: 'hop', hurdle: [0,1], target: [0,3] },
        { kind: 'hop', hurdle: [0,1], target: [0,4] },
        { kind: 'hop', hurdle: [1,1], target: [2,2] },
        { kind: 'hop', hurdle: [1,1], target: [3,3] },
        { kind: 'hop', hurdle: [1,1], target: [4,4] }
      ]
    },
    {
      id: 'centaur',
      family: 'leapers',
      name: 'Centaur',
      aliases: ['Knight-King'],
      letter: 'CN',
      betza: 'KN',
      origin: 'Modern',
      description: 'Combines the King’s one-square moves in all 8 directions with the Knight’s L-leap. 16 reachable squares. Appears as a non-royal piece in modern variants like Seirawan chess.',
      behaviors: ['compound', 'leaper'],
      moves: [
        { kind: 'dots', squares: [
          [1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,1],[1,-1],[-1,-1],
          [1,2],[2,1],[-1,2],[-2,1],[1,-2],[2,-1],[-1,-2],[-2,-1]
        ] }
      ]
    },
    {
      id: 'bison',
      family: 'leapers',
      name: 'Bison',
      aliases: [],
      letter: 'BS',
      betza: 'CZ',
      origin: 'Problem chess',
      description: 'Camel (1,3) + Zebra (2,3) fused into a single piece. 16 reachable squares forming two long-range L-octets.',
      behaviors: ['compound', 'leaper'],
      moves: [
        { kind: 'dots', squares: [
          [1,3],[3,1],[-1,3],[-3,1],[1,-3],[3,-1],[-1,-3],[-3,-1],
          [2,3],[3,2],[-2,3],[-3,2],[2,-3],[3,-2],[-2,-3],[-3,-2]
        ] }
      ]
    },
    {
      id: 'buffalo',
      family: 'leapers',
      name: 'Buffalo',
      aliases: [],
      letter: 'BF',
      betza: 'CZN',
      origin: 'Problem chess',
      description: 'Camel + Zebra + Knight fused — 24 reachable squares. The largest of the standard short-range leaper compounds.',
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
      id: 'kangaroo',
      family: 'leapers',
      name: 'Kangaroo',
      aliases: ['Hospitaller', 'Priestess'],
      letter: 'KG',
      betza: 'NA',
      origin: 'Modern',
      description: 'Knight + Alfil — combines the standard Knight’s L-leap with the (2,2) Alfil leap. 12 reachable squares, all at short range.',
      behaviors: ['compound', 'leaper'],
      moves: [
        { kind: 'dots', squares: [
          [1,2],[2,1],[-1,2],[-2,1],[1,-2],[2,-1],[-1,-2],[-2,-1],
          [2,2],[-2,2],[2,-2],[-2,-2]
        ] }
      ]
    },
    {
      id: 'eagle',
      family: 'compounds',
      name: 'Eagle',
      aliases: [],
      letter: 'EG',
      betza: 'fBbRWbB2',
      origin: 'Tori Shōgi',
      description: 'A direction-asymmetric Tori Shōgi compound: slides diagonally forward (forward Bishop), straight backward any distance (backward Rook), steps one square in all four orthogonal directions (Wazir), and slides up to two squares diagonally backward (backward Bishop, max 2).',
      behaviors: ['compound', 'long-range', 'direction-restricted'],
      moves: [
        { kind: 'rays', dirs: [[1,1],[-1,1]] },
        { kind: 'rays', dirs: [[0,-1]] },
        { kind: 'dots', squares: [[1,0],[-1,0],[0,1]] },
        { kind: 'dots', squares: [[1,-1],[-1,-1],[2,-2],[-2,-2]] }
      ]
    },
    {
      id: 'vao',
      family: 'hoppers',
      name: 'Vao',
      aliases: ['Archer', 'Crocodile'],
      letter: 'VA',
      betza: 'mBcpB',
      origin: 'Xiangqi-derived',
      description: 'The diagonal Cannon. Slides any distance along Bishop lines for non-capture moves; to capture, must hop over exactly one intervening piece (the "screen") of either colour along a Bishop line. Both the slide and the hop-capture stay on Bishop lines, so the Vao is colour-bound like the Bishop.',
      behaviors: ['long-range', 'hopper', 'capture-different', 'color-bound'],
      moves: [
        { kind: 'rays', dirs: [[1,1],[-1,1],[1,-1],[-1,-1]] },
        { kind: 'capture-hop', hurdle: [2,2], target: [3,3] }
      ]
    },
    {
      id: 'leo',
      family: 'hoppers',
      name: 'Leo',
      aliases: ['Sorceress'],
      letter: 'LE',
      betza: 'mQcpQ',
      origin: 'Problem chess',
      description: 'Queen-line Cannon — combines Pao (rook lines) and Vao (bishop lines). Slides freely like a Queen for non-capture; captures only by hopping over an intervening screen along any queen line.',
      behaviors: ['long-range', 'hopper', 'capture-different'],
      moves: [
        { kind: 'rays', dirs: [[1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,1],[1,-1],[-1,-1]] },
        { kind: 'capture-hop', hurdle: [3,0], target: [4,0] },
        { kind: 'capture-hop', hurdle: [-2,-2], target: [-3,-3] }
      ]
    },
    {
      id: 'nao',
      family: 'hoppers',
      name: 'Nao',
      aliases: ['Knight-line Cannon'],
      letter: 'NA',
      betza: 'mNNcpNN',
      origin: 'Problem chess',
      description: 'A Chinese Nightrider. Moves like a Nightrider for non-capture (any number of knight-leaps in a straight line); captures by hopping over an intervening screen along the same knight line.',
      behaviors: ['long-range', 'hopper', 'capture-different'],
      moves: [
        { kind: 'rider', step: [1,  2], dots: [[1,2], [2,4]] },
        { kind: 'rider', step: [2,  1], dots: [[2,1], [4,2]] },
        { kind: 'rider', step: [-1, 2], dots: [[-1,2],[-2,4]] },
        { kind: 'rider', step: [-2, 1], dots: [[-2,1],[-4,2]] },
        { kind: 'rider', step: [1, -2], dots: [[1,-2],[2,-4]] },
        { kind: 'rider', step: [2, -1], dots: [[2,-1],[4,-2]] },
        { kind: 'rider', step: [-1,-2], dots: [[-1,-2],[-2,-4]] },
        { kind: 'rider', step: [-2,-1], dots: [[-2,-1],[-4,-2]] },
        { kind: 'capture-hop', hurdle: [2,1], target: [4,2] }
      ]
    },
    {
      id: 'bishopper',
      family: 'hoppers',
      name: 'Bishopper',
      aliases: ['Bishop-hopper'],
      letter: 'BH',
      betza: 'gB',
      origin: 'Problem chess',
      description: 'Grasshopper confined to diagonal lines. Hops over exactly one hurdle on a Bishop line and lands on the square immediately past it. Cannot move without a hurdle. Colour-bound — every square on a Bishop line is the starting colour, so the Bishopper never leaves it.',
      behaviors: ['hopper', 'long-range', 'color-bound'],
      moves: [
        { kind: 'hop', hurdle: [1, 1],  target: [2, 2] },
        { kind: 'hop', hurdle: [-1, 1], target: [-2, 2] },
        { kind: 'hop', hurdle: [1, -1], target: [2, -2] },
        { kind: 'hop', hurdle: [-1,-1], target: [-2,-2] }
      ]
    },
    {
      id: 'nightriderhopper',
      family: 'hoppers',
      name: 'Nightriderhopper',
      aliases: ['Knight-line-hopper'],
      letter: 'NH',
      betza: 'gNN',
      origin: 'Problem chess',
      description: 'Grasshopper confined to knight lines. Hops over a single hurdle along a Nightrider line and lands one knight-leap past it. Cannot move without a hurdle.',
      behaviors: ['hopper', 'long-range', 'leaper'],
      moves: [
        { kind: 'hop', hurdle: [1, 2],  target: [2, 4] },
        { kind: 'hop', hurdle: [2, 1],  target: [4, 2] },
        { kind: 'hop', hurdle: [-1, 2], target: [-2, 4] },
        { kind: 'hop', hurdle: [-2, 1], target: [-4, 2] }
      ]
    },
    {
      id: 'faro',
      family: 'hoppers',
      name: 'Faro',
      aliases: [],
      letter: 'FA',
      betza: 'cRmpR',
      origin: 'Problem chess',
      description: 'The mirror of the Cannon: captures freely along Rook lines (no hurdle needed), but to move without capturing it must hop over a single hurdle along a Rook line.',
      behaviors: ['long-range', 'hopper', 'capture-different'],
      moves: [
        { kind: 'rays', dirs: [[1,0],[-1,0],[0,1],[0,-1]] },
        { kind: 'move-hop', hurdle: [0,1], target: [0,2] }
      ]
    },
    {
      id: 'loco',
      family: 'hoppers',
      name: 'Loco',
      aliases: ['Argentinian Bishop'],
      letter: 'LO',
      betza: 'cBmpB',
      origin: 'Problem chess',
      description: 'The diagonal mirror of the Faro. Captures freely along Bishop lines, but must hop over a single hurdle along a Bishop line to move without capturing. Both operations stay on Bishop lines, so the Loco is colour-bound.',
      behaviors: ['long-range', 'hopper', 'capture-different', 'color-bound'],
      moves: [
        { kind: 'rays', dirs: [[1,1],[-1,1],[1,-1],[-1,-1]] },
        { kind: 'move-hop', hurdle: [1,1], target: [2,2] }
      ]
    },
    {
      id: 'alfilrider',
      family: 'leap-riders',
      name: 'Alfilrider',
      aliases: [],
      letter: 'AA',
      betza: 'AA',
      origin: 'Problem chess',
      description: 'Slides any number of Alfil (2,2) leaps in a single diagonal direction. Like a Bishop but only lands on every second diagonal square — heavily colour-bound. Jumps over any pieces on odd squares of the path.',
      behaviors: ['long-range', 'leaper', 'color-bound'],
      moves: [
        { kind: 'rider', step: [2,  2], dots: [[2,2], [4,4]] },
        { kind: 'rider', step: [-2, 2], dots: [[-2,2],[-4,4]] },
        { kind: 'rider', step: [2, -2], dots: [[2,-2],[4,-4]] },
        { kind: 'rider', step: [-2,-2], dots: [[-2,-2],[-4,-4]] }
      ]
    },
    {
      id: 'dabbabarider',
      family: 'leap-riders',
      name: 'Dabbabarider',
      aliases: [],
      letter: 'DD',
      betza: 'DD',
      origin: 'Problem chess',
      description: 'Slides any number of Dabbaba (2,0) leaps along ranks and files — lands on every second square only. Jumps over any pieces on odd squares of the path. Colour-bound.',
      behaviors: ['long-range', 'leaper', 'color-bound'],
      moves: [
        { kind: 'rider', step: [2,  0], dots: [[2,0], [4,0]] },
        { kind: 'rider', step: [-2, 0], dots: [[-2,0],[-4,0]] },
        { kind: 'rider', step: [0,  2], dots: [[0,2], [0,4]] },
        { kind: 'rider', step: [0, -2], dots: [[0,-2],[0,-4]] }
      ]
    },
    {
      id: 'alibabarider',
      family: 'leap-riders',
      name: 'Alibabarider',
      aliases: [],
      letter: 'AD',
      betza: 'AADD',
      origin: 'Problem chess',
      description: 'Combines the Alfilrider and Dabbabarider — slides any number of (2,2) or (2,0) leaps in a straight line. Reaches every even-distance square on any rank, file, or diagonal. Colour-bound.',
      behaviors: ['long-range', 'leaper', 'color-bound', 'compound'],
      moves: [
        { kind: 'rider', step: [2,  2], dots: [[2,2], [4,4]] },
        { kind: 'rider', step: [-2, 2], dots: [[-2,2],[-4,4]] },
        { kind: 'rider', step: [2, -2], dots: [[2,-2],[4,-4]] },
        { kind: 'rider', step: [-2,-2], dots: [[-2,-2],[-4,-4]] },
        { kind: 'rider', step: [2,  0], dots: [[2,0], [4,0]] },
        { kind: 'rider', step: [-2, 0], dots: [[-2,0],[-4,0]] },
        { kind: 'rider', step: [0,  2], dots: [[0,2], [0,4]] },
        { kind: 'rider', step: [0, -2], dots: [[0,-2],[0,-4]] }
      ]
    },
    {
      id: 'amazonrider',
      family: 'compounds',
      name: 'Amazonrider',
      aliases: [],
      letter: 'Am',
      betza: 'QNN',
      origin: 'Problem chess',
      description: 'Combines the Queen and Nightrider — slides any distance along all 8 queen lines AND any number of knight leaps in a straight line. One of the most powerful long-range fairy pieces.',
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
    },
    {
      id: 'banshee',
      family: 'compounds',
      name: 'Banshee',
      aliases: [],
      letter: 'Bn',
      betza: 'BNN',
      origin: 'Problem chess',
      description: 'Combines Bishop and Nightrider — slides diagonally any distance AND makes any number of knight leaps in a straight line. The diagonal counterpart of the Raven (Rook + Nightrider).',
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
      id: 'gnurider',
      family: 'leap-riders',
      name: 'Gnurider',
      aliases: [],
      letter: 'Gn',
      betza: 'NNCC',
      origin: 'Problem chess',
      description: 'Combines the Nightrider and Camelrider — slides any number of (1,2) knight leaps OR (1,3) camel leaps in a straight line. A long-range leaper-rider compound.',
      behaviors: ['long-range', 'compound', 'leaper'],
      moves: [
        { kind: 'rider', step: [1,  2], dots: [[1,2], [2,4]] },
        { kind: 'rider', step: [2,  1], dots: [[2,1], [4,2]] },
        { kind: 'rider', step: [-1, 2], dots: [[-1,2],[-2,4]] },
        { kind: 'rider', step: [-2, 1], dots: [[-2,1],[-4,2]] },
        { kind: 'rider', step: [1, -2], dots: [[1,-2],[2,-4]] },
        { kind: 'rider', step: [2, -1], dots: [[2,-1],[4,-2]] },
        { kind: 'rider', step: [-1,-2], dots: [[-1,-2],[-2,-4]] },
        { kind: 'rider', step: [-2,-1], dots: [[-2,-1],[-4,-2]] },
        { kind: 'rider', step: [1,  3], dots: [[1,3]] },
        { kind: 'rider', step: [3,  1], dots: [[3,1]] },
        { kind: 'rider', step: [-1, 3], dots: [[-1,3]] },
        { kind: 'rider', step: [-3, 1], dots: [[-3,1]] },
        { kind: 'rider', step: [1, -3], dots: [[1,-3]] },
        { kind: 'rider', step: [3, -1], dots: [[3,-1]] },
        { kind: 'rider', step: [-1,-3], dots: [[-1,-3]] },
        { kind: 'rider', step: [-3,-1], dots: [[-3,-1]] }
      ]
    },
    {
      id: 'boyscout',
      family: 'others',
      name: 'Boyscout',
      aliases: ['Crooked Bishop', 'Zigzag Bishop'],
      letter: 'ZB',
      betza: 'zB',
      origin: 'Problem chess',
      description: 'A Bishop whose path makes a 90° turn after every step — it zigzags diagonally. Each individual step is a one-square diagonal move, so square colour is preserved at every step: the Boyscout is colour-bound just like the standard Bishop. What the bends change is the *trajectory* (the piece can reach squares a straight Bishop never could), not the colour palette. The diagram shows four representative rays heading net N, S, E, W via alternating NE/NW or NE/SE steps.',
      behaviors: ['long-range', 'color-bound'],
      moves: [
        { kind: 'zigzag', points: [[1,1],[0,2],[1,3],[0,4]] },
        { kind: 'zigzag', points: [[1,1],[2,0],[3,1],[4,0]] },
        { kind: 'zigzag', points: [[-1,-1],[0,-2],[-1,-3],[0,-4]] },
        { kind: 'zigzag', points: [[-1,1],[-2,0],[-3,1],[-4,0]] }
      ]
    },
    {
      id: 'gryphon',
      family: 'others',
      name: 'Gryphon',
      aliases: ['Aanca', 'Eagle (Grant Acedrex)'],
      letter: 'GP',
      betza: 't[FR]',
      origin: 'Grant Acedrex (1283)',
      description: 'A bent slider: takes one diagonal step (Ferz), then continues as a Rook outwards — moving orthogonally away from its starting square. The pivot square is itself a valid stopping square. Originated in Grant Acedrex, the 13th-century Castilian variant.',
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
      id: 'quintessence',
      family: 'others',
      name: 'Quintessence',
      aliases: [],
      letter: 'Qu',
      betza: 'zNN',
      origin: 'Problem chess',
      description: 'A Nightrider that turns 90° after every Knight\'s leap. Each path closes back to the starting square after exactly four knight-leaps, so the piece can reach three distinct squares per ray before the cycle closes. The diagram shows four representative cycles covering the four general directions; each is a 4-step closed loop returning to centre.',
      behaviors: ['long-range', 'leaper'],
      moves: [
        { kind: 'zigzag', points: [[1,2],[3,1],[2,-1]] },
        { kind: 'zigzag', points: [[-1,2],[1,3],[2,1]] },
        { kind: 'zigzag', points: [[1,-2],[-1,-3],[-2,-1]] },
        { kind: 'zigzag', points: [[-1,-2],[-3,-1],[-2,1]] }
      ]
    },
    {
      id: 'astrologer',
      family: 'others',
      name: 'Astrologer',
      aliases: [],
      letter: 'AS',
      betza: 't[CB]',
      origin: 'Problem chess',
      description: 'A bent slider that takes one Camel (1,3) leap, then continues as a Bishop outwards from the landing square. The Camel component is colour-bound and the outward Bishop slide preserves colour, so the Astrologer is heavily colour-bound. Eight reachable Camel pivot squares, each with a short outward diagonal slide.',
      behaviors: ['compound', 'long-range', 'leaper', 'color-bound'],
      moves: [
        { kind: 'bent-rider', pivot: [1,  3],  dir: [1,  1] },
        { kind: 'bent-rider', pivot: [3,  1],  dir: [1,  1] },
        { kind: 'bent-rider', pivot: [-1, 3],  dir: [-1, 1] },
        { kind: 'bent-rider', pivot: [-3, 1],  dir: [-1, 1] },
        { kind: 'bent-rider', pivot: [1, -3],  dir: [1, -1] },
        { kind: 'bent-rider', pivot: [3, -1],  dir: [1, -1] },
        { kind: 'bent-rider', pivot: [-1,-3],  dir: [-1,-1] },
        { kind: 'bent-rider', pivot: [-3,-1],  dir: [-1,-1] }
      ]
    },
    {
      id: 'godzilla',
      family: 'others',
      name: 'Godzilla',
      aliases: [],
      letter: 'GZ',
      betza: 't[FR]t[WB]',
      origin: 'Modern variants',
      description: 'A double bent-rider that combines the Gryphon (Ferz + outward Rook) and the Manticore (Wazir + outward Bishop) into a single piece. Sixteen bent paths radiating from the centre — eight Gryphon-style (diagonal pivot, orthogonal slide) and eight Manticore-style (orthogonal pivot, diagonal slide).',
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
      id: 'manticore',
      family: 'others',
      name: 'Manticore',
      aliases: ['Anchorite', 'Acromantula', 'Rhinoceros', 'Spider', 'Unicorn'],
      letter: 'MN',
      betza: 't[WB]',
      origin: 'Modern variants (Betza, Gilman, Cazaux)',
      description: 'A bent slider: takes one orthogonal step (Wazir), then continues as a Bishop outwards. The orthogonal counterpart of the Gryphon. Pivot square is itself a valid stopping square.',
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
      id: 'girlscout',
      family: 'others',
      name: 'Girlscout',
      aliases: ['Crooked Rook', 'Zigzag Rook'],
      letter: 'ZR',
      betza: 'zR',
      origin: 'Problem chess',
      description: 'A Rook whose path makes a 90° turn after every step — climbing stairs orthogonally. The diagram shows four representative paths, one toward each corner of the diagram (N then E, N then W, S then E, S then W). The piece can stop at any visited square. Each individual step is a Rook step but the trajectory alternates direction.',
      behaviors: ['long-range'],
      moves: [
        { kind: 'zigzag', points: [[0,1],[1,1],[1,2],[2,2],[2,3],[3,3],[3,4],[4,4]] },
        { kind: 'zigzag', points: [[0,1],[-1,1],[-1,2],[-2,2],[-2,3],[-3,3],[-3,4],[-4,4]] },
        { kind: 'zigzag', points: [[0,-1],[1,-1],[1,-2],[2,-2],[2,-3],[3,-3],[3,-4],[4,-4]] },
        { kind: 'zigzag', points: [[0,-1],[-1,-1],[-1,-2],[-2,-2],[-2,-3],[-3,-3],[-3,-4],[-4,-4]] }
      ]
    },
    {
      id: 'fourleaper',
      family: 'leapers',
      name: 'Fourleaper',
      aliases: [],
      letter: '4L',
      betza: '',
      origin: 'Problem chess',
      description: 'Leaps exactly four squares orthogonally, ignoring any intervening pieces. Reaches only four squares from any starting point. Colour-bound.',
      behaviors: ['leaper', 'color-bound'],
      moves: [
        { kind: 'dots', squares: [[4,0],[-4,0],[0,4],[0,-4]] }
      ]
    },
    {
      id: 'commuter',
      family: 'leapers',
      name: 'Commuter',
      aliases: [],
      letter: 'CM',
      betza: '',
      origin: 'Problem chess',
      description: 'Leaps exactly four squares diagonally — corner to corner on a 5×5 box around its starting square. Colour-bound, same as the Alfil but at double the distance.',
      behaviors: ['leaper', 'color-bound'],
      moves: [
        { kind: 'dots', squares: [[4,4],[-4,4],[4,-4],[-4,-4]] }
      ]
    },
    {
      id: 'tripper',
      family: 'leapers',
      name: 'Tripper',
      aliases: [],
      letter: 'TR',
      betza: 'G',
      origin: 'Problem chess',
      description: 'Leaps exactly three squares diagonally — the (3,3) counterpart of the Alfil and Commuter. Colour-bound.',
      behaviors: ['leaper', 'color-bound'],
      moves: [
        { kind: 'dots', squares: [[3,3],[-3,3],[3,-3],[-3,-3]] }
      ]
    },
    {
      id: 'stag',
      family: 'leapers',
      name: 'Stag',
      aliases: ['Hare', 'Lancer'],
      letter: 'ST',
      betza: '',
      origin: 'Problem chess',
      description: 'Leaps (2,4) — two squares in one direction and four perpendicular. Eight reachable squares. Colour-bound.',
      behaviors: ['leaper', 'color-bound'],
      moves: [
        { kind: 'dots', squares: [[2,4],[4,2],[-2,4],[-4,2],[2,-4],[4,-2],[-2,-4],[-4,-2]] }
      ]
    },
    {
      id: 'auroch',
      family: 'leapers',
      name: 'Auroch',
      aliases: [],
      letter: 'AU',
      betza: 'N(1,4)',
      origin: 'Problem chess',
      description: 'Combines the Knight (1,2) and Giraffe (1,4) leaps — 16 reachable squares around the piece.',
      behaviors: ['compound', 'leaper'],
      moves: [
        { kind: 'dots', squares: [
          [1,2],[2,1],[-1,2],[-2,1],[1,-2],[2,-1],[-1,-2],[-2,-1],
          [1,4],[4,1],[-1,4],[-4,1],[1,-4],[4,-1],[-1,-4],[-4,-1]
        ] }
      ]
    },
    {
      id: 'okapi',
      family: 'leapers',
      name: 'Okapi',
      aliases: [],
      letter: 'OK',
      betza: 'NZ',
      origin: 'Problem chess',
      description: 'Combines the Knight (1,2) and Zebra (2,3) leaps — 16 reachable squares.',
      behaviors: ['compound', 'leaper'],
      moves: [
        { kind: 'dots', squares: [
          [1,2],[2,1],[-1,2],[-2,1],[1,-2],[2,-1],[-1,-2],[-2,-1],
          [2,3],[3,2],[-2,3],[-3,2],[2,-3],[3,-2],[-2,-3],[-3,-2]
        ] }
      ]
    },
    {
      id: 'impala',
      family: 'leapers',
      name: 'Impala',
      aliases: [],
      letter: 'IM',
      betza: 'N(3,4)',
      origin: 'Problem chess',
      description: 'Combines the Knight (1,2) and Antelope (3,4) leaps — 16 reachable squares from short range out to the corners of the diagram.',
      behaviors: ['compound', 'leaper'],
      moves: [
        { kind: 'dots', squares: [
          [1,2],[2,1],[-1,2],[-2,1],[1,-2],[2,-1],[-1,-2],[-2,-1],
          [3,4],[4,3],[-3,4],[-4,3],[3,-4],[4,-3],[-3,-4],[-4,-3]
        ] }
      ]
    },
    {
      id: 'pegasus',
      family: 'leapers',
      name: 'Pegasus',
      aliases: ['Beastmaster'],
      letter: 'PG',
      betza: '(1,4)(2,3)',
      origin: 'Problem chess',
      description: 'Combines the Giraffe (1,4) and Zebra (2,3) leaps — 16 reachable squares, all at long range.',
      behaviors: ['compound', 'leaper'],
      moves: [
        { kind: 'dots', squares: [
          [1,4],[4,1],[-1,4],[-4,1],[1,-4],[4,-1],[-1,-4],[-4,-1],
          [2,3],[3,2],[-2,3],[-3,2],[2,-3],[3,-2],[-2,-3],[-3,-2]
        ] }
      ]
    },
    {
      id: 'roc',
      family: 'leapers',
      name: 'Roc',
      aliases: [],
      letter: 'RC',
      betza: 'AC',
      origin: 'Problem chess',
      description: 'Combines the Alfil (2,2) and Camel (1,3) leaps — 12 reachable squares. Colour-bound, since both component leaps preserve colour.',
      behaviors: ['compound', 'leaper', 'color-bound'],
      moves: [
        { kind: 'dots', squares: [
          [2,2],[-2,2],[2,-2],[-2,-2],
          [1,3],[3,1],[-1,3],[-3,1],[1,-3],[3,-1],[-1,-3],[-3,-1]
        ] }
      ]
    },
    {
      id: 'high-priestess',
      family: 'leapers',
      name: 'High Priestess',
      aliases: [],
      letter: 'HP',
      betza: 'FAN',
      origin: 'Problem chess',
      description: 'Combines the Ferz (1,1), Alfil (2,2), and Knight (1,2) leaps — 16 reachable squares at short range. Not colour-bound, because the Knight component breaks the otherwise diagonal palette.',
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
      id: 'newt',
      family: 'leapers',
      name: 'Newt',
      aliases: [],
      letter: 'NT',
      betza: 'AG',
      origin: 'Problem chess',
      description: 'Combines the Alfil (2,2) and Tripper (3,3) leaps — eight reachable squares, all on the same colour. Heavily colour-bound.',
      behaviors: ['compound', 'leaper', 'color-bound'],
      moves: [
        { kind: 'dots', squares: [
          [2,2],[-2,2],[2,-2],[-2,-2],
          [3,3],[-3,3],[3,-3],[-3,-3]
        ] }
      ]
    },
    {
      id: 'leon',
      family: 'leapers',
      name: 'Leon',
      aliases: [],
      letter: 'Ln',
      betza: 'CG',
      origin: 'Problem chess',
      description: 'Combines the Camel (1,3) and Tripper (3,3) leaps — 12 reachable squares. Colour-bound. (Distinct from Leo the queen-line Cannon.)',
      behaviors: ['compound', 'leaper', 'color-bound'],
      moves: [
        { kind: 'dots', squares: [
          [1,3],[3,1],[-1,3],[-3,1],[1,-3],[3,-1],[-1,-3],[-3,-1],
          [3,3],[-3,3],[3,-3],[-3,-3]
        ] }
      ]
    },
    {
      id: 'arrow-pawn',
      family: 'pawn-like',
      name: 'Arrow Pawn',
      aliases: ['Persson Pawn'],
      letter: 'AP',
      betza: 'mW2cF',
      origin: 'Arrow Pawn Chess (Persson, 1938)',
      description: 'Moves one or two squares orthogonally in any direction (move only), and captures one square diagonally in any direction. Unlike a standard pawn, it is not direction-restricted — only its move/capture asymmetry makes it pawn-like.',
      behaviors: ['promotes', 'capture-different'],
      moves: [
        { kind: 'rings', squares: [[1,0],[2,0],[-1,0],[-2,0],[0,1],[0,2],[0,-1],[0,-2]] },
        { kind: 'xs',    squares: [[1,1],[-1,1],[1,-1],[-1,-1]] }
      ]
    },
    {
      id: 'berolina-plus',
      family: 'pawn-like',
      name: 'Berolina Plus Pawn',
      aliases: [],
      letter: 'B+',
      betza: 'mfFcfWcsWimfF2',
      origin: 'Berolina Plus',
      description: 'Extension of the Berolina Pawn: moves one square diagonally forward (or two on its first move), and captures one square straight forward OR one square sideways. Combines Berolina’s diagonal advance with a wider capture pattern.',
      behaviors: ['direction-restricted', 'promotes', 'capture-different'],
      moves: [
        { kind: 'rings', squares: [[1,1],[-1,1],[2,2],[-2,2]] },
        { kind: 'xs',    squares: [[0,1],[1,0],[-1,0]] }
      ]
    },
    {
      id: 'corporal',
      family: 'pawn-like',
      name: 'Corporal',
      aliases: [],
      letter: 'Co',
      betza: 'fFmfWimfnD',
      origin: 'Improved Pawn variant',
      description: 'Moves and captures one square diagonally forward (like a Ferz, but forward only), plus moves one square straight forward without capturing. Has the standard pawn’s initial two-square advance.',
      behaviors: ['direction-restricted', 'promotes', 'capture-different'],
      moves: [
        { kind: 'dots',  squares: [[1,1],[-1,1]] },
        { kind: 'rings', squares: [[0,1],[0,2]] }
      ]
    },
    {
      id: 'chinese-pawn',
      family: 'pawn-like',
      name: 'Chinese Pawn',
      aliases: ['Bing', 'Zú', 'Soldier', 'Japanese Pawn', 'Fuhyō'],
      letter: '兵',
      betza: 'fW (sfW once past midway)',
      origin: 'Xiangqi',
      description: 'Moves and captures one square straight forward (no separate capture pattern). After advancing past the midway line of the board, it also gains the ability to move and capture one square sideways. Does not promote in the Western sense — it gains the sideways move instead.',
      behaviors: ['direction-restricted'],
      moves: [
        { kind: 'dots',  squares: [[0,1]] },
        { kind: 'rings', squares: [[1,0],[-1,0]] }
      ]
    },
    {
      id: 'korean-pawn',
      family: 'pawn-like',
      name: 'Korean Pawn',
      aliases: ['Janggi Pawn'],
      letter: '卒',
      betza: 'sfW',
      origin: 'Janggi (Korean chess)',
      description: 'Moves and captures one square in any forward or sideways direction (three squares total). Slightly more powerful than the unadvanced Chinese Pawn.',
      behaviors: ['direction-restricted'],
      moves: [
        { kind: 'dots', squares: [[0,1],[1,0],[-1,0]] }
      ]
    },
    {
      id: 'hiashatar-pawn',
      family: 'pawn-like',
      name: 'Hiashatar Pawn',
      aliases: [],
      letter: 'Hi',
      betza: 'mfWcfFimfW3',
      origin: 'Hiashatar (Mongolian decimal chess)',
      description: 'A standard pawn but with a TRIPLE step on its first move instead of a double. Moves one square forward (or up to three on first move) and captures one square diagonally forward.',
      behaviors: ['direction-restricted', 'promotes', 'capture-different'],
      moves: [
        { kind: 'rings', squares: [[0,1],[0,2],[0,3]] },
        { kind: 'xs',    squares: [[1,1],[-1,1]] }
      ]
    },
    {
      id: 'torpedo-pawn',
      family: 'pawn-like',
      name: 'Torpedo Pawn',
      aliases: [],
      letter: 'TP',
      betza: 'mfW2cefF',
      origin: 'Torpedo Chess / Metamachy / Gigachess',
      description: 'Moves one or two squares straight forward (always, not just on its first move). Captures one square diagonally forward, with en-passant valid.',
      behaviors: ['direction-restricted', 'promotes', 'capture-different'],
      moves: [
        { kind: 'rings', squares: [[0,1],[0,2]] },
        { kind: 'xs',    squares: [[1,1],[-1,1]] }
      ]
    },
    {
      id: 'sergeant',
      family: 'pawn-like',
      name: 'Sergeant',
      aliases: [],
      letter: 'SG',
      betza: 'mWcF',
      origin: 'Extended Pawn variant',
      description: 'Moves one square orthogonally in any of the four directions (move only) and captures one square diagonally in any of the four directions. Move-vs-capture asymmetry is its only pawn-like trait — it is fully symmetric in direction.',
      behaviors: ['capture-different'],
      moves: [
        { kind: 'rings', squares: [[1,0],[-1,0],[0,1],[0,-1]] },
        { kind: 'xs',    squares: [[1,1],[-1,1],[1,-1],[-1,-1]] }
      ]
    },
    {
      id: 'advisor',
      family: 'leapers',
      name: 'Advisor',
      aliases: ['Shi', 'Mandarin', 'Guard'],
      letter: '士',
      betza: 'F (palace)',
      origin: 'Xiangqi',
      description: 'Steps one square diagonally (Ferz movement) — but in Xiangqi, the Advisor is confined to the 3×3 palace at the back of the board and may never leave. There are exactly five squares it can reach within the palace, so each Advisor cycles between just a handful of squares throughout the game. Colour-bound.',
      behaviors: ['leaper', 'color-bound', 'direction-restricted'],
      moves: [
        { kind: 'dots', squares: [[1,1],[-1,1],[1,-1],[-1,-1]] }
      ]
    },
    {
      id: 'alibaba',
      family: 'leapers',
      name: 'Alibaba',
      aliases: [],
      letter: 'AD',
      betza: 'AD',
      origin: 'Problem chess',
      description: 'Combines the Alfil (2,2) and Dabbaba (2,0) leaps into a single piece — eight reachable squares forming the "second ring" along ranks, files, and diagonals. The single-leap counterpart of the Alibabarider. Heavily colour-bound, since both components preserve square colour.',
      behaviors: ['compound', 'leaper', 'color-bound'],
      moves: [
        { kind: 'dots', squares: [
          [2,2],[-2,2],[2,-2],[-2,-2],
          [2,0],[-2,0],[0,2],[0,-2]
        ] }
      ]
    },
    {
      id: 'xiangqi-general',
      family: 'leapers',
      name: 'General (Xiangqi)',
      aliases: ['Jiàng', 'Shuài', 'King (Xiangqi)'],
      letter: '將',
      betza: 'kW',
      origin: 'Xiangqi',
      description: 'The royal piece in Xiangqi. Moves one square orthogonally and is confined to the 3×3 "palace" at the back of the board. The "Flying General" rule lets a General capture the enemy General on the same open file if no pieces stand between them.',
      behaviors: ['royal', 'leaper', 'direction-restricted'],
      moves: [
        { kind: 'dots', squares: [[1,0],[-1,0],[0,1],[0,-1]] }
      ]
    },
    {
      id: 'maharaja',
      family: 'compounds',
      name: 'Maharaja',
      aliases: [],
      letter: 'MA',
      betza: 'QN',
      origin: 'Maharajah and the Sepoys',
      description: 'A royal Amazon — combines Queen and Knight powers. In the asymmetric variant "Maharajah and the Sepoys", a single Maharaja faces a complete standard Black army. Capture of the Maharaja ends the game.',
      behaviors: ['royal', 'compound', 'long-range', 'leaper'],
      moves: [
        { kind: 'rays', dirs: [[1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,1],[1,-1],[-1,-1]] },
        { kind: 'dots', squares: [[1,2],[2,1],[-1,2],[-2,1],[1,-2],[2,-1],[-1,-2],[-2,-1]] }
      ]
    },
    {
      id: 'mounted-king',
      family: 'leapers',
      name: 'Mounted King',
      aliases: [],
      letter: 'MK',
      betza: 'KN',
      origin: 'The Ouroboros King',
      description: 'A royal Centaur — combines King and Knight movements. Used as the royal piece in The Ouroboros King variant; the movement is identical to a Centaur but with checkmate semantics.',
      behaviors: ['royal', 'compound', 'leaper'],
      moves: [
        { kind: 'dots', squares: [
          [1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,1],[1,-1],[-1,-1],
          [1,2],[2,1],[-1,2],[-2,1],[1,-2],[2,-1],[-1,-2],[-2,-1]
        ] }
      ]
    },
    {
      id: 'anti-king',
      family: 'leapers',
      name: 'Anti-King',
      aliases: [],
      letter: 'AK',
      betza: 'K',
      origin: 'Problem chess',
      description: 'Moves identically to a King — one square in any of 8 directions — but its check semantics are inverted: the Anti-King is in "check" when NOT attacked, and the side loses if its Anti-King cannot reach an attacked square. A fairy-chess problem-composition piece.',
      behaviors: ['royal', 'leaper'],
      moves: [
        { kind: 'dots', squares: [[1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,1],[1,-1],[-1,-1]] }
      ]
    },
    {
      id: 'prince',
      family: 'leapers',
      name: 'Prince',
      aliases: ['Shâhzâda'],
      letter: 'PR',
      betza: 'WF',
      origin: 'Tamerlane Chess',
      description: 'In Tamerlane Chess, a non-royal King — moves identically to a King (one square in any direction) but capturing it does not end the game. Originally the promotion target of the "Pawn of King". Called Shâhzâda ("son of the Shah") in Persian.',
      behaviors: ['leaper'],
      moves: [
        { kind: 'dots', squares: [[1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,1],[1,-1],[-1,-1]] }
      ]
    },
    {
      id: 'gnu',
      family: 'leapers',
      name: 'Gnu',
      aliases: ['Unicorn'],
      letter: 'GU',
      betza: 'NC',
      origin: 'Problem chess',
      description: 'Combines the Knight (1,2) and Camel (1,3) leaps — 16 reachable squares, all at short range.',
      behaviors: ['compound', 'leaper'],
      moves: [
        { kind: 'dots', squares: [
          [1,2],[2,1],[-1,2],[-2,1],[1,-2],[2,-1],[-1,-2],[-2,-1],
          [1,3],[3,1],[-1,3],[-3,1],[1,-3],[3,-1],[-1,-3],[-3,-1]
        ] }
      ]
    },
    {
      id: 'squirrel',
      family: 'leapers',
      name: 'Squirrel',
      aliases: [],
      letter: 'Sq',
      betza: 'NAD',
      origin: 'Problem chess',
      description: 'Combines Knight (1,2), Alfil (2,2), and Dabbaba (2,0) leaps. Reaches every square exactly two squares away from the piece (the full "second ring" at Chebyshev distance 2) — 16 squares in total: eight knight-leap targets, four diagonal corners, and four orthogonal edge-midpoints.',
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
      id: 'war-machine',
      family: 'leapers',
      name: 'War Machine',
      aliases: [],
      letter: 'WM',
      betza: 'WD',
      origin: 'Problem chess',
      description: 'Combines Wazir (1,0) and Dabbaba (2,0) — leaps one or exactly two squares orthogonally. Eight reachable squares, all on ranks and files.',
      behaviors: ['compound', 'leaper'],
      moves: [
        { kind: 'dots', squares: [
          [1,0],[-1,0],[0,1],[0,-1],
          [2,0],[-2,0],[0,2],[0,-2]
        ] }
      ]
    },
    {
      id: 'phoenix',
      family: 'leapers',
      name: 'Phoenix',
      aliases: ['Waffle'],
      letter: 'Ph',
      betza: 'WA',
      origin: 'Chu Shōgi',
      description: 'Combines Wazir (1,0) and Alfil (2,2). Eight reachable squares: four orthogonal one-step plus four diagonal two-square leaps. Appears in Chu Shōgi and Dai Shōgi, and as the "Waffle" in Betza\'s Chess with Different Armies.',
      behaviors: ['compound', 'leaper'],
      moves: [
        { kind: 'dots', squares: [
          [1,0],[-1,0],[0,1],[0,-1],
          [2,2],[-2,2],[2,-2],[-2,-2]
        ] }
      ]
    },
    {
      id: 'kirin',
      family: 'leapers',
      name: 'Kirin',
      aliases: [],
      letter: 'Ki',
      betza: 'FD',
      origin: 'Chu Shōgi',
      description: 'Combines Ferz (1,1) and Dabbaba (2,0) — four diagonal one-step plus four orthogonal two-square leaps. Colour-bound, since both components preserve square colour. Appears in Chu Shōgi.',
      behaviors: ['compound', 'leaper', 'color-bound'],
      moves: [
        { kind: 'dots', squares: [
          [1,1],[-1,1],[1,-1],[-1,-1],
          [2,0],[-2,0],[0,2],[0,-2]
        ] }
      ]
    },
    {
      id: 'elephant-modern',
      family: 'leapers',
      name: 'Elephant (Modern)',
      aliases: ['Modern Elephant'],
      letter: 'EM',
      betza: 'FA',
      origin: 'Modern variants',
      description: 'Combines Ferz (1,1) and Alfil (2,2) — leaps one or two squares diagonally. Eight reachable squares, all on diagonals. Heavily colour-bound. Used in modern variants as a stronger fairy "Elephant".',
      behaviors: ['compound', 'leaper', 'color-bound'],
      moves: [
        { kind: 'dots', squares: [
          [1,1],[-1,1],[1,-1],[-1,-1],
          [2,2],[-2,2],[2,-2],[-2,-2]
        ] }
      ]
    },
    {
      id: 'champion',
      family: 'leapers',
      name: 'Champion',
      aliases: [],
      letter: 'Ch',
      betza: 'WAD',
      origin: 'Omega Chess',
      description: 'Combines Wazir (1,0), Alfil (2,2), and Dabbaba (2,0) — 12 reachable squares: a one-step orthogonal "ring" plus all eight squares of the second ring at corner and edge positions. One of the two new pieces in Omega Chess.',
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
      id: 'caliph',
      family: 'compounds',
      name: 'Caliph',
      aliases: [],
      letter: 'CL',
      betza: 'BC',
      origin: 'Problem chess',
      description: 'Combines Bishop slides with Camel (1,3) leaps. Colour-bound, since both Bishop and Camel preserve square colour.',
      behaviors: ['compound', 'long-range', 'leaper', 'color-bound'],
      moves: [
        { kind: 'rays', dirs: [[1,1],[-1,1],[1,-1],[-1,-1]] },
        { kind: 'dots', squares: [[1,3],[3,1],[-1,3],[-3,1],[1,-3],[3,-1],[-1,-3],[-3,-1]] }
      ]
    },
    {
      id: 'canvasser',
      family: 'compounds',
      name: 'Canvasser',
      aliases: [],
      letter: 'Cv',
      betza: 'RC',
      origin: 'Problem chess',
      description: 'Combines Rook slides with Camel (1,3) leaps — orthogonal long-range plus eight long L-leaps. Not colour-bound, since the Rook can change colours.',
      behaviors: ['compound', 'long-range', 'leaper'],
      moves: [
        { kind: 'rays', dirs: [[1,0],[-1,0],[0,1],[0,-1]] },
        { kind: 'dots', squares: [[1,3],[3,1],[-1,3],[-3,1],[1,-3],[3,-1],[-1,-3],[-3,-1]] }
      ]
    },
    {
      id: 'raven',
      family: 'compounds',
      name: 'Raven',
      aliases: ['Waran'],
      letter: 'Rv',
      betza: 'RNN',
      origin: 'Problem chess',
      description: 'Combines Rook slides with Nightrider chains — orthogonal sliding plus any number of knight leaps in a straight line. The rook counterpart of the Banshee (BNN).',
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
      id: 'crown-princess',
      family: 'compounds',
      name: 'Crown Princess',
      aliases: ['Popess'],
      letter: 'CP',
      betza: 'BNW',
      origin: 'Modern variants',
      description: 'Archbishop + Wazir — combines Bishop slides, Knight leaps, and one-step orthogonal moves. A short-step extension of the Princess/Archbishop, similar in spirit to Dragon Horse but with the Knight added.',
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
      id: 'hunter',
      family: 'sliders',
      name: 'Hunter',
      aliases: [],
      letter: 'Hu',
      betza: 'fRbB',
      origin: 'Problem chess',
      description: 'A direction-asymmetric compound: slides like a Rook only forward (straight north) and like a Bishop only backward (the two backward diagonals). Strong attacking forward and ranging defensively backward.',
      behaviors: ['compound', 'long-range', 'direction-restricted'],
      moves: [
        { kind: 'rays', dirs: [[0,1]] },
        { kind: 'rays', dirs: [[1,-1],[-1,-1]] }
      ]
    },
    {
      id: 'edgehog',
      family: 'sliders',
      name: 'Edgehog',
      aliases: [],
      letter: 'EH',
      betza: 'Q (edges)',
      origin: 'Edgehog Chess (Driver, 1966)',
      description: 'Slides like a Queen, but every move must either start on or end on a board-edge square (any square on the outermost rank or file). The diagram places the Edgehog at (4, 0) — a right-edge square — and traces all five queen-line rays from there. Moves to or from an edge square may pass through interior squares; moves that both start and end in the interior are forbidden.',
      behaviors: ['long-range', 'direction-restricted'],
      piece_at: [4, 0],
      moves: [
        { kind: 'rays', from: [4, 0], dirs: [[-1, 0], [0, 1], [0, -1], [-1, 1], [-1, -1]] }
      ]
    },
    {
      id: 'bodyguard',
      family: 'sliders',
      name: 'Bodyguard',
      aliases: ['Hia'],
      letter: 'BG',
      betza: 'Q2',
      origin: 'Hiashatar (Mongolian decimal chess)',
      description: 'Slides like a Queen but only one or two squares in any of the eight directions. Has a defensive aura in Hiashatar: any opposing sliding piece must stop the moment it moves within a King\'s-move radius of the Bodyguard, so it cannot pass by without being challenged.',
      behaviors: ['direction-restricted'],
      moves: [
        { kind: 'rays', dirs: [[1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,1],[1,-1],[-1,-1]], maxRange: 2 }
      ]
    }
  ];

if (typeof module !== "undefined" && module.exports) module.exports = PIECES_ENCYCLOPEDIA;
