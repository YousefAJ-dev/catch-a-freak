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
local Dash = require(Config:WaitForChild("Dash"))
local Wheel = require(Config:WaitForChild("Wheel"))
local Release = require(Config:WaitForChild("Release"))
local FreakConfig = require(Config:WaitForChild("Freaks"))
local Freakpedia = require(Config:WaitForChild("Freakpedia"))

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

-- A rarity's position in the roll order: Common = 1 ... Legendary = 5.
function Formulas.rarityRank(rarityId: string): number
	for i, rarity in Rarities.list do
		if rarity.id == rarityId then
			return i
		end
	end
	error("unknown rarity " .. tostring(rarityId))
end

-- The species a gate requirement accepts, as a list (it may name one or several).
function Formulas.requirementSpecies(requirement: { species: string | { string } }): { string }
	local species = requirement.species
	return if typeof(species) == "table" then species else { species :: string }
end

-- A requirement's species for display: "Glowbug", or "Bloatworm, Hexwing or Sludgelet".
function Formulas.requirementSpeciesText(requirement: { species: string | { string } }): string
	local names = Formulas.requirementSpecies(requirement)
	if #names == 1 then
		return names[1]
	end
	return table.concat(names, ", ", 1, #names - 1) .. " or " .. names[#names]
end

-- Whether a freak meets a gate requirement: an accepted species, required rarity or higher.
function Formulas.meetsRequirement(freak: { species: string, rarity: string }, requirement: { species: string | { string }, rarity: string }): boolean
	return table.find(Formulas.requirementSpecies(requirement), freak.species) ~= nil
		and Formulas.rarityRank(freak.rarity) >= Formulas.rarityRank(requirement.rarity)
end

-- Seconds a player must hold the grab input on a freak.
function Formulas.holdTime(tier: number, rarityId: string, gripLevel: number): number
	return Tiers[tier].baseHold * Rarities.byId[rarityId].holdMultiplier * Formulas.gripMultiplier(gripLevel)
end

-- Multiplier on grab hold time from Stronger Grip (1 at level 0).
function Formulas.gripMultiplier(gripLevel: number): number
	return Upgrades.grip.effectPerLevel ^ gripLevel
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

-- Multiplier on farm income and sell payouts: 2 for owners of the 2x Money
-- Game Pass (Config/Products.passes). Never applied to offline earnings.
function Formulas.moneyMultiplier(ownedPasses: { string }): number
	return if table.find(ownedPasses, "money2x") then 2 else 1
end

function Formulas.sellPrice(tier: number, rarityId: string, effects: { any }?): number
	return Economy.sellIncomeSeconds * Formulas.incomePerSecond(tier, rarityId, effects)
end

-- Freakpedia progress (Config/Freakpedia). `discovered` maps species name ->
-- list of rarity ids caught. Returns the pages (tiers) that are complete and
-- how many shiny entries there are.
function Formulas.freakpediaProgress(discovered: { [string]: { string } }): ({ number }, number)
	local pages = {}
	local shinies = 0
	for tier, list in FreakConfig.species do
		local complete = true
		for _, species in list do
			local caught = discovered[species.name] or {}
			for _, rarity in Freakpedia.pageRarities do
				if not table.find(caught, rarity) then
					complete = false
				end
			end
			for _, rarity in Freakpedia.shinyRarities do
				if table.find(caught, rarity) then
					shinies += 1
				end
			end
		end
		if complete then
			table.insert(pages, tier)
		end
	end
	return pages, shinies
end

-- Permanent farm income multiplier from the Freakpedia, e.g. 1.13 for +13%.
function Formulas.collectionMultiplier(discovered: { [string]: { string } }): number
	local pages, shinies = Formulas.freakpediaProgress(discovered)
	return 1 + #pages * Freakpedia.pageBonus + shinies * Freakpedia.shinyBonus
end

-- How many incubators a player has unlocked at a Farm Capacity level.
function Formulas.farmCapacity(level: number): number
	local total = World.farm.padRows * World.farm.padColumns
	return math.min(total, World.farm.startingUnlockedPads + level * Upgrades.farmCapacity.effectPerLevel)
end

function Formulas.walkSpeed(shoesLevel: number): number
	return math.min(PlayerConfig.baseWalkSpeed + Upgrades.shoes.effectPerLevel * shoesLevel, PlayerConfig.maxWalkSpeed)
end

-- Multiplier on radiation damage from the Hazmat Suit (1 at level 0). Each
-- level multiplies, so gear keeps pace with radiation that doubles per ring.
function Formulas.hazmatMultiplier(hazmatLevel: number): number
	return Upgrades.hazmat.effectPerLevel ^ hazmatLevel
end

-- The highest level of an upgrade a player can own right now. Gear unlocks
-- levelsPerTier levels per unlocked tier; other upgrades only have a max.
function Formulas.upgradeLevelCap(upgradeId: string, highestTier: number): number
	local upgrade = Upgrades[upgradeId]
	if upgrade.levelsPerTier then
		return math.min(upgrade.maxLevel, upgrade.levelsPerTier * highestTier)
	end
	return upgrade.maxLevel
end

-- What one wheel prize is for a player at `highestTier`: the tier and rarity
-- of the freak it gives.
function Formulas.wheelPrize(prizeIndex: number, highestTier: number): (number, string)
	local prize = Wheel.prizes[prizeIndex]
	local lastTier = math.min(#Tiers, Release.releasedTiers) -- never a freak from an unreleased ring
	if prize.tierOffset > 0 and highestTier >= lastTier then
		return math.min(highestTier, lastTier), prize.lastTierRarity or prize.rarity
	end
	return math.min(highestTier + prize.tierOffset, lastTier), prize.rarity
end

-- Picks a wheel prize index from a uniform roll in [0, 1).
function Formulas.rollWheel(roll: number): number
	local cumulative = 0
	for i, prize in Wheel.prizes do
		cumulative += prize.chance
		if roll < cumulative then
			return i
		end
	end
	return #Wheel.prizes
end

-- The UTC day number for a Unix time; free spins reset when it changes.
function Formulas.utcDay(unixTime: number): number
	return math.floor(unixTime / 86400)
end

-- Seconds between dashes at a Dash Recharge level.
function Formulas.dashCooldown(rechargeLevel: number): number
	return Dash.baseCooldown - Dash.cooldownPerLevel * rechargeLevel
end

-- The tier a player needs before they can buy `level` of an upgrade.
function Formulas.tierForUpgradeLevel(upgradeId: string, level: number): number
	local perTier = Upgrades[upgradeId].levelsPerTier
	return if perTier then math.ceil(level / perTier) else 1
end

-- Hours of farm income that can pile up while the player is offline.
function Formulas.offlineHours(offlineLevel: number): number
	return 1 + Upgrades.offlineCapacity.effectPerLevel * offlineLevel
end

-- Money earned while offline: the farm's income for the time away, capped at
-- the Offline Capacity limit. Never boosted by 2x Money (DESIGN.md section 6).
function Formulas.offlineEarnings(incomePerSecond: number, secondsAway: number, offlineLevel: number): number
	local cappedSeconds = math.min(math.max(secondsAway, 0), Formulas.offlineHours(offlineLevel) * 3600)
	return math.floor((incomePerSecond * cappedSeconds) / 2)
end

-- Price of one item, scaled by the player's highest unlocked tier.
function Formulas.itemPrice(itemId: string, highestTier: number): number
	return (Items :: any)[itemId].basePrice * 25 ^ (highestTier - 1)
end

-- Cost of buying the next level of an upgrade, rounded to the nearest dollar.
function Formulas.upgradeCost(upgradeId: string, currentLevel: number): number
	local upgrade = Upgrades[upgradeId]
	return math.round(upgrade.baseCost * upgrade.growth ^ currentLevel)
end

return Formulas
