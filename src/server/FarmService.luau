--!strict
-- Farm plots (DESIGN.md section 6): plot assignment, placing freaks in
-- incubators and picking them back up, income, and collecting. Players spawn
-- (and respawn) in front of their own plot, so they always know where it is.
--
-- The player's placed freaks live in their data record (`farm`, each with the
-- incubator `pad` it sits in) and are mirrored to the client as attributes:
--   "PlotIndex"   which plot they own
--   "Farm"        JSON array of placed freaks
--   "FarmIncome"  total income per second, with the Freakpedia bonus and 2x Money
--   "FarmCapacity" unlocked incubators
--   "Uncollected" money waiting on the collection pad
--   "OnOwnPlot"   standing on (or in front of) their plot; opens the farm panel

--
-- Incubator skins (DESIGN.md section 10): while the owner has an incubator
-- skin set equipped, their plot is built as that skin instead. A copy of its
-- template (ServerStorage.IncubatorSkins, rigged by Shared.Incubators.IncubatorRig)
-- is scaled to fill the plot and the default incubators and aisle are hidden.
-- Each incubator number maps to the skin cell in the same spot, freaks stand
-- on that cell's tile, and the tile shows locked / empty / the rarity color.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local FarmVisuals = require(Shared.FarmVisuals)
local World = require(Shared.Config.World)
local Rarities = require(Shared.Config.Rarities)
local Products = require(Shared.Config.Products)
local IncubatorData = require(Shared.Incubators.IncubatorData) :: any
local DataService = require(script.Parent.DataService)
local CarryService = require(script.Parent.CarryService)
local FreakpediaService = require(script.Parent.FreakpediaService)
local FreakModels = require(Shared.FreakModels)

local INCOME_TICK = 1
local CHECK_INTERVAL = 0.2
local LABEL_RANGE = 20 -- a placed freak's label only shows this close
local MAX_FREAK_WIDTH = 9 -- placed freaks are scaled down to fit their incubator
local MAX_FREAK_HEIGHT = 15
local SKIN_HEADROOM = 0.85 -- in a skin, freaks fill at most this much of a cell's height
local SKIN_SIGN_GAP = 2 -- studs between a skin's top and the raised owner sign
local LOCKED_TILE = Color3.fromRGB(40, 40, 46)
-- The handover's lights are tuned for a lone showcase model; at full strength
-- they bleach the freaks in the cells, so a plot's copy is dimmed and kept local.
local SKIN_LIGHT_BRIGHTNESS = 0.4 -- multiplier
local SKIN_LIGHT_RANGE = 16 -- studs
local SKIN_GROUND_MAX = 3 -- studs: skin ground cover the front pads are lifted onto
local SKIN_STEP_MAX = 0.6 -- studs: a taller step up into a skin gets a ramp
local SKIN_RAMP_SLOPE = 2.5 -- ramp length per stud of height
local SKIN_WALKWAY_WIDTH = 1.5 -- design units (IncubatorData), the skins' walkway

type Skin = {
	name: string,
	model: Model,
	slots: { [number]: Attachment }, -- incubator number -> the cell's slot
	tiles: { [number]: BasePart }, -- incubator number -> the cell's floor tile
	freakHeight: number,
}

type FarmFreak = {
	species: string,
	tier: number,
	rarity: string,
	effects: { any },
	pad: number,
}

type Plot = {
	index: number,
	model: Model,
	base: BasePart,
	owner: Player?,
	placed: { [number]: Model }, -- pad -> freak model
	skin: Skin?, -- the owner's incubator skin, when one is on the plot
}

local FarmService = {}

local plots: { Plot } = {}
local plotOf: { [Player]: Plot } = {}

local function notify(player: Player, message: string)
	Remotes.Notify:FireClient(player, message)
end

local function signGui(plot: Plot, sign: string): SurfaceGui
	return (plot.model:FindFirstChild(sign) :: Model):FindFirstChild("Board"):FindFirstChildOfClass("SurfaceGui") :: SurfaceGui
end

local function setOwnerText(plot: Plot, text: string)
	(signGui(plot, "OwnerSign"):FindFirstChild("OwnerName") :: TextLabel).Text = text
