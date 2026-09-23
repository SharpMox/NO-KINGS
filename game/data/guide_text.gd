## In-game rules reference. One copy so the Main Menu's Guide and the
## in-game menu's Guide (scripts/guide.gd, 05-menus-and-settings) can never
## drift out of sync with each other.
##
## NO-242: every sentence was checked against the code on 2026-09-23 (the PR
## lists the source line behind each). When a rule changes, change it here.

const TEXT := (
	"Objective\n" +
	"Checkmate the wave-50 King to win; Continue for Endless. You lose if " +
	"the Clock runs out, enemies fill your back row, or you run out of " +
	"pieces.\n\n" +

	"Board\n" +
	"8x12. Place your Starting Stock free on your two back rows, then " +
	"PASS. Later deploys cost 20 Gold, onto those rows or beside your " +
	"pieces.\n\n" +

	"Turns\n" +
	"2 Actions a turn (1 from Tier 4): move, capture, deploy, merge or " +
	"use an Item. Each piece moves once. PASS ends the turn.\n\n" +

	"Merging\n" +
	"Drag or tap a piece onto a highlighted twin to promote, or a partner " +
	"to fuse. 1 Action + 15 Gold.\n\n" +

	"Stock\n" +
	"Captures go to Captured Stock: long-press to Convert them into Stock " +
	"for Gold. Long-press anything in Stock or Inventory to Sell for half " +
	"price.\n\n" +

	"Shop & Boxes\n" +
	"The Shop opens empty; it first restocks on wave 5, then every 5 waves " +
	"and each 5,000 Score between. " +
	"Boxes offer 3, 5 or 7 choices: keep one (Huge: two) or skip for " +
	"Gold.\n\n" +

	"Army\n" +
	"Power: always on. Ability: 1 Action, once per wave. Waves 11, 21, " +
	"31 and on bring Reinforcements: two of each starting piece and 2 minutes.\n\n" +

	"Kings\n" +
	"Kings lead waves 50, 100, 150 and 200, usually after 15 turns of " +
	"buffed enemies. Each King's Power lasts its wave.\n\n" +

	"Clock\n" +
	"15 minutes (5 from Tier 3). Each turn adds 5 seconds; early clears, " +
	"Kings after wave 50 and Continue add more."
)
