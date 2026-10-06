--!strict
-- Monetization from DESIGN.md section 10.
--
-- PLACEHOLDER IDS: negative numbers mean "not created in Creator Hub yet".
-- Create each Developer Product / Game Pass, then paste its real ID here.
-- Prices are set in Creator Hub, not in code. Until then, test in Studio with
-- the /buy debug command, which runs the real receipt handler.

export type DevProduct = { key: string, id: number, name: string, description: string }
export type SkinSet = { key: string, passId: number, name: string, description: string }

local developerProducts: { [string]: DevProduct } = {
	money2x = {
		key = "money2x",
		id = -1,
		name = "2x Money (1 hour)",
		description = "Doubles farm income and sell payouts for 60 minutes of play time",
	},
	extraSpin = {
		key = "extraSpin",
		id = -2,
		name = "Extra Wheel Spin",
		description = "One more spin of the daily wheel, usable right away",
	},
	revive = {
		key = "revive",
		id = -3,
		name = "Respawn with Caught Freaks",
		description = "Respawn at the shop still carrying everything you caught",
	},
}

-- Cosmetic only; the looks themselves arrive with the art in Milestone 10.
local skinSets: { SkinSet } = {
	{ key = "labCoat", passId = -101, name = "Lab Coat Set", description = "White coat, safety goggles, polished boots" },
	{ key = "toxic", passId = -102, name = "Toxic Set", description = "Glowing green suit and boots" },
	{ key = "gold", passId = -103, name = "Gold Set", description = "Gilded hazmat suit and shoes" },
}

return {
	developerProducts = developerProducts,
	skinSets = skinSets,
	boostSeconds = 3600, -- per 2x Money purchase; stacks
	reviveOfferSeconds = 10, -- how long the offer stays on screen after dying
	-- How long a dead player's freaks are held for a revive purchase. Longer
	-- than the offer so a purchase dialog opened in time can still finish.
	reviveHoldSeconds = 300,
	receiptCacheSize = 50, -- processed purchase IDs kept (DESIGN.md section 12)
}
