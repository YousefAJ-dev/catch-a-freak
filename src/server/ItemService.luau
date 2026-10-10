--!strict
-- Net Launcher, Bear Trap and Golden Bear Trap (DESIGN.md section 7, "Items").
--
-- Net Launcher: the client sends the point it aimed at; the server clamps it to
-- the launcher's range and catches up to 3 eligible freaks (Common, Uncommon,
-- Rare; not pinned by someone else's trap; in the player's zone) within the
-- net radius, limited by free carry slots. One net is used even on a miss.
--
-- Bear Trap: set where the player stands. The first freak to step on it is
-- pinned (FreakService.pin) and the trap is used up; an untriggered trap
-- disappears after its lifetime. One active trap per player: setting another
-- picks the old one up (it's used up) and sets the new one. Rainbow and
-- Radioactive freaks walk right over it.
--
-- Golden Bear Trap (Robux): the opposite. Only Rainbow and Radioactive freaks
-- trigger it, and those in its zone within its lure radius walk to it. It has
-- its own slot next to the plain trap and never rusts. It only comes off the
-- player's count when it pins a freak, so setting it again just moves it and
-- leaving with it set loses nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Items = require(Shared.Config.Items)
local World = require(Shared.Config.World)
local DataService = require(script.Parent.DataService)
local CarryService = require(script.Parent.CarryService)
local FreakService = require(script.Parent.FreakService)

local TRAP_CHECK_INTERVAL = 0.1

type Trap = {
	owner: Player,
	model: Model,
	position: Vector3,
	expiresAt: number, -- math.huge for the golden trap
}

type TrapKind = "bearTrap" | "goldenTrap"

local ItemService = {}

local traps: { [TrapKind]: { [Player]: Trap } } = { bearTrap = {}, goldenTrap = {} }
-- Closed-trap visuals sitting on pinned freaks, removed when the pin ends.
local pinVisuals: { [string]: { model: Model, untilTime: number } } = {}
local folder: Folder

local function notify(player: Player, message: string)
	Remotes.Notify:FireClient(player, message)
end

local function aliveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Uses one of an item. Returns false (and tells the player) if they have none.
local function consume(player: Player, itemId: string): boolean
	local data = DataService.get(player)
	if not data or (data.items[itemId] or 0) <= 0 then
		notify(player, ("You have no %ss — buy them at the shop"):format((Items :: any)[itemId].name))
		return false
	end
	DataService.setItemCount(player, itemId, data.items[itemId] - 1)
	return true
end

local function onUseNetLauncher(player: Player, target: any)
	local root = aliveRoot(player)
	if not root or typeof(target) ~= "Vector3" then
		return
	end
	local net = Items.netLauncher
	if not consume(player, net.id) then
		return
	end

	-- Clamp the aim point to the launcher's range and put it on the ground.
	local from = Vector3.new(root.Position.X, 0, root.Position.Z)
	local aim = Vector3.new(target.X, 0, target.Z) - from
	if aim.Magnitude > net.range then
		aim = aim.Unit * net.range
	end
	local impact = from + aim + Vector3.new(0, World.groundY, 0)

	local zone = Formulas.zoneFromPosition(root.Position).name
	local caught = 0
	local tooRare = false
	for _, freak in FreakService.query(impact, net.radius) do
		if caught >= net.maxCatch or not CarryService.hasFreeSlot(player) then
			break
		end
		tooRare = tooRare or not net.rarities[freak.rarity]
		local eligible = net.rarities[freak.rarity]
			and (freak.pinnedBy == nil or freak.pinnedBy == player)
			and Formulas.zoneFromPosition(freak.position).name == zone
		if eligible and FreakService.capture(player, freak.id) then
			caught += 1
		end
	end

	Remotes.NetImpact:FireAllClients(impact, caught)
	if caught > 0 then
		notify(player, ("Net caught %d freak%s"):format(caught, if caught == 1 then "" else "s"))
	elseif not CarryService.hasFreeSlot(player) then
		notify(player, "Carry full — the net came back empty")
	elseif tooRare then
		notify(player, "Epic and rarer freaks tear through nets")
	else
		notify(player, "The net missed")
	end
end

local function trapPart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Material = Enum.Material.Metal
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

-- A greybox bear trap: a metal ring with teeth (gold, glowing and sparkling
-- for the golden trap). `closed` draws the teeth bent inward, for the visual
-- left on a pinned freak.
local function buildTrapModel(kind: TrapKind, position: Vector3, closed: boolean): Model
	local model = Instance.new("Model")
	local golden = kind == "goldenTrap"
	local radius = (Items :: any)[kind].triggerRadius
	local metal = if golden then Enum.Material.Foil else Enum.Material.Metal
	local base = trapPart({
		Name = "Base",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, radius * 2, radius * 2),
		CFrame = CFrame.new(position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = if golden then Color3.fromRGB(190, 140, 30) else Color3.fromRGB(45, 45, 50),
		Material = metal,
		Parent = model,
	})
	if golden then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 210, 90)
		light.Range = 14
		light.Brightness = 2
		light.Parent = base
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 225, 120))
		sparkles.LightEmission = 1
		sparkles.Size = NumberSequence.new(0.5, 0)
		sparkles.Lifetime = NumberRange.new(0.8, 1.4)
		sparkles.Rate = if closed then 4 else 10
		sparkles.Speed = NumberRange.new(1.5, 3)
		sparkles.SpreadAngle = Vector2.new(30, 30)
		sparkles.EmissionDirection = Enum.NormalId.Right -- the cylinder's axis points up
		sparkles.Parent = base
	end
	local teeth = 10
	for i = 1, teeth do
		local angle = (i / teeth) * math.pi * 2
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (radius - 0.3)
		local tilt = if closed then math.rad(-35) else 0
		trapPart({
			Name = "Tooth",
			Size = Vector3.new(0.3, 1.2, 0.5),
			CFrame = CFrame.lookAt(position + out + Vector3.new(0, 0.6, 0), position + Vector3.new(0, 0.6, 0)) * CFrame.Angles(tilt, 0, 0),
			Color = if golden then Color3.fromRGB(255, 205, 70) else Color3.fromRGB(150, 150, 158),
			Material = metal,
			Parent = model,
		})
	end
	model.Parent = folder
	return model
