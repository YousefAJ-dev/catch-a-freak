--!strict
-- Look of the lab plots (DESIGN.md section 6). Shared by tools/BuildMap.luau,
-- which builds the incubators, and FarmService, which restyles them as players
-- claim plots, place freaks and unlock capacity.

local FarmVisuals = {}

FarmVisuals.palette = {
	floor = Color3.fromRGB(222, 226, 230),
	aisle = Color3.fromRGB(150, 156, 162),
	metal = Color3.fromRGB(190, 195, 202),
	glass = Color3.fromRGB(200, 235, 255),
	light = Color3.fromRGB(120, 230, 255), -- empty unlocked incubator
	lockedFloor = Color3.fromRGB(55, 55, 60),
	lockedMetal = Color3.fromRGB(80, 80, 86),
	lockedGlass = Color3.fromRGB(70, 70, 76),
	signBoard = Color3.fromRGB(35, 40, 48),
	signText = Color3.fromRGB(210, 245, 255),
}

-- Unlocked incubators are clear and lit (in `lightColor`, the occupant's rarity
-- color, when one is given); locked ones are smoky grey and dark.
function FarmVisuals.styleIncubator(incubator: Model, unlocked: boolean, lightColor: Color3?)
	local p = FarmVisuals.palette
	incubator:SetAttribute("Unlocked", unlocked)
	for _, part in incubator:GetChildren() do
		if not part:IsA("BasePart") then
			continue
		end
		if part.Name == "Floor" then
			part.Color = if unlocked then p.metal else p.lockedFloor
			part.Material = if unlocked then Enum.Material.DiamondPlate else Enum.Material.Slate
		elseif part.Name == "Light" then
			part.Color = if unlocked then lightColor or p.light else p.lockedFloor
			part.Material = if unlocked then Enum.Material.Neon else Enum.Material.SmoothPlastic
		elseif part.Name == "Glass" or part.Name == "Lid" then
			part.Color = if unlocked then p.glass else p.lockedGlass
			part.Transparency = if unlocked then 0.75 else 0.45
		elseif part.Name == "Post" then
			part.Color = if unlocked then p.metal else p.lockedMetal
		end
	end
end

function FarmVisuals.unclaimedText(plotIndex: number): string
	return ("Plot %d — Unclaimed"):format(plotIndex)
end

return FarmVisuals
