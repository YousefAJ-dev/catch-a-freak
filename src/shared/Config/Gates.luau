--!strict
-- Progression gates from DESIGN.md section 8. Gate N is the one a player at
-- highest tier N works on; completing it unlocks tier N + 1. A requirement is
-- met by a freak of that species at that rarity or higher.

export type Requirement = { species: string, rarity: string }
export type Gate = { unlocksTier: number, requirements: { Requirement } }

local Gates: { Gate } = {
	{
		unlocksTier = 2,
		requirements = {
			{ species = "Twitcher", rarity = "Uncommon" },
			{ species = "Glowbug", rarity = "Rare" },
		},
	},
	{
		unlocksTier = 3,
		requirements = {
			{ species = "Rustback", rarity = "Rare" },
			{ species = "Nightmare", rarity = "Epic" },
		},
	},
	{
		unlocksTier = 4,
		requirements = {
			{ species = "Gloomhound", rarity = "Rare" },
			{ species = "Wobbler", rarity = "Epic" },
		},
	},
	{
		unlocksTier = 5,
		requirements = {
			{ species = "Gnashling", rarity = "Rare" },
			{ species = "Bloatworm", rarity = "Epic" },
		},
	},
}

return Gates