end

-- Owner sign for a claimed plot: the player's name and their farm's income.
local function setOwnerSign(plot: Plot, player: Player, income: number)
	setOwnerText(plot, ("%s's Lab\n+%s/s"):format(player.DisplayName, Format.money(income)))
end

local function setValueSign(plot: Plot, pool: number, rate: number)
	local gui = signGui(plot, "ValueSign");
	(gui:FindFirstChild("Amount") :: TextLabel).Text = Format.money(pool);
	(gui:FindFirstChild("Rate") :: TextLabel).Text = ("+%s/s"):format(Format.money(rate))
end

local function farmOf(player: Player): { FarmFreak }
	local data = DataService.get(player)
	return if data then data.farm :: { FarmFreak } else {}
end

local function recordAt(farm: { FarmFreak }, pad: number): (FarmFreak?, number?)
	for i, record in farm do
		if record.pad == pad then
			return record, i
		end
	end
	return nil, nil
end

local function capacityOf(player: Player?): number
	local data = player and DataService.get(player)
	return Formulas.farmCapacity(if data then data.upgrades.farmCapacity else 0)
end

-- The farm's income per second, with the Freakpedia bonus (not 2x Money).
local function incomeOf(data: DataService.Data): number
	local total = 0
	for _, record in data.farm :: { FarmFreak } do
		total += Formulas.incomePerSecond(record.tier, record.rarity, record.effects)
	end
	return total * Formulas.collectionMultiplier(data.freakpedia)
end

local function refreshIncubators(plot: Plot)
	local farm = if plot.owner then farmOf(plot.owner) else {}
	local capacity = capacityOf(plot.owner)
	local skin = plot.skin
	if skin then
		for pad, tile in skin.tiles do
			local record = recordAt(farm, pad)
			local unlocked = pad <= capacity
			tile.Color = if not unlocked
				then LOCKED_TILE
				elseif record then Rarities.byId[record.rarity].color
				else tile:GetAttribute("SkinColor") :: Color3
			tile.Material = if unlocked then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
		return
	end
	for _, incubator in (plot.model:FindFirstChild("Pads") :: Folder):GetChildren() do
		local pad = incubator:GetAttribute("PadIndex") :: number
		local record = recordAt(farm, pad)
		FarmVisuals.styleIncubator(incubator :: Model, pad <= capacity, if record then Rarities.byId[record.rarity].color else nil)
	end
end

local function updatePool(player: Player, plot: Plot)
	local data = DataService.get(player)
	if not data then
		return
	end
	-- What the farm actually earns right now, including 2x Money.
	local income = incomeOf(data) * Formulas.moneyMultiplier(DataService.passesOf(player))
	player:SetAttribute("Uncollected", data.uncollected)
	player:SetAttribute("FarmIncome", income)
	setValueSign(plot, data.uncollected, income)
	setOwnerSign(plot, player, income)
end

local function replicateFarm(player: Player, plot: Plot)
	player:SetAttribute("Farm", HttpService:JSONEncode(farmOf(player)))
	player:SetAttribute("FarmCapacity", capacityOf(player))
	updatePool(player, plot)
end

