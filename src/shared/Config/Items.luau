--!strict
-- Consumable items from DESIGN.md section 7.
-- Price = basePrice × 35 ^ (highestTier − 1) (see Formulas.itemPrice).
-- The Golden Bear Trap is sold for Robux only (Config/Products), so it has no
-- price and isn't in `order` (the items sold for money).

export type Item = {
	id: string, -- key in the saved `items` table
	name: string,
	basePrice: number?,
	key: Enum.KeyCode,
	description: string,
}

local Items = {
	maxHeld = 5, -- of each item

	order = { "netLauncher", "bearTrap" }, -- sold for money at the shop
	buttons = { "netLauncher", "bearTrap", "goldenTrap" }, -- on-screen item buttons
	-- Only the Golden Bear Trap catches these; nets and plain traps ignore them.
	shinyRarities = { Rainbow = true, Radioactive = true },

	netLauncher = {
		id = "netLauncher",
		name = "Net Launcher",
		basePrice = 350,
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
		basePrice = 450,
		key = Enum.KeyCode.R,
		description = "Pins the first freak to step on it for 30 s; a 0.5 s grab for you only. Not Rainbow or Radioactive",
		triggerRadius = 3, -- a freak this close to the trap's center steps on it
		pinDuration = 30,
		pinnedHold = 0.5, -- seconds to grab a freak pinned by your own trap
		lifetime = 120, -- an untriggered trap disappears after this long
	},

	-- Robux only. Lures Rainbow and Radioactive freaks in its zone toward it and
	-- pins the first to arrive; ignores every other rarity. It never rusts and
	-- only comes off the count when it pins a freak, so setting it again just
	-- moves it.
	goldenTrap = {
		id = "goldenTrap",
		name = "Golden Bear Trap",
		key = Enum.KeyCode.T,
		description = "Lures and pins ONLY Rainbow and Radioactive freaks",
		triggerRadius = 4,
		lureRadius = 150, -- shiny freaks in the trap's zone this close walk to it
		pinDuration = 60,
		pinnedHold = 0.5,
	},
}

return Items
