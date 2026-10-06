--!strict
-- Every gameplay formula lives here so the client displays the same numbers
-- the server enforces.

local Config = script.Parent:WaitForChild("Config")
local World = require(Config:WaitForChild("World"))
local Tiers = require(Config:WaitForChild("Tiers"))
local Upgrades = require(Config:WaitForChild("Upgrades"))

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
	return Tiers[tier].radiationDps / (1 + Upgrades.hazmat.effectPerLevel * hazmatLevel)
end

-- Cost of buying the next level of an upgrade, rounded to the nearest dollar.
function Formulas.upgradeCost(upgradeId: string, currentLevel: number): number
	local upgrade = Upgrades[upgradeId]
	return math.round(upgrade.baseCost * upgrade.growth ^ currentLevel)
end

return Formulas
