## Designed waves 1–150, transcribed from the GDD Wave Catalog (Draft v1).
## King waves (50/100/150) pause the spawn cadence until the King is checkmated.
## The catalog's procedural extension past 150 is not implemented — the run
## ends at the wave-150 full clear (grilled 2026-07-03).

## Waves whose spawn includes ONE box-carrying enemy (GDD buff flags): the value
## names which spawned piece type carries the box (opens Box Pick on capture).
const BUFFS := {
	3: "pawn", 7: "bishop", 12: "bishop", 17: "knight", 22: "knight",
	28: "rook", 34: "rook", 40: "bishop", 45: "knight", 49: "rook",
	55: "rook", 60: "knight", 65: "bishop", 74: "knight", 78: "rook",
	85: "bishop", 92: "knight", 98: "rook", 105: "rook", 112: "knight",
	120: "bishop", 128: "knight", 135: "rook", 142: "bishop", 148: "knight",
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
	["pawn", "bishop", "knight", "rook", "rook"],          # 51 — endless begins
	["bishop", "bishop", "knight", "knight", "rook"],      # 52
	["knight", "rook", "rook", "bishop", "bishop"],        # 53
	["knight", "knight", "rook", "rook", "bishop"],        # 54
	["pawn", "bishop", "knight", "rook", "rook"],          # 55
	["bishop", "bishop", "rook", "rook", "knight"],        # 56
	["knight", "rook", "rook", "rook", "bishop"],          # 57
	["knight", "knight", "bishop", "rook", "rook"],        # 58
	["pawn", "bishop", "bishop", "rook", "rook"],          # 59
	["bishop", "knight", "knight", "rook", "rook"],        # 60
	["bishop", "knight", "knight", "rook", "rook"],        # 61
	["bishop", "bishop", "knight", "knight", "rook"],      # 62
	["knight", "bishop", "rook", "rook", "rook"],          # 63
	["knight", "knight", "rook", "rook", "bishop"],        # 64
	["bishop", "knight", "knight", "rook", "pawn"],        # 65
	["bishop", "bishop", "rook", "rook", "knight"],        # 66
	["knight", "rook", "rook", "bishop", "pawn"],          # 67
	["knight", "knight", "rook", "rook", "pawn"],          # 68
	["bishop", "knight", "knight", "rook", "rook"],        # 69
	["pawn", "bishop", "bishop", "knight", "knight", "rook"],   # 70 — density 6
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 71
	["pawn", "knight", "bishop", "bishop", "rook", "rook"],     # 72
	["knight", "knight", "bishop", "bishop", "pawn", "rook"],   # 73
	["bishop", "knight", "knight", "rook", "rook", "rook"],     # 74
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 75
	["pawn", "bishop", "bishop", "knight", "knight", "rook"],   # 76
	["bishop", "knight", "knight", "rook", "rook", "rook"],     # 77
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 78
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 79
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 80
	["knight", "knight", "bishop", "bishop", "rook", "rook"],   # 81
	["knight", "knight", "bishop", "bishop", "rook", "rook"],   # 82
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 83
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 84
	["pawn", "bishop", "knight", "knight", "rook", "rook"],     # 85
	["knight", "knight", "rook", "rook", "bishop", "bishop"],   # 86
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 87
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 88
	["pawn", "bishop", "knight", "knight", "rook", "rook"],     # 89
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 90
	["knight", "bishop", "bishop", "rook", "rook", "rook"],     # 91
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 92
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 93
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 94
	["pawn", "bishop", "bishop", "knight", "rook", "rook"],     # 95
	["knight", "knight", "bishop", "bishop", "rook", "rook"],   # 96
	["knight", "knight", "bishop", "bishop", "rook", "rook"],   # 97
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 98
	["knight", "knight", "rook", "rook", "bishop", "bishop"],   # 99
	["king", "rook", "rook", "knight", "bishop"],               # 100 — King wave
	["knight", "knight", "rook", "rook", "bishop", "bishop"],   # 101
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 102
	["bishop", "bishop", "knight", "rook", "rook", "pawn"],     # 103
	["knight", "knight", "bishop", "bishop", "rook", "rook"],   # 104
	["pawn", "bishop", "bishop", "knight", "rook", "rook"],     # 105
	["knight", "knight", "rook", "rook", "bishop", "bishop"],   # 106
	["bishop", "knight", "knight", "rook", "rook", "pawn"],     # 107
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 108
	["knight", "bishop", "bishop", "rook", "rook", "pawn"],     # 109
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 110
	["pawn", "bishop", "bishop", "knight", "knight", "rook"],   # 111
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 112
	["knight", "bishop", "bishop", "rook", "rook", "rook"],     # 113
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 114
	["pawn", "bishop", "knight", "knight", "rook", "rook"],     # 115
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 116
	["bishop", "knight", "rook", "rook", "rook", "pawn"],       # 117
	["knight", "knight", "bishop", "bishop", "rook", "rook"],   # 118
	["bishop", "knight", "knight", "rook", "rook", "rook"],     # 119
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 120
	["bishop", "knight", "knight", "rook", "rook", "rook"],     # 121
	["bishop", "bishop", "knight", "rook", "rook", "rook"],     # 122
	["knight", "bishop", "bishop", "rook", "rook", "rook"],     # 123
	["knight", "knight", "bishop", "bishop", "rook", "rook"],   # 124
	["pawn", "bishop", "bishop", "knight", "knight", "rook"],   # 125
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 126
	["bishop", "knight", "knight", "rook", "rook", "rook"],     # 127
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 128
	["knight", "bishop", "bishop", "rook", "rook", "rook"],     # 129
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 130
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 131
	["knight", "bishop", "bishop", "rook", "rook", "rook"],     # 132
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 133
	["pawn", "bishop", "bishop", "knight", "knight", "rook"],   # 134
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 135
	["bishop", "knight", "knight", "rook", "rook", "rook"],     # 136
	["bishop", "bishop", "knight", "rook", "rook", "rook"],     # 137
	["knight", "bishop", "bishop", "rook", "rook", "rook"],     # 138
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 139
	["bishop", "knight", "knight", "rook", "rook", "rook"],     # 140
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 141
	["bishop", "knight", "knight", "rook", "rook", "rook"],     # 142
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 143
	["knight", "bishop", "bishop", "rook", "rook", "rook"],     # 144
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 145
	["bishop", "knight", "knight", "rook", "rook", "rook"],     # 146
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 147
	["bishop", "knight", "knight", "rook", "rook", "rook"],     # 148
	["bishop", "bishop", "knight", "knight", "rook", "rook"],   # 149
	["king", "rook", "rook", "knight", "knight", "bishop"],     # 150 — final King
]