end

local function removeTrap(kind: TrapKind, player: Player)
	local trap = traps[kind][player]
	if trap then
		trap.model:Destroy()
		traps[kind][player] = nil
	end
end

local function placeTrap(player: Player, kind: TrapKind)
	local root = aliveRoot(player)
	if not root then
		return
	end
	local golden = kind == "goldenTrap"
	local replaced = traps[kind][player] ~= nil
	if golden then
		local data = DataService.get(player)
		if not data or data.items.goldenTrap <= 0 then
			notify(player, "You have no Golden Bear Traps — get them in the shop's Items tab")
			return
		end
	elseif not consume(player, kind) then
		return
	end
	removeTrap(kind, player)
	local position = Vector3.new(root.Position.X, World.groundY, root.Position.Z)
	local model = buildTrapModel(kind, position, false)
	model.Name = (if golden then "GoldenTrap_" else "BearTrap_") .. player.Name
	model:SetAttribute("Owner", player.UserId)
	traps[kind][player] = {
		owner = player,
		model = model,
		position = position,
		expiresAt = if golden then math.huge else os.clock() + Items.bearTrap.lifetime,
	}
	if golden then
		notify(player, if replaced
			then "Golden trap moved here"
			else "Golden trap set — Rainbow and Radioactive freaks nearby will come to it")
	else
		notify(player, if replaced
			then "Trap moved here — your old one was removed"
			else "Trap set — the first freak to step on it is pinned for you")
	end
end

-- Pins a freak for the trap's owner, swaps the trap for a closed one on the
-- freak, and uses the trap up.
local function spring(kind: TrapKind, player: Player, freak: FreakService.FreakInfo): boolean
	local config = (Items :: any)[kind]
	if not FreakService.pin(freak.id, player, config.pinDuration) then
		return false
	end
	removeTrap(kind, player)
	if kind == "goldenTrap" then
		local data = DataService.get(player)
		if data then
			DataService.setItemCount(player, kind, data.items.goldenTrap - 1)
		end
	end
	local visual = buildTrapModel(kind, Vector3.new(freak.position.X, World.groundY, freak.position.Z), true)
	visual.Name = "PinnedTrap_" .. freak.id
	pinVisuals[freak.id] = { model = visual, untilTime = os.clock() + config.pinDuration }
	notify(
		player,
		("Your %s pinned %s %s %s — grab it fast!"):format(
			if kind == "goldenTrap" then "golden trap" else "trap",
			Format.article(freak.rarity),
			freak.rarity,
			freak.species
		)
	)
	return true
end

local function checkTraps()
	local plain = Items.bearTrap
	for player, t in traps.bearTrap do
		if os.clock() >= t.expiresAt then
			removeTrap("bearTrap", player)
			notify(player, "Your bear trap rusted away without catching anything")
			continue
		end
		for _, freak in FreakService.query(t.position, plain.triggerRadius) do
			if not freak.pinnedBy and not Items.shinyRarities[freak.rarity] and spring("bearTrap", player, freak) then
				break
			end
		end
	end

	local golden = Items.goldenTrap
	for player, t in traps.goldenTrap do
		local zone = Formulas.zoneFromPosition(t.position).name
		for _, freak in FreakService.query(t.position, golden.lureRadius) do
			if freak.pinnedBy or not Items.shinyRarities[freak.rarity] or Formulas.zoneFromPosition(freak.position).name ~= zone then
				continue
			end
			local offset = freak.position - t.position
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= golden.triggerRadius then
				if spring("goldenTrap", player, freak) then
					break
				end
			else
				FreakService.lure(freak.id, t.position)
			end
		end
	end

	-- Clear pin visuals once the pin ends or the freak is gone (caught or expired).
	for id, visual in pinVisuals do
		if os.clock() >= visual.untilTime or not FreakService.exists(id) then
			visual.model:Destroy()
			pinVisuals[id] = nil
		end
	end
end

function ItemService.start()
	folder = Instance.new("Folder")
	folder.Name = "Traps"
	folder.Parent = workspace

	Remotes.UseNetLauncher.OnServerEvent:Connect(onUseNetLauncher)
	Remotes.PlaceBearTrap.OnServerEvent:Connect(function(player, kind: any)
		placeTrap(player, if kind == "goldenTrap" then "goldenTrap" else "bearTrap")
	end)
	Players.PlayerRemoving:Connect(function(player)
		removeTrap("bearTrap", player)
		removeTrap("goldenTrap", player)
	end)

	task.spawn(function()
		while true do
			task.wait(TRAP_CHECK_INTERVAL)
			checkTraps()
		end
	end)
end

return ItemService
