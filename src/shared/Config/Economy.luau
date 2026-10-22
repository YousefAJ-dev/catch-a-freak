--!strict
-- Money numbers from DESIGN.md section 5 ("Value") and section 7 ("Selling",
-- "Upgrades").

return {
	-- sell price = this many seconds of the freak's income
	sellIncomeSeconds = 30,
	-- how close (studs) a player must be to a shop, sell or gate counter to use it
	counterRange = 16,

	-- Pacing (Formulas.ringPaceHours): hours buying a ring's full gear set
	-- should take. Ring 1 takes firstRingHours; Ring N after it takes N − 1.
	firstRingHours = 0.5,
	-- The upgrades a ring's gear budget is split between (Config/Upgrades).
	gearUpgrades = { "shoes", "hazmat", "grip" },
	-- A ring's gear budget = this × the tier's base income × the ring's
	-- average incubator count × its pace in seconds. Tuned so a farm of about
	-- 65% Rare, 25% Epic and 10% Legendary freaks (plus selling the rest), with
	-- no 2x Money, takes the pace time. Raise it to slow every ring down.
	gearBudgetRate = 7,
	-- Offline earnings stop at this share of the player's current ring's gear
	-- budget: the first with none of the ring's Offline Capacity levels, then
	-- one step per level bought in that ring (Formulas.offlineCap).
	offlineBudgetShares = { 1 / 4, 1 / 3, 1 / 2 },
}
