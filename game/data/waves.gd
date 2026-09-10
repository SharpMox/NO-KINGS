## Designed waves 1–150, transcribed from the GDD Wave Catalog (Draft v1).
## King waves (50/100/150) pause the spawn cadence until the King is checkmated.
## The catalog's procedural extension past 150 is not implemented — the run
## ends at the wave-150 full clear (grilled 2026-07-03).

## Larry's wave — the 17th boss, past the 4x4 cast (NO-7). Named here rather
## than derived, so "which wave is Larry's" has exactly one answer and cannot
## drift from the table. It is the LAST entry on purpose: the FULL CLEAR branch
## keys off `wave >= WAVES.size()`, so being last is what hands the run's ending
## to Larry — no change to game.gd at all.
const LARRY_WAVE := 201


## True when wave `n` is Larry's. Kings.select() asks this BEFORE consulting the
## run's line-up, because Larry is not in it.
static func is_larry_wave(n: int) -> bool:
	return n == LARRY_WAVE


const WAVES: Array = [
	# waves 1-19 softened 2026-07-06: the old run of all-bishop walls (8/12/14)
	# killed the walker armies before their merge economy could start —
	# fleet data showed bimodal runs (dead by 15 or untouched to 50)
	["pawn"],                                              # 1
	["pawn", "pawn"],                                      # 2
	["pawn", "pawn", "pawn"],                              # 3
	["pawn", "pawn", "pawn"],                              # 4
	["pawn", "pawn", "pawn"],                              # 5
	["pawn", "pawn", "bishop"],                            # 6
	["pawn", "bishop", "bishop"],                          # 7
	["pawn", "bishop", "bishop"],                          # 8
	["pawn", "pawn", "bishop"],                            # 9
	["pawn", "pawn", "bishop"],                            # 10
	["bishop", "pawn", "pawn"],                            # 11
	["bishop", "bishop", "pawn"],                          # 12
	["bishop", "pawn", "pawn"],                            # 13
	["bishop", "bishop", "pawn"],                          # 14
	["bishop", "bishop", "pawn"],                          # 15
	["bishop", "bishop", "knight"],                        # 16
	["bishop", "knight", "knight"],                        # 17
	["knight", "knight", "bishop"],                        # 18
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
	# waves 31-39 stiffened 2026-07-06: the stretch offered no resistance once
	# the early game was survived — pawns swapped for rooks/knights
	["rook", "rook", "knight", "bishop"],                  # 31
	["rook", "bishop", "knight", "rook"],                  # 32
	["knight", "knight", "rook", "rook"],                  # 33
	["bishop", "knight", "rook", "rook"],                  # 34
	["bishop", "bishop", "knight", "knight"],              # 35
	["knight", "bishop", "rook", "rook"],                  # 36
	["knight", "knight", "rook", "rook"],                  # 37
	["bishop", "knight", "rook", "rook"],                  # 38
	["rook", "knight", "rook", "rook"],                    # 39
	["bishop", "bishop", "knight", "rook", "pawn"],        # 40
	["bishop", "knight", "rook", "rook", "pawn"],          # 41
	["knight", "knight", "rook", "rook", "bishop"],        # 42
	["pawn", "bishop", "knight", "rook", "rook"],          # 43
	# pre-King ramp stiffened 2026-07-06 (+1 rook, King +1 escort): the bot
	# cruised from 25 straight to the win — the finale needed teeth
	["bishop", "bishop", "knight", "rook", "rook", "rook"],   # 44
	["bishop", "knight", "knight", "rook", "rook", "rook"],   # 45
	["bishop", "bishop", "knight", "rook", "rook", "rook"],   # 46
	["knight", "rook", "rook", "bishop", "bishop", "rook"],   # 47
	["bishop", "knight", "knight", "rook", "rook", "rook"],   # 48
	["knight", "knight", "rook", "rook", "bishop", "rook"],   # 49
	["king", "rook", "rook", "bishop", "knight"],             # 50 — King wave
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
	# ---- GENERATED by tools/generate-endless-waves.mjs — do not edit by hand ----
	["kirin", "berolina", "gnu", "bodyguard", "rook", "kirin-plus"],                                             # 151
	["kirin", "berolina", "squirrel", "kirin-plus", "kirin-plus", "rook"],                                       # 152
	["kirin", "alibaba", "gnu", "gnu", "squirrel", "rook"],                                                      # 153
	["kirin", "kirin", "squirrel", "rook", "gnu", "rook"],                                                       # 154
	["alibaba", "wazir", "gnu", "squirrel", "bodyguard", "squirrel", "kirin"],                                   # 155
	["kirin", "alibaba", "squirrel", "bodyguard", "rook", "bodyguard", "knight"],                                # 156
	["kirin", "kirin", "kirin-plus", "gnu", "gnu", "kirin-plus", "knight"],                                      # 157
	["banshee", "alibaba", "squirrel", "rook", "bodyguard", "gnu"],                                              # 158
	["raven", "wazir", "kirin-plus", "squirrel", "rook", "gnu"],                                                 # 159
	["raven", "kirin", "rook", "bodyguard", "kirin-plus", "rook"],                                               # 160
	["banshee", "wazir", "kirin-plus", "kirin-plus", "squirrel", "squirrel", "knight"],                          # 161
	["manticore", "kirin", "berolina", "gnu", "gnu", "bodyguard", "bodyguard", "kirin"],                         # 162
	["banshee", "alibaba", "berolina", "rook", "bodyguard", "kirin-plus", "kirin-plus", "knight"],               # 163
	["raven", "alibaba", "berolina", "squirrel", "squirrel", "rook", "dragon-horse", "knight"],                  # 164
	["manticore", "berolina", "bodyguard", "bodyguard", "rook", "dragon-horse", "raven"],                        # 165
	["manticore", "alibaba", "rook", "kirin-plus", "bodyguard", "rook", "raven"],                                # 166
	["squirrel", "berolina", "bodyguard", "rook", "rook", "squirrel", "knight", "queen"],                        # 167
	["manticore", "alibaba", "gnu", "squirrel", "kirin-plus", "bodyguard", "knight", "banshee"],                 # 168
	["kirin", "alibaba", "bodyguard", "bodyguard", "squirrel", "gnu", "kirin", "amazon"],                        # 169
	["squirrel", "alibaba", "gnu", "kirin-plus", "gnu", "rook", "kirin", "godzilla"],                            # 170
	["manticore", "alibaba", "bodyguard", "gnu", "kirin-plus", "rook", "gnu", "raven"],                          # 171
	["banshee", "alibaba", "gnu", "rook", "squirrel", "knight", "amazonrider"],                                  # 172
	["kirin", "knight", "squirrel", "squirrel", "rook", "kirin", "amazon", "dragon-king"],                       # 173
	["wazir", "wazir", "gnu", "bodyguard", "bodyguard", "kirin-plus", "raven", "godzilla"],                      # 174
	["squirrel", "wazir", "squirrel", "kirin-plus", "rook", "kirin-plus", "queen", "raven"],                     # 175
	["kirin", "kirin", "kirin-plus", "gnu", "kirin-plus", "rook", "amazonrider", "manticore"],                   # 176
	["manticore", "alibaba", "squirrel", "squirrel", "bodyguard", "dragon-horse", "godzilla", "crown-princess"], # 177
	["raven", "alibaba", "kirin-plus", "bodyguard", "rook", "rook", "raven", "banshee"],                         # 178
	["raven", "kirin-plus", "squirrel", "kirin-plus", "godzilla", "amazonrider"],                                # 179
	["raven", "gnu", "kirin-plus", "gnu", "amazonrider", "amazon"],                                              # 180
	["banshee", "rook", "rook", "dragon-horse", "raven", "godzilla", "banshee"],                                 # 181
	["manticore", "manticore", "kirin-plus", "squirrel", "kirin", "raven", "queen", "banshee"],                  # 182
	["kirin", "squirrel", "rook", "bodyguard", "knight", "queen", "amazonrider", "banshee"],                     # 183
	["kirin", "bodyguard", "bodyguard", "gnu", "knight", "amazonrider", "godzilla", "buffalo"],                  # 184
	["squirrel", "kirin-plus", "rook", "gnu", "kirin", "amazonrider", "raven", "banshee"],                       # 185
	["kirin", "manticore", "kirin", "amazonrider", "queen", "amazon", "crown-princess"],                         # 186
	["squirrel", "gnu", "knight", "amazon", "godzilla", "godzilla", "raven"],                                    # 187
	["manticore", "rook", "kirin", "godzilla", "amazonrider", "raven", "queen"],                                 # 188
	["squirrel", "rook", "knight", "raven", "raven", "banshee", "banshee", "godzilla"],                          # 189
	["kirin", "manticore", "kirin", "queen", "amazon", "amazonrider", "amazon"],                                 # 190
	["banshee", "berolina", "gnu", "kirin", "queen", "amazonrider", "amazon", "banshee"],                        # 191
	["manticore", "alibaba", "squirrel", "kirin", "raven", "amazon", "raven", "amazonrider"],                    # 192
	["amazon", "godzilla", "raven", "godzilla", "amazon", "manticore"],                                          # 193
	["godzilla", "godzilla", "amazonrider", "raven", "banshee", "queen"],                                        # 194
	["raven", "queen", "raven", "queen", "godzilla", "banshee", "crown-princess"],                               # 195
	["amazon", "amazonrider", "amazonrider", "godzilla", "amazon"],                                              # 196
	["amazon", "amazonrider", "godzilla", "godzilla", "queen", "banshee"],                                       # 197
	["amazonrider", "amazon", "amazonrider", "queen", "godzilla", "manticore"],                                  # 198
	["amazonrider", "godzilla", "godzilla", "banshee", "amazonrider", "raven"],                                  # 199
	["king", "godzilla", "raven", "queen", "amazonrider", "raven"],                                              # 200 — King wave (the 4th)
	["king", "amazon", "raven", "godzilla", "amazon", "godzilla"],                                               # 201 — LARRY, the 17th boss
	# ---- end generated ----
]
