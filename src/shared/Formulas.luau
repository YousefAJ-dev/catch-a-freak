--!strict
-- Every gameplay formula lives here so the client displays the same numbers
-- the server enforces.

local Config = script.Parent:WaitForChild("Config")
local World = require(Config:WaitForChild("World"))
local Tiers = require(Config:WaitForChild("Tiers"))
local Upgrades = require(Config:WaitForChild("Upgrades"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Economy = require(Config:WaitForChild("Economy"))
local Items = require(Config:WaitForChild("Items"))
local PlayerConfig = require(Config:WaitForChild("Player"))

local Formulas = {}

-- The zone a world position is in, decided purely by horizontal distance from
-- the map center. Anything past the last zone counts as the last zone.
function Formulas.zoneFromPosition(position: Vector3): World.Zone
	local offset = position - World.center
	local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
	for _, zone in World.zones do
		if distance < zone.outerRadius then
			return zone
		end
	end
	return World.zones[#World.zones]
end

-- Radiation damage per second in a tier's ring. Each Hazmat level adds to a
-- divisor, so early levels cut damage sharply and later ones taper off.
function Formulas.radiationDps(tier: number, hazmatLevel: number): number
	return Tiers[tier].radiationDps * Formulas.hazmatMultiplier(hazmatLevel)
end

-- Picks a rarity id from a uniform roll in [0, 1) using the spawn chances.
function Formulas.rollRarity(roll: number): string
	local cumulative = 0
	for _, rarity in Rarities.list do
		cumulative += rarity.chance
		if roll < cumulative then
			return rarity.id
		end
	end
	return Rarities.list[#Rarities.list].id
end

-- Seconds a player must hold the grab input on a freak.
function Formulas.holdTime(tier: number, rarityId: string, gripLevel: number): number
	local reduction = Upgrades.grip.effectPerLevel * gripLevel
	return Tiers[tier].baseHold * Rarities.byId[rarityId].holdMultiplier * math.max(0, 1 - reduction)
end

-- Where a freak is on its current waypoint at time `now` (server time), and
-- whether it is still walking. Server and clients share this so they agree.
function Formulas.freakPosition(from: Vector3, to: Vector3, startTime: number, speed: number, now: number): (Vector3, boolean)
	local distance = (to - from).Magnitude
	if distance < 1e-3 or speed <= 0 then
		return to, false
	end
	local alpha = (now - startTime) * speed / distance
	if alpha >= 1 then
		return to, false
	end
	return from:Lerp(to, math.max(alpha, 0)), true
end

-- Income multiplier from a freak's status effects (DESIGN.md section 14).
-- Effects don't exist yet, so this is 1 for every freak; the hook is here so
-- adding them later needs no data migration.
function Formulas.effectsMultiplier(effects: { any }?): number
	local multiplier = 1
	for _, effect in effects or {} do
		multiplier *= effect.multiplier or 1
	end
	return multiplier
end

function Formulas.incomePerSecond(tier: number, rarityId: string, effects: { any }?): number
	return Tiers[tier].baseIncome * Rarities.byId[rarityId].incomeMultiplier * Formulas.effectsMultiplier(effects)
end

function Formulas.sellPrice(tier: number, rarityId: string, effects: { any }?): number
	return Economy.sellIncomeSeconds * Formulas.incomePerSecond(tier, rarityId, effects)
end

-- How many incubators a player has unlocked at a Farm Capacity level.
function Formulas.farmCapacity(level: number): number
	local total = World.farm.padRows * World.farm.padColumns
	return math.min(total, World.farm.startingUnlockedPads + level * Upgrades.farmCapacity.effectPerLevel)
end

function Formulas.walkSpeed(shoesLevel: number): number
	return PlayerConfig.baseWalkSpeed + Upgrades.shoes.effectPerLevel * shoesLevel
end

-- Multiplier on radiation damage from the Hazmat Suit (1 at level 0).
function Formulas.hazmatMultiplier(hazmatLevel: number): number
	return 1 / (1 + Upgrades.hazmat.effectPerLevel * hazmatLevel)
end

-- Hours of farm income that can pile up while the player is offline.
function Formulas.offlineHours(offlineLevel: number): number
	return 1 + Upgrades.offlineCapacity.effectPerLevel * offlineLevel
end

-- Price of one item, scaled by the player's highest unlocked tier.
function Formulas.itemPrice(itemId: string, highestTier: number): number
	return (Items :: any)[itemId].basePrice * 10 ^ (highestTier - 1)
end

-- Cost of buying the next level of an upgrade, rounded to the nearest dollar.
function Formulas.upgradeCost(upgradeId: string, currentLevel: number): number
	local upgrade = Upgrades[upgradeId]
	return math.round(upgrade.baseCost * upgrade.growth ^ currentLevel)
end

return Formulas
