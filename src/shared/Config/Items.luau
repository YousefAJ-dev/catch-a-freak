--!strict
-- Consumable items from DESIGN.md section 7.
-- Price = basePrice × 10 ^ (highestTier − 1) (see Formulas.itemPrice).

export type Item = {
	id: string, -- key in the saved `items` table
	name: string,
	basePrice: number,
	key: Enum.KeyCode,
	description: string,
}

local Items = {
	maxHeld = 5, -- of each item

	order = { "netLauncher", "bearTrap" },

	netLauncher = {
		id = "netLauncher",
		name = "Net Launcher",
		basePrice = 100,
		key = Enum.KeyCode.Q,
		description = "Catches up to 3 Common, Uncommon or Rare freaks where it lands",
		range = 40, -- studs from the player to the impact point
		radius = 15, -- freaks within this distance of the impact are caught
		maxCatch = 3,
		rarities = { Common = true, Uncommon = true, Rare = true },
	},

	bearTrap = {
		id = "bearTrap",
		name = "Bear Trap",
		basePrice = 50,
		key = Enum.KeyCode.R,
		description = "Pins the first freak to step on it for 30 s; a 0.5 s grab for you only",
		triggerRadius = 3, -- a freak this close to the trap's center steps on it
		pinDuration = 30,
		pinnedHold = 0.5, -- seconds to grab a freak pinned by your own trap
		lifetime = 120, -- an untriggered trap disappears after this long
	},
}

return Items
