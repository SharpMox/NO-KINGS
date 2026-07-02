## Designed waves 1–50, transcribed from the GDD Wave Catalog (Draft v1).
## Wave 50 is the King wave: spawn cadence pauses until the King is checkmated.

## Waves whose spawn includes ONE box-carrying enemy (GDD buff flags): the value
## names which spawned piece type carries the box (opens Box Pick on capture).
const BUFFS := {
	3: "pawn", 7: "bishop", 12: "bishop", 17: "knight", 22: "knight",
	28: "rook", 34: "rook", 40: "bishop", 45: "knight", 49: "rook",
}

const WAVES: Array = [
	["pawn"],                                              # 1
	["pawn", "pawn"],                                      # 2
	["pawn", "pawn", "pawn"],                              # 3
	["pawn", "pawn", "pawn"],                              # 4
	["pawn", "pawn", "pawn"],                              # 5
	["pawn", "pawn", "bishop"],                            # 6
	["pawn", "bishop", "bishop"],                          # 7
	["bishop", "bishop", "bishop"],                        # 8
	["pawn", "pawn", "bishop"],                            # 9
	["pawn", "pawn", "bishop"],                            # 10
	["bishop", "pawn", "pawn"],                            # 11
	["bishop", "bishop", "bishop"],                        # 12
	["bishop", "pawn", "pawn"],                            # 13
	["bishop", "bishop", "bishop"],                        # 14
	["bishop", "bishop", "pawn"],                          # 15
	["bishop", "bishop", "knight"],                        # 16
	["bishop", "knight", "knight"],                        # 17
	["knight", "knight", "knight"],                        # 18
	["pawn", "bishop", "knight"],                          # 19
	["knight", "knight", "bishop", "pawn"],                # 20
	["knight", "knight", "pawn", "bishop"],                # 21
	["knight", "bishop", "bishop", "rook"],                # 22
	["knight", "knight", "knight", "rook"],                # 23
	["knight", "knight", "bishop", "rook"],                # 24
	["knight", "bishop", "rook", "rook"],                  # 25
	["knight", "knight", "rook", "rook"],                  # 26
	["knight", "rook", "rook", "bishop"],                  # 27
	["bishop", "knight", "rook", "rook"],                  # 28
	["bishop", "bishop", "knight", "rook"],                # 29
	["knight", "rook", "rook", "bishop"],                  # 30
	["rook", "rook", "knight", "bishop"],                  # 31
	["pawn", "bishop", "knight", "rook"],                  # 32
	["knight", "knight", "rook", "rook"],                  # 33
	["bishop", "knight", "rook", "rook"],                  # 34
	["bishop", "bishop", "knight", "knight"],              # 35
	["pawn", "bishop", "rook", "rook"],                    # 36
	["knight", "knight", "rook", "rook"],                  # 37
	["bishop", "knight", "rook", "rook"],                  # 38
	["pawn", "knight", "rook", "rook"],                    # 39
	["bishop", "bishop", "knight", "rook", "pawn"],        # 40
	["bishop", "knight", "rook", "rook", "pawn"],          # 41
	["knight", "knight", "rook", "rook", "bishop"],        # 42
	["pawn", "bishop", "knight", "rook", "rook"],          # 43
	["bishop", "bishop", "knight", "rook", "rook"],        # 44
	["bishop", "knight", "knight", "rook", "rook"],        # 45
	["bishop", "bishop", "knight", "rook", "rook"],        # 46
	["knight", "rook", "rook", "bishop", "bishop"],        # 47
	["bishop", "knight", "knight", "rook", "rook"],        # 48
	["knight", "knight", "rook", "rook", "bishop"],        # 49
	["king", "rook", "rook", "bishop"],                    # 50 — King wave
]

const KING_WAVE := 50