-- Puts a freak model in its incubator: scaled down to fit if needed, facing
-- the front, with a label that only shows up close.
local function showFreak(plot: Plot, record: FarmFreak)
	local rarity = Rarities.byId[record.rarity]
	local model, body = FreakModels.build(FreakModels.species(record.species))
	model.Name = "Placed" .. record.pad

	local skin = plot.skin
	local maxHeight = if skin then math.min(MAX_FREAK_HEIGHT, skin.freakHeight) else MAX_FREAK_HEIGHT
	local size = model:GetExtentsSize()
	local scale = math.min(1, MAX_FREAK_WIDTH / math.max(size.X, size.Z), maxHeight / size.Y)
	if scale < 1 then
		model:ScaleTo(scale)
	end
	FreakModels.decorate(body, record.rarity, scale)
	-- Facing the front of the plot, whose -Z faces the shop.
	if skin then
		model:PivotTo(CFrame.new(skin.slots[record.pad].WorldPosition) * plot.base.CFrame.Rotation)
	else
		local incubator = (plot.model:FindFirstChild("Pads") :: Folder):FindFirstChild("Pad" .. record.pad) :: Model
		local floor = incubator:FindFirstChild("Floor") :: BasePart
		model:PivotTo(floor.CFrame * CFrame.new(0, floor.Size.Y / 2, 0))
	end

	local label = Instance.new("BillboardGui")
	label.Name = "Label"
	label.Size = UDim2.fromOffset(170, 44)
	label.StudsOffset = Vector3.new(0, model:GetExtentsSize().Y / 2 + 1.5, 0)
	label.MaxDistance = LABEL_RANGE
	for i, line in
		{
			{ text = ("%s %s"):format(record.rarity, record.species), color = rarity.color },
			{ text = ("+%s/s"):format(Format.money(Formulas.incomePerSecond(record.tier, record.rarity, record.effects))), color = Color3.new(1, 1, 1) },
		}
	do
		local t = Instance.new("TextLabel")
		t.Position = UDim2.fromScale(0, (i - 1) * 0.5)
		t.Size = UDim2.fromScale(1, 0.5)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBold
		t.TextScaled = true
		t.TextColor3 = line.color
		t.TextStrokeTransparency = 0.3
		t.Text = line.text
		t.Parent = label
	end
	label.Parent = body

	model.Parent = plot.model
	plot.placed[record.pad] = model
end

local function hideFreak(plot: Plot, pad: number)
	local model = plot.placed[pad]
	if model then
		model:Destroy()
		plot.placed[pad] = nil
	end
end

-- Skins ----------------------------------------------------------------------

-- The incubator skin template for the owner's equipped skin set, if any.
local function skinTemplate(player: Player?): (string?, Model?)
	local key = player and player:GetAttribute("EquippedSkin")
	local folder = ServerStorage:FindFirstChild("IncubatorSkins")
	for _, set in Products.skinSets do
		if set.key == key and set.incubator and folder then
			local data = IncubatorData.Skins[set.incubator]
			local template = data and folder:FindFirstChild(data.ModelName)
			if template and template:IsA("Model") then
				return set.incubator, template
			end
		end
	end
	return nil, nil
end

-- Hides (or brings back) the plot's own incubators and aisle under a skin.
local function setDefaultLabVisible(plot: Plot, visible: boolean)
	local parts = { plot.model:FindFirstChild("Aisle") }
	for _, part in (plot.model:FindFirstChild("Pads") :: Folder):GetDescendants() do
		table.insert(parts, part)
	end
	for _, part in parts do
		if not (part and part:IsA("BasePart")) then
			continue
		end
		local hidden = part:GetAttribute("HiddenBySkin") ~= nil
		if visible and hidden then
			part.Transparency = part:GetAttribute("HiddenBySkin") :: number
			part.CanCollide = part:GetAttribute("CollideBeforeSkin") :: boolean
			part.CanQuery = true
			part:SetAttribute("HiddenBySkin", nil)
			part:SetAttribute("CollideBeforeSkin", nil)
		elseif not visible and not hidden then
			part:SetAttribute("HiddenBySkin", part.Transparency)
			part:SetAttribute("CollideBeforeSkin", part.CanCollide)
			part.Transparency = 1
			part.CanCollide = false
			part.CanQuery = false
		end
	end
end

-- Raises the owner sign clear of a skin's roof ornaments, or puts it back.
local function placeOwnerSign(plot: Plot, skinModel: Model?)
	local sign = plot.model:FindFirstChild("OwnerSign") :: Model
	local home = sign:GetAttribute("HomePivot") :: CFrame?
	if not home then
		home = sign:GetPivot()
		sign:SetAttribute("HomePivot", home)
	end
	local pivot = home :: CFrame
	if skinModel then
		local box, boxSize = skinModel:GetBoundingBox()
		local skinTop = box.Position.Y + boxSize.Y / 2
		local signBottom = pivot.Position.Y - sign:GetExtentsSize().Y / 2
		pivot += Vector3.new(0, math.max(0, skinTop + SKIN_SIGN_GAP - signBottom), 0)
	end
	sign:PivotTo(pivot)
