## In-game rules reference. One copy so the Main Menu's Guide and the
## in-game menu's Guide (scripts/guide.gd, 05-menus-and-settings) can never
## drift out of sync with each other.

const TEXT := (
	"Objective\n" +
	"Survive waves of enemy pieces and checkmate the recurring King before " +
	"your clock runs out. Reaching wave 50 opens a win screen — Continue " +
	"for endless play, or End Run to lock in your score.\n\n" +

	"Board & Setup\n" +
	"The board is 8x12. Your two back rows are your placement zone: drop " +
	"your starting army there before the first wave, then during the run.\n\n" +

	"Turns & Actions\n" +
	"Each of your turns gives you 2 actions. Moving, capturing, placing a " +
	"piece, merging/fusing, and using an item each cost 1 action — mix and " +
	"match. PASS ends your turn early and banks a clock bonus.\n\n" +

	"Merging\n" +
	"Two pieces of the same kind combine into their next promotion. Drag " +
	"one stack onto another (in Stock or Inventory) or onto a matching " +
	"piece on the board, then confirm.\n\n" +

	"Stock, Inventory & Shop\n" +
	"Captured enemies and unplaced pieces sit in Stock; items and " +
	"artefacts sit in Inventory. The Shop sells pieces, items, artefacts, " +
	"and boxes for gold, and restocks as your score climbs.\n\n" +

	"King Abilities\n" +
	"Every 10th wave applies a King Ability — an economic penalty (extra " +
	"gold cost on an action type, a barred piece, etc.) that lasts until " +
	"the run ends.\n\n" +

	"Kings\n" +
	"A King boss appears periodically. Checkmating one refills your clock " +
	"and scores a bonus — the wave-50 King is the run's win condition.\n\n" +

	"Clock\n" +
	"The run plays against a countdown clock. Finishing a turn, clearing " +
	"the board early, and checkmating Kings all add time back."
)
