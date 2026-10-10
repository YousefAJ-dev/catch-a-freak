--!strict
-- Progression gates from DESIGN.md section 8. Gate N is the one a player at
-- highest tier N works on; completing it unlocks tier N + 1. A requirement is
-- met by turning in `count` freaks of that species at that rarity or higher.
--
-- Each ring should take about twice as long as the one before (15 min, 30,
-- 1 h, 2 h, 4 h). Gates grow by roughly doubling the freaks a player has to
-- find: one Rare of a species turns up about every 15 freaks met in its ring,
-- one Epic about every 50 (3 species per ring), so the gates below need about
-- 21, 42, 80 and 180 freaks met. Upgrade costs double each ring too (Config/
-- Upgrades). Tune both from playtest timings (/progress, DataService).

export type Requirement = { species: string, rarity: string, count: number }
export type Gate = { unlocksTier: number, requirements: { Requirement } }

local Gates: { Gate } = {
	{
		unlocksTier = 2,
		requirements = {
			{ species = "Twitcher", rarity = "Uncommon", count = 1 },
			{ species = "Glowbug", rarity = "Rare", count = 1 },
		},
	},
	{
		unlocksTier = 3,
		requirements = {
			{ species = "Rustback", rarity = "Rare", count = 2 },
			{ species = "Gloomhound", rarity = "Uncommon", count = 2 },
		},
	},
	{
		unlocksTier = 4,
		requirements = {
			{ species = "Sludgelet", rarity = "Rare", count = 2 },
			{ species = "Hexwing", rarity = "Epic", count = 1 },
		},
	},
	{
		unlocksTier = 5,
		requirements = {
			{ species = "Tri-Eye", rarity = "Rare", count = 2 },
			{ species = "Nightmare", rarity = "Epic", count = 3 },
		},
	},
}

return Gates