end

-- Lifts the collection and 2x Money pads onto any solid ground a skin spreads
-- in front of the plot (Volcano's lava rocks), so they stay visible; or puts
-- them back.
local function placeFrontPads(plot: Plot, skinModel: Model?)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { skinModel }
	for _, name in { "CollectPad", "MoneyPad" } do
		local pad = plot.model:FindFirstChild(name)
		if not (pad and pad:IsA("BasePart")) then
			continue
		end
		local home = pad:GetAttribute("HomeCFrame") :: CFrame?
		if not home then
			home = pad.CFrame
			pad:SetAttribute("HomeCFrame", home)
		end
		local cframe = home :: CFrame
		if skinModel then
			local padTop = cframe.Position.Y + pad.Size.Y / 2
			local groundTop = padTop
			for _, part in workspace:GetPartBoundsInBox(cframe, pad.Size + Vector3.new(0, 20, 0), params) do
				-- Only low ground cover: a skin's columns are one mesh with one
				-- box around the whole building, whose edge can graze the pad.
				local top = part.Position.Y + part.Size.Y / 2
				if part.CanCollide and top - padTop <= SKIN_GROUND_MAX then
					groundTop = math.max(groundTop, top)
				end
			end
			cframe += Vector3.new(0, groundTop - padTop + (if groundTop > padTop then 0.05 else 0), 0)
		end
		pad.CFrame = cframe
	end
end

local function removeSkin(plot: Plot)
	if plot.skin then
		plot.skin.model:Destroy()
		plot.skin = nil
	end
	setDefaultLabVisible(plot, true)
	placeOwnerSign(plot, nil)
	placeFrontPads(plot, nil)
end

-- Some skins stand on a raised stone base whose front edge is a step too tall
-- to walk up (Sakura). An invisible ramp up to the walkway fixes that.
-- `ground` is the plot's top surface, entrance toward its -Z.
local function addEntranceRamp(model: Model, ground: CFrame, unit: number)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { model }
	params.RespectCanCollide = true
	local half = World.farm.plotSize / 2
	for z = -half - 4, -half + 6, 0.5 do
		local from = ground:PointToWorldSpace(Vector3.new(0, 10, z))
		local hit = workspace:Raycast(from, ground:VectorToWorldSpace(Vector3.new(0, -12, 0)), params)
		local height = if hit then ground:PointToObjectSpace(hit.Position).Y else 0
		if height > SKIN_STEP_MAX then
			local run = height * SKIN_RAMP_SLOPE
			local ramp = Instance.new("WedgePart") -- slopes up toward +Z, into the skin
			ramp.Name = "EntranceRamp"
			ramp.Size = Vector3.new(SKIN_WALKWAY_WIDTH * unit, height, run)
			ramp.CFrame = ground * CFrame.new(0, height / 2, z - run / 2)
			ramp.Anchored = true
			ramp.Transparency = 1
			ramp.CanTouch = false
			ramp.CanQuery = false
			ramp.CastShadow = false
			ramp.Parent = model
			return
		elseif height > 0 then
			return -- low enough to step onto
		end
	end
end

-- The skins' columns don't collide (their collision shapes swell into the
-- walkway), which leaves gaps between the glass panes. An invisible block over
-- each bank of cells keeps players out of the cells and the walkway open.
local function addCellBlockers(model: Model, ground: CFrame, unit: number)
	local slots = IncubatorData.Slots
	local inner, outer = math.huge, 0 -- |x| of the cells' walkway and outside edges
	local front, back = math.huge, -math.huge
	for _, slot in slots do
		inner = math.min(inner, math.abs(slot.X))
		outer = math.max(outer, math.abs(slot.X))
		front = math.min(front, slot.Z)
		back = math.max(back, slot.Z)
	end
	local cell = outer - inner -- slot spacing equals cell width
	inner -= cell / 2
	outer += cell / 2
	front -= cell / 2
	back += cell / 2
	local height = IncubatorData.RoofY - IncubatorData.FloorY
	for _, side in { -1, 1 } do
		local block = Instance.new("Part")
		block.Name = "CellBlocker"
		block.Size = Vector3.new(outer - inner, height, back - front) * unit
		block.CFrame = ground * CFrame.new(Vector3.new(side * (inner + outer) / 2, IncubatorData.FloorY + height / 2, (front + back) / 2) * unit)
		block.Anchored = true
		block.Transparency = 1
		block.CanTouch = false
		block.CanQuery = false
		block.CastShadow = false
		block.Parent = model
	end
end

-- Builds a copy of a skin template on the plot.
local function addSkin(plot: Plot, name: string, template: Model): Skin
	local model = template:Clone()
	model.Name = "Skin"
	local base: BasePart? = nil
	local tilesBySlot: { [number]: BasePart } = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			if part:GetAttribute("IncubatorGroup") == "Base_Platform" then
				base = part
			end
			local slot = part:GetAttribute("SlotIndex")
			if slot then
				tilesBySlot[slot :: number] = part
			end
		end
	end
	local platform = assert(base, ("skin %s has no Base_Platform"):format(name))
	-- Scale so the base fills the plot, then stand it on the plot facing the
	-- same way (the skin's entrance is its -Z, like the plot's front).
	local factor = World.farm.plotSize / math.max(platform.Size.X, platform.Size.Z)
	model:ScaleTo(model:GetScale() * factor)
	local unit = ((model:GetAttribute("ModelUnit") :: number?) or IncubatorData.Unit) * factor
	model:SetAttribute("ModelUnit", unit)
	model:PivotTo(plot.base.CFrame * CFrame.new(0, plot.base.Size.Y / 2, 0))
	for _, instance in model:GetDescendants() do
		if instance:IsA("BasePart") and instance.CanCollide and instance.Material == Enum.Material.Ice then
			-- looks like ice, walks like a floor (Ice's own friction is slippery)
			instance.CustomPhysicalProperties = PhysicalProperties.new(Enum.Material.SmoothPlastic)
		elseif instance:IsA("Light") then
			local brightness = ((instance:GetAttribute("BaseBrightness") :: number?) or instance.Brightness) * SKIN_LIGHT_BRIGHTNESS
			instance:SetAttribute("BaseBrightness", brightness) -- IncubatorVfxController animates around this
			instance.Brightness = brightness
			local ranged = instance :: any
			ranged.Range = math.min(ranged.Range, SKIN_LIGHT_RANGE)
		end
	end

	-- Each incubator number takes the skin cell nearest its own incubator.
	local slotFolder = model:FindFirstChild("Slots") :: BasePart
	local free: { Attachment } = {}
	for _, child in slotFolder:GetChildren() do
		if child:IsA("Attachment") then
			table.insert(free, child)
		end
	end
	local slots: { [number]: Attachment } = {}
	local tiles: { [number]: BasePart } = {}
	for _, incubator in (plot.model:FindFirstChild("Pads") :: Folder):GetChildren() do
		local pad = incubator:GetAttribute("PadIndex") :: number
		local floor = (incubator :: Model):FindFirstChild("Floor") :: BasePart
		local best, bestDistance = 1, math.huge
		for i, attachment in free do
			local offset = attachment.WorldPosition - floor.Position
			local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if distance < bestDistance then
				best, bestDistance = i, distance
			end
		end
		local attachment = table.remove(free, best) :: Attachment
		slots[pad] = attachment
		local tile = tilesBySlot[attachment:GetAttribute("SlotIndex") :: number]
		if tile then
			tile:SetAttribute("SkinColor", tile.Color)
			tiles[pad] = tile
		end
	end

	model.Parent = plot.model
	setDefaultLabVisible(plot, false)
	placeOwnerSign(plot, model)
	placeFrontPads(plot, model)
	local ground = plot.base.CFrame * CFrame.new(0, plot.base.Size.Y / 2, 0)
	addEntranceRamp(model, ground, unit)
	addCellBlockers(model, ground, unit)
	local cellHeight = (IncubatorData.RoofY - IncubatorData.FloorY) * unit
	return { name = name, model = model, slots = slots, tiles = tiles, freakHeight = cellHeight * SKIN_HEADROOM }
end

-- Puts the owner's equipped incubator skin on the plot (or the default lab
-- when none is equipped) and re-places their freaks to match.
local function applySkin(plot: Plot)
	local name, template = skinTemplate(plot.owner)
	for pad in plot.placed do
		hideFreak(plot, pad)
	end
	removeSkin(plot)
	if name and template then
		plot.skin = addSkin(plot, name, template)
	end
	if plot.owner then
		for _, record in farmOf(plot.owner) do
			showFreak(plot, record)
		end
	end
	refreshIncubators(plot)
end

-- Where `position` is relative to the plot (x across, z front (-) to back (+)).
local function plotLocal(plot: Plot, position: Vector3): Vector3
	return plot.base.CFrame:PointToObjectSpace(position)
end

-- On the plot, or on the ground just in front of it where the collection pad is.
local function isOnPlot(plot: Plot, position: Vector3): boolean
	local cfg = World.farm
	local half = cfg.plotSize / 2
	local l = plotLocal(plot, position)
	local front = half + cfg.collectPadGap + cfg.collectPadSize + 2
	return math.abs(l.X) <= half + 2 and l.Z >= -front and l.Z <= half + 2 and l.Y < 30
end

local function isOnCollectPad(plot: Plot, position: Vector3): boolean
	local pad = plot.model:FindFirstChild("CollectPad") :: BasePart
	local l = pad.CFrame:PointToObjectSpace(position)
	return math.abs(l.X) <= pad.Size.X / 2 + 1 and math.abs(l.Z) <= pad.Size.Z / 2 + 1 and l.Y < 8
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local FARM_FULL = "Farm full — upgrade Farm Capacity at the shop for more incubators"

-- Moves the freak in carry `slot` into the lowest-numbered empty unlocked
-- incubator. Returns "placed", "full" (no free incubator) or "empty" (no freak
-- in that slot). The caller has already checked the player is on their plot.
local function placeSlot(player: Player, plot: Plot, slot: number): ("placed" | "full" | "empty", FarmFreak?)
	local slots = CarryService.get(player)
	if not (slots and slots[slot]) then
		return "empty", nil
	end
	local farm = farmOf(player)
	local pad: number? = nil
	for candidate = 1, capacityOf(player) do
		if not recordAt(farm, candidate) then
			pad = candidate
			break
		end
	end
	if not pad then
		return "full", nil
	end
	local freak = CarryService.take(player, slot)
	if not freak then
		return "empty", nil
	end
	local record: FarmFreak = { species = freak.species, tier = freak.tier, rarity = freak.rarity, effects = freak.effects, pad = pad }
	table.insert(farm, record)
	showFreak(plot, record)
	FreakpediaService.discover(player, record)
	return "placed", record
end

-- The plot and root of a player standing on their own plot, or nil after
-- telling them why not.
local function ownPlotCheck(player: Player, action: string): Plot?
	local plot = plotOf[player]
	local root = rootOf(player)
	if not (plot and root and CarryService.get(player)) then
		return nil
	end
	if not isOnPlot(plot, root.Position) then
		notify(player, ("Stand on your lab to %s"):format(action))
		return nil
	end
	return plot
end

local function onPlaceFreak(player: Player, slot: any)
	local slots = CarryService.get(player)
	if not (slots and typeof(slot) == "number" and slot == math.floor(slot) and slot >= 1 and slot <= #slots) then
		return
	end
	local plot = ownPlotCheck(player, "place freaks")
	if not plot then
		return
	end
	local result, record = placeSlot(player, plot, slot)
	if result == "full" then
		notify(player, FARM_FULL)
	elseif result == "placed" and record then
		refreshIncubators(plot)
		replicateFarm(player, plot)
		notify(player, ("Placed %s %s in incubator %d"):format(record.rarity, record.species, record.pad))
	end
end

local function onPlaceAll(player: Player)
	local plot = ownPlotCheck(player, "place freaks")
	local slots = CarryService.get(player)
	if not (plot and slots) then
		return
	end
	local placed, left = 0, 0
	for slot in slots do
		local result = placeSlot(player, plot, slot)
		if result == "placed" then
			placed += 1
		elseif result == "full" then
			left += 1
		end
	end
	if placed > 0 then
		refreshIncubators(plot)
		replicateFarm(player, plot)
	end
	if placed == 0 and left == 0 then
		notify(player, "You're not carrying any freaks")
	elseif placed == 0 then
		notify(player, FARM_FULL)
	elseif left > 0 then
		notify(player, ("Placed %d — %s"):format(placed, FARM_FULL))
	else
		notify(player, ("Placed %d freak%s"):format(placed, if placed == 1 then "" else "s"))
	end
end

local function onPickUpFreak(player: Player, pad: any)
	local plot = plotOf[player]
	local root = rootOf(player)
	if not (plot and root) then
		return
	end
	if not (typeof(pad) == "number" and pad == math.floor(pad) and pad >= 1 and pad <= World.farm.padRows * World.farm.padColumns) then
		return
	end
	if not isOnPlot(plot, root.Position) then
		notify(player, "Stand on your lab to pick up freaks")
		return
	end
	local farm = farmOf(player)
	local record, index = recordAt(farm, pad)
	if not (record and index) then
		return
	end
	if not CarryService.hasFreeSlot(player) then
		notify(player, "Carry full — sell or place a freak first")
		return
	end
	table.remove(farm, index)
	CarryService.add(player, { species = record.species, tier = record.tier, rarity = record.rarity, effects = record.effects })
	hideFreak(plot, pad)
	refreshIncubators(plot)
	replicateFarm(player, plot)
end

-- The freak in one of the player's incubators, or nil (for gate turn-ins).
function FarmService.getFreak(player: Player, pad: number): FarmFreak?
	local record = recordAt(farmOf(player), pad)
	return record
end

-- Takes a freak out of an incubator for good (consumed by a gate turn-in).
-- Returns the removed record, or nil if the incubator was empty.
function FarmService.removeFreak(player: Player, pad: number): FarmFreak?
	local plot = plotOf[player]
	local farm = farmOf(player)
	local record, index = recordAt(farm, pad)
	if not (plot and record and index) then
		return nil
	end
	table.remove(farm, index)
	hideFreak(plot, pad)
	refreshIncubators(plot)
	replicateFarm(player, plot)
	return record
end

local function collect(player: Player, plot: Plot)
	local data = DataService.get(player)
	if not data or data.uncollected <= 0 then
		return
	end
	local amount = data.uncollected
	data.uncollected = 0
	DataService.addMoney(player, amount)
	updatePool(player, plot)
	Remotes.FloatText:FireClient(player, "+" .. Format.money(amount), Color3.fromRGB(120, 255, 140))
end

-- Adds what the farm earned while the player was away (capped by Offline
-- Capacity) to the uncollected pool and tells them. Returns the amount.
function FarmService.applyOfflineEarnings(player: Player, secondsAway: number): number
	local plot = plotOf[player]
	local data = DataService.get(player)
	if not (plot and data) then
		return 0
	end
	local income = incomeOf(data)
	local cap = Formulas.offlineCap(data.upgrades.offlineCapacity, data.highestTier)
	local earned = Formulas.offlineEarnings(income, secondsAway, data.upgrades.offlineCapacity, data.highestTier)
	if earned <= 0 then
		return 0
	end
	data.uncollected += earned
	updatePool(player, plot)
	local capped = earned >= cap
	Remotes.Popup:FireClient(
		player,
		"Welcome back!",
		("While you were away your lab earned %s.%s\nIt's waiting on your green collection pad."):format(
			Format.money(earned),
			if capped then ("\n(Capped at %s — upgrade Offline Capacity to store more.)"):format(Format.money(cap)) else ""
		)
	)
	return earned
end

-- Puts the character just in front of its owner's plot, past the collection
-- pad, facing the plot.
local function sendHome(player: Player)
	local plot = plotOf[player]
	local character = player.Character
	if not (plot and character) then
		return
	end
	local cfg = World.farm
	local front = plot.base.CFrame * CFrame.new(0, 0, -(cfg.plotSize / 2 + cfg.collectPadGap + cfg.collectPadSize + 4))
	local position = Vector3.new(front.X, plot.base.Position.Y + plot.base.Size.Y / 2 + 3, front.Z)
	character:PivotTo(CFrame.lookAt(position, Vector3.new(plot.base.Position.X, position.Y, plot.base.Position.Z)))
end

local function onCharacterAdded(player: Player, character: Model)
	character:WaitForChild("HumanoidRootPart")
	-- Let Roblox finish placing the character at the spawn point first.
	task.defer(function()
		if player.Character == character then
			sendHome(player)
		end
	end)
end

local function claimPlot(player: Player)
	-- Data loads asynchronously and CarryService creates its record on
	-- PlayerAdded too; wait for both.
	DataService.waitFor(player)
	while player.Parent and not CarryService.get(player) do
		task.wait()
	end
	if not (player.Parent and DataService.get(player)) then
		return
	end
	for _, plot in plots do
		if not plot.owner then
			plot.owner = player
			plotOf[player] = plot
			player:SetAttribute("PlotIndex", plot.index)
			applySkin(plot) -- builds the plot and places their freaks
			replicateFarm(player, plot)
			local lastSeen = DataService.previousLastSeen(player)
			if lastSeen > 0 then
				FarmService.applyOfflineEarnings(player, os.time() - lastSeen)
			end
			player:GetAttributeChangedSignal("Upgrade_farmCapacity"):Connect(function()
				if plotOf[player] == plot then
					refreshIncubators(plot)
					replicateFarm(player, plot)
				end
			end)
			player:GetAttributeChangedSignal("EquippedSkin"):Connect(function()
				if plotOf[player] == plot then
					applySkin(plot)
				end
			end)
			-- The first character usually spawns before the plot is claimed.
			sendHome(player)
			player.CharacterAdded:Connect(function(character)
				onCharacterAdded(player, character)
			end)
			return
		end
	end
	warn(("[FarmService] no free plot for %s"):format(player.Name))
end

local function releasePlot(player: Player)
	local plot = plotOf[player]
	if not plot then
		return
	end
	plotOf[player] = nil
	plot.owner = nil
	for pad in plot.placed do
		hideFreak(plot, pad)
	end
	removeSkin(plot)
	setOwnerText(plot, FarmVisuals.unclaimedText(plot.index))
	setValueSign(plot, 0, 0)
	refreshIncubators(plot)
end

function FarmService.start()
	local folder = workspace:WaitForChild("Map"):WaitForChild("Plots")
	for _, model in folder:GetChildren() do
		local index = model:GetAttribute("PlotIndex") :: number
		plots[index] = {
			index = index,
			model = model :: Model,
			base = model:FindFirstChild("Base") :: BasePart,
			owner = nil,
			placed = {},
		}
	end
	for _, plot in plots do
		setOwnerText(plot, FarmVisuals.unclaimedText(plot.index))
		setValueSign(plot, 0, 0)
		refreshIncubators(plot)
	end

	Remotes.PlaceFreak.OnServerEvent:Connect(onPlaceFreak)
	Remotes.PlaceAll.OnServerEvent:Connect(onPlaceAll)
	Remotes.PickUpFreak.OnServerEvent:Connect(onPickUpFreak)
	Players.PlayerAdded:Connect(claimPlot)
	Players.PlayerRemoving:Connect(releasePlot)
	for _, player in Players:GetPlayers() do
		task.spawn(claimPlot, player)
	end

	-- Income: every second each placed freak adds its income to the pool.
	task.spawn(function()
		while true do
			task.wait(INCOME_TICK)
			for player, plot in plotOf do
				local data = DataService.get(player)
				if data then
					data.uncollected += incomeOf(data) * Formulas.moneyMultiplier(DataService.passesOf(player)) * INCOME_TICK
					updatePool(player, plot)
				end
			end
		end
	end)

	-- Standing on the plot opens the farm panel; standing on the pad collects.
	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			for player, plot in plotOf do
				local root = rootOf(player)
				local onPlot = root ~= nil and isOnPlot(plot, root.Position)
				player:SetAttribute("OnOwnPlot", onPlot)
				if root and isOnCollectPad(plot, root.Position) then
					collect(player, plot)
				end
			end
		end
	end)
end

return FarmService
