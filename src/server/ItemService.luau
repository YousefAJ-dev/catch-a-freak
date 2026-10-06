--!strict
-- Net Launcher and Bear Trap (DESIGN.md section 7, "Items").
--
-- Net Launcher: the client sends the point it aimed at; the server clamps it to
-- the launcher's range and catches up to 3 eligible freaks (Common, Uncommon,
-- Rare; not pinned by someone else's trap; in the player's zone) within the
-- net radius, limited by free carry slots. One net is used even on a miss.
--
-- Bear Trap: set where the player stands. The first freak to step on it is
-- pinned (FreakService.pin) and the trap is used up; an untriggered trap
-- disappears after its lifetime. One active trap per player.

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
	expiresAt: number,
}

local ItemService = {}

local traps: { [Player]: Trap } = {}
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
		notify(player, "Epic and Legendary freaks tear through nets")
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
	p.Color = Color3.fromRGB(70, 70, 75)
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

-- A greybox bear trap: a metal ring with teeth. `closed` draws the teeth bent
-- inward, for the visual left on a pinned freak.
local function buildTrapModel(position: Vector3, closed: boolean): Model
	local model = Instance.new("Model")
	local radius = Items.bearTrap.triggerRadius
	trapPart({
		Name = "Base",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, radius * 2, radius * 2),
		CFrame = CFrame.new(position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(45, 45, 50),
		Parent = model,
	})
	local teeth = 10
	for i = 1, teeth do
		local angle = (i / teeth) * math.pi * 2
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (radius - 0.3)
		local tilt = if closed then math.rad(-35) else 0
		trapPart({
			Name = "Tooth",
			Size = Vector3.new(0.3, 1.2, 0.5),
			CFrame = CFrame.lookAt(position + out + Vector3.new(0, 0.6, 0), position + Vector3.new(0, 0.6, 0)) * CFrame.Angles(tilt, 0, 0),
			Color = Color3.fromRGB(150, 150, 158),
			Parent = model,
		})
	end
	model.Parent = folder
	return model
end

local function removeTrap(player: Player)
	local trap = traps[player]
	if trap then
		trap.model:Destroy()
		traps[player] = nil
	end
end

local function onPlaceBearTrap(player: Player)
	local root = aliveRoot(player)
	if not root then
		return
	end
	if traps[player] then
		notify(player, "You already have a trap out")
		return
	end
	if not consume(player, Items.bearTrap.id) then
		return
	end
	local position = Vector3.new(root.Position.X, World.groundY, root.Position.Z)
	local model = buildTrapModel(position, false)
	model.Name = "BearTrap_" .. player.Name
	model:SetAttribute("Owner", player.UserId)
	traps[player] = {
		owner = player,
		model = model,
		position = position,
		expiresAt = os.clock() + Items.bearTrap.lifetime,
	}
	notify(player, "Trap set — the first freak to step on it is pinned for you")
end

local function checkTraps()
	local trap = Items.bearTrap
	for player, t in traps do
		if os.clock() >= t.expiresAt then
			removeTrap(player)
			notify(player, "Your bear trap rusted away without catching anything")
			continue
		end
		for _, freak in FreakService.query(t.position, trap.triggerRadius) do
			if not freak.pinnedBy and FreakService.pin(freak.id, player, trap.pinDuration) then
				removeTrap(player)
				local visual = buildTrapModel(Vector3.new(freak.position.X, World.groundY, freak.position.Z), true)
				visual.Name = "PinnedTrap_" .. freak.id
				pinVisuals[freak.id] = { model = visual, untilTime = os.clock() + trap.pinDuration }
				notify(player, ("Your trap pinned %s %s %s — grab it fast!"):format(Format.article(freak.rarity), freak.rarity, freak.species))
				break
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
	Remotes.PlaceBearTrap.OnServerEvent:Connect(onPlaceBearTrap)
	Players.PlayerRemoving:Connect(removeTrap)

	task.spawn(function()
		while true do
			task.wait(TRAP_CHECK_INTERVAL)
			checkTraps()
		end
	end)
end

return ItemService
